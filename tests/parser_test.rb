# todo: use a real testing framework

require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'

source = File.read('language/02.e').to_s
lexer  = Lexer.new source
tokens = lexer.lex

parser = Parser.new tokens
statements = parser.parse

puts "\nSTATEMENTS\n\n"
puts statements
