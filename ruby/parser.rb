# todo; use Expression#set_location_span line, column, line_end, column_end for every single expression

module Code
	class Parser
		attr_accessor :i, :input, :precedences

		def initialize input = []
			@precedences = PRECEDENCES.dup
			# Track these so that they can be considered during parse-time
			@custom_infix         = ::Set.new
			@custom_prefix        = ::Set.new
			@custom_postfix       = ::Set.new
			@custom_circumfix     = ::Set.new
			@input                = input
			@i                    = 0 # index of current lexeme
			@struct_nesting_depth = 0 # how many `<...>` structs #parse_struct is currently inside of -- see #split_glued_close_angles!
		end

		def input= value
			@input = value
			@i     = 0
		end

		def output
			scan_and_register_operator_overloads_before_parsing # This has to be done before parsing because overloaded operators have to set their precedence level, which if done at runtime would the behavior of #precedence_for that now depends on an updated prcedence table with new precedences added.

			expressions = []
			while lexemes?
				@last_expression = expressions.compact.last
				expressions << parse_expression
			end

			expressions.compact
		end

		def copy_location expr, from_lexeme_or_expr
			return expr unless from_lexeme_or_expr

			expr.line_start   = from_lexeme_or_expr.line_start
			expr.column_start = from_lexeme_or_expr.column_start
			expr.line_end     = from_lexeme_or_expr.line_end
			expr.column_end   = from_lexeme_or_expr.column_end
			expr.source_file  = from_lexeme_or_expr.source_file

			expr
		end

		def scan_and_register_operator_overloads_before_parsing
			# The pattern:    @    operator   {user_operator}   @   {fixity}   {precedence_integer}
			#                 t0   t1          user_operator    t3   fixity     prec
			input.each_cons(6) do |t0, t1, user_operator, t3, fixity, prec|
				next unless t0.value == '@' && t1.value == 'operator' && t3.value == '@'

				fixities = %w(infix prefix postfix circumfix)
				raise Operator_Overload_Fixity_Must_Be_One_Of.new(fixities) unless fixities.include? fixity.value

				@precedences[user_operator.value] = case prec.value
				when '('
					# todo; Log a warning that precedence was omitted and a fallback is used.
					precedence_for user_operator.value
				else
					raise Operator_Overload_Precedence_Must_Be_Integer.new prec unless prec.type == :number
					prec.value.to_i
				end

				case fixity.value
				when 'infix' then @custom_infix << user_operator.value
				when 'prefix' then @custom_prefix << user_operator.value
				when 'postfix' then @custom_postfix << user_operator.value
				when 'circumfix' then @custom_circumfix << user_operator.value
				end
			end
		end

		# If the given operator doesn't exist then it returns Code::DEFAULT_OPERATOR_PRECEDENCE which binds somewhere around the equality operators. See Code::PRECEDENCES
		# Neat reference for precedences: https://rosettacode.org/examples/Operator_precedence
		# @param operator [::String]
		# @return precedence [Integer]
		def precedence_for operator
			@precedences[operator] || DEFAULT_OPERATOR_PRECEDENCE
		end

		# input[i - 1]
		def prev_lexeme
			input[[i - 1, 0].max]
		end

		# input[i]
		# @return [Code::Lexeme]
		def curr_lexeme
			input[i]
		end

		# input[i..]
		def remainder
			input[i..]
		end

		def lexemes?
			i < input.length
		end

		def reduce lexeme = %W(\n \r)
			eat while lexemes? && curr?(lexeme)
		end

		def reduce_newlines
			eat while lexemes? && curr?(:delimiter) && %W(\n \r).include?(curr_lexeme.value)
		end

		def curr? * sequence
			return false unless remainder && lexemes?
			return false if sequence.count > remainder.count

			slice = remainder.slice(0, sequence.count)
			slice.each_with_index.all? do |lexeme, index|
				expected = sequence[index]

				if expected.is_a?(Code::Array) || expected.is_a?(::Array)
					expected.any? do |alt|
						lexeme.is(alt)
					end
				else
					lexeme.is(expected)
				end
			end
		end

		def peek ahead = 1
			raise 'Parser.input is nil' unless input

			index = ahead.clamp(0, input.count)
			input[i + index]
		end

		def peek_until lexeme = nil
			return remainder unless lexeme

			depth = 0
			remainder.take_while do |it|
				depth += 1 if it.value == '{'
				depth -= 1 if it.value == '}'

				# `Lexeme#is` already dispatches correctly on `lexeme`'s own class (Symbol -> type match, String -> value match, Array -> any-match, a full Lexeme -> #== by value) -- the old inline check only ever handled a full Lexeme or a raw value, silently never matching a bare type Symbol (`:delimiter`) passed as a stop marker.
				stop = it.is lexeme

				!(stop && depth <= 0)
			end
		end

		def peek_contains? contains, stop_at_lexeme = nil
			peek_until(stop_at_lexeme).any? do |t|
				t.is contains
			end
		end

		def func_declaration_follows?
			depth = 0
			remainder.each do |token|
				next if LITERAL_LEXEME_TYPES.include? token.type

				depth += 1 if token.value == '('
				depth -= 1 if token.value == ')'

				return true if token.value == Code::FUNCTION_DELIMITER && depth == 1
				return false if depth <= 0 && token.value == ')'
			end
			false
		end

		PARAM_LIST_TOKEN_VALUES = %w[, : -> < > @].freeze

		def anon_func_param_list_follows?
			depth = 0
			remainder.each do |token|
				# A real param list is never spelled with a literal -- `.join(';')`'s lone string argument isn't a param list that merely happens to contain `;`, it's an ordinary call.
				return false if LITERAL_LEXEME_TYPES.include? token.type

				if token.value == '('
					depth += 1
					next if depth == 1 # the opening paren itself
					return false # a nested group -- too complex for the bare sugar
				end
				return false if %w([ {).include? token.value
				depth -= 1 if token.value == ')'
				return false if depth <= 0

				return true if token.value == Code::FUNCTION_DELIMITER
				next if token.type == :newline
				next if %i[identifier Identifier].include? token.type
				next if PARAM_LIST_TOKEN_VALUES.include? token.value
				return false
			end
			false
		end

		# `NAME: Enum [`, `NAME: Enum\Backing [`, or `NAME: Backing [` -- always an enum. Safe to claim
		# any `Capitalized: Type [` broadly, since a `Capitalized: Type` expression is never subscripted.
		def annotated_enum_declaration_follows?
			return false unless curr?(TYPE_IDENTIFIER, ':')
			base = peek 2
			return false unless base && TYPE_IDENTIFIER.include?(base.type)

			ahead = 3
			ahead += 2 if base.value == 'Enum' && peek(ahead)&.value == TAG_OPERATOR
			peek(ahead)&.value == '['
		end

		# `curr` is a TYPE_IDENTIFIER, `peek` is `[`. An enum unless the brackets hold exactly one plain
		# expression -- that lone case is an ordinary subscript (`Config[key]`).
		def bare_enum_declaration_follows?
			depth       = 0
			prev_ident  = false
			saw_content = false
			j           = i + 1

			while (tok = input[j])
				v          = tok.value
				is_newline = tok.type == :delimiter && NEWLINES.include?(v)

				if ['(', '[', '{'].include? v
					depth      += 1
					prev_ident = false
				elsif [')', ']', '}'].include? v
					depth -= 1
					return !saw_content if depth.zero? # empty `[]` -> enum; one plain expr -> subscript
					prev_ident = false
				elsif depth == 1 && !is_newline
					ident = %i[identifier Identifier IDENTIFIER].include?(tok.type) && !tok.reserved

					return true if v == ',' || v == ':=' || v == '='
					return true if prev_ident && (v == ':' || ident) # `NAME:` annotation, or two members
					return true if ident && input[j + 1]&.value == '[' # nested `NAME [`

					saw_content = true
					prev_ident  = ident
				end

				j += 1
			end

			false
		end

		def integer_tag_next?
			curr?(TAG_OPERATOR, :number) && peek(1).value.match?(/\A\d+\z/)
		end

		def type_then_integer_tag_next?
			curr?(TYPE_IDENTIFIER, TAG_OPERATOR, :number) && peek(2).value.match?(/\A\d+\z/)
		end

		# @param expr  [Code::Expression] expression to set location on
		# @param from  [Code::Lexeme]     lexeme that begins the expression
		# @param till  [Code::Lexeme]     lexeme that completes the expression
		# @return expr [Code::Expression] the given expression
		def set_expr_location expr, from, till
			expr.source_file  = from.source_file
			expr.column_start = from.column_start
			expr.line_start   = from.line_start
			expr.column_end   = till.column_end
			expr.line_end     = till.line_end
			expr
		end

		# idea: support sequence of elements where an element can be one of many, like the sequence [IdentifierToken, [:=, =]]
		def eat * sequence
			raise "tried to eat #{sequence} but out of lexemes" unless lexemes?

			if sequence.nil? || sequence.empty? || sequence.one?
				eaten = curr_lexeme
				if sequence&.one? && !eaten.is(sequence[0])
					raise "Parser#eat expected #{sequence[0].inspect} but ate #{eaten.value.inspect}"
				end
				@i    += 1
				return eaten
			end
		end

		#
		#   for <collection> [map/select/reject] [by <stride>[,<overlap>]]
		#       it, at
		#   end
		#
		#   for items map by 2
		#       it #[items.0, items.1], [items.2, items.3], ...
		#   end
		#
		#   for items map by 2,1
		#       it #[items.0, items.1], [items.1, items.2], [items.2, items.3], ...
		#   end
		#
		def parse_for_loop_expr
			start     = curr_lexeme
			it        = Code::For_Loop_Expr.new
			it.lexeme = eat 'for'

			lexemes = peek_until "\n"

			exactly_two_commas      = lexemes.count { _1.is(',') } == 2
			exactly_one_declaration = lexemes.count { _1.is(':=') } == 1
			valid_traditional_loop  = exactly_two_commas && exactly_one_declaration

			if valid_traditional_loop
				it.counter = parse_expression
				eat ','
				it.condition = parse_expression
				eat ','
				it.step = parse_expression

			else
				it.collection = parse_expression

				if curr? Code::FOR_VERBS and verb = eat
					it.type   = verb
					it.lexeme = verb
				end

				if curr? 'by' and eat 'by'
					it.stride = begin_expression

					if curr? ',' and eat ','
						it.overlap = begin_expression
						# Code.assert it.overlap.is_a? ::Integer
					end
				end
			end

			reduce_newlines

			it.body           = []
			it.when_cases     = []
			it.when_else_case = []

			until curr? 'end'
				if curr? 'when'
					it.when_cases << parse_when_expr
				elsif curr? 'else'
					eat 'else'
					until curr? 'end'
						it.when_else_case << parse_expression
					end
				else
					it.body << parse_expression
				end

				reduce_newlines
			end

			it.body           = it.body.compact
			it.when_cases     = it.when_cases.compact
			it.when_else_case = it.when_else_case.compact

			closing = eat 'end'
			set_expr_location it, start, closing
		end


		#
		# when <condition>
		#     body
		# when/else/elsif/elif/end <--- terminators of the body
		#
		# This is only used inside for-loops and if-family, otherwise "when" identifier is free to use
		def parse_when_expr
			start         = curr_lexeme
			it            = When_Expr.new
			it.operator   = eat 'when'
			it.condition = parse_expression
			it.body       = []

			until curr? %w(when else elsif elif end)
				expr = parse_expression
				it.body << expr if expr
			end

			it.body = it.body.compact

			set_expr_location it, start, it.condition
		end

		def parse_conditional_expr
			start = curr_lexeme

			it            = Code::Conditional_Expr.new
			it.type       = eat # One of %w(if while unless until)
			it.condition  = parse_expression
			it.when_true  = []
			it.when_false = []
			it.when_cases = [] # only collected in the if_true branch
			reduce_newlines

			# @clean

			until curr? %w(end else elif elsif elwhile elswhile)
				if curr? 'when'
					it.when_cases << parse_when_expr
				else
					expr = parse_expression
					it.when_true << expr if expr
				end

				reduce_newlines
			end

			closing = if curr? %w(elif elsif elwhile elswhile)
				it.when_false = parse_conditional_expr

			elsif curr? %w(else) and eat
				until curr? 'end'
					expr = parse_expression
					it.when_false << expr if expr
					reduce_newlines
				end
				eat 'end'

			elsif curr? %w(} end)
				eat

			else
				# todo: errors.rb
				raise "\n\nYou messed your if/elif/else up\n"
			end

			set_expr_location it, start, closing
		end

		def parse_circumfix_expr opening: '('
			start = curr_lexeme
			it    = Code::Circumfix_Expr.new
			it.grouping = CIRCUMFIX_GROUPINGS[opening] or raise "parse_circumfix_expr unknown opening #{opening}"
			eat opening
			reduce_newlines
			closing = it.grouping[1]

			it.expressions = []
			until curr? closing
				# note; A bare identifier immediately followed by `,` is special-cased here rather than going through #parse_expression, same fix #parse_struct already needed for `<...>`: #begin_expression's nil-init dispatch would otherwise interfere.
				it.expressions << if curr?(ANY_IDENTIFIER, ',')
					parse_identifier_expr
				else
					parse_expression
				end
				break if curr? closing

				eat if curr? ','
				reduce_newlines
			end

			it.expressions = it.expressions.compact
			closing        = eat closing
			set_expr_location it, start, closing
		end

		# TYPE_IDENT [ ... ]  /  TYPE_IDENT: Enum[\Backing] [ ... ]  /  TYPE_IDENT: Backing [ ... ]
		#   member forms: TYPE_IDENT | TYPE_IDENT, | TYPE_IDENT: TYPE_IDENT | TYPE_IDENT := EXPR | TYPE_IDENT: TYPE_IDENT = EXPR
		def parse_enum_expr
			start            = curr_lexeme
			expr             = Code::Enum_Expr.new
			expr.expressions = []
			expr.name        = eat TYPE_IDENTIFIER

			# `: Enum` / `: Enum\Backing` / `: Backing` -- the backing type lands on `expr.type`.
			if curr? ':'
				eat ':'
				base = eat TYPE_IDENTIFIER
				if base.value == 'Enum'
					if curr? TAG_OPERATOR
						eat TAG_OPERATOR
						expr.type = parse_identifier_expr
					end
				else
					expr.type = copy_location Code::Identifier_Expr.new(base), base
				end
			end

			eat '['

			#   TYPE_IDENT [ ... ]
			until curr? ']'
				reduce_newlines
				break if curr? ']'

				item = if curr? TYPE_IDENTIFIER, '['
					parse_enum_expr
				else
					#   TYPE_IDENT              # gets its own unique value
					#   TYPE_IDENT,             # with comma
					#   TYPE_IDENT: TYPE_IDENT
					#   TYPE_IDENT := EXPR
					#   TYPE_IDENT: TYPE_IDENT = EXPR
					item_name = parse_identifier_expr # also consumes a trailing `: Type` annotation itself, if there is one

					Code.assert item_name.is_a? Code::Identifier_Expr

					case curr_lexeme.value
					when ','
						parse_nil_init_expr item_name
					when ':='
						eat ':='
						infix          = Code::Infix_Expr.new
						infix.operator = Lexeme.new(:operator, ':=')
						infix.left     = item_name
						infix.right    = parse_expression
						set_expr_location infix, item_name, infix.right
					when '='
						eat '='
						infix          = Code::Infix_Expr.new
						infix.operator = Lexeme.new(:operator, '=')
						infix.left     = item_name
						infix.right    = parse_expression
						set_expr_location infix, item_name, infix.right
					else
						# Bare TYPE_IDENT (with or without a `: Type` annotation already picked up above), nothing following -- next token is '}' or the next member's own name. A plain bare name (no type) gets the same nil-init treatment as the explicit-comma form; a typed-but-unvalued name (`ABC: Some_Type`) is left as the Identifier_Expr #parse_identifier_expr already built.
						item_name.type ? item_name : parse_nil_init_expr(item_name)
					end
				end

				eat if curr? ','
				reduce_newlines

				expr.expressions << item
			end
			closing = eat ']'
			set_expr_location expr, start, closing
		end

		def parse_func
			start            = curr_lexeme
			func             = Code::Func_Expr.new
			func.expressions = [] # Expression
			func.parameters  = [] # Param_Expr

			if curr?(SCOPE_KEYWORDS, '.')
				func.name = parse_self_prefixed_identifier
			elsif curr?(SCOPE_KEYWORDS) || curr?(:identifier)
				func.name = parse_identifier_expr
			end

			# note; A bare `identifier: ( ... ;)` (no type between the colon and the paren) is the new self-declaring signature form (`double: (Number -> Number;)`) of a function. parse_identifier_expr only consumes the colon itself when it's followed by an actual `: Type`/`: <...>` (or Struct)
			signature_colon = curr? ':'
			eat ':' if signature_colon

			func.lexeme = func.name&.lexeme
			eat '('
			reduce_newlines

			until curr? Code::FUNCTION_DELIMITER
				before_i    = @i
				param_start = curr_lexeme

				if curr? '->' and eat '->'
					# A function (named or anonymous) declaring its own return type inline, at the end of its param list: `(a: Number -> Number; ... )`. Distinct from `identifier: Type (...)`, which is a signature reference/alias, not an implementation declaring its own type.
					func.type = begin_expression
					next
				end

				param = Code::Param_Expr.new

				if curr? Code::CONTEXT_OPERATOR # @
					identifier = parse_identifier_expr
					case identifier&.value
					when 'splatr'
						param.add_to_readable = true
					when 'splat'
						param.add_to_writable = true
					else
						raise "unsupported directive #{identifier&.value} in a param list -- only @splat / @splatr"
					end
				end

				if curr? TYPE_IDENTIFIER
					param.type   = eat
					param.lexeme = param.type
				elsif curr? '('
					nested_start = curr_lexeme
					param.type   = parse_func
					param.lexeme = param.type.lexeme || nested_start
				else
					if curr? :identifier, :identifier
						param.label  = eat :identifier
						param.lexeme = eat :identifier
					elsif curr? :identifier
						param.lexeme = eat :identifier
					end

					# note; something in the if/else below depends on param.name being present
					param.name = param.lexeme

					if curr?('...') and dots = eat('...') # f (x...; ...) -- same as f (x: Arguments; ...)
						param.variadic = true
						param.type     ||= copy_location Code::Identifier_Expr.new('Arguments'), dots
					end

					if curr?(':', TYPE_IDENTIFIER)
						eat ':'
						param.type     = begin_expression # picks up a trailing `\<...>`/`\Name` itself (readable as param.type.tag), see #parse_identifier_expr
						param.variadic = true if %w(Arguments Args).include? param.type&.value
					elsif curr?(':', '<')
						eat ':'
						param.type = parse_struct # bare struct annotation, e.g. `right: <name: String, type: Any, value: Any>` -- structural rather than nominal, see #check_struct_type_contract
					elsif curr?(':', '(')
						eat ':'
						# A param typed with an inline func signature, e.g. `callable: (;)`/`callable: (Number -> Number;)` -- unlike the top-level self-declaring signature form, there's no name here to attach to, so this is a plain recursive #parse_func call, not routed through the `func.type && !has_real_body` -> Func_Signature_Expr repackaging at the bottom of #parse_func. Without this branch, the `:` was never consumed here (only TYPE_IDENTIFIER/`<` were recognized after it), so the outer param loop kept re-reading the same un-consumed `:` forever -- an infinite loop, not a parse error.
						param.type = parse_func
					end

					# note; These are intentionally separate ifs
					if curr? ':='
						eat ':='
						param.default = parse_expression
					elsif param.type && curr?('=')
						# `:=` is only required when there's no `: Type` to declare it instead.
						eat '='
						param.default = parse_expression
					end
				end

				# The branches above only recognise real param-list tokens (names, `: Type`, labels, defaults, `->`). A stray token they all skipped (a number, a string, an operator) -- raise before touching `param`'s location, since nothing was actually parsed for it (`param.lexeme`/`.type`/`.default` all still nil) -- or the `until` loop spins forever.
				raise "unexpected #{curr_lexeme.value.inspect} in function parameter list" if @i == before_i

				func.parameters << param
				set_expr_location param, param_start, param.default || param.type || param.lexeme
				eat if curr? ','
				reduce_newlines
			end

			eat Code::FUNCTION_DELIMITER if curr? Code::FUNCTION_DELIMITER
			reduce_newlines

			until curr? ')'
				func.expressions << parse_expression
				reduce_newlines
			end

			closing = eat ')'

			if (func.type || signature_colon) && !func.expressions.any?
				sig        = Code::Func_Signature_Expr.new
				sig.name   = func.name
				sig.type   = func.type
				sig.lexeme = func.lexeme
				sig.params = func.parameters
				return set_expr_location sig, start, closing
			end

			set_expr_location func, start, closing
		end

		def integer_tag_struct_expr
			start  = curr_lexeme
			member = parse_number_expr

			it        = Code::Struct_Expr.new
			it.lexeme = Code::Lexeme.new :struct, '<>'
			it.types  = [member]
			it.names  = [nil]
			set_expr_location it, start, member.lexeme
		end

		def parse_struct
			# TYPE_IDENTIFIER <...>
			start     = curr_lexeme
			it        = Code::Struct_Expr.new
			it.name   = eat if curr? TYPE_IDENTIFIER
			it.lexeme = Code::Lexeme.new :struct, '<>'
			it.types  = []
			it.names  = []
			eat '<'
			closing = parse_struct_members it
			set_expr_location it, start, closing
		end

		# The member list inside `<...>` -- factored out of #parse_struct so struct-composition's trailing body (`Both | Abc | Def <extra: String>`) can reuse it without re-eating a leading name. Returns the closing `>` lexeme.
		def parse_struct_members it
			@struct_nesting_depth += 1
			begin
				loop do
					split_glued_close_angles!
					break if curr? '>'

					reduce_newlines
					split_glued_close_angles!
					break if curr? '>'

					element = if curr?(:identifier, ':', '(') && func_declaration_follows?
						# Like `to_s: (-> String;)`
						parse_func
					elsif curr?(ANY_IDENTIFIER, ',')
						parse_identifier_expr
					else
						parse_expression(precedence_for('<'))
					end

					# A named member can carry a default, typed (`dict: Dictionary = {}`) or bare (`id := 4815`) -- both bind looser than `precedence_for('<')`, so #parse_expression left them for us here.
					if curr? ':='
						eat ':='
						element.member_default = parse_expression(precedence_for('<'))
					elsif element.is_a?(Code::Identifier_Expr) && element.type && curr?('=')
						eat '='
						element.member_default = parse_expression(precedence_for('<'))
					end

					# A `:` still here means `element`'s own `: Type` lookahead saw one but declined it (not a valid type) -- almost always a Dictionary-style `key: value` typo, invalid in a struct member list.
					raise Code::Invalid_Struct_Member_Annotation.new(curr_lexeme) if curr? ':'

					it.types << element
					it.names << if element.is_a?(Code::Func_Signature_Expr)
						element.name&.value || element.value
					elsif element.is_a?(Code::Identifier_Expr) && (element.type || element.member_default)
						element.value
					end

					eat if curr? ','
				end
				eat '>'
			ensure
				@struct_nesting_depth -= 1
			end
		end

		def parse_type_decl
			# todo; The | TYPE_COMPOSITION_OPERATOR is currently only working in #parse_type_decl. I can peek until end of line, if I see another | then it's a circumfix. However if there are more |s then maybe we can presume the expression type like this:
			#
			#   1 | = composition
			#   2 | = circumfix
			#   3+ odd probably  = composition
			#   3+ even probably = circumfix
			#
			#   :absolute_value_circumfix
			#

			start    = curr_lexeme
			it       = Code::Type_Expr.new eat # one of valid_idents
			it.name  = it.lexeme.value
			is_type  = Helpers.type_identifier? it.name
			is_const = Helpers.constant_identifier? it.name

			Code.assert is_type || is_const, "Type names can only be Capitalized or UPPERCASE" # todo; proper error

			if curr?(TAG_OPERATOR, '<') and eat(TAG_OPERATOR)
				# Inline anonymous struct literal (`Array\<String>`) -- reuses #parse_struct verbatim.
				it.tag      = parse_struct # returns nil if none was found
				it.tag.name = it.name if it.tag
			elsif curr?(TAG_OPERATOR, TYPE_IDENTIFIER) and eat(TAG_OPERATOR)
				# Named reference, no `<...>` (`Array\Task_Schema`) -- resolved at interpret time.
				it.tag = parse_identifier_expr
			elsif integer_tag_next? and eat(TAG_OPERATOR)
				# Version tag, no `<...>` (`Primary_Key\123`) -- same as `\<123>`.
				it.tag      = integer_tag_struct_expr
				it.tag.name = it.name
			end

			# When no body and no composition chain follow e.g.
			#
			#   x: Abc<Number>
			#   y := Abc<Number>
			#   Abc<Number>()
			#   Abc<4815>()
			#
			# Then this is a reference to an existing type (optionally tagged), not a declaration. `it.expressions` stays nil here so callers (like #interp_type) can tell this apart from a real, even if empty, `{}` body. Whatever follows (like a trailing `(...)` call) is picked up in #complete_expression, same as any other primary expression.
			# A composed operand can be a struct literal too (`Type | <x: Int> {}`), not just a type name.
			unless curr?('{') || curr?(TYPE_COMPOSITION_OPERATORS, ANY_IDENTIFIER) || curr?(TYPE_COMPOSITION_OPERATORS, '<')
				closing = if it.tag
					it.tag
				else
					it.lexeme
				end
				return set_expr_location it, start, closing
			end

			it.expressions = []

			until curr? '{'
				break unless curr?(TYPE_COMPOSITION_OPERATORS, ANY_IDENTIFIER) || curr?(TYPE_COMPOSITION_OPERATORS, '<')
				it.expressions << parse_composition_expr
			end

			unless curr? '{'
				# A trailing `<...>` composes structs instead of a type's `{}` body. Speculative -- a bare `<` could just as easily be a comparison (`x := A | B < 5`), so only commit if it actually parses as a struct.
				if curr?('<') && (body = try_parse_struct_body)
					it.struct_body = body
					return set_expr_location it, start, body
				end

				# No body followed the composition chain (`Abc|Def`, `A & B`, ...) so this is a reference to an anonymous type built by applying the chain, not a declaration.
				it.anonymous_composition = true

				closing = if it.expressions
					it.expressions.last
				else
					it.lexeme
				end
				return set_expr_location it, start, closing
			end

			eat '{'
			reduce_newlines

			until curr?('}')
				it.expressions << parse_expression
				reduce_newlines
			end

			it.expressions = it.expressions.compact

			closing = eat '}'
			set_expr_location it, start, closing
		end

		def parse_comment
			lexeme   = eat
			it       = Code::Comment_Expr.new lexeme
			it.value = copy_location Code::String_Expr.new(lexeme), lexeme
			it.body  = copy_location Code::String_Expr.new(lexeme), lexeme
			it.type  = lexeme.type
			set_expr_location it, lexeme, lexeme
		end

		def parse_fence_expr
			lexeme   = eat
			it       = Code::Fence_Expr.new lexeme
			it.value = copy_location Code::String_Expr.new(lexeme), lexeme
			it.type  = lexeme.type # :fence by default
			set_expr_location it, lexeme, lexeme
		end

		def parse_html_expr
			# TODO: :html_vs_type_expr
			start      = curr_lexeme
			it         = Code::Html_Fence_Expr.new eat
			it.value   = copy_location Code::String_Expr.new(start), start
			it.body    = it.value
			it.element = it.lexeme
			copy_location it, start
		end

		def parse_composition_expr
			start         = curr_lexeme
			expr          = Code::Composition_Expr.new
			expr.operator = eat(:operator)
			ident         = curr?('<') ? parse_struct : parse_identifier_expr

			while curr?('.') && peek.is(:Identifier)
				dot_op         = eat('.')
				right          = parse_identifier_expr
				infix          = Code::Infix_Expr.new
				infix.left     = ident
				infix.operator = dot_op
				infix.right    = right
				set_expr_location infix, ident, right
				ident = infix
			end

			# A composed operand can itself be a tagged reference (`| Other\<'users'>`) -- #parse_identifier_expr already consumed it onto `.tag`; repackage into a Type_Expr so #interp_composition resolves it properly instead of dropping it.
			if ident.is_a?(Code::Identifier_Expr) && ident.tag
				type_ref      = Code::Type_Expr.new
				type_ref.name = ident.value
				type_ref.tag  = ident.tag
				copy_location type_ref, ident
				ident = type_ref
			end

			expr.identifier = ident
			set_expr_location expr, start, ident
		end

		# `x := |Compo` / `y := |This ^ That` -- a composition chain with no left operand, used as a value. Same Type_Expr shape #parse_type_decl builds for `Base | Compo`, just with `.name` left nil. Only reachable from `:=`'s own RHS parsing.
		def parse_bare_composition_chain
			start                    = curr_lexeme
			it                       = Code::Type_Expr.new
			it.anonymous_composition = true
			it.expressions           = []

			it.expressions << parse_composition_expr while curr?(TYPE_COMPOSITION_OPERATORS, ANY_IDENTIFIER)

			set_expr_location it, start, it.expressions.last
		end

		def parse_statement_expr
			start = curr_lexeme
			Code::Statement_Expr.new.tap do |it|
				eat '`'
				it.expression = parse_expression
				closing       = eat '`'
				set_expr_location it, start, closing
			end
		end

		def parse_callsite_splat
			dots              = eat '...'
			prefix            = Prefix_Expr.new
			prefix.operator   = Lexeme.new(:operator, dots.value)
			prefix.expression = parse_expression precedence_for(dots.value)
			set_expr_location prefix, dots, prefix.expression
		end

		def parse_identifier_expr
			start = curr_lexeme
			expr  = Code::Identifier_Expr.new

			if curr? CONTEXT_OPERATOR
				at_lexeme = eat CONTEXT_OPERATOR
				if curr? ANY_IDENTIFIER
					expr.prefixed_with_at = true # @word -- an @-prefixed identifier
				else
					# bare `@`
					expr.lexeme  = at_lexeme
					expr.privacy = :public
					expr.kind    = :identifier
					return copy_location expr, start
				end
			end

			expr.lexeme  = eat
			expr.privacy = Code.privacy_of_ident expr.value

			# A type reference can carry its own trailing tag. A named reference recurses, so `Abc\Cd\Ef` nests as `.tag.tag`. note; A recursive call here never goes through #parse_type_decl so it's handled directly.
			# `nil` is a reserved lowercase keyword, not a TYPE_IDENTIFIER, but it's tagged the same way
			# (`nil\<reason: Any>`, `nil\Error(...)`) -- sugar for tagging the real `Nil` type; see
			# #interp_identifier's 'nil' branch, which desugars into an ordinary Nil\<...> reference.
			taggable = TYPE_IDENTIFIER.include?(expr.lexeme.type) || expr.value == 'nil'
			if taggable && curr?(TAG_OPERATOR, '<')
				eat TAG_OPERATOR
				expr.tag      = parse_struct
				expr.tag.name = expr.value if expr.tag
			elsif taggable && curr?(TAG_OPERATOR, TYPE_IDENTIFIER)
				eat TAG_OPERATOR
				expr.tag = parse_identifier_expr # named reference, e.g. `Abc\Task_Schema`
			elsif taggable && integer_tag_next?
				eat TAG_OPERATOR
				expr.tag      = integer_tag_struct_expr # version tag, e.g. `Primary_Key\123`
				expr.tag.name = expr.value
			end

			if curr?(':', TYPE_IDENTIFIER)
				eat ':'
				expr.type = curr?(TYPE_IDENTIFIER, TYPE_COMPOSITION_OPERATORS) ? parse_type_decl : parse_identifier_expr
				expr.tag  = expr.type.tag
			elsif curr?(':', '<')
				eat ':'
				expr.type = parse_struct # bare struct annotation, e.g. `thing: <String, Number>` -- sugar for `thing: Struct<String, Number>`
			end

			expr.kind = Code.type_of_identifier expr.value
			# The end of this expression's own span isn't always `expr.lexeme` -- a trailing tag
			# (`\<...>`/`\Name`/`\123`) or `: Type` annotation consumes more tokens past the bare
			# name, and `expr.type` (if present) is always the last of those to be parsed.
			closing = expr.type || expr.tag || expr.lexeme
			set_expr_location expr, start, closing
		end

		def parse_self_prefixed_identifier
			keyword = eat
			eat '.'

			expr                = parse_identifier_expr
			expr.scope_operator = Code::Lexeme.new(:operator, keyword.value)
			# `expr` already has its own correct end (from the recursive #parse_identifier_expr call
			# above) -- only the start needs moving back to `keyword`, to include "self."/"Self." itself.
			set_expr_location expr, keyword, expr
		end

		def parse_symbol_expr
			start = curr_lexeme
			eat ':'
			name = eat
			it   = Code::Symbol_Expr.new name
			set_expr_location it, start, name
		end

		def parse_route_expr
			start       = curr_lexeme
			route_token = eat :route

			# Split "get://users/:id" => ["get", "users/:id"]
			parts       = route_token.value.split HTTP_VERB_SEPARATOR
			http_method = parts[0]
			path_string = parts[1] || ''

			# Extract parameter names from dynamic path segments. ":id/:action" => ["id", "action"]
			path_segments = path_string.split '/'
			param_names   = path_segments
			                .select { |segment| segment.start_with?(':') }
			                .map { |segment| segment[1..-1] } # Remove ':' prefix

			# Parse handler function (must follow route declaration).
			# todo: Consider being able to use an existing identifier in place of a function expression
			reduce_newlines
			expr = parse_expression

			# Validate: handler params must include all route params
			handler_params = if expr.is_a? Code::Func_Expr
				expr.parameters.map(&:name).map(&:value)
			else
				[]
			end

			missing_params = param_names - handler_params
			# todo: Is this a case that needs to be handled?
			# unless missing_params.empty?
			# end

			route             = Code::Route_Expr.new
			route.http_method = Code::Identifier_Expr.new.tap do |expr|
				expr.value = http_method
				expr.kind  = :identifier
				copy_location expr, route_token
			end
			route.path        = path_string
			route.expression  = expr
			route.param_names = param_names

			set_expr_location route, start, expr
		end

		def parse_percent_literal_expr
			start = curr_lexeme

			eat # %
			kind = eat # PERCENT_LITERALS

			eat '('
			reduce_newlines

			# Items split only on whitespace (or `,`), not per lexer token -- #parse_percent_literal_item merges e.g. `1px` back into one item.
			items = []
			until curr? ')'
				items << parse_percent_literal_item

				break if curr? ')'
				eat if curr? ','
				reduce_newlines
			end

			closing = eat ')'

			percent_lit             = Code::Percent_Literal_Expr.new # This extends Circumfix_Expr
			percent_lit.kind        = kind.value
			percent_lit.grouping    = '[]' # so that it interprets as an array later
			percent_lit.expressions = items

			valid_items = percent_lit.expressions.all? do |it|
				# Each of these can easily be converted to a string, so for now they're the only ones allowed.
				it.is_a?(Code::Identifier_Expr) || it.is_a?(Code::Number_Expr) || it.is_a?(Code::Operator_Expr) || it.is_a?(Code::Statement_Expr)
			end

			raise Code::Invalid_Percent_Literal_Expression.new(percent_lit) unless valid_items

			set_expr_location percent_lit, start, closing
		end

		# One item is a run of tokens with no whitespace between them, not one lexer token (`1px` lexes as number+identifier). A backtick item never merges -- it's a whole evaluated expression.
		def parse_percent_literal_item
			item = parse_percent_literal_token
			return item if item.is_a? Code::Statement_Expr

			while !curr?(')') && !curr?(',') && !curr?('`') && lexeme_adjacent?(item.lexeme, curr_lexeme)
				item = merge_percent_literal_items item, parse_percent_literal_token
			end

			item
		end

		# One bare token at a time, not #parse_expression -- an operator item (`+`/`-`) is also a valid prefix operator, and parse_expression would swallow the next item as its operand.
		def parse_percent_literal_token
			if curr? '`'
				parse_statement_expr
			elsif curr? :operator
				parse_operator_expr
			elsif curr? :number
				parse_number_expr
			elsif curr?(ANY_IDENTIFIER)
				parse_identifier_expr
			else
				# Anything else still has to consume at least one token, or the caller's loop spins forever -- lets #parse_percent_literal_expr's own check raise a clean error instead.
				parse_expression
			end
		end

		# No gap between the two lexemes in the original source -- same line, second starting exactly one column past where the first ends.
		def lexeme_adjacent? a, b
			a && b && a.line_end == b.line_start && a.column_end + 1 == b.column_start
		end

		# Concatenates two adjacent items' source text -- always folds into a plain Identifier_Expr, since #interp_percent_literal only reads `.value`/`.lexeme` off it either way.
		def merge_percent_literal_items left, right
			lexeme            = left.lexeme.dup
			lexeme.value      = "#{left.lexeme.value}#{right.lexeme.value}"
			lexeme.line_end   = right.lexeme.line_end
			lexeme.column_end = right.lexeme.column_end

			merged = Code::Identifier_Expr.new lexeme
			set_expr_location merged, left, right
		end

		def parse_beginless_range_expr
			Code::Infix_Expr.new.tap do |it|
				it.left     = nil
				it.operator = eat
				it.right    = parse_expression precedence_for(it.operator.value)
				it.right    = it.right.left if it.right.is_a? Code::Nil_Init_Expr

				set_expr_location it, it.operator, it.right # Typically I store `start = curr_lexeme` but here I know that it.operator was the first eaten lexeme here.
			end
		end

		def parse_endless_range_expr left_side_expr
			Code::Infix_Expr.new.tap do |it|
				it.left     = left_side_expr
				it.operator = eat

				# [2..], an endless range: the operator with nothing after it
				if !lexemes? || (curr?(:delimiter) && ["]", ")", "}", ",", ";", "\n", "\r"].include?(curr_lexeme.value))
					it.right = nil
				else
					it.right = parse_expression
					it.right = it.right.left if it.right.is_a? Code::Nil_Init_Expr
				end

				set_expr_location it, left_side_expr, it.right || it.operator
			end
		end

		def parse_operator_expr
			start = curr_lexeme
			# A method just for this might seem silly, but I thought the same when I decided #make_expr should be a giant method. This will help in the long run, and consistency is key to keeping this maintainable.

			operator_lexeme = eat(:operator)

			it = Code::Operator_Expr.new operator_lexeme
			copy_location it, start
		end

		def parse_number_expr
			start       = curr_lexeme
			expr        = Code::Number_Expr.new start
			expr.lexeme = eat(:number)
			if expr.lexeme.value.count('.') > 1
				expr                  = Code::Array_Index_Expr.new expr.lexeme
				expr.indices_in_order = expr.lexeme.value.split '.'
				expr.indices_in_order = expr.indices_in_order.map &:to_i
				# It's important not to convert number.value here to anything to preserve the variant number of dots in the string. I think this'll be cool syntax, 2d_array.1.2 would be the equivalent of 2d_array[1][2].
			elsif expr.lexeme.value.include? '.'
				expr.type  = :float
				expr.value = expr.value.to_f
			else
				expr.type  = :integer
				expr.value = expr.value.to_i
			end
			copy_location expr, start
		end

		# `left`, when given, is an identifier already parsed by the caller (e.g. #parse_enum_expr, which has to parse a member's name itself first to look ahead and decide which member form it's looking at) -- skips re-parsing it from the current position, which by then is already past it.
		def parse_nil_init_expr left = nil
			start = left&.lexeme || curr_lexeme

			expr          = Code::Nil_Init_Expr.new
			expr.lexeme   = start
			expr.left     = left || (curr?(SELF_KEYWORDS, '.') ? parse_self_prefixed_identifier : parse_identifier_expr)
			expr.operator = Lexeme.new(:operator, '=')

			nil_expr         = Code::Identifier_Expr.new
			nil_expr.value   = 'nil'
			nil_expr.kind    = :identifier
			nil_expr.privacy = Code.privacy_of_ident 'nil'
			expr.right       = nil_expr

			# The synthetic `nil` on the right never came from real source, so the true end of this
			# expression is wherever `expr.left` ends (which may extend past `start`'s own single
			# lexeme -- a tagged/typed left side, or a freshly-parsed one when `left` wasn't given).
			set_expr_location expr, start, expr.left
		end

		def parse_context_call context_ident, precedence
			member          = Code::Infix_Expr.new
			member.operator = Code::Lexeme.new(:operator, '.')
			member.left     = copy_location Code::Identifier_Expr.new(Code::CONTEXT_OPERATOR), context_ident
			member.right    = copy_location Code::Identifier_Expr.new(context_ident.value), context_ident
			copy_location member, context_ident

			paren    = curr?('(') && lexeme_adjacent?(context_ident.lexeme, curr_lexeme)
			bare_arg = lexemes? && !paren && !(curr?(:delimiter) && CONTEXT_ARG_TERMINATORS.include?(curr_lexeme.value))

			# note; A stack function (`@push_scope`, `@load`, ...) is never a capturable reference.
			bare_ref = !paren && !bare_arg && !Code::Context::STACK_FUNCTIONS.include?(context_ident.value)
			return complete_expression member, precedence if bare_ref

			call           = Code::Call_Expr.new
			call.receiver  = member
			closing        = context_ident
			call.arguments = if paren and eat '('
				args = []
				reduce_newlines
				until curr? ')'
					args << parse_expression
					eat if curr? ','
					reduce_newlines
				end
				closing = eat ')'
				args
			elsif bare_arg
				args = [parse_expression(precedence_for('for'))] # note; Precedence "for" allows for-loop as a postfix expression
				args << parse_expression(precedence_for('for')) while curr? ',' and eat ','
				closing = args.last
				args
			else
				[] # bare `@pop_scope` etc -- a 0-arg call
			end
			set_expr_location call, context_ident, closing
			complete_expression call, precedence
		end

		# `@operator <op> @infix <precedence> ( left, right; ... )` -- a genuine declaration form, not a
		# call. `start` is the just-parsed `@operator` identifier itself, so the whole declaration's
		# location can start there rather than at `<op>`, the second token.
		def parse_operator_overload start, precedence
			op_lexeme     = eat # the operator symbol/identifier itself -- not via parse_expression (custom fixity would misparse it)
			unless %i(operator identifier).include? op_lexeme.type
				raise "An operator can only be an :operator or :identifier. Your `#{op_lexeme.value}` is :#{op_lexeme.type}. Maybe it's reserved. todo; Better message!"
			end
			operator_expr = Code::Operator_Expr.new op_lexeme
			copy_location operator_expr, op_lexeme

			next_expr = begin_expression
			if next_expr.is_a?(Code::Identifier_Expr) && next_expr.prefixed_with_at && %w(prefix infix postfix circumfix).include?(next_expr.value)
				prec = if curr? '('
					precedence_for(operator_expr.value)
				else
					# A bare primitive parse -- the precedence is immediately followed by the overload's own func body `(left, right; ...)`, and parse_expression's call-continuation would swallow that `(`.
					Code.assert curr? :number
					parse_number_expr.value
				end
				unless prec.is_a? ::Numeric
					raise "an operator overload requires the following form:\n\n\t@operator <operator> @infix <precedence> (left, right; ...)\twhere <precedence> is optional."
				end

				overload            = Code::Operator_Overload_Expr.new operator_expr.lexeme
				overload.fixity     = next_expr.lexeme
				overload.precedence = prec
				overload.func_expr  = parse_func
				overload.value      = operator_expr.lexeme.value
				set_expr_location overload, start, overload.func_expr
				return complete_expression overload, precedence
			end

			complete_expression next_expr, precedence
		end

		# `Ident <...>` and an ordinary `<` comparison that just happens to start with a capitalized identifier (`X < Y`) are indistinguishable by lookahead alone -- rather than trying to enumerate every legitimate statement-ending token a struct's own member values could contain (`,` inside a member list is fine, but so is a `(`/`)`/`[`/`{}` nested inside one member's own default value), just attempt the real parse and see what happens. Saves the token position first; a syntax error anywhere in the attempt (ran out of tokens hunting for a `>` that was never coming, or any other `Parser#eat` mismatch) rewinds back to it, so the caller falls through to ordinary expression parsing (`X < Y` as a comparison) instead.
		def try_parse_struct
			saved_i = @i
			parse_struct
		rescue StandardError
			@i = saved_i
			nil
		end

		# Same speculative/backtracking approach as #try_parse_struct, for a nameless trailing `<...>` after a composition chain (#parse_type_decl's struct-composition case) rather than one following a bare type name.
		def try_parse_struct_body
			saved_i = @i
			start   = curr_lexeme
			Code::Struct_Expr.new.tap do |it|
				it.lexeme = Code::Lexeme.new :struct, '<>'
				it.types  = []
				it.names  = []
				eat '<'
				closing = parse_struct_members it
				set_expr_location it, start, closing
			end
		rescue StandardError
			@i = saved_i
			nil
		end

		# `>>`/`>>>`/etc are legitimate operators elsewhere (right-shift, `>>=`), but two or more `<...>` structs closing back-to-back (`Array\<String>>`) glue into that same token at the lexer level -- the same ambiguity C++ has with nested template brackets. Splits the current lexeme in place into that many separate `>` tokens whenever it's a pure run of `>` characters, so each nested #parse_struct call can close with its own ordinary `eat '>'`. A no-op on anything else (a lone `>`, or a real `>>=`/`>>` that isn't closing a struct at all), so callers can call it defensively before every `>` check without needing to know whether gluing actually happened here.
		def split_glued_close_angles!
			return unless curr_lexeme && curr_lexeme.value.is_a?(::String) && curr_lexeme.value.length > 1 && curr_lexeme.value.chars.all? { |char| char == '>' }

			glued  = curr_lexeme
			closes = glued.value.chars.each_index.map do |index|
				closer              = glued.dup
				closer.value        = '>'
				closer.column_start = glued.column_start + index
				closer.column_end   = closer.column_start
				closer
			end

			input[i, 1] = closes
		end

		def begin_expression precedence = STARTING_PRECEDENCE, member_rhs: false
			raise Code::Out_Of_Tokens.new(@last_expression) unless lexemes?

			if curr? :route
				parse_route_expr

			elsif curr?(ANY_IDENTIFIER, Code::NIL_INIT_POSTFIX) || curr?(SCOPE_KEYWORDS, '.', ANY_IDENTIFIER, Code::NIL_INIT_POSTFIX)
				parse_nil_init_expr

			elsif (curr?('(') || curr?(:identifier, '(') || curr?(:identifier, ':', '(') || curr?(SCOPE_KEYWORDS, '(') || curr?(SCOPE_KEYWORDS, '.', :identifier, '(') || curr?(SCOPE_KEYWORDS, '.', :identifier, ':', '(')) && func_declaration_follows? && (!member_rhs || curr?('('))
				parse_func

			elsif (curr?(TYPE_IDENTIFIER, '[') && bare_enum_declaration_follows?) || annotated_enum_declaration_follows?
				parse_enum_expr

			elsif curr?(TYPE_IDENTIFIER, '<') && (structured = try_parse_struct)
				structured

			elsif curr?('<') && curr_lexeme.type == :operator && !@custom_prefix.include?('<')
				parse_struct

			elsif curr?(TYPE_IDENTIFIER, '{') || curr?(TYPE_IDENTIFIER, TAG_OPERATOR, '<') || curr?(TYPE_IDENTIFIER, TAG_OPERATOR, TYPE_IDENTIFIER) || type_then_integer_tag_next? || curr?(TYPE_IDENTIFIER, TYPE_COMPOSITION_OPERATORS)
				# No trailing `{` guard needed for the named-reference form -- unlike `/`, `\` never collides with anything else in Code, so it's unambiguous with or without a body.
				parse_type_decl

			elsif curr?(TYPE_COMPOSITION_OPERATORS) && peek.is(:Identifier)
				parse_composition_expr

			elsif curr? 'for'
				parse_for_loop_expr

			elsif curr? %w(if while unless until)
				parse_conditional_expr

			elsif curr?(:identifier, ':', :Identifier) || curr?(ANY_IDENTIFIER) || curr?(CONTEXT_OPERATOR)
				parse_identifier_expr

			elsif curr?(%w( [ \( { |)) && curr?(:delimiter)
				# :absolute_value_circumfix
				parse_circumfix_expr opening: curr_lexeme.value

			elsif curr?(':', :identifier) || curr?(':', :Identifier) || curr?(':', :IDENTIFIER)
				parse_symbol_expr

			elsif curr? '%', PERCENT_LITERALS, '('
				parse_percent_literal_expr

			elsif curr? '`'
				parse_statement_expr

			elsif curr? '...'
				parse_callsite_splat

			elsif curr?(%w(.. ..<)) && curr?(:operator)
				parse_beginless_range_expr

			elsif curr? :operator
				parse_operator_expr

			elsif curr? :number
				parse_number_expr

			elsif curr? :string
				start = curr_lexeme
				expr  = Code::String_Expr.new eat(:string)
				copy_location expr, start

			elsif curr? ','
				# todo: Don't just discard the comma, make tuples implied when commas are found in #complete_expression
				eat and nil

			elsif curr? FUNCTION_DELIMITER
				raise Code::Reserved_Function_Delimiter.new curr_lexeme

			elsif curr?(:delimiter) && NEWLINES.include?(curr_lexeme.value)
				reduce_newlines and nil

			elsif curr? :html
				parse_html_expr

			elsif curr? :fence
				parse_fence_expr

			elsif curr? :comment
				parse_comment

			else
				raise "Unhandled lexeme: #{curr_lexeme.inspect}"
			end
		end

		def parse_expression precedence = STARTING_PRECEDENCE, member_rhs: false
			# 7/20/25, Unforunately, some other code depends on this being coupled with #complete_expression. That's okay for now, but lesson learned.
			#
			# 7/26/25, It's decoupled now but still kind of ugly. This is fine though, because it will allow me to handle any partial expressions. An example of a partial expression would be the code prior to an inline conditional:
			#
			#   /————\           <~ partial expression
			#   <code> if true
			#   \————————————/   <~ complete expression
			#

			expression = begin_expression precedence, member_rhs: member_rhs
			complete_expression expression, precedence, member_rhs: member_rhs
		end

		# todo: Factor out the various branches of code in here?
		def complete_expression expr, precedence = STARTING_PRECEDENCE, member_rhs: false
			return expr unless expr && lexemes?

			if !member_rhs && expr.is_a?(Code::Identifier_Expr) && expr.prefixed_with_at
				# `@name: T` / `@name := v` / `@name = v`
				context_member_decl = !%w(operator ruby).include?(expr.value) &&
				                      (expr.type || curr?('=') || curr?(':='))

				unless context_member_decl
					return parse_operator_overload(expr, precedence) if expr.value == 'operator'
					return parse_context_call(expr, precedence) if Code::Context::FUNCTIONS.include?(expr.value)
				end
			end

			# note; `PREFIX.include?(expr.value)` matches by VALUE, not by lexeme type -- deliberate, since
			# keyword-like prefixes (`return`, `not`) are lexed as plain identifiers, not a dedicated
			# operator type, so there's no `.type == :operator` to check for those. But that means a
			# String_Expr whose own CONTENT happens to collide with a prefix symbol (`'!'`, `'-'`, a
			# string literally spelled `'return'`) matched too -- `"hi".end_with?('!')` parsed `'!'` as
			# the `!` prefix operator applied to nothing, not the string value "!". A string's content
			# should never be reinterpreted as an operator, so it's excluded here regardless of value.
			prefix    = !expr.is_a?(Code::Operator_Overload_Expr) && !expr.is_a?(Code::String_Expr) && (PREFIX.include?(expr.value) || (expr.is_a?(Code::Operator_Expr) && @custom_prefix.include?(expr.value)))
			infix     = INFIX.include?(curr_lexeme.value) || @custom_infix.include?(curr_lexeme.value)
			postfix   = POSTFIX.include?(curr_lexeme.value) || @custom_postfix.include?(curr_lexeme.value)
			circumfix = CIRCUMFIX.include?(curr_lexeme.value)

			if prefix
				expr = Code::Prefix_Expr.new.tap do |it|
					it.operator   = expr
					it.expression = parse_expression precedence_for(it.operator.value)
					# `it.expression` can be nil -- a bare `return`/`not` with nothing following.
					set_expr_location it, it.operator, it.expression || it.operator
				end

				return complete_expression expr, precedence
			elsif infix
				if COMPOUND_OPERATORS.include? curr_lexeme.value
					# note: I seem to have forgotten this important check for precedence here. I'm sure there are other places todo
					curr_operator_prec = precedence_for curr_lexeme.value
					return expr if curr_operator_prec <= precedence

					it          = Code::Infix_Expr.new
					it.left     = expr
					it.operator = eat
					it.right    = parse_expression precedence_for it.operator.value
					it.right    = it.right.left if it.right.is_a? Code::Nil_Init_Expr

					set_expr_location it, expr, it.right
					return complete_expression it, precedence
				elsif RANGE_OPERATORS.include? curr_lexeme.value
					# A `.`/`.?` RHS is always a bare member name -- `a.b...c` is `(a.b)...c`, never `a.(b...c)`.
					return expr if member_rhs
					it = parse_endless_range_expr expr
					return complete_expression it, precedence
				else
					while (INFIX.include?(curr_lexeme.value) || @custom_infix.include?(curr_lexeme.value)) && curr?(:operator)
						# A `>>`/`>>>`/etc token might really be two or more `<...>` structs closing back-to-back (`Array\<String>>`), glued at the lexer level -- split it into individual `>` tokens whenever a lone `>` would stop this very loop anyway (i.e. we're already at or below `>`'s own precedence) AND we're actually somewhere inside a `<...>` struct right now. Both conditions matter: the precedence check alone would also misfire on an ordinary top-level `8 >> 2 >> 1` (that recurses into its own right-hand side at `>>`'s own high precedence, satisfying the precedence check on its own); gating on `@struct_nesting_depth` keeps a genuine `>>`/`>>=` completely unaffected everywhere outside a struct.
						split_glued_close_angles! if @struct_nesting_depth > 0 && curr_lexeme.value.length > 1 && curr_lexeme.value.chars.all? { |char| char == '>' } && precedence_for('>') <= precedence

						# It's very important that the curr?(:operator) check here remains because otherwise it breaks Code::Call_Expr when the receiver is an Code::Infix_Expr.
						curr_operator      = curr_lexeme.value
						curr_operator_prec = precedence_for curr_operator

						if curr_operator_prec <= precedence
							return expr
						end

						left          = expr
						expr          = Code::Infix_Expr.new
						expr.left     = left
						expr.operator = eat(curr_lexeme.value)
						expr.right    = if expr.operator.value == ':=' && curr?(TYPE_COMPOSITION_OPERATORS) && peek.is(:Identifier)
							# `x := |Compo` -- a composition chain used as a value, not #parse_expression's usual single bare Composition_Expr.
							parse_bare_composition_chain
						else
							parse_expression curr_operator_prec, member_rhs: DOT_ACCESS_OPERATORS.include?(expr.operator.value)
						end
						expr.right    = expr.right.left if expr.right.is_a? Code::Nil_Init_Expr

						if expr.left.is(Code::Identifier_Expr) && expr.operator.value == '.' && expr.right.is(Code::Number_Expr) && expr.right.type == :float
							# @copypaste from above #parse_expression when :number.
							number                  = Code::Array_Index_Expr.new expr.right.lexeme
							number.indices_in_order = expr.right.value.to_s.split '.'
							number.indices_in_order = number.indices_in_order.map &:to_i
							copy_location number, expr.right
							expr.right = number
						end

						set_expr_location expr, left, expr.right || expr.operator
						return complete_expression expr, precedence
					end
				end

			elsif postfix && precedence_for(curr_lexeme.value) > precedence
				expr = Code::Postfix_Expr.new.tap do |it|
					it.expression = expr
					it.operator   = eat(%i(operator identifier))
					set_expr_location it, it.expression, it.operator
				end
			end

			# `!func_declaration_follows?` matters here too, not just #begin_expression's own dispatch: any expression immediately followed by `(...)` looks like a call continuation regardless of what the receiver even is (a string, a number, ...), so `"endpoint" (;)` – an unrelated anonymous func literal on the same line – would otherwise get swallowed as a bogus call on the string instead of starting its own, separate top-level expression.
			#
			# Exception – the "spread lambda" sugar: a single anonymous-function argument may drop its own parens, `xs.map(x; x * 2)` for `xs.map((x; x * 2))`. Only when the receiver is a member access, a call result, or a subscript – shapes that are unambiguously a call target and can't be an accidental adjacent `(;)` literal (`"endpoint" (;)`) or a fresh `f(x; body)` declaration (#begin_expression's `member_rhs` path already kept the member name an identifier so we land here with the whole `x.foo` as `expr`).
			spread_receiver   = expr.is_a?(Code::Call_Expr) || expr.is_a?(Code::Subscript_Expr) || (expr.is_a?(Code::Infix_Expr) && expr.operator&.value == '.')
			spread_lambda_arg = curr?('(') && spread_receiver && anon_func_param_list_follows?
			call_expr         = curr?('(') && curr?(:delimiter) && (!func_declaration_follows? || spread_lambda_arg)
			subscript         = curr? '['
			if call_expr && (precedence_for(curr_lexeme.value) > precedence)
				receiver      = expr
				expr          = Code::Call_Expr.new
				expr.receiver = receiver
				closing       = if spread_lambda_arg
					func           = parse_func
					expr.arguments = [func]
					func
				else
					circumfix      = parse_circumfix_expr(opening: curr_lexeme.value)
					expr.arguments = circumfix.expressions
					circumfix
				end

				set_expr_location expr, receiver, closing
				return complete_expression expr, precedence
			elsif subscript && (precedence_for(curr_lexeme.value) > precedence)
				it            = Code::Subscript_Expr.new
				it.receiver   = expr
				it.expression = parse_circumfix_expr opening: curr_lexeme.value

				set_expr_location it, it.receiver, it.expression
				return complete_expression it, precedence
			end

			if curr? 'for'
				return expr if precedence_for(curr_lexeme.value) <= precedence

				# @paste from original For_Loop_Expr initialization, with modifications
				it        = Code::For_Loop_Expr.new
				it.lexeme = eat 'for'
				it.body   = [expr]

				lexemes = peek_until "\n"

				exactly_two_commas      = lexemes.count { _1.is(',') } == 2
				exactly_one_declaration = lexemes.count { _1.is(':=') } == 1
				valid_traditional_loop  = exactly_two_commas && exactly_one_declaration

				if valid_traditional_loop
					it.counter = parse_expression
					eat ','
					it.condition = parse_expression
					eat ','
					it.step = parse_expression

				else
					it.collection = parse_expression

					if curr? Code::FOR_VERBS and verb = eat
						it.type   = verb
						it.lexeme = verb
					end

					if curr? 'by' and eat 'by'
						it.stride = begin_expression
						# todo: Should I check that it's a number here? Yes.

						if curr? ',' and eat ','
							it.overlap = begin_expression
						end

					end
				end

				set_expr_location it, it.lexeme, (it.step || it.overlap || it.stride || it.collection)
				return complete_expression it, precedence
			end

			if curr?(%w(if while unless until))
				if precedence_for(curr_lexeme.value) <= precedence
					return expr
				end

				it            = Code::Conditional_Expr.new
				it.when_true  = []
				it.when_false = []
				it.type       = eat # One of %w(if while unless until)
				it_prec       = precedence_for it.type.value
				it.condition  = parse_expression
				it.when_true  = [expr]
				set_expr_location it, expr, it.condition
				return complete_expression it, precedence
			end

			expr
		end

	end
end
