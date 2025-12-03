module Ore
	class Context
		attr_accessor :routes, :servers, :loaded_files, :source_files

		def initialize
			@routes       = {}
			@servers      = []
			@loaded_files = {} # {filename: expressions}
			@source_files = {} # {filepath: source_code} for error reporting
		end

		def register_source filepath, source_code
			resolved = filepath ? File.expand_path(filepath) : '<input>'
			# todo: This shouldn't default to "<input>", that's weird
			@source_files[resolved] = source_code
		end

		def get_source_lines filepath
			source = @source_files[filepath]
			source ? source.lines.map(&:chomp) : []
		end

		def load_file filepath, into_scope
			resolved_path = File.expand_path filepath

			unless loaded_files[resolved_path]
				code                        = File.read resolved_path
				lexemes                     = Ore::Lexer.new(code).output
				expressions                 = Ore::Parser.new(lexemes).output
				loaded_files[resolved_path] = expressions
			end

			# Always interpret into the target scope (allows reuse in different scopes)
			expressions      = loaded_files[resolved_path]
			temp_interpreter = Ore::Interpreter.new expressions, into_scope
			temp_interpreter.output

			nil
		end
	end
end
