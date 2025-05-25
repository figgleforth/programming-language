require './lang/lexer/lexer'
require './lang/parser/parser'
require 'awesome_print'

source = File.read 'readme.txt'
tokens = Lexer.new(source).output
expressions = Parser.new(tokens).output

# ap tokens
ap expressions
