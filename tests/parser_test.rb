require_relative '../source/lexer'
require_relative '../source/parser'

# source = '1 + 2 * 3 - 4 / 2'
file = 'language/expressions.e'
source = File.read(file).to_s

puts "\n\n:: #{file} ::\n\n"

lexer = Lexer.new source
tokens = lexer.make_tokens

parser = Parser.new tokens
statements = parser.parse

puts "\n:: #{file} ::"

statements.each do |stmt|
   puts
   puts stmt.to_s
end
