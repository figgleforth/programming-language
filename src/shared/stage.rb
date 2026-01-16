module Ore
	class Stage
		attr_accessor :input, :skip

		def initialize input
			@input = input
		end

		def output
			raise "#{self.class.name} hasn't implemented Stage#output"
		end
	end
end
