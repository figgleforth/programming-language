module Reserved_Tokens
	RESERVED_IDENTIFIERS        = %w(
		if    elsif    elif    else
		while elswhile elwhile else
		unless until true false nil
		skip stop   and or operator
		raise return
	).sort_by! { -_1.length }
	RESERVED_IDENTIFIERS_HASHED = RESERVED_IDENTIFIERS.map &:hash

	RESERVED_OPERATORS        = %w(>!!! >!! >! =; .. .< >. >< .? -> .@ @ -@ ./ ../ .../).sort_by! { -_1.length }
	RESERVED_OPERATORS_HASHED = RESERVED_OPERATORS.map &:hash

	RESERVED_CHARS        = %w< [ { ( , ) } ] >.sort_by! { -_1.length } # these cannot be used in custom operator identifiers. They are only for program structure {}, collections [,] and (,)
	RESERVED_CHARS_HASHED = RESERVED_CHARS.map &:hash

	VALID_CHARS        = %w(. = + - ~ * ! @ # $ % ^ & ? / | < > _ : ; ).sort_by! { -_1.length } # examples of valid operators `.:.:`, `.~~~~~:::`, `|||`, `====.==`
	VALID_CHARS_HASHED = VALID_CHARS.map &:hash
	LEGAL_SYMBOLS      = VALID_CHARS

	PREFIX        = %w(_ __ - + ! ?? ~ > @ # -# >!!! >!! >! ./ ../ .../).sort_by! { -_1.length } # @ _ for scope[@/_]
	PREFIX_HASHED = PREFIX.map &:hash

	INFIX        = %w(. .@ = + - * : / % < > += -= *= |= /= %= &= ^= <<= >>= !== === >== == != <= >= && || & | ^ << >> ** .? .. .< >< >. or and).sort_by! { -_1.length }
	INFIX_HASHED = INFIX.map &:hash

	POSTFIX        = %w(! ? ?? =;).sort_by! { -_1.length }
	POSTFIX_HASHED = POSTFIX.map &:hash

	ALL        = [RESERVED_IDENTIFIERS, RESERVED_OPERATORS, RESERVED_CHARS, VALID_CHARS, PREFIX, INFIX, POSTFIX].inject :+
	ALL_HASHED = [RESERVED_IDENTIFIERS_HASHED, RESERVED_OPERATORS_HASHED, RESERVED_CHARS_HASHED, VALID_CHARS_HASHED, PREFIX_HASHED, INFIX_HASHED, POSTFIX_HASHED].inject :+

	unless ALL.uniq.count == ALL_HASHED.uniq.count
		raise "Hash collision"
	end
end


class Token
	include Reserved_Tokens

	attr_accessor :string, :start_index, :end_index, :line, :column, :location_label


	def initialize string = ''
		@string = string
	end


	# token == CommentToken
	# token == '#'
	def == other
		unless other
			return false
		end

		if other.is_a? String
			other == string
		elsif other.is_a? Class
			other == self.class || self.is_a?(other)
		else
			# other.ancestors.include? self
			raise "unknown == with #{other.inspect}"
		end
	end


	def is other
		unless other
			return false
		end

		if other.is_a? String
			other == string
		elsif other.is_a? Class
			other == self.class || self.is_a?(other)
		else
			# other.ancestors.include? self
			raise "unknown == with #{other.inspect}"
		end
	end


	def infix?
		INFIX.include? string
	end


	def prefix?
		PREFIX.include? string
	end


	def postfix?
		POSTFIX.include? string
	end


	def constant? # all upper, LIKE_THIS
		test = string&.gsub('_', '')&.gsub('%', '')
		test&.chars&.all? { |c| c.upcase == c }
	end


	def class? # capitalized, Like_This or This
		# test = string&.gsub('_', '')&.gsub('%', '')
		# test[0]&.upcase == test[0] and not constant?
		first = without_leading_underscores[0]
		first && first.upcase == first && !constant?
	end


	def member? # all lower, some_method or some_variable
		# test = string #&.gsub('_', '')&.gsub('%', '')
		# test&.chars&.all? { |c| c.downcase == c }
		first = without_leading_underscores[0]
		first && first.downcase == first
	end


	def without_leading_underscores
		string.gsub(/^#{Regexp.escape('_')}+/, '')
	end
end


class Reserved_Token < Token

end


class Delimiter_Token < Token
end


class Identifier_Token < Token
	def location_in_source # unused
		"#{line}:#{column}"
	end
end


class Operator_Token < Identifier_Token

	def constant?
		false
	end


	def class?
		false
	end


	def member?
		true
	end
end


class Key_Operator_Token < Operator_Token

	def to_s
		string
	end

end


class Key_Identifier_Token < Token
	def member?
		false
	end


	def constant?
		false
	end


	def class?
		false
	end
end


class String_Token < Token
	def interpolated?
		string.include? '`'
	end
end


class Number_Token < Token
	def type_of_number
		if string[0] == '.'
			:float_decimal_beg
		elsif string[-1] == '.'
			:float_decimal_end
		elsif string&.include? '.'
			:float_decimal_mid
		else
			:integer
		end
	end


	# https://stackoverflow.com/a/18533211/1426880
	def string_to_float
		Float(string)
		i, f = string.to_i, string.to_f
		i == f ? i : f
	rescue ArgumentError
		self
	end
end


class Comment_Token < Token
	attr_accessor :multiline # may be useful for generating documentation

	def initialize string = nil, multiline = false
		super string
		@multiline = multiline
	end
end


class EOF_Token < Token
	def initialize string = 'EOF'
		super
	end
end
