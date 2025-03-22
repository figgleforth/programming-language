class Token
	# include Reserved_Tokens

	attr_accessor :string, :start_index, :end_index, :line, :column

	def initialize string = ''
		self.string = string
	end

	def isa other
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

	def to_s
		"#{self.class.name}(#{self.string.inspect.gsub('"', '')})"
	end
end


class Reserved_Token < Token

end


class Delimiter_Token < Token
end


class Identifier_Token < Token
end


class Reserved_Identifier_Token < Identifier_Token
end


class Operator_Token < Identifier_Token
end


class Reserved_Operator_Token < Operator_Token
end


class String_Token < Token
end


class Number_Token < Token
	def string= value
		@string = value.gsub('_', '').gsub(',', '')
	end

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
		if string.include? '.'
			f
		else
			i == f ? i : f
		end
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
