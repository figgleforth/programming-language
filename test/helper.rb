require './lang/constants'
require './lang/lexer/lexer'
require './lang/parser/parser'
require './lang/interpreter/interpreter'
require './lang/interpreter/constructs'

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

# todo, A helper for asserting lexeme.type, like assert_operator(out) or assert_type(:operator, out). I don't have a preference for either, but it's needed. :lexeme_type_helper
