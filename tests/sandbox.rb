require_relative '../source/lexer/lexer'
require_relative '../source/parser/parser'
require_relative '../source/parser/ast'
require_relative '../source/interpreter/interpreter'

tokens = Lexer.new(File.read('tests/sandbox.em').to_s).lex
ast    = Parser.new(tokens).to_ast

if ARGV.include? 'interpret'
    output = Interpreter.new(ast).interpret!
    puts "SANDBOX INTERPRETED OUTPUT\n\n#{output || output.inspect}"
else
    puts "SANDBOX PARSED OUTPUT\n\n"
    ast.each do |it|
        puts it.inspect
        puts
    end
end
