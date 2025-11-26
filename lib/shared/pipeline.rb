module Air
	class Pipeline
		attr_accessor :with_std

		def initialize with_std = true
			@with_std = with_std
		end

		def output source_code
			lexemes      = Lexer.new(source_code).output
			expressions  = Parser.new(lexemes).output
			global_scope = with_std ? Air::Global.with_standard_library : Air::Global.new
			interpreter  = Interpreter.new expressions, global_scope

			interpreter.output
		end
	end

	def self.interp_file filepath, with_std: true
		interp_code File.read(filepath), with_std: with_std
	end

	def self.interp_code code, with_std: true
		pipe = Pipeline.new with_std
		pipe.output code
	end
end
