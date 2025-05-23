require_relative 'expression'

class Parser
	TYPE_COMPOSITION_OPERATORS = %w(| & - ^)
	ANY_IDENTIFIER             = %i(identifier Identifier IDENTIFIER)
	GROUPINGS                  = { '(' => '()', '{' => '{}', '[' => '[]' }.freeze
	STARTING_PRECEDENCE        = 0

	attr_accessor :i, :input

	def initialize input = []
		@input = input
		@i     = 0 # index of current token
	end

	# Array of precedences and symbols for that precedence. if the token provided matches one of the operator symbols then its precedence is returned. Nice reference: https://rosettacode.org/wiki/Operator_precedence
	def precedence_for(operator)
		# higher number = tighter binding
		[
			[1000, %w(>!!! >!! >! ./ ../ .../)],
			[900, %w(**)], # exponentiation
			[800, %w(* / %)], # multiply, divide, modulo
			[700, %w(+ -)], # add, subtract
			[600, %w(<< >>)], # bitwise shifts
			[550, %w(< <= > >=)], # relational
			[500, %w(== != === !==)], # equality
			[400, TYPE_COMPOSITION_OPERATORS], # bitwise AND (&), XOR (^), OR (|)
			[300, %w(&& and)], # logical AND
			[200, %w(|| or)], # logical OR (including keyword forms)
			[140, %w(: .)], # member access, labels
			[120, %w(= += -= *= /= %= &= |= ^= <<= >>=)], # assignments
			[100, %w(,)], # comma
			[80, %w(.? ? : .. .< >. >< !)]
		].each do |prec, ops|
			return prec if ops.sort_by { -it.length }.include?(operator)
		end

		STARTING_PRECEDENCE
	end

	# input[i - 1]
	def prev
		input[[i - 1, 0].max]
	end

	# input[i]
	def curr
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
				t.is_a? token
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
			eaten = curr
			if sequence&.one? && !eaten.is(sequence[0])
				raise "#eat(#{sequence[0].inspect}) got #{eaten.value.inspect}), at #{curr.inspect}, prev #{prev.inspect}"
			end
			@i    += 1
			return eaten
		end
	end

	def parse_conditional_expr
		Conditional_Expr.new.tap do |it|
			it.type      = eat.value # %w(if while)
			it.condition = begin_expression

			reduce_newlines
			until curr? %w(end else elsif elif ef elswhile)
				expr = begin_expression
				it.when_true << expr if expr
			end

			if curr? %w(elsif elif elswhile elwhile)
				it.when_false = parse_conditional_expr

			elsif curr? 'else' and eat
				until curr? 'end'
					expr = begin_expression
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
				it.expressions << begin_expression(precedence_for(opening))
				break if curr? closing

				eat ','
				reduce_newlines
			end

			eat closing
		end
	end

	def parse_func precedence, named: false
		Func_Expr.new.tap do |expr|
			if named
				expr.name = eat(:identifier).value

				if curr? ':' and eat ':'
					expr.type = eat(:Identifier).value
				end
			end

			eat '{' and reduce_newlines

			until curr? ';'
				expr.param_decls << Param_Decl.new.tap do |decl|
					if curr?(:identifier, :identifier)
						decl.label = eat(:identifier).value
					end

					decl.name = eat(:identifier).value

					if curr? '=' and eat '='
						decl.default = begin_expression
					end

					eat ',' if curr? ','
					reduce_newlines
				end
			end

			eat ';'
			reduce_newlines

			until curr? '}'
				statement = begin_expression precedence
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
				decl.expressions << begin_expression
			end

			decl.expressions = decl.expressions.compact
			# decl.composition_exprs << decl.composition_exprs.compact

			eat '}'
		end
	end

	def begin_expression precedence = STARTING_PRECEDENCE
		expression = if curr?('{') && !peek_contains?(';', '}')
			Dict_Expr.new.tap do |expr|
				eat '{' and reduce_newlines
				until curr? '}'
					separators = %w(: =) # any %w(: =) any
					entry      = begin_expression
					raise "must use : or = for #{entry.inspect}" unless entry.is_a?(Infix_Expr) && separators.include?(entry.operator)

					expr.expressions << entry
					eat ',' if curr? ','
					reduce_newlines
				end

				eat '}'
			end

		elsif curr? %w( [ \( )
			# todo generalize { as well
			parse_circumfix_expr opening: curr.value

		elsif (curr?('{') || curr?(:identifier, '{')) && peek_contains?(';', '}')
			parse_func precedence, named: curr?(:identifier)

		elsif curr?(:Identifier, '{') || curr?(:Identifier, TYPE_COMPOSITION_OPERATORS, :Identifier)
			parse_type_decl

		elsif curr?(TYPE_COMPOSITION_OPERATORS) && peek == :Identifier
			Composition_Expr.new.tap do
				it.operator   = eat(:operator).value
				it.expression = eat(:Identifier).value
			end

		elsif curr? %w(if while)
			parse_conditional_expr

		elsif curr?(:number) && (peek.is(:identifier) || peek.is(:IDENTIFIER))
			Infix_Expr.new.tap do
				it.left     = eat.value
				it.operator = '*'
				it.right    = begin_expression
				unless it.right
					raise "it.right is nil? #{it.right.inspect} at (#{it.start_location}:#{it.end_location}). curr #{curr}"
				end
			end

		elsif curr? ANY_IDENTIFIER
			Identifier_Expr.new eat.value

		elsif curr? :operator
			Operator_Expr.new eat(:operator).value

		elsif curr? :number
			Number_Expr.new eat(:number).value

		elsif curr? :string
			String_Expr.new eat(:string).value

		elsif curr? :delimiter
			reduce_newlines and nil

		else
			raise "Unhandled token: #{curr.inspect}"
		end

		aug expression, precedence
	end

	def aug expr, precedence = STARTING_PRECEDENCE
		return expr unless expr && tokens?

		if expr.value == '.' && curr.is('/') # ./ like self in Ruby
			eat '/'
			expr          = Prefix_Expr.new
			expr.operator = './'
			raise "./ must be followed by one of #{ANY_IDENTIFIER}" unless curr? ANY_IDENTIFIER
			expr.expression = Identifier_Expr.new(eat.value)
			return aug expr, precedence
		elsif expr.value == '.' && curr.is('.') && peek.is('/') # ../ global scope
			eat '.'
			eat '/'
			expr          = Prefix_Expr.new
			expr.operator = '../'
			raise "../ must be followed by one of #{ANY_IDENTIFIER}" unless curr? ANY_IDENTIFIER
			expr.expression = Identifier_Expr.new(eat.value)
			return aug expr, precedence
		elsif expr.value == '.' && curr.is('.') && peek.is('.') && peek(2).is('/') # .../ 3rd_party/libs
			eat '.'
			eat '.'
			eat '/'
			expr          = Prefix_Expr.new
			expr.operator = '.../'
			raise ".../ must be followed by one of #{ANY_IDENTIFIER}" unless curr? ANY_IDENTIFIER
			expr.expression = Identifier_Expr.new(eat.value)
			return aug expr, precedence
		end

		prefix  = Lexer::PREFIX.include?(expr.value)
		infix   = curr?(:operator) && Lexer::INFIX.include?(curr.value)
		postfix = Lexer::POSTFIX.include?(curr.value)

		if prefix
			expr = Prefix_Expr.new.tap do
				it.operator   = expr.value
				it.expression = begin_expression precedence_for(expr.value)
			end

			unless expr.expression
				raise "Prefix_Expr expected an expression after `#{expr.operator}`"
			end

			return aug expr, precedence

		elsif infix
			while curr?(:operator) && Lexer::INFIX.include?(curr.value)
				curr_operator_prec = precedence_for(curr.value)
				raise "Unknown precedence for infix operator #{curr.inspect}" unless curr_operator_prec

				return expr if curr_operator_prec <= precedence

				expr = Infix_Expr.new.tap do
					it.left     = expr
					it.operator = eat.value
					it.right    = begin_expression curr_operator_prec
					unless it.right
						raise "Infix_Expr expected an expression after `#{it.operator.inspect}` (#{it.operator.line}:#{it.operator.line})"
					end
				end
			end

		elsif postfix
			if curr? ':', :Identifier
				eat ':'
				expr.type = eat(:Identifier).value
			else
				expr = Postfix_Expr.new.tap {
					_1.expression = expr
					_1.operator   = eat(:operator).value
				}
			end

			return aug expr, precedence

		end

		# if curr? '(' and eat '('
		# 	expr = Call_Expr.new.tap do
		# 		# :receiver, :arguments
		# 		_1.receiver  = expr
		# 		_1.arguments = []
		#
		# 		until curr? ')'
		# 			_1.arguments << Param_Expr.new.tap do |arg|
		# 				if curr? Identifier_Token, ':' #, Token
		# 					arg.label = eat Identifier_Token
		# 					eat ':'
		# 				end
		#
		# 				arg.expression = parse_expr
		# 			end
		#
		# 			eat if curr? ','
		# 		end
		#
		# 		eat ')'
		# 	end

		expr
	end

	def output
		expressions = []
		expressions << begin_expression while tokens?
		expressions.compact
	end
end
