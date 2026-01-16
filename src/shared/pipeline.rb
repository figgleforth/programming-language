module Ore
	class Pipeline
		attr_accessor :stages

		def self.default
			self.new Ore::Lexer, Ore::Parser, Ore::Interpreter
		end

		def initialize * stages
			@stages = stages
		end

		def run input
			result = input
			stages.each_with_index do |it, at|
				stage = if it.is_a? Class
					it.new result
				else
					it
				end
				
				stage.input = result
				next if stage.skip

				result = stage.output
			end
			result
		end
	end
end
