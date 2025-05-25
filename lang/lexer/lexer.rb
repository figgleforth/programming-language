# todo document all methods

Token = Struct.new('Token', :type, :value, :reserved, :line, :column) do
	def is compare
		if compare.is_a? Symbol
			type == compare
		elsif compare.is_a? String
			value == compare
		else
			self == compare
		end
	end

	def isnt compare
		is(compare) == false
	end

	def to_s
		"#{value}(#{type})"
	end

	def location
		"#{line}:#{column}"
	end
end

class Lexer
	attr_accessor :i, :col, :row, :input

	INFIX = %w(
		+ - * ** / % ~ = == === ? .
		+= -= *= |= /= %= &= ^= != <= >=
		&& || & | << >>
		.. >. .< ><
		and or
	).sort_by { -it.size }.freeze

	PREFIX = %w(! - + ~ # @ ? & ^ ./ ../ .../).sort_by { -it.size }.freeze

	POSTFIX = %w(=;)

	RESERVED = %w(
		[ { ( , _ . ) } ] : ;
		+ - * ** / % ~ = == ===
		+= -= *= |= /= %= &= ^= != <= >= =;
		! ? ?? !! && || & | << >>
		.. >. .< ><
		@ ./ ../ .../
		``` `

		if elsif elif else
		while elswhile elwhile
		unless until true false nil
		skip stop and or return
	).sort_by { -it.size }.freeze

	COMMENT_CHAR = '`'.freeze

	def initialize input = 'greeting = "hello world"'
		@i     = 0 # index of current char in input string
		@col   = 1 # short for column
		@row   = 1 # short for line
		@input = input
	end

	def whitespace? char = curr
		char == "\t" || char == "\s"
	end

	def newline? char = curr
		%W(\r\n \t \n).include? char
	end

	def delimiter? char = curr
		%W(, \n \t \r \s).include? char
	end

	def identifier? char = curr
		char == '_' || alpha?(char)
	end

	def numeric? char = curr
		char&.match? /\A\d+\z/
	end

	def alpha? char = curr
		char&.match? /\A\p{Alpha}+\z/
	end

	def alphanumeric? char = curr
		char&.match? /\A\p{Alnum}+\z/
	end

	def symbol? char = curr
		char&.match? /\A[^\p{Alnum}\s]+\z/
	end

	def chars?
		i < input.length
	end

	# input[i - 1]
	def prev
		return nil if i <= 0
		input[i - 1]
	end

	# input[i]
	def curr
		input[i]
	end

	def peek offset_from_curr = 1, length = 1
		input[i + offset_from_curr, length]
	end

	def eat expected = nil
		if expected && expected != curr
			raise "#eat expected #{expected} not #{curr.inspect}"
		end

		if newline? curr
			@row += 1
			@col = 1
		else
			@col += 1
		end
		@i += 1

		prev
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
		valid = %w(. _)

		while chars? && (numeric? || valid.include?(curr))
			if curr == '.' && !numeric?(peek)
				break
			end

			it += eat
			eat while curr == '_'
			break if it.include?('.') && curr == '.'
		end
		it
	end

	def lex_oneline_comment
		it = ''
		eat '`'
		eat while whitespace?

		while chars? && !newline?
			it += eat

		end
		it
	end

	def lex_multiline_comment
		marker = lex_many 3, '```'
		it     = ''

		eat while whitespace? || newline?

		while chars? && peek(0, 3) != marker
			it += eat
			if newline? # preserve one newline
				it += eat
				eat while newline?
			end
		end

		lex_many 3, marker
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
		oper = String.new
		while chars? && symbol? && curr != '`'
			oper << eat
		end
		oper
	end

	def lex_identifier
		ident = String.new
		ident << eat while curr == '_'
		can_end_with = %w(! ?)

		while chars? && (identifier? || numeric?)
			ident << eat
			break if newline? || whitespace? || curr == '#'
			if can_end_with.include? curr
				ident << eat
				break
			end
		end

		ident
	end

	def identifier_type ident
		def constant? ident # all upper, LIKE_THIS
			test = ident&.gsub('_', '')&.gsub('%', '')
			test&.chars&.all? { |c| c.upcase == c }
		end

		def class? ident # capitalized, Like_This or This
			ident[0] && ident[0].upcase == ident[0] && !constant?(ident)
		end

		def member? ident # lowercased start, lIKE_THIS or thIS or this
			ident[0] && ident[0].downcase == ident[0]
		end

		without_leading__ = ident.gsub(/^#{Regexp.escape('_')}+/, '')
		if constant? without_leading__
			:IDENTIFIER
		elsif class? without_leading__
			:Identifier
		elsif member? without_leading__
			:identifier
		else
			raise "unknown identifier type #{ident.inspect}"
		end
	end

	def output
		tokens = []

		while chars?
			single    = curr == '`'
			multiline = peek(0, 3) == '```'

			token = Token.new.tap do
				it.column = col
				it.line   = row

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
					reduce_delimiters unless %w(, ;).include? it.value

				elsif numeric?
					it.type  = :number
					it.value = lex_number

				elsif %w(' ").include? curr
					it.type  = :string
					it.value = lex_string

				elsif identifier? || %w(_).include?(curr)
					it.value = lex_identifier
					it.type  = identifier_type it.value

				elsif symbol? curr
					it.type  = :operator
					it.value = if %w(. ; { } ( ) [ ]).include? curr
						if curr == '.' && (peek == '.' || peek == '<')
							lex_operator
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

			next if whitespace?(token.value) && token.type != :string
			next if token.type == :comment

			token.reserved = RESERVED.include? token.value
			tokens << token
		end

		tokens.compact
	end
end
