require './src/constants'
require './src/lexer/lexer'
require './src/parser/parser'
require './src/interpreter/interpreter'
require './src/interpreter/constructs'

def interp code
	lexemes     = Lexer.new(code).output
	expressions = Parser.new(lexemes).output
	Interpreter.new(expressions).output
end

def parse code
	lexemes = Lexer.new(code).output
	Parser.new(lexemes).output
end

def lex code
	Lexer.new(code).output
end

def interp_file file_path
	interp File.read file_path
end

def parse_file file_path
	parse File.read file_path
end
