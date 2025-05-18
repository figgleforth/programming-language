require_relative 'token'

# todo too many duplicate declarations %w() with parens, braces, etc
# todo document all methods
class Lexer
	RESERVED = %w(
		! ? ?? !! : ; .. >. .< ><
		@ .@ .? ./ ../ .../ [ { ( , _ . ) } ]
		+= -= *= |= /= %= &= ^= != <= >= =;
		&& || & | << >> ` ```
		+ - ~ = * ** :: ? : / %
		if elsif elif else
		while elswhile elwhile
		unless until true false nil
		skip stop and or
		return
	).sort_by { -_1.size }.freeze

	attr_accessor :i, :col, :row, :input

	def initialize input = 'greeting = "hello world"'
		@i     = 0 # index of current char in input string
		@col   = 1 # short for column
		@row   = 1 # short for line
		@input = input
	end

	# @return [Boolean] true when the current char is a tab or space
	def whitespace? char
		char == "\t" || char == "\s" || char&.match?(/[ \t]/)
	end

	def newline? char
		%W(\r\n \t).include? char # \r\n is for Windows
	end

	def delimiter? char
		%W(; , \n \t \r \s).include?(char)
	end

	def structure? char
		%w(, ; { } ( ) [ ]).include? char
	end

	def numeric? char
		char&.match? /\A\d+\z/
	end

	def alpha? char
		char&.match? /\A\p{Alpha}+\z/
	end

	def alphanumeric? char
		char&.match? /\A\p{Alnum}+\z/
	end

	def symbol? char
		char&.match? /\A[^\p{Alnum}\s]+\z/
	end

	def identifier? char
		char == '_' || alpha?(char)
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
			raise "#eat expected #{expected} not #{curr_char.inspect}"
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
			raise "#eat_many expected '#{expected_chars}' not #{it.inspect}"
		end

		it
	end

	def eat_number
		eat if curr_char == '_'
		it    = String.new
		valid = %w(. _)

		while chars_remaining? && (numeric?(curr_char) || valid.include?(curr_char))
			if curr_char == '.' && !numeric?(peek)
				break
			end

			it += eat
			eat while curr_char == '_'
			break if it.include?('.') && curr_char == '.'
		end
		it
	end

	#? comments to be inlined anywhere and ignored by autodoc, parser, etc
	#- foo `inlined comment` = 123
	def eat_oneline_comment
		it = ''
		eat '`'
		eat while whitespace?(curr_char)

		while chars_remaining? && !newline?(curr_char)
			it += eat

		end
		it
	end

	def eat_multiline_comment
		marker = eat_many 3, '```'
		it     = ''

		eat while whitespace?(curr_char) || newline?(curr_char)

		while chars_remaining? && peek(0, 3) != marker
			it += eat
			if newline?(curr_char) # preserve one newline
				it += eat
				eat while newline?(curr_char)
			end
		end

		eat_many 3, marker
		it
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

	def eat_operator
		oper     = String.new
		reserved = %w(. ; { })

		while chars_remaining? && symbol?(curr_char)
			oper << eat
			break if reserved.include? oper
		end

		oper
	end

	# - begin with @ or _ or #
	# - contain alphanueric or _
	# - end alhpanumeric or ! or ?
	def eat_identifier
		ident = String.new
		ident << eat while curr_char == '_'
		can_end_with = %w(! ?)

		while chars_remaining? && identifier?(curr_char)
			ident << eat
			break if newline?(curr_char) || whitespace?(curr_char) || curr_char == '#'
			if can_end_with.include? curr_char
				ident << eat
				break
			end
		end

		ident
	end

	# @param input [String, required] Code to lex
	# @return [Array<Token>] Array of Tokens
	def output
		tokens = []
		while chars_remaining?
			single    = curr_char == '`'
			multiline = peek(0, 3) == '```'

			token = Token.new.tap do
				it.column = col
				it.line   = row

				if single || multiline
					it.type  = :comment
					it.value = if multiline
						eat_multiline_comment
					else
						eat_oneline_comment
					end

				elsif delimiter? curr_char
					it.type  = :delimiter
					it.value = eat

					reduce_delimiters unless %w(, ;).include? it.value
					next if %W(\s \t).include? it.value

				elsif numeric?(curr_char) || (%w(. _).include?(curr_char) && numeric?(peek))
					it.type  = :number
					it.value = eat_number

				elsif %w(' ").include? curr_char
					it.type  = :string
					it.value = eat_string

				elsif identifier?(curr_char) || %w(_).include?(curr_char)
					it.type  = :identifier
					it.value = eat_identifier

				elsif symbol? curr_char
					it.type  = :operator
					it.value = if %w(. ; { } ( ) [ ]).include? curr_char
						eat
					else
						eat_operator
					end

				else
					raise "#output unlexed char #{curr_char.inspect}"
				end
			end

			token.reserved = RESERVED.include? token.value
			tokens << token
		end

		tokens << Token.new(:eof, eat, true, row, col)
		tokens.compact
	end
end
