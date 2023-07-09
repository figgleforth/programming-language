require './language.rb'

filename = './language/test.lang'
source_code = File.read(filename)

lexer = Lexer.new(source_code)
tokens = lexer.tokens

puts "tokens: ", tokens

# parser = Parser.new(tokens)

# hint) abstract syntax tree
# ast = parser.parse

# puts ast.inspect


