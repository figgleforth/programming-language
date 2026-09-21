module Code
	class Lexeme
		LITERAL_TYPES = %i[string symbol number fence html].freeze

		attr_accessor :type, :value, :reserved, :quotation_style, :line_start, :column_start, :line_end, :column_end, :source_file

		def initialize type = nil, value = nil, reserved = nil, quotation_style = nil
			@type = type
			@value = value
			@reserved = reserved
			@quotation_style = quotation_style
		end

		def == other
			if other.is_a? Lexeme
				value == other.value
			else
				super other
			end
		end

		def is compare
			if compare.is_a? Symbol
				compare == type
			elsif compare.is_a? ::String
				!LITERAL_TYPES.include?(type) && compare == value
			elsif compare.is_a? ::Array
				compare.any? do |it|
					if it.is_a? Symbol
						it == type
					else
						!LITERAL_TYPES.include?(type) && it == value
					end
				end
			else
				compare == self
			end
		end

		def isnt compare
			is(compare) == false
		end

		def line_col
			"#{line_start}:#{column_start}..#{line_end}:#{column_end}"
		end
	end
end
