require './src/parser/expressions'
require './src/shared/constants'

class Parser
	attr_accessor :i, :input

	def initialize input = []
		@input = input
		@i     = 0 # index of current lexeme
	end

	def output
		expressions = []
		while lexemes?
			expressions << make_expression
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
			if lexeme.is_a? Lexeme
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
				raise "#eat(#{sequence[0].inspect}) got #{eaten.value.inspect}), at #{curr_lexeme.inspect}, prev #{prev_lexeme.inspect}"
			end
			@i    += 1
			return eaten
		end
	end

	def parse_conditional_expr
		it            = Conditional_Expr.new
		it.type       = eat.value # One of %w(if while unless until)
		it.condition  = make_expression
		it.when_true  = []
		it.when_false = []
		reduce_newlines

		# @clean

		until curr? %w(end else elsif elif ef elwhile elswhile elsewhile)
			expr = make_expression
			it.when_true << expr if expr
			reduce_newlines
		end

		if curr? %w(elsif elif ef el elwhile elswhile elsewhile)
			it.when_false = parse_conditional_expr

		elsif curr? %w(else el) and eat
			until curr? 'end'
				expr = make_expression
				it.when_false << expr if expr
				reduce_newlines
			end
			eat 'end'

		elsif curr? %w(} end)
			eat

		else
			raise "\n\nYou messed your if/elsif/else up\n"
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
			it.expressions << make_expression
			break if curr? closing

			eat if curr? ','
			reduce_newlines
		end

		eat closing
		it.expressions = it.expressions.compact
		it
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
				param = Param_Expr.new

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
				reduce_newlines
			end

			eat ';'
			reduce_newlines

			until curr? '}'
				statement = make_expression
				expr.expressions << statement
			end

			expr.expressions = expr.expressions.compact
			eat '}'

		end
	end

	def parse_type_decl
		# Just to note again, allowing constant-style identifiers for single-letter types
		valid_idents = %I(Identifier IDENTIFIER)
		Type_Expr.new.tap do |decl|
			decl.name = eat.value

			until curr? '{'
				if curr?(TYPE_COMPOSITION_OPERATORS, valid_idents)
					decl.expressions << Composition_Expr.new.tap do
						it.operator = eat(:operator).value
						it.name     = eat
					end
				end
			end

			eat '{'

			until curr? '}'
				decl.expressions << make_expression
			end

			decl.expressions = decl.expressions.compact

			eat '}'
		end
	end

	def make_expression precedence = STARTING_PRECEDENCE
		raise "No more lexems to #make_expression" unless lexemes?

		expression = if (curr?('{') || curr?(:identifier, '{') || curr?(:identifier, ':', :Identifier, '{')) && peek_contains?(';', '}')
			parse_func precedence, named: curr?(:identifier)

		elsif curr?(:Identifier, '{') || curr?(:Identifier, TYPE_COMPOSITION_OPERATORS) || (curr?(:IDENTIFIER, '{') && curr_lexeme.value.length == 1)
			# I'm special-casing IDENTIFIERS of length 1 and allowing them to become Types too. So you can have types like G {}.
			# bug :Identifier_function when parsing `Identifier {;}`
			parse_type_decl

		elsif curr?(TYPE_COMPOSITION_OPERATORS) && peek.is(:Identifier)
			Composition_Expr.new.tap do
				it.operator = eat(:operator).value
				it.name     = eat(:Identifier)
			end

		elsif curr? %w(if while unless until)
			parse_conditional_expr

		elsif curr?(:identifier, ':', :Identifier)
			Identifier_Expr.new.tap do
				it.value = eat.value
				eat ':'
				it.type = eat(:Identifier).value
			end

		elsif curr? ANY_IDENTIFIER
			Identifier_Expr.new eat.value

		elsif curr? %w( [ \( { |)
			parse_circumfix_expr opening: curr_lexeme.value

		elsif curr?(':', :identifier) || curr?(':', :Identifier) || curr?(':', :IDENTIFIER)
			eat ':'
			Symbol_Expr.new eat.value.to_sym

		elsif curr? :operator
			Operator_Expr.new eat(:operator).value

		elsif curr? :number
			number       = Number_Expr.new
			number.value = eat(:number).value
			if number.value.count('.') > 1
				number                  = Array_Index_Expr.new number.value
				number.indices_in_order = number.value.split '.'
				number.indices_in_order = number.indices_in_order.map &:to_i
				# It's important not to convert number.value here to anything to preserve the variant number of dots in the string. I think this'll be cool syntax, 2d_array.1.2 would be the equivalent of 2d_array[1][2].
			elsif number.value.include? '.'
				number.type  = :float
				number.value = number.value.to_f
			else
				number.type  = :integer
				number.value = number.value.to_i
			end
			number

		elsif curr? :string
			String_Expr.new eat(:string).value

		elsif curr? :delimiter
			reduce_newlines

		elsif curr? :comment
			eat and nil

		else
			raise "Unhandled lexeme: #{curr_lexeme.inspect}"
		end

		modify_expression expression, precedence
	end

	def modify_expression expr, precedence = STARTING_PRECEDENCE
		return expr unless expr && lexemes?

		if expr.is_a?(Identifier_Expr) && curr_lexeme.is(';')
			left            = expr
			expr            = Postfix_Expr.new
			expr.expression = left
			expr.operator   = eat(curr_lexeme.value).value
			return expr
		end

		if curr_lexeme.is ','
			eat and return expr
		end

		scope_prefix = %w(./ ../ .../).find do |it|
			expr.is it
		end

		if scope_prefix
			expr            = Prefix_Expr.new
			expr.operator   = scope_prefix
			expr.expression = make_expression
			return modify_expression expr, precedence
		end

		prefix    = PREFIX.include? expr.value
		infix     = INFIX.include? curr_lexeme.value
		postfix   = POSTFIX.include? curr_lexeme.value
		circumfix = CIRCUMFIX.include? curr_lexeme.value

		if prefix
			expr = Prefix_Expr.new.tap do |it|
				it.operator   = expr.value
				it.expression = make_expression precedence_for(it.operator)
			end

			if not expr.expression
				raise "Prefix_Expr expected an expression after `#{expr.operator}`"
			end

			return modify_expression expr, precedence
		elsif infix
			if COMPOUND_OPERATORS.include? curr_lexeme.value
				it          = Infix_Expr.new
				it.left     = expr
				it.operator = eat.value
				it.right    = make_expression precedence_for(it.operator)

				return modify_expression it, precedence
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
					expr.right    = make_expression curr_operator_prec

					if expr.left.is(Identifier_Expr) && expr.operator == '.' && expr.right.is(Number_Expr) && expr.right.type == :float
						number                  = Array_Index_Expr.new expr.right.value.to_s
						number.indices_in_order = number.value.split '.'
						number.indices_in_order = number.indices_in_order.map &:to_i
						expr.right              = number
						# Copypaste from above #make_expression when :number.
					end

					return modify_expression expr, precedence
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
			return modify_expression expr, precedence
		elsif subscript
			it            = Subscript_Expr.new
			it.receiver   = expr
			it.expression = parse_circumfix_expr opening: curr_lexeme.value
			it
			return modify_expression it, precedence
		end

		if curr?(%w(if while unless until))
			if precedence_for(curr_lexeme.value) <= precedence
				return expr
			end

			it           = Conditional_Expr.new
			it.type      = eat.value
			it_prec      = precedence_for it.type
			it.condition = make_expression
			if %w(unless until).include? it.type
				it.when_false = [expr]
			else
				it.when_true = [expr]
			end
			return modify_expression it, precedence
		end

		expr
	end

end
