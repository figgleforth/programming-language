# todo: use a real testing framework

require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'

source = File.read('emerald/02.em').to_s
lexer  = Lexer.new source
tokens = lexer.lex

parser     = Parser.new tokens
statements = parser.parse

puts "\nSTATEMENTS\n\n"
statements.each do |s|
   puts "- #{s}"
end
