require_relative 'air'

class Parser
	attr_accessor :i, :input

	def initialize input = []
		@input = input
		@i     = 0 # index of current lexeme
	end

	def output
		expressions = []
		while lexemes?
			expressions << parse_expression
		end
		expressions.compact
	end

	# Array of precedences and symbols for that precedence. if the lexeme provided matches one of the operator symbols then its precedence is returned. Nice reference: https://rosettacode.org/wiki/Operator_precedence
	def precedence_for operator
		# todo, This is ugly. Maybe a case/when?
		# higher number = tighter binding
		[
			[1200, %w(. .?)],
			[1100, %w([ { \( )],
			[1000, %w(! not)], # exponentiation
			[900, %w(**)], # exponentiation
			[800, %w(* / %)], # multiply, divide, modulo
			[700, %w(+ -)], # add, subtract
			[600, %w(<< >>)], # bitwise shifts
			[550, %w(< <= <=> > >=)], # relational
			[500, %w(== != === !==)], # equality
			[400, %w(| & - ^)], # bitwise AND (&), XOR (^), OR (|)
			[300, %w(&& and)], # logical AND
			[200, %w(|| or)], # logical OR (including keyword forms)
			[140, %w(:)], # member access, labels
			[100, %w(,)], # comma
			[90, %w(= += -= *= /= %= &= |= ^= <<= >>=)], # assignments
			[80, %w(.. .< >. ><)], # ranges
			[70, %w(return)],
			[60, %w(unless if while until)],
		].each do |prec, ops|
			return prec if ops.sort_by(&SORT_BY_LENGTH_DESC).include?(operator)
		end

		STARTING_PRECEDENCE
	end

	# input[i - 1]
	def prev_lexeme
		input[[i - 1, 0].max]
	end

	# input[i]
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
		eat while lexemes? && curr?(%W(\n \r))
	end

	def curr?(*sequence)
		return false unless remainder && lexemes?
		return false if sequence.count > remainder.count

		slice = remainder.slice(0, sequence.count)
		slice.each_with_index.all? do |lexeme, index|
			expected = sequence[index]

			if expected.is_a?(Array)
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

		remainder.slice_before do |t|
			if lexeme.is_a? Air::Lexeme
				t.is lexeme
			else
				t.value == lexeme
			end
		end.to_a.first
	end

	def peek_contains? contains, stop_at_lexeme = nil
		peek_until(stop_at_lexeme).any? do |t|
			t.is contains
		end
	end

	# idea: support sequence of elements where an element can be one of many, like the sequence [IdentifierToken, [:=, =]]
	def eat * sequence
		raise "tried to eat #{sequence} but out of lexemes" unless lexemes?

		if sequence.nil? || sequence.empty? || sequence.one?
			eaten = curr_lexeme
			if sequence&.one? && !eaten.is(sequence[0])
				raise "Parser#eat ate #{eaten.value.inspect} but expected #{sequence[0].inspect}"
			end
			@i    += 1
			return eaten
		end
	end

	def parse_for_loop_expr
		# TODO :incomplete
		eat 'for'
		it = For_Loop_Expr.new

		#
		# for expr
		# for expr by integer
		#
		# for ident in expr # it.custom_identifier is the ident
		# for ident in expr by integer
		#

		it.iterable = begin_expression # todo, Assert iterable is composed with Iterable, or has the same shape as Iterable.
		reduce_newlines

		it.body = []
		until curr? 'end'
			it.body << parse_expression
		end

		# if curr? :identifier, 'in'
		# 	# for ident in expr
		# 	# for ident in expr by integer
		# else
		# 	# for expr
		# 	# for expr by integer
		# end

		it
	end

	def parse_conditional_expr
		it            = Conditional_Expr.new
		it.type       = eat.value # One of %w(if while unless until)
		it.condition  = parse_expression
		it.when_true  = []
		it.when_false = []
		reduce_newlines

		# @clean

		until curr? %w(end else elif elwhile)
			expr = parse_expression
			it.when_true << expr if expr
			reduce_newlines
		end

		if curr? %w(elif elwhile)
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
			raise "\n\nYou messed your if/elif/else up\n"
		end
		it
	end

	def parse_circumfix_expr opening: '('
		it = Circumfix_Expr.new
		it.grouping = CIRCUMFIX_GROUPINGS[opening] or raise "parse_circumfix_expr unknown opening #{opening}"
		eat opening
		reduce_newlines
		closing = it.grouping[1]

		until curr? closing
			it.expressions << parse_expression
			break if curr? closing

			eat if curr? ','
			reduce_newlines
		end

		eat closing
		it.expressions = it.expressions.compact
		it
	end

	def parse_func precedence = STARTING_PRECEDENCE, named: false
		func = Func_Expr.new

		if curr? :identifier
			func.name = eat(:identifier)

			if curr? ':' and eat ':'
				func.type = eat(:Identifier)
			end
		end

		eat '{'
		reduce_newlines

		until curr? ';'
			param = Param_Expr.new

			if curr? :identifier, :identifier
				param.label = eat(:identifier).value
				param.name  = eat(:identifier).value
			else
				param.name = eat(:identifier).value
			end

			if curr? ':' and eat ':'
				param.type = eat(:Identifier)
			end

			if curr? '=' and eat '='
				param.default = parse_expression
			end

			if param.default.is_a?(Postfix_Expr) && param.default.operator == ';'
				param.default = param.default.expression
				func.expressions << param
				break
			end

			func.expressions << param
			eat if curr? ','
			reduce_newlines
		end

		eat ';' if curr? ';'
		reduce_newlines

		until curr? '}'
			statement = parse_expression
			func.expressions << statement
		end

		func.expressions = func.expressions.compact.uniq # bug, The first Param is twice in the array, with the same object_id. Dedupe it for now. Figure out the real issue later.
		eat '}'

		func
	end

	def parse_type_decl
		# bug, When parsing `Identifier {;}`. :Identifier_function
		# todo, The | TYPE_COMPOSITION_OPERATOR is currently only working in #parse_type_decl. I can peek until end of line, if I see another | then it's a circumfix. However if there are more |s then maybe we can presume the expression type like this:
		#
		#   1 | = composition
		#   2 | = circumfix
		#   3+ odd probably  = composition
		#   3+ even probably = circumfix
		#
		#   :absolute_value_circumfix
		#

		valid_idents = %I(Identifier IDENTIFIER)
		it           = Type_Expr.new
		it.name      = eat

		until curr? '{'
			if curr?(TYPE_COMPOSITION_OPERATORS, ANY_IDENTIFIER)
				it.expressions << parse_composition_expr
			end
		end

		eat '{'

		until curr? '}'
			it.expressions << parse_expression
		end

		it.expressions = it.expressions.compact

		eat '}'
		it
	end

	def parse_html_expr
		# TODO: Should attributes and data attributes be filtered out of @expressions and into their own attr like :attributes, :data_attributes, etc?
		# TODO: :html_vs_type_expr

		eat '<'
		it = Html_Element_Expr.new eat
		eat '>'

		eat '{'
		it.expressions = []
		until curr? '}'
			it.expressions << parse_expression
		end

		it.expressions.compact!
		# TODO: Print a warning if a `render` function isn't declared?

		eat '}'
		it
	end

	def parse_composition_expr
		expr = Composition_Expr.new

		# You might notice that whenever I eat(:identifier), I don't extract just the value because I want to store the Token. But in the case of an operator, the string is probably fine?
		expr.operator   = eat(:operator).value
		expr.identifier = parse_identifier_expr
		expr
	end

	def parse_identifier_expr
		expr = Identifier_Expr.new
		if curr? REFERENCE_PREFIX
			expr.reference = true
			eat REFERENCE_PREFIX
		elsif curr? DIRECTIVE_PREFIX
			expr.directive = true
			eat DIRECTIVE_PREFIX
		elsif curr? SCOPE_OPERATORS
			expr.scope_operator = parse_manual_scope
		end

		expr.value = eat.value

		# 7/20/25, I'm storing the type as well, even though I haven't written any code to support types yet.

		if curr?(':', :Identifier)
			eat ':'
			expr.type = eat(:Identifier)
		end

		expr.kind = Air.type_of_identifier expr.value
		expr
	end

	#   Manual scoping notes.
	#   Expected tokens: [<one or chain of SCOPE_OPERATORS>, <one of ANY_IDENTIFIER>]
	#   ——————————————————————————————————————————
	#   ./year      ../MODE     .../whatever(4, 8)
	#   ./Atom      ../name     .../whatever + 15
	#   ./VERSION   ../String   .../Array(16, 23)
	#   —————————————————————————————————————————
	#
	#   ✅   ./            current instance's scope
	#   ✅   ../           relative scope, chainable
	#   ✅   .../          global scope, aka bottom of the stack
	#
	#   ✅   ../../        begins the chain at whatever scope is on on top of the stack
	#   ✅   ./../../      begins the chain at the current instance
	#
	#   ❌   .../../../      cannot start with .../
	#   ❌   ../../.../      cannot end with .../
	#   ❌   ../.././        cannot end with ./
	#
	def parse_manual_scope
		scope = eat.value

		if scope == '../'
			# It would be interesting to climb the stack like "../../../thing.whatever", especially if debugging.
			while curr? '../'
				scope += eat('../').value
			end
		end

		if curr?(SCOPE_OPERATORS) || !curr?(ANY_IDENTIFIER)
			# There should not be any more scope operators at this point. We've implicitly handled ./ and .../, and explicitly handled chains of ../ so it's either malformed or something
			raise Invalid_Scoped_Identifier, "#{scope.inspect} with next token: #{curr_lexeme.inspect}"
		end

		scope
	end

	def parse_symbol_expr
		eat ':'
		Symbol_Expr.new eat.value.to_sym
	end

	def parse_route_expr
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
		handler = parse_func

		# Validate: handler params must include all route params
		handler_params = handler.expressions
		                 .select { |expr| expr.is_a?(Param_Expr) }
		                 .map(&:name)

		missing_params = param_names - handler_params
		unless missing_params.empty?
			# todo: Add this error to lib/shared/errors.rb
			raise "Route parameters #{missing_params.inspect} not found in handler parameters"
		end

		route             = Route_Expr.new
		route.http_method = Identifier_Expr.new.tap do |expr|
			expr.value = http_method
			expr.kind  = :identifier
		end
		route.path        = path_string
		route.expression  = handler
		route.param_names = param_names

		route
	end

	def parse_operator_expr
		# A method just for this might seem silly, but I thought the same when I decided #make_expr should be a giant method. This will help in the long run, and consistency is key to keeping this maintainable.
		Operator_Expr.new eat(:operator).value
	end

	def parse_number_expr
		expr       = Number_Expr.new
		expr.value = eat(:number).value
		if expr.value.count('.') > 1
			expr                  = Array_Index_Expr.new expr.value
			expr.indices_in_order = expr.value.split '.'
			expr.indices_in_order = expr.indices_in_order.map &:to_i
			# It's important not to convert number.value here to anything to preserve the variant number of dots in the string. I think this'll be cool syntax, 2d_array.1.2 would be the equivalent of 2d_array[1][2].
		elsif expr.value.include? '.'
			expr.type  = :float
			expr.value = expr.value.to_f
		else
			expr.type  = :integer
			expr.value = expr.value.to_i
		end
		expr
	end

	def parse_nil_init_postfix_expr
		expr            = Postfix_Expr.new
		expr.expression = parse_identifier_expr # eat # identifier
		expr.operator   = eat.value
		expr
	end

	def begin_expression precedence = STARTING_PRECEDENCE
		raise Out_Of_Tokens unless lexemes?

		if curr? :route
			parse_route_expr

		elsif curr? ANY_IDENTIFIER, ';'
			parse_nil_init_postfix_expr

		elsif (curr?('{') || curr?(:identifier, '{') || curr?(:identifier, ':', :Identifier, '{')) && peek_contains?(';', '}')
			parse_func precedence, named: curr?(:identifier)

		elsif curr?(:Identifier, '{') || curr?(:Identifier, TYPE_COMPOSITION_OPERATORS) || \
		      (curr?(:IDENTIFIER, '{') && curr_lexeme.value.length == 1)
			# To be able to treat one-letter identifiers as types, I special-case IDENTIFIERS of length 1 in the conditional for this elsif clause.
			parse_type_decl

		elsif curr?(TYPE_COMPOSITION_OPERATORS) && peek.is(:Identifier)
			parse_composition_expr

		elsif curr? 'for'
			# TODO :incomplete
			parse_for_loop_expr

		elsif curr? %w(if while unless until)
			parse_conditional_expr

		elsif curr?(:identifier, ':', :Identifier) || curr?(ANY_IDENTIFIER) || curr?(REFERENCE_PREFIX, :identifier) || curr?(SCOPE_OPERATORS) || curr?(DIRECTIVE_PREFIX, :identifier)
			parse_identifier_expr

		elsif curr?('<', ANY_IDENTIFIER, '>')
			parse_html_expr

		elsif curr? %w( [ \( { |)
			# :absolute_value_circumfix
			parse_circumfix_expr opening: curr_lexeme.value

		elsif curr?(':', :identifier) || curr?(':', :Identifier) || curr?(':', :IDENTIFIER)
			parse_symbol_expr

		elsif curr? :operator
			parse_operator_expr

		elsif curr? :number
			parse_number_expr

		elsif curr? :string
			String_Expr.new eat(:string).value

		elsif curr? ';'
			eat ';' and nil

		elsif curr? :delimiter
			reduce_newlines

		elsif curr? :comment
			# 8/6/25, Returning the comment here means that it will count as an expression in, for example, a case where a comment is the last thing inside a function body. So this breaks expressions with comments at the end. I'll leave this here, commented out, because I do want to do something with these comments in the future.
			# token        = eat
			# comment      = Comment_Expr.new token.value
			# comment.type = token.type
			# comment
			eat and nil

		else
			raise "Unhandled lexeme: #{curr_lexeme.inspect}"
		end
	end

	def parse_expression precedence = STARTING_PRECEDENCE
		# 7/20/25, Unforunately, some other code depends on this being coupled with #complete_expression. That's okay for now, but lesson learned.
		#
		# 7/26/25, It's decoupled now but still kind of ugly. This is fine though, because it will allow me to handle any partial expressions. An example of a partial expression would be the code prior to an inline conditional:
		#
		#   /————\           <~ partial expression
		#   <code> if true
		#   \————————————/   <~ complete expression
		#

		expression = begin_expression precedence
		complete_expression expression, precedence
	end

	# todo: Factor out the various branches of code in here?
	def complete_expression expr, precedence = STARTING_PRECEDENCE
		return expr unless expr && lexemes?

		if curr_lexeme.is(',')
			eat and return expr
		end

		if expr.is_a?(Identifier_Expr) && expr.directive
			directive            = Directive_Expr.new
			directive.name       = expr
			directive.expression = begin_expression

			return complete_expression directive, precedence
		end

		scope_prefix = %w(./ ../ .../).find do |it|
			expr.is it
		end

		if scope_prefix
			next_expr = begin_expression
			if next_expr.is_a? Infix_Expr
				expr            = Prefix_Expr.new
				expr.operator   = scope_prefix
				expr.expression = next_expr
			end
		end

		prefix    = PREFIX.include? expr.value
		infix     = INFIX.include? curr_lexeme.value
		postfix   = POSTFIX.include? curr_lexeme.value
		circumfix = CIRCUMFIX.include? curr_lexeme.value

		if prefix
			expr = Prefix_Expr.new.tap do |it|
				it.operator   = expr.value
				it.expression = parse_expression precedence_for(it.operator)
			end

			unless expr.expression
				raise "Prefix_Expr expected an expression after `#{expr.operator}`"
			end

			return complete_expression expr, precedence
		elsif infix
			if COMPOUND_OPERATORS.include? curr_lexeme.value
				it          = Infix_Expr.new
				it.left     = expr
				it.operator = eat.value
				it.right    = parse_expression precedence_for it.operator
				return complete_expression it, precedence
			elsif RANGE_OPERATORS.include? curr_lexeme.value
				it          = Infix_Expr.new
				it.left     = expr
				it.operator = eat.value
				it.right    = parse_number_expr
				return complete_expression it, precedence
			else
				while INFIX.include?(curr_lexeme.value) && curr?(:operator)
					# It's very important that the curr?(:operator) check here remains because otherwise it breaks Call_Expr when the receiver is an Infix_Expr.
					curr_operator      = curr_lexeme.value
					curr_operator_prec = precedence_for curr_operator

					if curr_operator_prec <= precedence
						return expr
					end

					left          = expr
					expr          = Infix_Expr.new
					expr.left     = left
					expr.operator = eat(curr_lexeme.value).value
					expr.right    = parse_expression curr_operator_prec

					if expr.left.is(Identifier_Expr) && expr.operator == '.' && expr.right.is(Number_Expr) && expr.right.type == :float
						# Copypaste from above #parse_expression when :number.
						number                  = Array_Index_Expr.new expr.right.value.to_s
						number.indices_in_order = number.value.split '.'
						number.indices_in_order = number.indices_in_order.map &:to_i
						expr.right              = number
					end

					return complete_expression expr, precedence
				end
			end

		elsif postfix
			expr = Postfix_Expr.new.tap do |it|
				it.expression = expr
				it.operator   = eat(:operator).value
			end
		end

		call_expr = curr? '('
		subscript = curr? '['
		if call_expr && (precedence_for(curr_lexeme.value) > precedence)
			receiver       = expr
			fix            = parse_circumfix_expr opening: curr_lexeme.value
			expr           = Call_Expr.new
			expr.receiver  = receiver
			expr.arguments = fix.expressions
			return complete_expression expr, precedence
		elsif subscript
			it            = Subscript_Expr.new
			it.receiver   = expr
			it.expression = parse_circumfix_expr opening: curr_lexeme.value
			it
			return complete_expression it, precedence
		end

		if curr?(%w(if while unless until))
			if precedence_for(curr_lexeme.value) <= precedence
				return expr
			end

			it           = Conditional_Expr.new
			it.type      = eat.value # One of %w(if while unless until)
			it_prec      = precedence_for it.type
			it.condition = parse_expression
			if %w(unless until).include? it.type
				it.when_false = [expr]
			else
				it.when_true = [expr]
			end
			return complete_expression it, precedence
		end

		expr
	end

end
