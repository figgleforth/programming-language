require_relative 'tokens'

module Language
	def self.sort_by_length array
		array.sort_by { -_1.length }
	end

	# allowed to be used for operators `.:.:`, `.~~~~~:::`, `|||`, `====.==`
	LEGAL_OPERATOR_CHARS = sort_by_length %w(. = + - ~ * ! @ # $ % ^ & ? / | < > _ : ; )
	# .sort_by { -_1.length }

	# these cannot be used for identifiers, they're only for program structure {}, collections [,] and (,)
	RESERVED_CHARS = sort_by_length %w< [ { ( , ) } ] >
	# .sort_by { -_1.length }

	RESERVED_IDENTIFIERS = sort_by_length %w(
		if    elsif    elif    else
		while elswhile elwhile else
		unless until true false nil
		skip stop   and or operator
		raise return
	)
	# .sort_by { -_1.length }

	# operators that cannot be overridden. eg. printing, initialization, ranges, scope operator, etc
	RESERVED_OPERATORS = sort_by_length %w(>!!! >!! >! =; ≠ = . .. .< >. >< .? @ ./ ../ .../)
	# .sort_by { -_1.length }

	COMMENT_CHAR            = '`'.freeze
	MULTILINE_COMMENT_CHARS = '```'.freeze
end


class Lexer

	attr_accessor :i, :col, :row, :source, :tokens#, :lexeme

	def initialize source_code = ''
		self.source = source_code
	end

	def source= src
		@source = src
		@tokens = [] # final output
		@i      = 0 # index of current char in source string
		@col    = 1 # short for column
		@row    = 1 # short for line
		# @lexeme = '' # the current string being tokenized
	end

	# todo comment the rest of these, with this type of comment:
	# @return [Boolean] true when the current char is a tab or space
	def whitespace?
		curr_char == "\t" || curr_char == "\s"
	end

	def newline?
		curr_char == "\n" || curr_char == "\r\n" # \r\n is for Windows
	end

	def delimiter?
		%W(; , \n \s \t \r).include? curr_char # W to preserve escapes
	end

	def numeric?
		curr_char.match?(/\A\d+\z/)
	end

	def alpha?
		curr_char.match?(/\A\p{Alpha}+\z/)
	end

	def alphanumeric?
		curr_char.match?(/\A\p{Alnum}+\z/)
	end

	def symbol?
		curr_char.match?(/\A[^\p{Alnum}\s]+\z/)
	end

	def identifier?
		alphanumeric? || curr_char == '_'
	end

	def legal_operator_char?
		Language::LEGAL_OPERATOR_CHARS.include? curr_char
	end

	def reserved?
		Language::RESERVED_CHARS.include? curr_char
	end

	def chars_remaining?
		i < source.length
	end

	def curr_char
		source[i]
	end

	def last_char
		source[i - 1]
	end

	def peek start_distance_from_curr = 1, length = 1
		source[i + start_distance_from_curr, length]
	end

	def eat expected = nil
		if newline?
			@row += 1
			@col = 1
		else
			@col += 1
		end

		@i += 1

		if expected && expected != last_char
			raise "Expected '#{expected}' but got '#{last_char}'"
		end

		last_char
	end

	def eat_many length = 1, expected_chars = nil
		''.tap do |str|
			length.times do
				str << eat
			end

			if expected_chars && expected_chars != str
				raise "Expected '#{expected_chars}' but got '#{str}'"
			end
		end
	end

	def eat_number
		''.tap do |number|
			valid         = %w(. _)
			decimal_found = false

			while chars_remaining? && (numeric? || valid.include?(string))
				number << eat
				last_number_char = number[-1]
				decimal_found    = true if last_number_char == '.'

				if curr_char == '.' && (peek(1) == '.' || peek(1) == '<')
					break # because these are the range operators .. and .<
				end

				raise "Number #{number} already contains a period. curr #{inspect}" if decimal_found && curr_char == '.'
				break if newline? || whitespace?
			end
		end
	end

	def make_identifier_token
		# of alphanumeric words, or combinations of symbols. the gist here is that we construct alphanumeric identifiers or symbolic identifiers depending on what the first character is. after each is constructed, if it happens to be a reserved word or symbol then return the reserved version of the token. otherwise it's a valid identifier. examples: #$@%, ...., ...?, ...?!@#, etc, are valid identifiers. Note that they cannot end with a dot unless all other symbols are dots.

		string        = ''
		starting_char = curr_char
		if starting_char.legal_operator_char? # eat any combination of legal symbols
			while legal_operator_char?
				string += eat
			end

			if Token::RESERVED_OPERATORS.include? string
				return Key_Operator_Token.new string
			end

			if string[-1] == '.' && !string.chars.all? { _1 == '.' }
				# !!! This is because it would be impossible to know when to stop parsing dots and maybe parse a dotted member access.
				raise "Custom operator `#{string}` cannot end with a dot unless all other characters are dots. But you can start with or include other dots anywhere else."
			end

			Operator_Token.new string
		elsif starting_char.identifier?
			while identifier?
				string += eat
				eat while curr_char == '\\' # !!! I think backslashes in the middle of identifiers is useful for lining up your declarations.
			end

			# in case this identifier happens to be a keyword, we're going to bail early here.
			if Token::RESERVED_IDENTIFIERS.include? string
				return Key_Identifier_Token.new string
			end

			Identifier_Token.new string
		else
			raise "#make_identifier_token unknown #{curr_char}"
		end
	end

	def eat_until_delimiter
		"".tap {
			while chars_remaining? && !delimiter?
				_1 << eat
			end
			eat while newline?
		}
	end

	def eat_oneline_comment
		''.tap do |comment|
			eat Language::COMMENT_CHAR
			eat while whitespace? # skip whitespace or tab before body

			while chars_remaining? && !newline? # and not curr == Language::COMMENT_CHAR
				comment << eat
			end

			# eat if curr == Language::COMMENT_CHAR # ??? this allows comments in between expressions. I'm not sure how pleasant this would be because it breaks syntax coloring. But this makes sense to have. Imagine putting `short comments` between variables in a complex equation.
		end
	end

	def eat_multiline_comment
		''.tap do |comment|
			marker = '```'
			eat_many 3, marker
			eat while whitespace? || newline?

			while chars_remaining? && peek(0, 3) != marker
				comment << eat
				eat while newline?
			end

			eat_many 3, marker
		end
	end

	def eat_string
		''.tap do |str|
			quote = eat

			while chars_remaining? && curr_char != quote
				str << eat
			end

			eat quote
		end
	end

	def reduce_delimiters
		eat while (delimiter? && last_char == curr_char)
	end

	def lowercase? c
		c.downcase == c
	end

	def uppercase? c
		c.upcase == c
	end

	def lex
		raise 'Lexer.source is nil' unless source

		while chars_remaining?
			index_before_this_lex_loop = i
			col_before                 = col
			row_before                 = row

			is_comment = curr_char == Language::COMMENT_CHAR || peek(0, 3) == Language::MULTILINE_COMMENT_CHARS

			token = if is_comment # if curr == Language::COMMENT_CHAR # comments!
				if peek(0, 3) == Language::MULTILINE_COMMENT_CHARS
					eat_multiline_comment
					# elsif peek(0, 2) == '##'
					# 	eat_oneline_comment # is this one needed?
				else
					eat_oneline_comment
				end
				# Comment_Token.new(comment) # todo make use of these
				nil

			elsif curr_char == '\\'
				eat and nil

			elsif delimiter? # ( { [ , ] } ) \n \s \t \r ;
				if curr_char == ';' || curr_char == ','
					Delimiter_Token.new(eat)
				elsif curr_char == "\s"
					eat and nil

				elsif curr_char == "\n" || curr_char == "\r" || curr_char == "\s" || curr_char == "\t"
					Delimiter_Token.new(eat).tap do
						reduce_delimiters # if _1.string == "\n" or _1.string == "\s"  or _1.string == "\t"
					end
				else
					# ( { [ , ] } )
					Delimiter_Token.new(eat)
				end

			elsif numeric?
				Number_Token.new(eat_number)

			elsif curr_char == '.' && peek&.numeric?
				Number_Token.new(eat_number)

			elsif legal_operator_char? || identifier? # this will make all identifiers, reserved or otherwise
				make_identifier_token

			elsif curr_char == '"' || curr_char == "'"
				String_Token.new(eat_string)

			elsif reserved?
				Reserved_Token.new(eat)

			else
				raise "unknown curr_char #{curr_char.inspect} \n\t#{inspect}"
			end

			next unless token

			token.start_index = index_before_this_lex_loop
			token.end_index   = i

			token.column         = col_before
			token.line           = row_before
			token.location_label = "#{token.line}:#{token.column}"

			tokens << token
		end

		tokens << EOF_Token.new
		tokens.compact!
		tokens
	end

end
