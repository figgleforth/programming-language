module Code
	class Type_Checker
		attr_accessor :input

		def initialize input
			@input  = input
			@scopes = [new_scope_frame]

			# Per-declared-type member/method registry, keyed by qualified type name ("Web_Application", "Array\Web_Server" for a tagged type
			@type_info  = Hash.new { |h, k| h[k] = { members: {}, methods: {} } }
			@type_stack = [] # qualified type names currently being walked, innermost last

			# `Ident := SomeType` (a bare, uncalled type reference, no `()`) -- maps the alias's own
			# name to the real qualified type name it stands for, so `Ident()` resolves methods
			# through the same @type_info entry the real type registered under. See #check_inferred_declaration.
			@type_aliases = {}

			# Each type declared in this file -> the type names it composes with `|`, or :unknown when it also uses `&`/`~`/`^` (or composes a value). See #types_compatible?.
			@composed_types_by_name = {}
		end

		def output
			errors = input.filter_map { check _1 }.flatten.compact
			raise Type_Checking_Failed.new errors if errors.any?
		end

		NUMERIC_FAMILY = %w[Number Integer Float Decimal Rational].freeze

		# Stdlib type aliases (`Int := Integer`, `Str := String`, ...) -- this checker has no scope to
		# resolve them at runtime, so it normalizes the handful of concrete-type ones it reasons about.
		TYPE_ALIASES = {
			'Int' => 'Integer', 'Flo' => 'Float', 'Dec' => 'Decimal', 'Num' => 'Number', 'Str' => 'String',
		}.freeze

		BUILTIN_TYPES = (NUMERIC_FAMILY + %w[String Symbol Bool Nil]).freeze

		def types_compatible? declared, inferred, seen = []
			declared = @type_aliases.fetch declared, declared
			inferred = @type_aliases.fetch inferred, inferred
			declared = TYPE_ALIASES.fetch declared, declared
			inferred = TYPE_ALIASES.fetch inferred, inferred
			return true if declared == 'Any' || declared == inferred
			return declared == 'Number' || inferred == 'Number' if NUMERIC_FAMILY.include?(declared) && NUMERIC_FAMILY.include?(inferred)

			# A user type can only be ruled out when this file declares it, composed with `|` alone. A type from a loaded file, or one that uses `&`/`~`/`^`, is unknown, so it passes (skip rather than guess).
			known = ->(name) { BUILTIN_TYPES.include?(name) || @composed_types_by_name.key?(name) }
			return true unless known[declared] && known[inferred]
			return false if BUILTIN_TYPES.include? inferred

			operands = @composed_types_by_name[inferred]
			return true if operands == :unknown || seen.include?(inferred)
			operands.any? { |operand| types_compatible? declared, operand, seen + [inferred] } # `Deeper | Combined {}` is-a whatever Combined is
		end

		# Maps an expression to its Code type name. Returns nil if unknown.
		def infer_type expr
			case expr
			when Code::String_Expr then 'String'
			when Code::Number_Expr then expr.type == :float ? 'Float' : 'Integer'
			when Code::Symbol_Expr then 'Symbol'
			when Code::Identifier_Expr then type_by_identifier expr.value
			when Code::Infix_Expr then infer_dot_type expr
			else nil
			end
		end

		# Resolves `receiver`'s own static type, then looks up `member` as a declared member on that type. Returns nil the moment any link in the chain isn't statically known (an untyped local, a plain untagged bare type, etc), same "skip rather than guess" philosophy as the rest of this checker.
		def infer_dot_type expr
			return nil unless expr.operator&.value == '.'
			return nil unless expr.right.is_a? Code::Identifier_Expr

			receiver_type = infer_type expr.left
			return nil unless receiver_type

			@type_info[receiver_type][:members][expr.right.value]
		end

		# Looks up `name`'s declared type, searching from the current scope outward.
		def type_by_identifier name
			find_in_scopes :types, name
		end

		def func_signature_by_identifier name
			find_in_scopes :funcs, name
		end

		def register_func expr
			return unless expr.name
			return if expr.parameters.any?(&:variadic) # variadic arity / element typing isn't statically modeled

			param_types = expr.parameters.map do |p|
				next p.type if composed_annotation? p.type # `m: "a" | "b"` -- #check_call reads the whole chain
				# structural params aren't checked statically
				p.type&.value unless p.type.is_a?(Code::Struct_Expr) # todo;  add #check_struct
			end
			declare :funcs, expr.name.value, param_types
			@type_info[@type_stack.last][:methods][expr.name.value] = param_types if @type_stack.last
		end

		# `expr` is a Call_Expr's receiver: either a bare function name (`add(...)`) or a `.`-chain ending in a method name (`app.servers.push(...)`). Returns the param type array for whichever one it resolves to, or nil if neither does.
		def resolve_call_signature receiver
			if receiver.is_a? Code::Identifier_Expr
				func_signature_by_identifier receiver.value
			elsif receiver.is_a?(Code::Infix_Expr) && receiver.operator&.value == '.' && receiver.right.is_a?(Code::Identifier_Expr)
				receiver_type = infer_type receiver.left
				receiver_type && @type_info[receiver_type][:methods][receiver.right.value]
			end
		end

		def check_call expr
			signature = resolve_call_signature expr.receiver
			return nil unless signature.is_a? ::Array

			expr.arguments.each_with_index.filter_map do |arg, i|
				expected = signature[i]
				next nil unless expected
				next nil if composed_annotation?(expected) && annotation_accepts?(expected, arg)
				inferred = infer_type arg
				next nil if inferred.nil? && !composed_annotation?(expected)
				next nil if !composed_annotation?(expected) && types_compatible?(expected, inferred)
				Type_Mismatch.new arg, composed_annotation?(expected) ? annotation_display(expected) : expected, value_display(arg, expected)
			end
		end

		def check_infix expr
			case expr.operator&.value
			when '='
				check_typed_assignment expr
			when ':=', '::' # `Int32 :: Integer` is an alias. `Int32 := Integer` binds the same type, so it is one too.
				check_inferred_declaration expr
				nil
			end
		end

		# `x: Type = value` is the only case with an explicit declared type to actually compare a literal RHS against.
		def check_typed_assignment expr
			return nil unless expr.left.respond_to?(:type) && expr.left.type
			return nil if expr.left.type.is_a? Code::Struct_Expr # structural annotations aren't checked statically

			operands = annotation_operands expr.left.type # e.g. ["String"], ["Int", "Nil"] for `x: Int | Nil`, or literal expressions for `x: "a" | "b"`
			first    = operands.first
			declare_member expr.left.value, first.is_a?(::String) ? first : infer_type(first)
			return nil if annotation_accepts? expr.left.type, expr.right

			Type_Mismatch.new expr, annotation_display(expr.left.type), value_display(expr.right, expr.left.type)
		end

		# The operands an annotation names: a type name String (`x: Int` gives ["Int"], `x: Int | Nil` gives ["Int", "Nil"]), or a literal expression (`x: "a" | "b"`). A value that satisfies the annotation at run time satisfies at least one operand, whatever the operators are, so a value that matches none of them is always a mismatch. The operators themselves are checked only at run time (Code::Type_Alias).
		def annotation_operands type_expr
			return [] unless type_expr
			return [type_expr.value] unless composed_annotation? type_expr

			operands = [type_expr.leading_literal || type_expr.name]
			type_expr.expressions.each do |composition|
				next unless composition.is_a? Code::Composition_Expr

				operand = composition.identifier
				operands << if literal_type_expr? operand
					operand
				else
					operand.is_a?(Code::Type_Expr) ? operand.name : operand.value
				end
			end
			operands.compact
		end

		def composed_annotation? type_expr
			type_expr.is_a?(Code::Type_Expr) && type_expr.anonymous_composition
		end

		# @pasted from Interpreter#literal_type_expr?
		def literal_type_expr? expr
			return %w(true false nil).include?(expr.value) if expr.is_a? Code::Identifier_Expr

			expr.is_a?(Code::String_Expr) || expr.is_a?(Code::Number_Expr) || expr.is_a?(Code::Symbol_Expr)
		end

		# Can `value_expr` satisfy the annotation? A literal value must equal a literal operand, or have a type that a type operand allows. Any other value is checked by its type only, and a value of unknown type always passes.
		def annotation_accepts? type_expr, value_expr
			value_literal = literal_type_expr?(value_expr) ? literal_key(value_expr) : nil
			inferred      = infer_type value_expr
			return true if value_literal.nil? && inferred.nil?

			annotation_operands(type_expr).any? do |operand|
				if operand.is_a? ::String
					inferred.nil? || types_compatible?(operand, inferred)
				elsif value_literal
					literal_key(operand) == value_literal
				else
					operand_type = infer_type operand # `"a"` allows only Strings, so an Integer value cannot match it
					inferred.nil? || operand_type.nil? || types_compatible?(operand_type, inferred)
				end
			end
		end

		# The same key for two literals that the language's `==` calls equal: `5` and `5.0`, but not `"fill"` and `:fill`.
		def literal_key expr
			case expr
			when Code::String_Expr then ['String', expr.value]
			when Code::Symbol_Expr then ['Symbol', expr.value.to_s]
			when Code::Number_Expr then ['Number', expr.value]
			else [expr.value] # true, false, nil
			end
		end

		# The annotation as written, with its own operators (`Int & String`, `"fill" | "line"`), for an error message.
		def annotation_display type_expr
			return type_expr.value unless composed_annotation? type_expr

			text     = ->(operand) { literal_type_expr?(operand) ? literal_text(operand) : (operand.is_a?(Code::Type_Expr) ? operand.name : operand.value) }
			operands = type_expr.expressions.grep(Code::Composition_Expr).map { "#{it.operator.value} #{text.call it.identifier}" }
			[type_expr.leading_literal ? text.call(type_expr.leading_literal) : type_expr.name, *operands].compact.join ' '
		end

		# Against an annotation with a literal in it, a literal value shows as written (`"fil"`), since its type alone (`String`) would not say why it fails. Otherwise the value shows as its type.
		def value_display expr, type_expr
			literal_annotation = composed_annotation?(type_expr) && annotation_operands(type_expr).any? { !it.is_a?(::String) }
			literal_annotation && literal_type_expr?(expr) ? literal_text(expr) : infer_type(expr)
		end

		def literal_text expr
			case expr
			when Code::String_Expr then expr.quotation_style == :double ? %("#{expr.value}") : "'#{expr.value}'"
			when Code::Symbol_Expr then ":#{expr.value}"
			else expr.value.to_s
			end
		end

		# `x := Type(...)` / `x := Type<Struct>(...)` / `Ident := SomeType`
		def check_inferred_declaration expr
			return unless expr.left.is_a? Code::Identifier_Expr

			if !(expr.right.is_a?(Code::Type_Expr) && expr.right.anonymous_composition) && (aliased = qualified_type_name(expr.right))
				@type_aliases[expr.left.value] = aliased
				return
			end

			if expr.right.is_a?(Code::Identifier_Expr) && Helpers.type_identifier?(expr.left.value) && Helpers.type_identifier?(expr.right.value)
				@type_aliases[expr.left.value] = expr.right.value
				return
			end

			constructed = constructed_type_name expr.right
			return unless constructed

			declare_member expr.left.value, constructed
		end

		def declare_member name, type_name
			declare :types, name, type_name
			@type_info[@type_stack.last][:members][name] = type_name if @type_stack.last
		end

		def constructed_type_name expr
			return nil unless expr.is_a? Code::Call_Expr
			receiver = expr.receiver

			case receiver
			when Code::Type_Expr
				qualified_type_name receiver
			when Code::Identifier_Expr
				@type_aliases.fetch(receiver.value, receiver.value) if Helpers.type_identifier? receiver.value
			end
		end

		def qualified_type_name expr
			return nil unless expr.is_a? Code::Type_Expr
			return expr.name unless expr.tag

			# A named reference (`Abc\Task_Schema`) has no member list to render -- just use its own name.
			return "#{expr.name}#{Code::TAG_OPERATOR}#{expr.tag.value}" unless expr.tag.is_a? Code::Struct_Expr

			member_names = expr.tag.types.map { |t| t.value if t.is_a? Code::Identifier_Expr }
			return nil if member_names.any?(&:nil?)

			"#{expr.name}<#{member_names.join(',')}>"
		end

		def check_param expr
			return nil unless expr.type && expr.default
			return nil if expr.variadic # `x: Args` is a variadic marker, not a real element type
			return nil if expr.type.is_a? Code::Struct_Expr # structural annotations aren't checked statically
			return nil if annotation_accepts? expr.type, expr.default

			Type_Mismatch.new expr, annotation_display(expr.type), value_display(expr.default, expr.type)
		end

		def check_return_type expr
			return nil unless expr.type
			return nil if expr.type.is_a? Code::Struct_Expr # structural annotations aren't checked statically
			return nil if expr.expressions.empty?

			return nil if annotation_operands(expr.type) == ['Nil'] # `-> Nil` discards the last expression at runtime, see #interp_func_body
			return nil if annotation_accepts? expr.type, expr.expressions.last

			raise Code::Type_Contract_Violation.new(expr.expressions.last, annotation_display(expr.type), value_display(expr.expressions.last, expr.type))
		end

		# `nil` means there is no error with the expression. The pattern for most of the cases is just: recurse into child expressions and collect errors.
		# @return nil, Error, or Array of Errors.
		def check expr
			case expr
			when Code::Infix_Expr
				check_infix expr

			when Code::Param_Expr
				check_param expr

			when Code::Prefix_Expr
				check expr.expression
			when Code::Postfix_Expr
				check expr.expression
			when Code::Route_Expr
				check expr.expression

			when Code::Circumfix_Expr
				check expr.expressions
			when Code::Func_Expr
				# #register_func runs before the new scope is pushed, so the function's own name is declared into the *enclosing* scope (visible to siblings, and to the function's own body too since lookups search outward so recursive calls still resolve).
				register_func expr
				body_errors = with_new_scope { check expr.parameters + expr.expressions }
				check_return_type expr # raises directly -- see its own comment
				body_errors
			when Code::Type_Expr
				if expr.expressions
					if (name = qualified_type_name expr)
						operands = expr.expressions.grep(Code::Composition_Expr).map do |composition|
							operand = composition.identifier
							next nil unless composition.operator&.value == '|'
							operand.is_a?(Code::Type_Expr) ? operand.name : (operand.value if operand.is_a?(Code::Identifier_Expr))
						end
						@composed_types_by_name[name] = operands.include?(nil) ? :unknown : operands
					end
					@type_stack.push qualified_type_name(expr)
					result = with_new_scope { check expr.expressions }
					@type_stack.pop
					result
				end

			when Code::Subscript_Expr
				[check(expr.receiver), check(expr.expression)]
			when Code::For_Loop_Expr
				[check(expr.collection), check(expr.body)]
			when Code::Call_Expr
				check_call expr

			when Code::Conditional_Expr
				[
					check(expr.condition),
					check(expr.when_true),
					check(expr.when_false),
				]

			when ::Array
				expr.filter_map { check _1 }

			else
				nil
			end
		end

		private

		def new_scope_frame
			{ types: {}, funcs: {} }
		end

		def declare kind, name, value
			@scopes.last[kind][name] = value
		end

		def find_in_scopes kind, name
			@scopes.reverse_each do |scope|
				return scope[kind][name] if scope[kind].key? name
			end
			nil
		end

		def with_new_scope
			@scopes.push new_scope_frame
			yield
		ensure
			@scopes.pop
		end
	end
end
