Lexeme = Struct.new('Lexeme', :type, :value, :reserved, :l0, :c0, :l1, :c1) do
	def is compare
		if compare.is_a? Symbol
			compare == type
		elsif compare.is_a? String
			compare == value
		else
			compare == self
		end
	end

	def isnt compare
		is(compare) == false
	end
end
