require_relative 'tokens'


class Char
	attr_accessor :string


	def initialize str
		@string = str
	end


	def whitespace?
		string == "\t" or string == "\s"
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
		# return false if string == '='
		colon? or comma? or newline? or whitespace? or carriage_return? # or Token::RESERVED_CHARS.include? string
	end


	def numeric?
		!!(string =~ /\A[0-9]+\z/)
	end


	def alpha?
		!!(string =~ /\A[a-zA-Z]+\z/)
	end


	def alphanumeric?
		!!(string =~ /\A[a-zA-Z0-9]+\z/)
	end


	def symbol?
		!!(string =~ /\A[^a-zA-Z0-9\s]+\z/)
	end


	def identifier?
		# return false if Char.new(string[0]).numeric? # ??? due to how anything is an identifier now, we just have to weed out numbers here
		alphanumeric? or string == '_'
	end


	def reserved_identifier?
		Token::RESERVED_IDENTIFIERS.include? string
	end


	def reserved_operator?
		Token::RESERVED_OPERATORS.include? string
	end


	def legal_symbol?
		Token::VALID_CHARS.include? string
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

	# RESERVED_IDENTIFIERS = %w(
	# 	if    elsif    elif    else
	# 	while elswhile elwhile else
	# 	unless until true false nil
	# 	pri private pub public
	# 	and or operator self
	# 	raise return skip stop
	# )
	# >!!! >!! >! >~
	# .../ ../ ./
	# =; ->
	# @{ @\( @[

	# RESERVED_OPERATORS = %w(>!!! >!! >! >~ .../ ../ ./ =; -> ~> = .)

	# ??? if users can't make identifiers out of symbols, then maybe these reserved symbols above should become operators

	# !!! new map tap where
	# I'm not sure theses belong in this list, I'd rather they were identifiers. Because

	# RESERVED_CHARS = %w< [ { ( , ) } ] > # these cannot be used in custom operator identifiers. They are only for program structure {}, collections [,] and (,)

	# CHARS_ALLOWED = %w(. = + - ~ * ! @ # $ % ^ & ? / | < > _ : ; ) # these can be used in custom operator identifiers. Some builtin operators are made from these symbols, others require some reserved ones. eg. >! ./ =;. Except that we might want to restrict some, like the =

	attr_accessor :i, :col, :row, :source, :tokens


	def initialize source = nil
		@source = source
		@tokens = []
		@i      = 0 # index of current char in source string
		@col    = 1 # short for column
		@row    = 1 # short for line
	end


	def source= str
		@source = str
		@tokens = []
		@i      = 0 # index of current char in source string
		@col    = 1 # short for column
		@row    = 1 # short for line
	end


	def location_in_source
		"#{row}:#{col}"
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


	def peek_until_delimiter
		index = 0
		while index < source.length and not Char.new(source[index]).delimiter?
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

		if expected and expected != last
			raise "Expected '#{expected}' but got '#{last}'"
		end

		last
	end


	def eat_many length = 1, expected_chars = nil
		''.tap do |str|
			length.times do
				str << eat
			end

			if expected_chars and expected_chars != str
				raise "Expected '#{expected_chars}' but got '#{str}'"
			end
		end
	end


	def eat_number
		''.tap do |number|
			valid         = %w(. _)
			decimal_found = false

			while chars? and (curr.numeric? or valid.include?(curr.string))
				number << eat
				last_number_char = number[-1]
				decimal_found    = true if last_number_char == '.'

				if curr == '.' and (peek(1) == '.' or peek(1) == '<')
					break # because these are the range operators .. and .<
				end

				raise "Number #{number} already contains a period. curr #{curr.inspect}" if decimal_found and curr == '.'
				break if curr.newline? or curr.whitespace?
			end
		end
	end


	def make_identifier_token # of alphanumeric words, or combinations of symbols. This is cool, you'll see!
		# the gist here is that we construct alphanumeric identifiers or symbolic identifiers depending on what the first character is. after each is constructed, if it happens to be a reserved alpha or symbol then return that. otherwise it's a valid identifier. examples: #$@% is a valid identifier.
		# if CHARS_RESERVED.include? curr.string
		# 	return Delimiter_Token.new eat # these are ({[]}),
		# end # ??? this should never fire. Not sure why I had this here

		string = ''
		if curr.legal_symbol? # eat any combination of legal symbols

			while curr.legal_symbol?
				string += eat

				if string[0] == '.' and curr != '.'
					# string.match?(/\A\.+\z/)
					break
				end

				if string[0] != '.' and curr == '.'
					break
				end
			end

			# otherwise, if we got here, the constructed symbol is not an illegal singular symbol. now we check if it constructed a reserved symbol
			if Token::RESERVED_OPERATORS.include? string
				# return Key_Identifier_Token.new string # these are =; :: -> >!!! >!! >! >~ .../ ../ ./
				return Key_Operator_Token.new string # these are =; :: -> >!!! >!! >! >~ .../ ../ ./
			end

			# ??? cannot end with dot unless it's all just dots. This is because it would be impossible to know when to stop parsing dots and maybe parse a dotted member access.
			if string[-1] == '.' and not string.chars.all? { _1 == '.' }
				raise "Custom operator `#{string}` cannot end with a dot unless all other characters are dots"
			end

			# manual catch for set literal
			# @[ { (

			if string == '@' and %([ \( {).include? curr.string
				string += eat
				# return Key_Identifier_Token.new string
				return Key_Operator_Token.new string
			end

			Operator_Token.new string
		elsif curr.identifier?
			while curr.identifier?
				string += eat
				eat while curr == '\\' # ??? I think backslashes in the middle of identifiers is cool
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


	def eat_oneline_comment
		''.tap do |comment|
			eat '`'
			eat while curr.whitespace? # skip whitespace or tab before body

			while chars? and not curr.newline? # and not curr == '`'
				comment << eat
			end

			# eat if curr == '`' # this allows comments in between expressions
		end
	end


	def eat_until_delimiter
		"".tap {
			while chars? and not curr.delimiter?
				_1 << eat
			end
			eat while curr.newline?
		}
	end


	# note: stored value doesn't preserve newlines. maybe it should in case I want to generate documentation from these comments.
	def eat_multiline_comment
		''.tap do |comment|
			marker = '```' # '###'
			eat_many 3, marker
			eat while curr.whitespace? or curr.newline?

			while chars? and peek(0, 3) != marker
				comment << eat
				eat while curr.newline?
			end

			eat_many 3, marker
			# bug: if you comment out a ## comment line, it becomes ### which then expects a closing ###. Not sure if I should add `if peek(0, 3) == marker`
		end
	end


	def eat_string
		''.tap do |str|
			quote = eat

			while chars? and curr != quote
				str << eat
			end

			eat quote # eat the ending quote
		end
	end


	def reduce_delimiters
		eat while curr.delimiter? and last == curr
	end


	def lowercase? c
		c.downcase == c
	end


	def uppercase? c
		c.upcase == c
	end


	def lex input = nil # note anything that's just eaten is ignored. The parser will only receive what's in @tokens
		@source = input if input
		raise 'Lexer.source is nil' unless source

		# Delimiter_Token
		#	( { [ , ] } )

		while chars?
			index_before_this_lex_loop = @i
			col_before                 = @col
			row_before                 = @row

			token = if curr == '`' # comments!
				comment = if peek(0, 3) == '```'
					eat_multiline_comment
				elsif peek(0, 2) == '`'
					eat_oneline_comment
				else
					eat_oneline_comment
				end
				# Comment_Token.new(comment)
				nil

			elsif curr == '\\'
				eat and nil

			elsif curr.delimiter? # ( { [ , ] } ) \n \s \t \r ;

				if curr == ';' or curr == ','
					Delimiter_Token.new(eat)
				elsif curr == "\s"
					eat and nil

				elsif curr == "\n" or curr == "\r" or curr == "\s" or curr == "\t"
					Delimiter_Token.new(eat).tap {
						reduce_delimiters # if _1.string == "\n" or _1.string == "\s"  or _1.string == "\t"
					}
					# elsif curr == "\r"# or curr == "\t"# or curr == "\s"
					# 	eat and nil
				else
					# ( { [ , ] } )
					Delimiter_Token.new(eat)
				end

			elsif curr.numeric?
				Number_Token.new(eat_number)

			elsif curr == '.' and peek&.numeric?
				Number_Token.new(eat_number)

			elsif curr.legal_symbol? or curr.identifier? # this will make all identifiers, reserved or otherwise
				make_identifier_token

			elsif curr == '"' or curr == "'"
				String_Token.new(eat_string)

			elsif curr.reserved?
				Reserved_Token.new(eat)

			else
				raise "unknown #{curr}"
			end

			next unless token

			token.start_index = index_before_this_lex_loop
			token.end_index   = @i

			token.column = col_before
			token.line   = row_before

			@tokens << token
		end

		tokens << EOF_Token.new
		tokens.compact!
		tokens
	end

end
