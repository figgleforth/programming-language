module Code
	class CLI
		INSTRUCTIONS = <<~INST
			--- Usage
				bin/program <file>          Short for `bin/program run <file>`
				bin/program [COMMAND]       Run command from COMMANDS below

				bin/program -h | --help     Show help instructions
				bin/program -v | --version  Show version number

			--- COMMANDS
				run <file>                  Run file with hot-reload 
				check <file>                Run basic type check on file

				repl                        [Very WIP] Enter repl mode

				interp <code>               Run code string without hot reload
				interpf <file>              Run file once without hot reload

				parse <code>                Puts AST for code
				parsef <file>               Puts AST for file

				declare <code>              Show forward declarations for code
				declaref <file>             Show forward declarations for file

				lex <code>                  Puts lexer tokens for code
				lexf <file>                 Puts lexer tokens for file


			--- SUFFIX OPTIONS
				-p | --puts                 Prints output created by program

				-r | --reload               Hot reload for .(rb|code) and cwd
				                            + Restarts process on any change,
				                              instead of reloading in place

			--- EXAMPLES
				bin/program guides/hello_world.code -p
				bin/program lex "x = 5 + 3" -p

				bin/program parsef guides/hello_world.code -p
				bin/program interp "4815" -p

		INST

		def self.run argv
			new(argv).run
		end

		def initialize argv
			@argv         = argv
			@command      = argv[0]
			@arg          = argv[1]
			@print_output = argv.include?('-p') || argv.include?('--puts')
			@reload       = argv.include?('-r') || argv.include?('--reload')
		end

		def run
			if @argv.empty?
				puts INSTRUCTIONS
				exit 1
			end

			case @command
			when '-v', '--version'
				puts "Code #{VERSION}"
			when '-h', '--help'
				puts INSTRUCTIONS
			when 'repl'
				Code::REPL.new.run
			when 'check'
				Code.type_check_file @arg
			when 'lex'
				dump Code.lex(@arg)
			when 'lexf'
				dump Code.lex_file(@arg)
			when 'parse'
				dump Code.parse(@arg)
			when 'parsef'
				dump Code.parse_file(@arg)
			when 'declare'
				dump Code.declare(@arg)
			when 'declaref'
				dump Code.declare_file(@arg)
			when 'interp'
				run_source @arg
			when 'interpf'
				run_source ::File.read(@arg), file: @arg
			when 'interp-nostd'
				run_source @arg, load_standard_library: false
			when 'interpf-nostd'
				run_source ::File.read(@arg), file: @arg, load_standard_library: false
			when 'run'
				hot_reload @arg
			else
				hot_reload @command
			end
		rescue Errno::ENOENT => e
			# The missing file might be the one the CLI was told to run, or one the program itself
			# tried to open (::File.read, @load). Errno::ENOENT names the real path in its
			# message ("... - <path>"); fall back to the CLI argument only if that isn't there.
			missing = e.message.include?(' - ') ? e.message.split(' - ').last : (@arg || @command)
			$stderr.puts "Could not find file `#{missing}`"
			exit 1
		rescue Code::Error => e
			$stderr.puts e.message
			exit 1
		end

		private

		def dump result
			pp result if @print_output
		end

		def run_source source_code, file: nil, load_standard_library: true
			interpreter                       = Code::Interpreter.new
			interpreter.load_standard_library = load_standard_library
			interpreter.register_source file, source_code if file
			result = interpreter.run source_code
			puts interpreter.stringify_for_display(result) if @print_output
		end

		def hot_reload filepath
			interpreter, result = Code::Hot_Reloader.new(filepath, reload: @reload).run
			puts interpreter.stringify_for_display(result) if @print_output && interpreter
		end
	end
end
