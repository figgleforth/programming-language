module Code
	class Lexer

		attr_accessor :source_file # set from outside. As is :input but that's got its own setter
		attr_reader :index, :column, :line, :lexemes, :input

		def initialize input = '@puts greeting := "Hello :)"'
			self.input = input
		end

		def input= string
			@lexemes = []
			@input   = string
			@index   = 0 # index of current char in input string
			@column  = 1 # short for column
			@line    = 1 # short for line
		end

		def make_lexeme
			lexeme             = Lexeme.new
			lexeme.source_file = @source_file

			mark_start lexeme
			yield(lexeme) if block_given?
			mark_end lexeme

			lexeme.reserved = Code::RESERVED.include? lexeme.value
			lexeme
		end

		# Also accepts a block. Use this to automatically mark a Lexeme's location while you lex it.
		# @param [Code::Lexeme] lexeme
		def mark lexeme
			mark_start lexeme
			yield(lexeme) if block_given?
			mark_end lexeme
			lexeme
		end

		def mark_start lexeme
			lexeme.line_start   = @line
			lexeme.column_start = @column
		end

		def mark_end lexeme
			lexeme.line_end = @line
			lexeme.column_end = [1, @column-1].max # Column can be 1 after a newline, and I want to follow convention (at least RubyMine's convention) of starting at column 1 not 0.
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

		def negative_number?
			curr == '-' && numeric?(peek) && should_lex_negative_number?(@lexemes)
		end

		def alpha? char = curr
			char&.match? Code::ALPHA_REGEX
		end

		def alphanumeric? char = curr
			char&.match? Code::ALPHANUMERIC_REGEX
		end

		def symbolic? char = curr
			char&.match? SYMBOLIC_REGEX
		end

		def route_pattern?
			return false unless identifier?

			verb_match = Code::HTTP_VERBS.any? { |verb| peek(0, verb.length) == verb }
			return false unless verb_match

			verb_length = Code::HTTP_VERBS.find { |verb| peek(0, verb.length) == verb }.length
			peek(verb_length, 3) == '://'
		end

		def load_path_pattern? tokens = @lexemes
			return false unless preceded_by_at_load? tokens
			peek(0, 2) == './' || peek(0, 3) == '../' || peek(0, 2) == '~/'
		end

		def preceded_by_at_load? tokens
			non_whitespace          = tokens.reverse.reject { |t| t.type == :whitespace }
			load_tok, at_tok, prior = non_whitespace[0], non_whitespace[1], non_whitespace[2]

			return false unless load_tok&.type == :identifier && load_tok.value == 'load'
			return false unless at_tok&.type == :operator && at_tok.value == '@'

			!(prior&.type == :operator && prior.value == '.')
		end

		def should_lex_negative_number? tokens
			last_token = tokens.reverse.find do |t|
				t.type != :whitespace
			end
			return true if last_token.nil?

			# After operators or opening delimiters, lex as negative number but NOT after closing delimiters like ')' which would be subtraction: (x)-1
			if last_token.type == :delimiter
				return !%w<) ] }>.include?(last_token.value)
			end

			last_token.type == :operator
		end

		def chars?
			@index < @input.length
		end

		def prev
			return nil if @index <= 0
			@input[@index - 1]
		end

		def curr
			@input[@index]
		end

		def reduce_delimiters
			eat while (delimiter? && prev == curr)
		end

		def reduce_whitespace
			eat while (whitespace? && prev == curr)
		end

		def accumulate_char char
			it = ::String.new
			it << eat(char) while chars? && curr == char
			it
		end

		def peek offset_from_curr = 1, length = 1
			@input[@index + offset_from_curr, length]
		end

		def eat expected = nil
			if expected && expected != curr
				raise Code::Lexed_Unexpected_Char.new(expected: expected, got: curr)
			end

			eaten  = curr
			@index += 1

			if newline? eaten
				@line   += 1
				@column = 1
			else
				@column += 1
			end

			eaten
		end

		def eat_n_times_and_expect length = 1, expected_chars = nil
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

		def eat_operator
			# note; Operators cannot start with or end with: ' " { } ( ) [ ] and that is a strict rule.
			str = ::String.new
			# `..` is a prefix of `..<`/`...` and `>..` of `>..<`, so match longest, not first.
			range_like = Code::RANGE_OPERATORS + ['...']
			while chars? && symbolic?
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

		def lex_number
			def eat_number
				it    = ::String.new
				valid = %w(. _) # An exception for _ is that it cannot be the last character because then you could miss underscored declarations like `1_decl`. This should be lexed as number 1, and identifier _decl.

				# 7/7/25, I'm intentionally allowing multiple dots in a number for Array_Index_Expr
				while chars? && (numeric? || valid.include?(curr))
					break if valid.include?(curr) && !numeric?(peek)
					break if it[-1] == '_' && !numeric?(curr)

					it << eat
					eat '_' while curr == '_' && numeric?(peek)
				end
				it.strip
			end

			prefix = if %w(+ -).include? curr
				eat
			end

			make_lexeme do |lexeme|
				lexeme.type  = :number
				lexeme.value = "#{prefix}#{eat_number}"
			end
		end

		def lex_string
			def eat_string
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

			make_lexeme do |lexeme|
				lexeme.quotation_style = curr == "'" ? :single : :double
				lexeme.type            = :string
				lexeme.value           = eat_string
			end
		end

		def lex_route
			def eat_route
				verb = ::String.new
				while chars? && (identifier? || alphanumeric?)
					break unless Code::HTTP_VERBS.any? { |v| v.start_with?(verb + curr) }
					verb << eat
				end

				eat_n_times_and_expect 3, Code::HTTP_VERB_SEPARATOR # That's the `://` part

				path = ::String.new
				while chars? && !whitespace? && !newline? && curr != '('
					path << eat
				end

				"#{verb}://#{path}"
			end

			make_lexeme do |lexeme|
				lexeme.type  = :route
				lexeme.value = eat_route
			end
		end

		def lex_comment
			def eat_comment
				eat Code::COMMENT_PREFIX

				it = ::String.new
				reduce_whitespace

				it << eat while chars? && !newline?
				it.strip
			end

			make_lexeme do |lexeme|
				lexeme.type  = :comment
				lexeme.value = eat_comment
			end
		end

		def lex_block_comment
			def eat_block_comment
				char          = curr
				marker_length = accumulate_char(char).length

				it = ::String.new
				while chars? && peek(0, marker_length) != char * marker_length
					it << eat
				end

				accumulate_char char
				it # todo; #strip?
			end

			make_lexeme do |lexeme|
				lexeme.type  = :comment
				lexeme.value = eat_block_comment
			end
		end

		def lex_identifier
			def eat_identifier
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

			make_lexeme do |lexeme|
				lexeme.value = eat_identifier
				lexeme.type  = Code.type_of_identifier lexeme.value
				if %w(for skip stop).include?(lexeme.value)
					lexeme.type = :operator
				end
			end
		end

		def lex_load_path
			def eat_load_path
				it = ::String.new
				while chars? && !newline?
					if curr == '\\' && whitespace?(peek)
						eat # the backslash itself, discarded
						it << eat # the escaped space, kept literally
					elsif whitespace?
						break
					else
						it << eat
					end
				end
				it
			end

			make_lexeme do |lexeme|
				lexeme.type            = :string
				lexeme.quotation_style = :single
				lexeme.value           = eat_load_path
			end
		end

		def lex_fence
			def eat_fence_block
				char          = curr
				marker_length = accumulate_char(char).length
				it            = ::String.new

				eat while whitespace? || newline?

				while chars? && peek(0, marker_length) != char * marker_length
					it << eat
					if newline? # preserve one newline
						it << eat
						eat while newline?
					end
				end

				accumulate_char char
				it
			end

			make_lexeme do |lexeme|
				fence_value = eat_fence_block
				is_html     = fence_value.downcase.start_with? "html"
				if is_html
					fence_value = fence_value[4..] # strip html
				end

				lexeme.value = fence_value
				lexeme.type  = if is_html
					:html
				else
					:fence
				end
			end
		end

		def lex_delimiter
			make_lexeme do |lexeme|
				lexeme.value = eat
				lexeme.type  = :delimiter
			end
		end

		def lex_whitespace
			make_lexeme do |lexeme|
				lexeme.type  = :whitespace
				lexeme.value = eat
			end
		end

		def lex_operator
			make_lexeme do |lexeme|
				lexeme.type  = :operator
				lexeme.value = if %w(. | & ).include? curr
					case [curr, peek, peek(2)]
					in ['.', p, _] if identifier?(p) && p != '_'
						eat_operator
					in ['.', '<', _] | ['.', '.', _]
						eat_operator
					in ['|', '|', '=']
						eat_operator
					in ['&', '&', '=']
						eat_operator
					in ['|', '=', _]
						eat_operator
					in ['&', '=', _]
						eat_operator
					in ['|', '|', _] | ['&', '&', _]
						str = ::String.new
						str << eat
						str << eat
						str
					in ['.', '?', _]
						str = ::String.new
						str << eat
						str << eat
						str
					else
						eat
					end
				else
					eat_operator
				end
			end
		end

		# note; This can be simplified with some metaprogramming, but that abstracts the learning opportunity. I'll leave this as a big if/else case because it's easiest to reason about.
		def output
			@lexemes = []

			while chars?
				lexeme = if Code::BLOCK_COMMENT_DELIMITER == peek(0, Code::BLOCK_COMMENT_DELIMITER.length)
					lex_block_comment

				elsif Code::FENCE_DELIMITER == peek(0, Code::FENCE_DELIMITER.length)
					lex_fence

				elsif Code::COMMENT_PREFIX == curr
					lex_comment

				elsif whitespace?
					lex_whitespace and next

				elsif %w(' ").include? curr
					lex_string

				elsif delimiter?
					lex_delimiter

				elsif numeric? || negative_number?
					lex_number

				elsif route_pattern?
					lex_route

				elsif identifier?
					lex_identifier

				elsif load_path_pattern?
					lex_load_path

				elsif symbolic?
					lex_operator

				else
					raise Code::Lex_Char_Not_Implemented.new curr
				end

				@lexemes << lexeme
			end

			@lexemes.compact
		end
	end
end
