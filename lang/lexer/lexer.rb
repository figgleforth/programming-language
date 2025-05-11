# todo document all methods

require_relative 'errors'
require_relative '../language'
require_relative 'token'

# Converts source code into tokens
class Lexer

	attr_accessor :i, :col, :row, :input, :tokens

	def initialize
		@tokens = [] # final output
		@i      = 0 # index of current char in input string
		@col    = 1 # short for column
		@row    = 1 # short for line
		@input  = ''
	end

	# Stores the index, column, and row state before calling the block.
	# @param token_class to instantiate (eg, String_Token, Number_Token, etc)
	# @param block [String] expects yielded block to return a value to be used with token_class#new
	# @return [Token] an instance of the given token class
	def create_token token_class, &block
		unless token_class.ancestors.include? Token
			raise Lexing_Error.new("#create_token expected toke_class #{token_class} to be an ancestor of Token")
		end

		start      = i
		col_before = col
		row_before = row
		value      = block.call
		raise Lexing_Error.new("asf") unless value

		token             = token_class.new value
		token.start_index = start
		token.end_index   = start + value.length
		token.column      = col_before
		token.line        = row_before
		token
	end

	# @return [Boolean] true when the current char is a tab or space
	def whitespace? char
		char == "\t" || char == "\s" || char&.match?(/[ \t]/)
	end

	def newline? char
		char == "\n" || char == "\r\n" # \r\n is for Windows
	end

	def delimiter? char
		%W(; , \n \s \t \r).include? char # W to preserve escapes
	end

	def numeric? char
		char&.match?(/\A\d+\z/)
	end

	def alpha? char
		char&.match?(/\A\p{Alpha}+\z/)
	end

	def alphanumeric? char
		char&.match?(/\A\p{Alnum}+\z/)
	end

	def symbol? char
		char&.match?(/\A[^\p{Alnum}\s]+\z/)
	end

	def identifier? char
		curr_char == '_' || alpha?(char)
	end

	def legal_identifier_special_char? char
		Language::LEGAL_IDENT_SPECIAL_CHARS.include? char
	end

	def reserved? char
		Language::RESERVED_OPERATOR_IDENTIFIERS.include?(char) || Language::RESERVED_IDENTIFIERS.include?(char)
	end

	def chars_remaining?
		i < input.length
	end

	def curr_char
		input[i]
	end

	def prev_char
		return nil if i <= 0
		input[i - 1]
	end

	# @param offset_from_curr [Integer] from the current character to start
	# @param length [Integer] of characters to peek
	# @return [String] of given length
	def peek offset_from_curr = 1, length = 1
		input[i + offset_from_curr, length]
	end

	def add_to_clipboard text
		IO.popen('pbcopy', 'w') do |clipboard|
			clipboard << text
			puts "Added #{text} to clipboard"
		end
	end

	def eat expected = nil
		if expected && expected != curr_char
			add_to_clipboard "#{row}:#{col}"
			raise Lexing_Error.new "Lexer#eat expected #{expected}, not #{curr_char.inspect}"
		end

		if newline? curr_char
			@row += 1
			@col = 1
		else
			@col += 1
		end
		@i += 1

		prev_char
	end

	def eat_many length = 1, expected_chars = nil
		it = ''
		while chars_remaining? && length > 0
			it     += eat
			length -= 1
		end

		if expected_chars && expected_chars != it
			raise Lexing_Error.new "Lexer#eat_many expected '#{expected_chars}', not #{it.inspect}"
		end

		it
	end

	def eat_number
		it            = ''
		valid         = %w(. _)
		decimal_found = false

		while chars_remaining? && (numeric?(curr_char) || valid.include?(curr_char))
			it               += eat
			last_number_char = it[-1]
			decimal_found    = true if last_number_char == '.'

			if curr_char == '.' && (peek(1) == '.' || peek(1) == '<')
				break # because these are the range operators .. and .<
			end

			raise Lexing_Error.new("#eat_number: Number #{it} already contains a period. curr #{inspect}") if decimal_found && curr_char == '.'
			break if newline?(curr_char) || whitespace?(curr_char)
		end
		it
	end

	def make_identifier_token
		def token_if_reserved str
			if Language::RESERVED_IDENTIFIERS.include? it
				create_token(Reserved_Identifier_Token) { it }
			elsif Language::RESERVED_OPERATOR_IDENTIFIERS.include? it
				create_token(Reserved_Operator_Token) { it }
			end
		end

		it = ''
		until newline?(curr_char) || whitespace?(curr_char) || !chars_remaining?
			it += eat
			eat while curr_char == '\\'
		end

		if Language::RESERVED_IDENTIFIERS.include? it
			return create_token(Reserved_Identifier_Token) { it }
		elsif Language::RESERVED_OPERATOR_IDENTIFIERS.include? it
			return create_token(Reserved_Operator_Token) { it }
		end

		if it.end_with?('.')
			all_dots = it.chars.all? { _1 == '.' }
			raise Lexing_Error.new("#make_identifier_token custom operator `#{it}` cannot end with a dot unless all other characters are dots. But you can start with or include other dots anywhere else.") unless all_dots
		end # this is because it would be impossible to know when to stop parsing dots and maybe parse a dotted member access.

		create_token(Identifier_Token) { it }
	end

	def eat_until_delimiter
		it = ''
		while chars_remaining? && !delimiter?(curr_char)
			it += eat
		end
		eat while newline?
		it
	end

	# idea: allow comments to be inlined anywhere, ignored by autodoc and parser
	#       foo `inlined comment` = 123
	def eat_oneline_comment
		it = ''
		eat Language::COMMENT_CHAR
		eat while whitespace?(curr_char)

		while chars_remaining? && !newline?(curr_char)
			it += eat

		end
		it
	end

	def eat_multiline_comment
		marker  = eat_many 3, Language::MULTILINE_COMMENT_CHARS
		comment = ''

		eat while whitespace?(curr_char) || newline?(curr_char)

		while chars_remaining? && peek(0, 3) != marker
			comment += eat
			if newline?(curr_char) # preserve one newline
				comment += eat
				eat while newline?(curr_char)
			end
		end

		eat_many 3, marker
		comment
	end

	def eat_string
		it    = ''
		quote = eat

		while chars_remaining? && curr_char != quote
			it += eat
		end

		eat quote
		it
	end

	def reduce_delimiters
		eat while (delimiter?(curr_char) && prev_char == curr_char)
	end

	def lowercase? c
		c.downcase == c
	end

	def uppercase? c
		c.upcase == c
	end

	def reset_attrs starting_input = ''
		@tokens = [] # final output
		@i      = 0 # index of current char in input string
		@col    = 1 # short for column
		@row    = 1 # short for line
		@input  = starting_input
	end

	# @param input [String, required] Code to lex
	# @return [Array<Token>] Array of Tokens
	def lex input_source
		raise Lexing_Error.new('Lexer#lex: input is nil') unless input_source

		reset_attrs input_source

		while chars_remaining?
			index_before_this_lex_loop = i
			col_before_this_lex_loop   = col
			row_before_this_lex_loop   = row

			# comment checks
			single = curr_char == Language::COMMENT_CHAR
			multip = peek(0, 3) == Language::MULTILINE_COMMENT_CHARS

			start = curr_char

			token = \
			   if single || multip
				   comment = multip ? eat_multiline_comment : eat_oneline_comment
				   Comment_Token.new comment, multip

			   elsif curr_char == '\\'
				   eat and next

			   elsif %W(; , \s \n \r \t ).include? curr_char
				   if curr_char == ','
					   create_token(Delimiter_Token) { eat }

				   elsif %W(\n \r \t).include? curr_char
					   token = create_token(Delimiter_Token) { eat }
					   reduce_delimiters
					   token

				   elsif curr_char == "\s"
					   eat and next
				   else
					   create_token(Delimiter_Token) { eat }
				   end

			   elsif numeric?(curr_char) || (curr_char == '.' && numeric?(peek))
				   create_token(Number_Token) { eat_number }

			   elsif curr_char == '"' || curr_char == "'"
				   create_token(String_Token) { eat_string }

			   else
				   make_identifier_token
			   end

			unless token
				raise Lexing_Error.new("Lexer#lex encountered a nil token.")
			end

			token.start_index = index_before_this_lex_loop
			token.end_index   = i
			token.column      = col_before_this_lex_loop + (i - index_before_this_lex_loop) - 1
			token.line        = row_before_this_lex_loop

			tokens << token
		end

		tokens << EOF_Token.new
		tokens.compact
	end
end
