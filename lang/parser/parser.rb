class Parser
	require './lang/parser/expression'
	require './lang/constants'

	attr_accessor :i, :input

	def initialize input = []
		@input = input
		@i     = 0 # index of current lexeme
	end

	# Array of precedences and symbols for that precedence. if the lexeme provided matches one of the operator symbols then its precedence is returned. Nice reference: https://rosettacode.org/wiki/Operator_precedence
	def precedence_for operator
		# #todo Make this better
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
			[90, %w(= := += -= *= /= %= &= |= ^= <<= >>=)], # assignments
			[80, %w(.. .< >. ><)], # ranges
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
		it.type       = eat.value # %w(if while)
		it.condition  = make_expression
		it.when_true  = []
		it.when_false = []

		# todo Clean this up, what is this shit? It should just loop until curr? 'end'

		reduce_newlines
		until curr? %w(end else elsif elif ef el elwhile elswhile elsewhile)
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
			it.expressions << make_expression #(precedence_for(opening))
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
		Type_Decl.new.tap do |decl|
			decl.name = eat.value

			until curr? '{'
				if curr?(TYPE_COMPOSITION_OPERATORS, valid_idents)
					decl.composition_exprs << Composition_Expr.new.tap do
						it.operator = eat(:operator).value
						it.name     = eat.value
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
		raise "No more lexems to #make_expression" unless lexemes?

		expression = if (curr?('{') || curr?(:identifier, '{') || curr?(:identifier, ':', :Identifier, '{')) && peek_contains?(';', '}')
			parse_func precedence, named: curr?(:identifier)

		elsif curr?(:Identifier, '{') || curr?(:Identifier, TYPE_COMPOSITION_OPERATORS) || (curr?(:IDENTIFIER, '{') && curr_lexeme.value.length == 1)
			# I'm special-casing IDENTIFIERS of length 1 and allowing them to become Types too. So you can have types like G {}.
			parse_type_decl

		elsif curr?(TYPE_COMPOSITION_OPERATORS) && peek.is(:Identifier)
			Composition_Expr.new.tap do
				it.operator = eat(:operator).value
				it.name     = eat(:Identifier).value
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
			Symbol_Expr.new eat.value

		elsif curr? :operator
			Operator_Expr.new eat(:operator).value

		elsif curr? :number
			Number_Expr.new eat(:number).value

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

		if curr_lexeme.is ',' # This allows comma separating declarations
			eat and return expr
		end

		# The three scope identifiers are parsed here, ./, ../, and .../.
		if expr.is('./')
			expr            = Prefix_Expr.new
			expr.operator   = './'
			expr.expression = make_expression #(100000)
			return modify_expression expr, precedence
		elsif expr.is('../')
			expr            = Prefix_Expr.new
			expr.operator   = '../'
			expr.expression = make_expression
			return modify_expression expr, precedence
		elsif expr.is('.../')
			expr            = Prefix_Expr.new
			expr.operator   = '.../'
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

			unless expr.expression
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
					# It's very important that the && :operator check remains because otherwise it breaks Call_Expr when the receiver is an Infix_Expr. However, this breaks the and/or infix because those lex as :identifier.

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

		if curr? %w(if while unless until)
			it           = Conditional_Expr.new
			it.type      = eat.value # if, while, etc
			it.condition = make_expression
			if %w(unless until).include? it.type
				it.when_false = [expr]
			else
				it.when_true = [expr]
			end
			expr         = it
		end

		expr
	end

	def output
		expressions = []
		while lexemes?
			expressions << make_expression
		end
		expressions.compact
	end
end
