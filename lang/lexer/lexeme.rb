Lexeme = Struct.new('Lexeme', :type, :value, :reserved, :line, :column) do
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
end
