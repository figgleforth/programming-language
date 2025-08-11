require_relative 'shared/constants'
require_relative 'shared/helpers'
require_relative 'shared/lexeme'

class Lexer
	attr_accessor :i, :col, :line, :input

	def initialize input = 'greeting = "hello world"'
		@i     = 0 # index of current char in input string
		@col   = 1 # short for column
		@line  = 1 # short for line
		@input = input
	end

	def whitespace? char = curr
		WHITESPACES.include? char
	end

	def newline? char = curr
		NEWLINES.include? char
	end

	def delimiter? char = curr
		DELIMITERS.include? char
	end

	def identifier? char = curr
		char == '_' || alpha?(char)
	end

	def numeric? char = curr
		char&.match? NUMERIC_REGEX
	end

	def alpha? char = curr
		char&.match? ALPHA_REGEX
	end

	def alphanumeric? char = curr
		char&.match? ALPHANUMERIC_REGEX
	end

	def symbol? char = curr
		char&.match? SYMBOLIC_REGEX
	end

	def chars?
		i < input.length
	end

	def prev
		return nil if i <= 0
		input[i - 1]
	end

	def curr
		input[i]
	end

	def peek offset_from_curr = 1, length = 1
		input[i + offset_from_curr, length]
	end

	def eat expected = nil
		if expected && expected != curr
			raise "#eat expected #{expected.inspect} not #{curr.inspect}"
		end

		eaten = curr
		@i    += 1

		if newline? eaten
			@line += 1
			@col  = 1
		else
			@col += 1
		end

		eaten
	end

	def lex_many length = 1, expected_chars = nil
		it = ''
		while chars? && length > 0
			it     += eat
			length -= 1
		end

		if expected_chars && expected_chars != it
			raise "#lex_many expected '#{expected_chars}' not #{it.inspect}"
		end

		it
	end

	def lex_number
		it    = String.new
		valid = %w(. _) # An exception for _ is that it cannot be the last character because then you could miss underscored declarations like `1_decl`. This should be lexed as number 1, and identifier _decl.

		# 7/7/25, I'm intentionally allowing multiple dots in a number for Array_Index_Expr
		while chars? && (numeric? || valid.include?(curr))
			break if valid.include?(curr) && !numeric?(peek)
			break if it[-1] == '_' && !numeric?(curr)

			it += eat
			eat '_' while curr == '_' && numeric?(peek)
		end
		it
	end

	def lex_oneline_comment
		it = ''
		eat COMMENT_CHAR
		eat while whitespace?

		while chars? && !newline?
			it += eat

		end
		it
	end

	def lex_multiline_comment
		marker = lex_many COMMENT_MULTILINE_CHAR.length, COMMENT_MULTILINE_CHAR
		it     = ''

		eat while whitespace? || newline?

		while chars? && peek(0, 3) != marker
			it += eat
			if newline? # preserve one newline
				it += eat
				eat while newline?
			end
		end

		lex_many COMMENT_MULTILINE_CHAR.length, COMMENT_MULTILINE_CHAR
		it
	end

	def lex_string
		it    = ''
		quote = eat

		while chars? && curr != quote
			it += eat
		end

		eat quote
		it
	end

	def reduce_delimiters
		eat while (delimiter? && prev == curr)
	end

	def lex_operator
		it = String.new
		while chars? && symbol?
			it << eat
		end

		it
	end

	def lex_identifier
		it = String.new
		it << eat while curr == '_'
		can_end_with = %w(! ?)

		while chars? && (identifier? || numeric?)
			it << eat
			break if newline? || whitespace? || curr == '#'
			if can_end_with.include? curr
				it << eat
				break
			end
		end

		it
	end

	def output
		tokens = []

		while chars?
			single    = curr == COMMENT_CHAR
			multiline = peek(0, COMMENT_MULTILINE_CHAR.length) == COMMENT_MULTILINE_CHAR

			token = Lexeme.new.tap do
				it.l0 = line
				it.c0 = col

				if single || multiline
					it.type  = :comment
					it.value = if multiline
						lex_multiline_comment
					else
						lex_oneline_comment
					end

				elsif delimiter? curr
					it.type  = :delimiter
					it.value = eat

				elsif whitespace? curr
					it.type  = :whitespace
					it.value = eat

				elsif numeric?
					it.type  = :number
					it.value = lex_number

				elsif %w(' ").include? curr
					it.type  = :string
					it.value = lex_string

				elsif identifier? || %w(_).include?(curr)
					it.value = lex_identifier
					it.type  = type_of_identifier it.value
					if %w(for).include?(it.value)
						it.type = :operator
					end

				elsif symbol?(curr)
					it.type  = :operator
					it.value = if %w(. | & ).include? curr
						# #todo Is it possible to avoid having to do this?
						if curr == '.' && (peek == '.' || peek == '<')
							lex_operator

						elsif curr == '.' && peek == '/'
							lex_operator

						elsif curr == '.' && (peek == '.' && peek(2) == '/')
							lex_operator

						elsif curr == '.' && (peek == '.' && peek(2) == '.' && peek(3) == '/')
							lex_operator

						elsif curr == '|' && peek == '|' && peek(2) == '='
							lex_operator

						elsif curr == '&' && peek == '&' && peek(2) == '='
							lex_operator

						elsif curr == '|' && peek == '='
							lex_operator

						elsif curr == '&' && peek == '='
							lex_operator

						elsif (curr == '|' && peek == '|') || (curr == '&' && peek == '&')
							str = String.new
							str << eat
							str << eat
							str
						else
							eat
						end
					else
						lex_operator
					end

				else
					raise "#output unlexed char #{curr.inspect}"
				end
			end

			next if whitespace?(token.value)

			token.l1 = line
			token.c1 = col

			token.reserved = RESERVED.include? token.value
			tokens << token
		end

		tokens.compact
	end
end
