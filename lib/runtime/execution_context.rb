module Air
	class Execution_Context
		attr_accessor :routes, :servers, :loaded_files

		def initialize
			@routes       = {}
			@servers      = []
			@loaded_files = {} # {filename: code}
		end
	end
end
