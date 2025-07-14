require './src/shared/constants'
require './src/shared/constructs'
require './src/interpreter'
require './src/lexer'
require './src/parser'

def interp code
	lexemes      = lex code
	expressions  = parse code
	@interpreter = Interpreter.new expressions
	@interpreter.output
end

def parse code
	lexemes = lex code
	@parser = Parser.new lexemes
	@parser.output
end

def lex code
	@lexer = Lexer.new code
	@lexer.output
end

def interp_file file_path
	interp File.read file_path
end

def parse_file file_path
	parse File.read file_path
end

def refute_raises * exceptions
	yield
rescue *exceptions => e
	flunk "Expected no exception, but got #{e.class}: #{e.message}"
end

def assert condition
	raise "Expected condition to be truthy." unless condition
end
