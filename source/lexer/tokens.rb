class Token
	attr_accessor :string, :start_index, :end_index, :line, :column

	RESERVED_IDENTIFIERS = %w(
		if    elsif    elif    else
		while elswhile elwhile else
		unless until true false nil
		pri private pub public
		and or operator self
		raise return skip stop
	).sort_by! { -_1.length }

	RESERVED_OPERATORS = %w(>!!! >!! >! =; .. .< >. >< .? @{ @[ @\( ->).sort_by! { -_1.length }

	RESERVED_CHARS = %w< [ { ( , ) } ] >.sort_by! { -_1.length } # these cannot be used in custom operator identifiers. They are only for program structure {}, collections [,] and (,)

	VALID_CHARS = %w(. = + - ~ * ! @ # $ % ^ & ? / | < > _ : ; ).sort_by! { -_1.length } # examples of valid operators `.:.:`, `.~~~~~:::`, `|||`, `====.==`

	PREFIX  = %w(++ -- - + ! ?? ~ @ _ >!!! >!! >!).sort_by! { -_1.length } # @ _ for scope[@/_]
	INFIX   = %w(. = + - * : / % < > += -= *= |= /= %= &= ^= <<= >>= !== === >== == != <= >= && || & | ^ << >> ** .? .. .< >< >. or and).sort_by! { -_1.length }
	POSTFIX = %w(++ -- ! ? ?? =;).sort_by! { -_1.length }


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
			other == self.class or self.is_a?(other)
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
		first and first.upcase == first and not constant?
	end


	def member? # all lower, some_method or some_variable
		# test = string #&.gsub('_', '')&.gsub('%', '')
		# test&.chars&.all? { |c| c.downcase == c }
		first = without_leading_underscores[0]
		first and first.downcase == first
	end


	def without_leading_underscores
		string.gsub(/^#{Regexp.escape('_')}+/, '')
	end


	# def inspect
	# 	string
	# end
end


class Reserved_Token < Token

end


class Delimiter_Token < Token
	# def to_s
	# 	string.inspect
	# end
end


class Identifier_Token < Token
end


class Operator_Token < Token

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

	# def inspect
	# 	"Key_Op(#{string.inspect})"
	# end

end


class Key_Identifier_Token < Token
	# def inspect
	# 	"Key_Ident(#{string})"
	# end

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
	# def inspect
	# 	"String(#{string})"
	# end

	def interpolated?
		string.include? '`'
	end
end


class Number_Token < Token
	# def inspect
	# 	# string
	# 	"Num(#{string})"
	# end

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


	# def inspect
	# 	# "Comment(#{string})"
	# 	"Comment()"
	# end
end


class EOF_Token < Token
end
