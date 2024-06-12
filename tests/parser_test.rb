# @todo use a real testing framework

require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'

source = File.read('emerald/tests/05.em').to_s
lexer  = Lexer.new source
tokens = lexer.lex
# puts "tokens"
# puts
# tokens.each do |t|
#     puts "- #{t}"
# end
# puts "///////"

parser     = Parser.new tokens
program = parser.to_ast

puts
# puts "\n== TOKENS ==\n"
# puts tokens

puts "============="
puts "== PROGRAM ==\n\n"
puts program
