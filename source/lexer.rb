module Code
	class Lexer
		attr_accessor :i, :col, :line, :source_file, :input

		def initialize input = 'greeting = "hello world"'
			@input = input
			@i     = 0 # index of current char in input string
			@col   = 1 # short for column
			@line  = 1 # short for line
		end

		def input= value
			@input = value
			@i     = 0
			@col   = 1
			@line  = 1
		end

		def whitespace? char = curr
			Code::WHITESPACES.include? char
		end

		def newline? char = curr
			Code::NEWLINES.include? char
		end

		def delimiter? char = curr
			Code::DELIMITERS.include? char
		end

		def identifier? char = curr
			char == '_' || alpha?(char)
		end

		def numeric? char = curr
			char&.match? Code::NUMERIC_REGEX
		end

		def alpha? char = curr
			char&.match? Code::ALPHA_REGEX
		end

		def alphanumeric? char = curr
			char&.match? Code::ALPHANUMERIC_REGEX
		end

		def symbol? char = curr
			char&.match? SYMBOLIC_REGEX
		end

		def route_pattern?
			return false unless identifier?

			verb_match = Code::HTTP_VERBS.any? { |verb| peek(0, verb.length) == verb }
			return false unless verb_match

			verb_length = Code::HTTP_VERBS.find { |verb| peek(0, verb.length) == verb }.length
			peek(verb_length, 3) == '://'
		end

		def load_path_pattern? tokens
			return false unless preceded_by_at_load? tokens
			peek(0, 2) == './' || peek(0, 3) == '../' || peek(0, 2) == '~/'
		end

		def preceded_by_at_load? tokens
			non_whitespace         = tokens.reverse.reject { |t| t.type == :whitespace }
			load_tok, at_tok, prior = non_whitespace[0], non_whitespace[1], non_whitespace[2]

			return false unless load_tok&.type == :identifier && load_tok.value == 'load'
			return false unless at_tok&.type == :operator && at_tok.value == '@'

			!(prior&.type == :operator && prior.value == '.')
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
				raise Code::Lexed_Unexpected_Char.new(expected: expected, got: curr)
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
			it = ::String.new
			while chars? && length > 0
				it << eat
				length -= 1
			end

			if expected_chars && expected_chars != it
				raise Code::Lexed_Unexpected_Char.new(expected: expected_chars, got: it)
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

				it << eat
				eat '_' while curr == '_' && numeric?(peek)
			end
			it
		end

		def should_lex_negative_number? tokens
			last_token = tokens.reverse.find { |t| t.type != :whitespace }
			return true if last_token.nil?

			# After operators or opening delimiters, lex as negative number but NOT after closing delimiters like ')' which would be subtraction: (x)-1
			if last_token.type == :delimiter
				return !%w<) ] }>.include?(last_token.value)
			end

			last_token.type == :operator
		end

		def lex_oneline_comment
			it = ::String.new
			eat Code::COMMENT_CHAR
			eat while whitespace?

			while chars? && !newline?
				it << eat

			end
			it
		end

		# Reads a run of consecutive occurrences of `char`, however long -- used for both the opening and closing markers of a block comment/fence, so a longer run on the outer wrapper can safely swallow a same-length (or shorter) inner one without closing early. Mirrors Markdown's own rule for nesting code fences: a marker only closes a block opened by a marker of equal or greater length; a shorter run of the same char is just literal content.
		def lex_repeated_char_run char
			it = ::String.new
			it << eat while chars? && curr == char
			it
		end

		def lex_block_comment
			char          = curr
			marker_length = lex_repeated_char_run(char).length

			it = ::String.new
			while chars? && peek(0, marker_length) != char * marker_length
				it << eat
			end

			lex_repeated_char_run char
			it
		end

		def lex_fence_block
			char          = curr
			marker_length = lex_repeated_char_run(char).length
			it            = ::String.new

			eat while whitespace? || newline?

			while chars? && peek(0, marker_length) != char * marker_length
				it << eat
				if newline? # preserve one newline
					it << eat
					eat while newline?
				end
			end

			lex_repeated_char_run char
			it
		end

		def lex_string
			it    = ::String.new
			quote = eat

			# todo: Refactor this, maybe? I was trying to use interpolation pipes in multiline text (see ./examples/basic_page.code) and realized that I wasn't escaping those, which led to the interpreter trying to actually interpolate the string.
			while chars? && curr != quote
				if curr == '\\'
					eat
					if chars?
						escaped = eat
						case escaped
						when 'n' then it << "\n"
						when 't' then it << "\t"
						when 'r' then it << "\r"
						when '\\' then it << "\\"
						when quote then it << quote
						else
							# it << '\\' + escaped
							it << "\\#{escaped}"
						end
					else
						raise Code::Unterminated_String_Literal.new
					end
				else
					it << eat
				end
			end

			if !chars? || curr != quote
				raise Code::Unterminated_String_Literal.new
			end

			eat quote
			it
		end

		def reduce_delimiters
			eat while (delimiter? && prev == curr)
		end

		def lex_operator
			# note; Operators cannot start with or end with: ' " { } ( ) [ ] and that is a strict rule.
			str = ::String.new
			# `..` is a prefix of `..<`/`...` and `>..` of `>..<`, so match longest, not first.
			range_like = Code::RANGE_OPERATORS + ['...']
			while chars? && symbol?
				# Keep `Type<Struct>.member` from lexing `>.` as one token and eating the closing `>`.
				break if str == '>' && curr == '.' && peek != '.'
				break if str == Code::TAG_OPERATOR && curr == '<'
				break if str == Code::CONTEXT_OPERATOR && curr == '.'
				break if str == '<' && curr == '>'

				str << eat

				if range_like.include? str
					next if range_like.any? do |op|
						op.length > str.length && op.start_with?(str) && op[str.length] == curr
					end
					break
				end

				break if Code::ILLEGAL_OPERATOR_CHARS.include? str
				break if Code::ILLEGAL_OPERATOR_CHARS.include? curr
			end
			str
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
				break unless Code::HTTP_VERBS.any? { |v| v.start_with?(verb + curr) }
				verb << eat
			end

			protocol_sep = lex_many 3, Code::HTTP_VERB_SEPARATOR

			path = ::String.new
			while chars? && !whitespace? && !newline? && curr != '('
				path << eat
			end

			"#{verb}://#{path}"
		end

		def lex_load_path
			it = ::String.new
			while chars? && !newline?
				if curr == '\\' && whitespace?(peek)
					eat        # the backslash itself, discarded
					it << eat  # the escaped space, kept literally
				elsif whitespace?
					break
				else
					it << eat
				end
			end
			it
		end

		def output
			tokens = []

			while chars?
				single = curr == Code::COMMENT_CHAR
				blocked = peek(0, Code::BLOCK_COMMENT_CHARS.length) == Code::BLOCK_COMMENT_CHARS
				fenced = peek(0, Code::FENCE_CHARS.length) == Code::FENCE_CHARS

				token = Code::Lexeme.new.tap do
					it.source_file = source_file
					it.l0          = line
					it.c0          = col

					if single || blocked || fenced
						if fenced
							it.value = lex_fence_block
							it.type  = if it.value.downcase.start_with? "html\n"
								it.value = it.value[5..] # strips html and the newline
								:html
							else
								:fence
							end
						elsif blocked
							it.type  = :comment
							it.value = lex_block_comment
						else
							it.type  = :comment
							it.value = lex_oneline_comment
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
						it.type            = :string
						it.quotation_style = curr == "'" ? :single : :double
						it.value           = lex_string

					elsif route_pattern?
						it.type  = :route
						it.value = lex_route

					elsif identifier?
						it.value = lex_identifier
						it.type  = Code.type_of_identifier it.value
						if %w(for skip stop).include?(it.value)
							it.type = :operator
						end

					elsif load_path_pattern? tokens
						# A bare, unquoted path right after `@load` -- `./x`, `../x`, `~/x` is lexed as an ordinary :string token (quotation_style set as if it were '...')
						it.type            = :string
						it.quotation_style = :single
						it.value           = lex_load_path

					elsif curr == '.' && peek == '?'
						# Again I'm special casing for `.?` which is my version of Ruby's `&.`
						it.type  = :operator
						it.value = "#{eat}#{eat}"

					elsif symbol?(curr)
						it.type = :operator
						if %w(. | & ).include? curr
							it.value = case [curr, peek, peek(2)]
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
							it.value = lex_operator
						end

					else
						raise Code::Lex_Char_Not_Implemented.new(char: curr)
					end

					it.l1 = line
					it.c1 = (line > it.l0) ? col : col - 1
				end

				next if token.type == :whitespace

				token.reserved = Code::RESERVED.include? token.value
				tokens << token
			end

			tokens.compact
		end
	end
end
