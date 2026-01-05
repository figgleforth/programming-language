require_relative '../ore'

module Ore
	class Lexer
		attr_accessor :i, :col, :line, :input, :source_file

		def initialize input = 'greeting = "hello world"', filepath: nil
			@i           = 0 # index of current char in input string
			@col         = 1 # short for column
			@line        = 1 # short for line
			@input       = input
			@source_file = filepath ? File.expand_path(filepath) : '<inline>'
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

		def route_pattern?
			return false unless identifier?

			verb_match = HTTP_VERBS.any? { |verb| peek(0, verb.length) == verb }
			return false unless verb_match

			verb_length = HTTP_VERBS.find { |verb| peek(0, verb.length) == verb }.length
			peek(verb_length, 3) == '://'
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
				raise Ore::Lexed_Unexpected_Char.new(expected: expected, got: curr)
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
				raise Ore::Lexed_Unexpected_Char.new(expected: expected_chars, got: it)
			end

			it
		end

		def lex_number
			it    = ::String.new
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

		def should_lex_negative_number? tokens
			last_token = tokens.reverse.find { |t| t.type != :whitespace }
			return true if last_token.nil?

			# After operators or opening delimiters, lex as negative number nut NOT after closing delimiters like ')' which would be subtraction: (x)-1
			if last_token.type == :delimiter
				return !%w<) ] }>.include?(last_token.value)
			end

			last_token.type == :operator
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

			# todo: Refactor this, maybe? I was trying to use interpolation pipes in multiline text (see ./examples/basic_page.ore) and realized that I wasn't escaping those, which led to the interpreter trying to actually interpolate the string.
			while chars? && curr != quote
				if curr == '\\'
					eat
					if chars?
						escaped = eat
						case escaped
						when 'n' then it += "\n"
						when 't' then it += "\t"
						when 'r' then it += "\r"
						when '\\' then it += "\\"
						when quote then it += quote
						else
							it += '\\' + escaped
						end
					else
						raise Ore::Unterminated_String_Literal.new
					end
				else
					it += eat
				end
			end

			if !chars? || curr != quote
				raise Ore::Unterminated_String_Literal.new
			end

			eat quote
			it
		end

		def reduce_delimiters
			eat while (delimiter? && prev == curr)
		end

		def lex_operator
			# todo: Operators cannot start with or end with: ' " { } ( )
			it = ::String.new
			while chars? && symbol? && !%w(' " { } ( ) ).include?(curr)
				it << eat

				break if (SCOPE_OPERATORS - ['.']).include? it # note: This needs to break on all known operators except plain '.' because '.' is part of other identifiers like `..`, so we need to be able to capture other operators that include dot.
			end

			it
		end

		def lex_identifier
			it = ::String.new
			it << eat while curr == '_'
			can_end_with = %w(! ?)

			while chars? && (identifier? || numeric?)
				it << eat
				break if newline? || whitespace?
				if can_end_with.include? curr
					it << eat
					break
				end
			end

			it
		end

		def lex_route
			verb = ::String.new
			while chars? && (identifier? || alphanumeric?)
				break unless HTTP_VERBS.any? { |v| v.start_with?(verb + curr) }
				verb << eat
			end

			protocol_sep = lex_many 3, HTTP_VERB_SEPARATOR

			path = ::String.new
			while chars? && !whitespace? && !newline? && curr != '{'
				path << eat
			end

			"#{verb}://#{path}"
		end

		def output
			tokens = []

			while chars?
				single    = curr == COMMENT_CHAR
				multiline = peek(0, COMMENT_MULTILINE_CHAR.length) == COMMENT_MULTILINE_CHAR

				token = Ore::Lexeme.new.tap do
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

					elsif curr == '-' && numeric?(peek) && should_lex_negative_number?(tokens)
						it.type = :number
						eat
						it.value = '-' + lex_number

					elsif numeric?
						it.type  = :number
						it.value = lex_number

					elsif %w(' ").include? curr
						it.type  = :string
						it.value = lex_string

					elsif route_pattern?
						it.type  = :route
						it.value = lex_route

					elsif identifier?
						it.value = lex_identifier
						it.type  = Ore.type_of_identifier it.value
						if %w(for skip stop).include?(it.value)
							it.type = :operator
						end

					elsif symbol?(curr)
						it.type  = :operator
						it.value = if %w(. | & ).include? curr
							case [curr, peek, peek(2)]
							in ['.', p, _] if identifier?(p) && p != '_'
								lex_operator
							in ['.', '<', _] | ['.', '.', _]
								lex_operator
							in ['|', '|', '=']
								lex_operator
							in ['&', '&', '=']
								lex_operator
							in ['|', '=', _]
								lex_operator
							in ['&', '=', _]
								lex_operator
							in ['|', '|', _] | ['&', '&', _]
								str = ::String.new
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
						raise Ore::Lex_Char_Not_Implemented.new(char: curr)
					end

					it.l1 = line
					it.c1 = (line > it.l0) ? col : col - 1
				end

				next if whitespace?(token.value)

				token.reserved = RESERVED.include? token.value
				tokens << token
			end

			tokens.compact
		end
	end
end
