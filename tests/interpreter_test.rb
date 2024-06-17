# @todo use a real testing framework

require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'
require_relative '../source/interpreter/interpreter'

source = File.read('tests/sandbox.em').to_s
lexer  = Lexer.new source
tokens = lexer.lex

parser      = Parser.new tokens
expressions = parser.parse_until

interp = Interpreter.new expressions
interp.evaluate!
