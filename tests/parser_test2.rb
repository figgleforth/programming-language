require_relative '../source/lexer'
require_relative '../source/parser2'

source = File.read('examples/03.sp').to_s

lexer = Lexer.new(source)
tokens = lexer.make_tokens

parser = Parser2.new(tokens)
statements = parser.parse

puts "\n\nSTATEMENTS:\n\n"
statements.each do |stmt|
   puts '- ' + stmt.to_s
   puts
end
