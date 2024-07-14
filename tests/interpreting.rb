require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'
require_relative '../source/interpreter/interpreter'


def t code, &block
    raise ArgumentError, '#t requires a code string' unless code.is_a?(String)
    raise ArgumentError, '#t requires a block' unless block_given?

    begin
        tokens = Lexer.new(code).lex
        ast    = Parser.new(tokens).to_ast
        output = Interpreter.new(ast).interpret!
    rescue Exception => e
        output = e # so that I can explicitly test what the output might be, even when the interpreter raises an exception. I probably won't use this much, but it works for now
    end

    block_result = block.call output

    if not block_result
        raise "\n\n——————————— FAILED TEST\n#{code}\n——————————— PROGRAM OUTPUT\n#{output.inspect}\n———————————\n"
    end

    @tests_ran ||= 0
    @tests_ran += 1
end


# t File.read('tests/sandbox.em').to_s do |it|
#     true
# end

t '' do |it|
    it.nil?
end

t '1' do |it|
    it == 1 and it.is_a? Integer
end

t '-1' do |it|
    it == -1 and it.is_a? Integer
end

t '48.15' do |it|
    it == 48.15 and it.is_a? Float
end

t '16.' do |it|
    it == 16.0 and it.is_a? Float
end

t '.23' do |it|
    it.is_a? Float
end

t '2 + 3' do |it|
    it == 5
end

t '4 - 5' do |it|
    it == -1
end

t '6 * 7' do |it|
    it == 42
end

t "8/9" do |it|
    it == 0
end

t "10%11" do |it|
    it == 10
end

t "-1 + +3" do |it|
    it == 2
end

t "(1 + 2) * 3" do |it|
    it == 9 and it.is_a? Integer
end

t "1/2" do |it|
    it == 0
end

t "1/2.0" do |it|
    it == 0.5
end

t "1.0/2" do |it|
    it == 0.5
end

t "1.0/2.0" do |it|
    it == 0.5
end

t "true" do |it|
    it == true
end

t "!true" do |it|
    it == false
end

t "false" do |it|
    it == false
end

t "!false" do |it|
    it == !false
end

t "x = 1" do |it|
    it == 1
end

t ":lost" do |it|
    it == :lost
end

t "'lost'" do |it|
    it.is_a? String
end

t "'lost' == :lost" do |it|
    it == false
end

t ":lost == :lost" do |it|
    it == true
end

t "'lost' == 'lost'" do |it|
    it == true
end

t "a = 1 + 2" do |it|
    it == 3
end

t "{ b = 8 }" do |it|
    it.is_a? RuntimeError and it.message == 'Parser expected token(s): ["}"]'
end

t "b = 7
b
" do |it|
    it == 7
end

t "
a = 4815
b = a" do |it|
    it == 4815
end

t "boo" do |it|
    it.is_a? RuntimeError and it.message == "Undefined `boo`"
end

t "b = nil" do |it|
    it == nil
end

t "1, nil, 3" do |it|
    it == 3
end

t "'b in a string', b, 4+2, nil" do |it|
    it.is_a? RuntimeError and it.message == "Undefined `b`"
end

t "'`b` interpolated into the string'" do |it|
    it.is_a? String # todo: implement interpolation
end

t "x = 'the island'" do |it|
    it.is_a? String
end

t "
method { 4815162342 }
method()
" do |it|
    it == 4815162342
end
