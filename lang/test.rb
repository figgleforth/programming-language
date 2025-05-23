require './lang/lexer/lexer'
require './lang/parser/parser'

source = File.read 'readme.txt'
tokens = Lexer.new(source).output
expressions = Parser.new(tokens).output

# puts tokens.inspect
puts expressions.map(&:inspect)
