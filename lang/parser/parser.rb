require_relative 'expression'

class Parser
	TYPE_COMPOSITION_OPERATORS = %w(| & - ^)
	ANY_IDENTIFIER             = %i(identifier Identifier IDENTIFIER)
	GROUPINGS                  = { '(' => '()', '{' => '{}', '[' => '[]', '|' => '||' }.freeze
	STARTING_PRECEDENCE        = 0
	PRECEDENCE_OFFSET          = 100

	attr_accessor :i, :input, :output

	def initialize input = []
		@input = input
		@i     = 0 # index of current token
	end

	def precedence_for2 operator
		precedence = STARTING_PRECEDENCE
		operators  = [
			%w(= >!!! >!! >! ./ ../ .../),
			%w(= == != === !==),
			%w(**),
			%w(.. .< >. ><), # RANGES
			%w(* / %),
			%w(+ -),
			%w(<< >>),
			%w(< <= <=> > >=),
			%w(| & - ^), # TYPE_COMPOSITION_OPERATORS
			%w(&& and),
			%w(|| or),
			%w(.),
			%w(+= -= *= /= %= &= |= ^= <<= >>=),
			%w(,),
			%w(.? ? : !),
		]

		operators.each do |ops|
			return precedence if ops.sort_by do
				-it.length
			end.include?(operator)
			precedence += PRECEDENCE_OFFSET
		end

		precedence
	end

	# Array of precedences and symbols for that precedence. if the token provided matches one of the operator symbols then its precedence is returned. Nice reference: https://rosettacode.org/wiki/Operator_precedence
	def precedence_for operator
		# higher number = tighter binding
		[
			[1000, %w(>!!! >!! >! ./ ../ .../)],
			[900, %w(**)], # exponentiation
			[800, %w(* / %)], # multiply, divide, modulo
			[700, %w(+ -)], # add, subtract
			[600, %w(<< >>)], # bitwise shifts
			[550, %w(< <= <=> > >=)], # relational
			[500, %w(== != === !==)], # equality
			[400, TYPE_COMPOSITION_OPERATORS], # bitwise AND (&), XOR (^), OR (|)
			[300, %w(&& and)], # logical AND
			[200, %w(|| or)], # logical OR (including keyword forms)
			[140, %w(: . !)], # member access, labels
			[100, %w(,)], # comma
			[90, %w(= += -= *= /= %= &= |= ^= <<= >>=)], # assignments
			[80, %w(.? ? : .. .< >. ><)]
		].each do |prec, ops|
			return prec if ops.sort_by { -it.length }.include?(operator)
		end

		STARTING_PRECEDENCE
	end

	# input[i - 1]
	def prev_expr
		input[[i - 1, 0].max]
	end

	# input[i]
	def curr_expr
		input[i]
	end

	# input[i..]
	def remainder
		input[i..]
	end

	def tokens?
		i < input.length
	end

	def reduce_newlines
		eat while tokens? && curr?(%W(\n \r))
	end

	def curr?(*sequence)
		return false unless remainder

		remainder.slice(0, sequence.count).each_with_index.all? do |token, index|
			pattern = sequence[index]

			if pattern.is_a?(Array)
				pattern.any? { |alt| token.is(alt) }
			else
				token.is(pattern)
			end
		end
	end

	def peek ahead = 1
		raise 'Parser.input is nil' unless input

		index = ahead.clamp(0, input.count)
		input[i + index]
	end

	def peek_until token = nil
		return remainder unless token

		remainder.slice_before do |t|
			if token.is_a? Token
				t.is token
			else
				t.value == token
			end
		end.to_a.first
	end

	def peek_contains? contains, stop_at_token = nil
		peek_until(stop_at_token).any? do |t|
			t.is contains
		end
	end

	# idea: support sequence of elements where an element can be one of many, like the sequence [IdentifierToken, [:=, =]]
	def eat * sequence
		raise "tried to eat #{sequence} but out of tokens" unless tokens?

		if sequence.nil? || sequence.empty? || sequence.one?
			eaten = curr_expr
			if sequence&.one? && !eaten.is(sequence[0])
				raise "#eat(#{sequence[0].inspect}) got #{eaten.value.inspect}), at #{curr_expr.inspect}, prev #{prev_expr.inspect}"
			end
			@i    += 1
			return eaten
		end
	end

	def parse_conditional_expr
		Conditional_Expr.new.tap do |it|
			it.type      = eat.value # %w(if while)
			it.condition = make_expression

			reduce_newlines
			until curr? %w(end else elsif elif ef elswhile)
				expr = make_expression
				it.when_true << expr if expr
			end

			if curr? %w(elsif elif elswhile elwhile)
				it.when_false = parse_conditional_expr

			elsif curr? 'else' and eat
				until curr? 'end'
					expr = make_expression
					it.when_false << expr if expr
				end
				eat 'end'

			elsif curr? %w(} end)
				eat

			else
				raise "\n\nYou messed your if/elsif/else up\n"
			end
		end
	end

	def parse_circumfix_expr opening: '('
		Circumfix_Expr.new.tap do |it|
			it.grouping = GROUPINGS[opening] or raise "parse_circumfix_expr unknown opening #{opening}"
			eat opening
			closing = it.grouping[1]

			until curr? closing
				it.expressions << make_expression(precedence_for(opening))
				break if curr? closing

				eat if curr? ','
				reduce_newlines
			end

			eat closing
			it.expressions = it.expressions.compact
		end
	end

	def parse_func precedence, named: false
		Func_Expr.new.tap do |expr|
			if curr? :identifier
				expr.name = eat(:identifier).value

				if curr? ':' and eat ':'
					expr.type = eat(:Identifier).value
				end
			end

			eat '{'
			reduce_newlines

			# func: Optional_Type { label param: Optional_Type = optional_expr, etc ; }
			until curr? ';'
				eat if curr? ','

				# name, label, type, default, portal
				param = Param_Decl.new

				if curr? :identifier, :identifier
					param.label = eat(:identifier).value
				end

				param.name = eat(:identifier).value
				if curr? ':' and eat ':'
					param.type = eat(:Identifier).value
				end

				if curr? '=' and eat '='
					param.default = make_expression
				end

				expr.param_decls << param

				# expect either , or ; or \n
				# raise "expected , ; or newline" unless curr? %W(, ; \n)

				# if curr? ','
				# 	eat
				# else
				# 	reduce_newlines
				# 	raise "ERROR expected , or ; when declaring " unless curr? %w(, ;)
				# end
				# eat if curr? ','
				# if !curr?(%W(; \n))
				# 	eat ','
				# end
				reduce_newlines
			end

			eat ';'
			reduce_newlines

			until curr? '}'
				statement = make_expression precedence
				expr.expressions << statement
			end

			expr.expressions = expr.expressions.compact
			eat '}'

		end
	end

	def parse_type_decl
		Type_Decl.new.tap do |decl|
			decl.identifier = eat(:Identifier).value

			until curr? '{'
				if curr?(TYPE_COMPOSITION_OPERATORS) # these could be in begin_expr's if-statment but
					decl.composition_exprs << Composition_Expr.new.tap do
						it.operator   = eat(:operator).value
						it.expression = eat(:Identifier).value
					end
				end
			end

			eat '{'

			until curr? '}'
				decl.expressions << make_expression
				if decl.expressions.last.is_a? Composition_Expr
					decl.composition_exprs << decl.expressions.pop
				end
			end

			decl.expressions       = decl.expressions.compact
			decl.composition_exprs = decl.composition_exprs.compact

			eat '}'
		end
	end

	def make_expression precedence = STARTING_PRECEDENCE
		expression = if (curr?('{') || curr?(:identifier, '{') || curr?(:identifier, ':', :Identifier, '{')) && peek_contains?(';', '}')
			parse_func precedence, named: curr?(:identifier)

		elsif curr?(:Identifier, '{') || curr?(:Identifier, TYPE_COMPOSITION_OPERATORS, :Identifier)
			parse_type_decl

		elsif curr?(TYPE_COMPOSITION_OPERATORS) && peek.is(:Identifier)
			Composition_Expr.new.tap do
				it.operator   = eat(:operator).value
				it.expression = eat(:Identifier).value
			end

		elsif curr? %w(if while)
			parse_conditional_expr

		elsif curr? :identifier, ':', :identifier
			raise "SYNTAX ERROR cannot have a type that is not capitalized, meaning a Type versus variable or function"

		elsif curr?(:identifier, ':', :Identifier)
			Identifier_Expr.new(eat.value).tap do
				eat ':'
				it.type = eat(:Identifier).value
			end

		elsif curr? ANY_IDENTIFIER
			Identifier_Expr.new eat.value

		elsif curr? %w( [ \( { |)
			parse_circumfix_expr opening: curr_expr.value

		elsif curr? :operator
			Operator_Expr.new eat(:operator).value

		elsif curr? :number
			Number_Expr.new eat(:number).value

		elsif curr? :string
			String_Expr.new eat(:string).value

		elsif curr? :delimiter
			reduce_newlines

		else
			raise "Unhandled token: #{curr_expr.inspect}"
		end

		modify_expression expression, precedence
	end

	def modify_expression expr, precedence = STARTING_PRECEDENCE
		return expr unless expr && tokens?

		if curr_expr.is ','
			eat and return expr
		end

		# Handle specific shorthand assigments such as +=, -=, etc by swapping operators and nesting Infix_Exprs: a += b becomes a = a + b

		if Lexer::INFIX.include?(curr_expr.value) && peek.is('=')
			actual_operator = eat.value # one of the ::INFIXes
			expr            = Infix_Expr.new.tap do |left|
				left.left     = expr
				left.operator = eat.value
				raise "UHOH" unless left.operator == '='
				left.right = Infix_Expr.new.tap do |right|
					right.left     = expr
					right.operator = actual_operator
					right.right    = make_expression
				end
			end
			return modify_expression expr, precedence
		end

		# The three scope identifiers are parsed here, ./, ../, and .../

		if expr.is('.') && curr_expr.is('/')
			eat '/'
			expr          = Prefix_Expr.new
			expr.operator = './'
			raise "./ must be followed by one of #{ANY_IDENTIFIER}" unless curr? ANY_IDENTIFIER
			expr.expression = make_expression
			return modify_expression expr, precedence
		elsif expr.is('.') && curr_expr.is('.') && peek.is('/')
			eat '.'
			eat '/'
			expr          = Prefix_Expr.new
			expr.operator = '../'
			raise "../ must be followed by one of #{ANY_IDENTIFIER}" unless curr? ANY_IDENTIFIER
			expr.expression = make_expression
			return modify_expression expr, precedence
		elsif expr.is('.') && curr_expr.is('.') && peek.is('.') && peek(2).is('/')
			eat '.'
			eat '.'
			eat '/'
			expr          = Prefix_Expr.new
			expr.operator = '.../'
			raise ".../ must be followed by one of #{ANY_IDENTIFIER}" unless curr? ANY_IDENTIFIER
			expr.expression = make_expression
			return modify_expression expr, precedence
		end

		if curr? '(' and eat '('
			expr = Call_Expr.new(expr).tap do
				until curr? ')'
					it.arguments << Param_Expr.new.tap do |arg|
						if curr? :identifier, ':'
							arg.label = eat(:identifier).value
							eat ':'
						end

						arg.expression = make_expression
					end

					eat if curr? ','
				end

				eat ')'
			end
			return modify_expression expr, precedence
		end

		prefix  = Lexer::PREFIX.include?(expr.value)
		infix   = curr?(:operator) && Lexer::INFIX.include?(curr_expr.value)
		infix   ||= expr.is(:number) && (peek.is(:identifier) || peek.is(:IDENTIFIER))
		postfix = Lexer::POSTFIX.include?(curr_expr.value)

		if prefix
			expr = Prefix_Expr.new.tap do
				it.operator   = expr.value
				it.expression = make_expression
			end

			unless expr.expression
				raise "Prefix_Expr expected an expression after `#{expr.operator}`"
			end

		elsif infix
			while curr?(:operator) && Lexer::INFIX.include?(curr_expr.value)
				curr_operator_prec = precedence_for(curr_expr.value)
				raise "Unknown precedence for infix operator #{curr_expr.inspect}" unless curr_operator_prec

				return expr if curr_operator_prec <= precedence

				expr = Infix_Expr.new.tap do
					it.left     = expr
					it.operator = eat.value
					it.right    = make_expression curr_operator_prec

					unless it.right
						raise "it.right is nil\n\nexpr: #{it.inspect}\ncurr: #{curr_expr.inspect}"
					end
					# end
				end

				return modify_expression expr, precedence
			end

		elsif postfix
			expr = Postfix_Expr.new.tap do
				_1.expression = expr
				_1.operator   = eat(:operator).value
			end

		end

		# if curr?('{') && peek_contains?(';', '}')
		#! todo passing a block
		# end

		expr
	end

	def output
		output = []
		while tokens?
			output << make_expression
		end
		output.compact
	end
end
