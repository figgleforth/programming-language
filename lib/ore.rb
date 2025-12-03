require_relative 'shared/constants'
require_relative 'shared/helpers'

# Compile-time (source to AST)
require_relative 'compiler/lexeme'
require_relative 'compiler/expressions'
require_relative 'compiler/lexer'
require_relative 'compiler/parser'

# Runtime (AST to execution)
require_relative 'runtime/errors'
require_relative 'runtime/scope'
require_relative 'runtime/types'
require_relative 'runtime/context'
require_relative 'runtime/server_runner'
require_relative 'runtime/interpreter'

module Ore
	extend Helpers

	def self.interp_file filepath, with_std: true
		interp File.read(filepath), with_std: with_std, filepath: File.expand_path(filepath)
	end

	def self.interp_file_with_hot_reload filepath
		require 'listen'

		reload          = true
		listener        = nil
		current_servers = []
		shutdown        = false

		Signal.trap 'INT' do
			puts "\nShutting down..."
			shutdown = true
			Thread.main.raise Interrupt
		end

		Signal.trap 'TERM' do
			puts "\nShutting down..."
			shutdown = true
			Thread.main.raise Interrupt
		end

		begin
			while reload && !shutdown
				reload = false

				code        = File.read filepath
				global      = Ore::Global.with_standard_library
				interpreter = Ore::Interpreter.new Ore.parse(code), global
				result      = interpreter.output

				if interpreter.context.servers.any?
					current_servers = interpreter.context.servers

					unless listener
						listener = Listen.to('.', only: /\.(ore|rb)$/) do |modified, added, removed|
							puts "\nReloading..."
							reload = true
							current_servers.each(&:stop)
						end
						listener.start

						puts "Server(s) running. Press Ctrl+C to stop."
						puts "Watching for .ore and .rb file changes..."
					end

					current_servers.each do |server|
						server.server_thread&.join
					end
				end
			end
		rescue Interrupt
		ensure
			listener&.stop if listener
			current_servers.each &:stop
		end

		result
	end

	def self.interp source_code, with_std: true, filepath: nil
		context = Ore::Context.new
		context.register_source filepath || '<input>', source_code

		lexemes      = Lexer.new(source_code, filepath: filepath).output
		expressions  = Parser.new(lexemes, source_file: filepath).output
		global_scope = with_std ? Global.with_standard_library : Global.new
		interpreter  = Interpreter.new expressions, global_scope, context

		interpreter.output
	end

	def self.parse_file filepath
		parse File.read(filepath)
	end

	def self.parse source_code
		lexemes = Lexer.new(source_code).output
		Parser.new(lexemes).output
	end

	def self.lex_file filepath
		lex File.read(filepath)
	end

	def self.lex source_code
		Lexer.new(source_code).output
	end
end
