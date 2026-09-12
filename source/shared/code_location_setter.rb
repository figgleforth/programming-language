module Code
	module Code_Location_Setter
		# [Code::Code_Location]
		attr_accessor :code_location

		# @param [::Integer] l0 starting line
		# @param [::Integer] c0 starting column
		# @param [::Integer] l1 ending line
		# @param [::Integer] c1 ending column
		# @return [Code::Code_Location]
		def set_location_span l0, c0, l1, c1
			@code_location = Code_Location[l0, c0, l1, c1]
		end
	end
end
