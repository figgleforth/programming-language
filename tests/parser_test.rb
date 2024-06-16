# @todo use a real testing framework

require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'

source  = File.read('tests/sandbox.em').to_s
lexer   = Lexer.new source
tokens  = lexer.lex
parser  = Parser.new tokens
program = parser.to_ast

puts "\n\n============= AST (#{[program].flatten.count} statements):\n\n"
# puts program
[program].flatten.each do |expr|
    puts expr.inspect
    puts
end
