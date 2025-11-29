require_relative 'constants'
require_relative 'helpers'

# Compile-time (source to AST)
require_relative 'compiler/lexeme'
require_relative 'compiler/expressions'
require_relative 'compiler/lexer'
require_relative 'compiler/parser'

# Runtime (AST to execution)
require_relative 'runtime/errors'
require_relative 'runtime/scope'
require_relative 'runtime/types'
require_relative 'runtime/execution_context'
require_relative 'runtime/interpreter'

module Air
	extend Helpers

	def self.interp_file filepath, with_std: true
		interp File.read(filepath), with_std: with_std
	end

	def self.interp source_code, with_std: true
		lexemes      = Lexer.new(source_code).output
		expressions  = Parser.new(lexemes).output
		global_scope = with_std ? Global.with_standard_library : Global.new
		interpreter  = Interpreter.new expressions, global_scope

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
