Lexeme = Struct.new('Lexeme', :type, :value, :reserved, :l0, :c0, :l1, :c1) do
	def is compare
		if compare.is_a? Symbol
			compare == type
		elsif compare.is_a? String
			compare == value
		elsif compare.is_a? Array
			compare.any? do |it|
				it == value
			end
		else
			compare == self
		end
	end

	def isnt compare
		is(compare) == false
	end

	def line_col
		"#{l0}:#{c0}..#{l1}:#{c1}"
	end
end
