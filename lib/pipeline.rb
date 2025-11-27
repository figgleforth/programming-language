module Air
	class Pipeline
		attr_accessor :with_std

		def initialize with_std = true
			@with_std = with_std
		end

		def output source_code
			Air.interp source_code, with_std: with_std
		end
	end
end
