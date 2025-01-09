require_relative 'tokens'


class Char
	attr_accessor :string


	def initialize str
		@string = str
	end


	def whitespace?
		string == "\t" || string == "\s"
	end


	def newline?
		string == "\n"
	end


	def carriage_return?
		string == "\r"
	end


	def colon?
		string == ';'
	end


	def comma?
		string == ','
	end


	def delimiter?
		colon? || comma? || newline? || whitespace? || carriage_return? # || Token::RESERVED_CHARS.include? string
	end


	def numeric?
		!!(string =~ /\A[0-9]+\z/)
	end


	def alpha? str = nil
		!!((str || string) =~ /\A[a-zA-Z]+\z/)
	end


	def alphanumeric?
		!!(string =~ /\A[a-zA-Z0-9]+\z/)
	end


	def symbol?
		!!(string =~ /\A[^a-zA-Z0-9\s]+\z/)
	end


	def identifier?
		alphanumeric? || string == '_'
	end


	def reserved_identifier?
		Token::RESERVED_IDENTIFIERS.include? string
	end


	def reserved_operator?
		Token::RESERVED_OPERATORS.include? string
	end


	def legal_symbol?
		Token::LEGAL_SYMBOLS.include? string
	end


	def reserved?
		Token::RESERVED_CHARS.include? string
	end


	def == other
		if other.is_a? String
			other == string
		else
			other == self.class
		end
	end


	def to_s
		string.inspect
	end
end


class Lexer
	attr_accessor :i, :col, :row, :source, :tokens


	def initialize source = nil
		self.source = source
		# @source = source
		# @tokens = []
		# @i      = 0 # index of current char in source string
		# @col    = 1 # short for column
		# @row    = 1 # short for line
	end


	def source= str
		@source = str
		@tokens = []
		@i      = 0 # index of current char in source string
		@col    = 1 # short for column
		@row    = 1 # short for line
	end


	def chars?
		@i < source.length
	end


	def curr
		Char.new source[@i]
	end


	def peek start_distance_from_curr = 1, length = 1
		Char.new source[@i + start_distance_from_curr, length]
	end


	def peek_until_delimiter # unused
		index = 0
		while index < source.length && !Char.new(source[index]).delimiter?
			index += 1
		end
		source[0...index]
	end


	def last
		source[@i - 1]
	end


	def eat expected = nil
		if curr.newline?
			@row += 1
			@col = 1
		else
			@col += 1
		end

		@i += 1

		if expected && expected != last
			raise "Expected '#{expected}' but got '#{last}'"
		end

		last
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

			while chars? && (curr.numeric? || valid.include?(curr.string))
				number << eat
				last_number_char = number[-1]
				decimal_found    = true if last_number_char == '.'

				if curr == '.' && (peek(1) == '.' || peek(1) == '<')
					break # because these are the range operators .. and .<
				end

				raise "Number #{number} already contains a period. curr #{curr.inspect}" if decimal_found && curr == '.'
				break if curr.newline? || curr.whitespace?
			end
		end
	end


	def make_identifier_token
		# of alphanumeric words, or combinations of symbols. the gist here is that we construct alphanumeric identifiers or symbolic identifiers depending on what the first character is. after each is constructed, if it happens to be a reserved word or symbol then return the reserved version of the token. otherwise it's a valid identifier. examples: #$@%, ...., ...?, ...?!@#, etc, are valid identifiers. Note that they cannot end with a dot unless all other symbols are dots.

		string        = ''
		starting_char = curr
		if starting_char.legal_symbol? # eat any combination of legal symbols
			while curr.legal_symbol?
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
			while curr.identifier?
				string += eat
				eat while curr == '\\' # !!! I think backslashes in the middle of identifiers is useful for lining up your declarations.
			end

			# in case this identifier happens to be a keyword, we're going to bail early here.
			if Token::RESERVED_IDENTIFIERS.include? string
				return Key_Identifier_Token.new string
			end

			Identifier_Token.new string
		else
			raise "#make_identifier_token unknown #{curr}"
		end
	end


	def eat_until_delimiter
		"".tap {
			while chars? && !curr.delimiter?
				_1 << eat
			end
			eat while curr.newline?
		}
	end


	def eat_oneline_comment
		''.tap do |comment|
			eat '`'
			eat while curr.whitespace? # skip whitespace or tab before body

			while chars? && !curr.newline? # and not curr == '`'
				comment << eat
			end

			# eat if curr == '`' # ??? this allows comments in between expressions. I'm not sure how pleasant this would be because it breaks syntax coloring. But this makes sense to have. Imagine putting `short comments` between variables in a complex equation.
		end
	end


	def eat_multiline_comment
		''.tap do |comment|
			marker = '```'
			eat_many 3, marker
			eat while curr.whitespace? || curr.newline?

			while chars? && peek(0, 3) != marker
				comment << eat
				eat while curr.newline?
			end

			eat_many 3, marker
		end
	end


	def eat_string
		''.tap do |str|
			quote = eat

			while chars? && curr != quote
				str << eat
			end

			eat quote
		end
	end


	def reduce_delimiters
		eat while (curr.delimiter? && last == curr)
	end


	def lowercase? c
		c.downcase == c
	end


	def uppercase? c
		c.upcase == c
	end


	def lex input = nil # note output is @tokens so to ignore a token means to exclude it from @tokens
		@source = input if input
		raise 'Lexer.source is nil' unless source

		while chars?
			index_before_this_lex_loop = @i
			col_before                 = @col
			row_before                 = @row

			token = if curr == '`' # comments!
				if peek(0, 3) == '```'
					eat_multiline_comment
				elsif peek(0, 2) == '``'
					eat_oneline_comment
				else
					eat_oneline_comment
				end
				# Comment_Token.new(comment) # todo make use of these
				nil

			elsif curr == '\\'
				eat and nil

			elsif curr.delimiter? # ( { [ , ] } ) \n \s \t \r ;
				if curr == ';' || curr == ','
					Delimiter_Token.new(eat)
				elsif curr == "\s"
					eat and nil

				elsif curr == "\n" || curr == "\r" || curr == "\s" || curr == "\t"
					Delimiter_Token.new(eat).tap do
						reduce_delimiters # if _1.string == "\n" or _1.string == "\s"  or _1.string == "\t"
					end
				else
					# ( { [ , ] } )
					Delimiter_Token.new(eat)
				end

			elsif curr.numeric?
				Number_Token.new(eat_number)

			elsif curr == '.' && peek&.numeric?
				Number_Token.new(eat_number)

			elsif curr.legal_symbol? || curr.identifier? # this will make all identifiers, reserved or otherwise
				make_identifier_token

			elsif curr == '"' || curr == "'"
				String_Token.new(eat_string)

			elsif curr.reserved?
				Reserved_Token.new(eat)

			else
				raise "unknown #{curr}"
			end

			next unless token

			token.start_index = index_before_this_lex_loop
			token.end_index   = @i

			token.column         = col_before
			token.line           = row_before
			token.location_label = "#{token.line}:#{token.column}"

			@tokens << token
		end

		@tokens << EOF_Token.new
		@tokens.compact!
		@tokens
	end

end
