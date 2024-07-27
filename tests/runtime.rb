require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'
require_relative '../source/interpreter/runtime'
require 'pp'


def t code, &block
    raise ArgumentError, '#t requires a code string' unless code.is_a?(String)
    raise ArgumentError, '#t requires a block' unless block_given?

    begin
        exception = nil # store it so that I can check against the error message below
        tokens    = Lexer.new(code).lex
        ast       = Parser.new(tokens).to_ast
        output    = Runtime.new(ast).evaluate
    rescue Exception => e
        exception = e
        raise e
    end

    block_param  = exception || output
    block_result = block.call output, exception

    if not block_result
        raise "\n\n——————————— FAILED TEST\n#{code}\n——————————— #t it (param 1)\n#{output.inspect}\n——————————— #t exception (param 2)\n#{exception.inspect}\n———————————\n"
    end

    @tests_ran ||= 0
    @tests_ran += 1
end


t File.read('./examples/runtime.em').to_s do |it|
    true
end

# t '123' do |it|
#     it == 123
# end
#
# t '"abc"' do |it|
#     it == "abc"
# end
#
# t ':xyz' do |it|
#     it == ":xyz"
# end
#
# t 'nil' do |it|
#     it == nil
# end
#
# t 'woof = 123
# bark' do |it, e|
#     e.is_a? RuntimeError and e.message == 'Undefined `bark` in global[@,woof]'
# end
#
# t '{ -> }' do |it|
#     it.is_a? Block_Expr
# end
#
# t 'x = { -> }' do |it|
#     it.is_a? Block_Expr
# end
#
# t 'bark { -> }' do |it|
#     it.is_a? Block_Expr
# end
#
# t 'bark { -> "woof" }
# bark()' do |it|
#     it == "woof"
# end
#
# t '{ x y }' do |it|
#     it == { "x" => nil, "y" => nil }
# end
#
# # t 'Game {
# # 	id = 123;
# # }.tap {
# # 	game1 = it.new
# # 	game2 = it.new
# # }' do |it|
# #
# # end
