require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'
require_relative '../source/interpreter/interpreter'


def t code, &block
    raise ArgumentError, '#t requires a code string' unless code.is_a?(String)
    raise ArgumentError, '#t requires a block' unless block_given?

    begin
        exception = nil # store it so that I can check against the error message below. todo: make some kind of error message object, similar to localization? Would be cool to allow you to customize the error messages
        tokens    = Lexer.new(code).lex
        ast       = Parser.new(tokens).to_ast
        output    = Interpreter.new(ast).interpret!
    rescue Exception => e
        exception = e
    end

    block_param  = exception || output
    block_result = block.call block_param

    if not block_result
        raise "\n\n——————————— FAILED TEST\n#{code}\n——————————— PROGRAM OUTPUT\n#{output.inspect}\n———————————\nBlock called with: #{block_param.inspect}"
    end

    @tests_ran ||= 0
    @tests_ran += 1
end


t File.read('tests/sandbox.em').to_s do |it|
    true
end

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
    it == 0.23 and it.is_a? Float
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
    it == true
end

t 'true && false' do |it|
    it == false
end

t 'true || false' do |it|
    it == true
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
    it == { 'b' => 8 }
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

t 'boo' do |it|
    it.is_a? RuntimeError and it.message == 'Undefined `boo`'
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

t '{ -> true }' do |it|
    it == true
end

t "
method { -> 4 }
method2 { 5 }
method() + method2()
" do |it|
    it == 9
end
