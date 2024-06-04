# @todo use a real testing framework

require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'
require_relative '../source/interpreter/interpreter'

source = File.read('emerald/tests/05.em').to_s
lexer  = Lexer.new source
tokens = lexer.lex

parser     = Parser.new tokens
statements = parser.parse

interpreter = Interpreter.new statements

# puts
# puts "\n== TOKENS ==\n"
# puts tokens

# puts "\n== PARSED STATEMENTS ==\n\n"
# puts statements.join("\n\n")

puts "\n== INTERPRETATION ==\n\n"
puts interpreter.interpret
