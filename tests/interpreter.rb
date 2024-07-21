require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'
require_relative '../source/interpreter/interpreter'
require 'pp'


def t code, &block
    raise ArgumentError, '#t requires a code string' unless code.is_a?(String)
    raise ArgumentError, '#t requires a block' unless block_given?

    begin
        exception = nil # store it so that I can check against the error message below
        tokens    = Lexer.new(code).lex
        ast       = Parser.new(tokens).to_ast
        output    = Interpreter.new(ast).interpret!
    rescue Exception => e
        exception = e
    end

    block_param  = exception || output
    block_result = block.call block_param

    if not block_result
        raise "\n\n——————————— FAILED TEST\n#{code}\n——————————— PROGRAM OUTPUT\n#{output.inspect}\n——————————— Block called with:\n#{block_param.inspect}\n———————————\n"
    end

    @tests_ran ||= 0
    @tests_ran += 1
end


t 'x { in -> in }
x()' do |it|
    it.is_a? Nil_Construct
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
    it == ':lost'
end

t "'lost'" do |it|
    it.is_a? String and it == '"lost"'
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
    it.is_a? RuntimeError and it.message == 'undefined variable or function `boo` in scope: Global'
end

t "b = nil" do |it|
    it.is_a? Nil_Construct
end

t "1, nil, 3" do |it|
    it == 3
end

t "'b in a string', b, 4+2, nil" do |it|
    it.is_a? RuntimeError and it.message == "undefined variable or function `b` in scope: Global"
end

t "'`b` interpolated into the string'" do |it|
    it.is_a? String
end

t "x = 'the island'" do |it|
    it.is_a? String
end

t '{ a = 4 + 8, x, y = 1, z = "2" -> true }' do |it|
    it == true
end

t "
func { -> 4 }
func2 { -> 6 }
func() + func2()
" do |it|
    it == 10
end

t 'func { -> 1 }' do |it|
    it.is_a? Block_Construct
end

t '0..87' do |it|
    it.is_a? Range_Construct
end

t '1.<10' do |it|
    it.is_a? Range_Construct
end

t 'abc?def' do |it|
    it.is_a? RuntimeError and it.message == 'Cannot have ? or ! or : in the middle of an identifier'
end

t 'abc!def' do |it|
    it.is_a? RuntimeError and it.message == 'Cannot have ? or ! or : in the middle of an identifier'
end

t 'abc:def' do |it|
    it.is_a? RuntimeError and it.message == 'undefined variable or function `abc` in scope: Global'
end

t 'f { x = 3 -> x*3 }
f()' do |it|
    it == 9
end

t 'f { x = 3 -> x*3 }
f(4)' do |it|
    it == 12
end

t 'x { in -> in }
x()' do |it|
    it.is_a? Nil_Construct
end

t 'x { in = nil -> in }
x()' do |it|
    it.is_a? Nil_Construct
end

t 'x { in = 1 -> in }
x()' do |it|
    it == 1
end

t 'x = nil
f { in -> in || x }
f()
' do |it|
    it.is_a? Nil_Construct
end

t 'x = 3
f { in -> in || x }
f()
' do |it|
    it == 3
end

t 'x = 3
f { in -> in || x }
f(4)
' do |it|
    it == 4
end

t 'SOME_CONSTANT' do |it|
    it.is_a? RuntimeError and it.message == 'undefined constant `SOME_CONSTANT` in scope: Global'
end

t 'Random' do |it|
    it.is_a? RuntimeError and it.message == 'undefined class `Random` in scope: Global'
end

t 'Random {}' do |it|
    it.is_a? Class_Construct and it.name == 'Random'
end

t 'Random {}
Random
' do |it|
    it.is_a? Class_Construct and it.name == 'Random'
end

t '{ x = 4 }' do |it|
    it == { 'x' => 4 }
end

t '{ x: 4 }' do |it|
    it == { 'x' => 4 }
end

t '{ x = { y = 48} }' do |it|
    it == { 'x' => { 'y' => 48 } }
end

t 'Random {}
Random.new
' do |it|
    it.is_a? Instance_Construct and it.class_construct.name == 'Random'
end

t 'x=1
if x > 2 {
    "yep"
else
    "nope"
}
' do |it|
    it == "\"nope\""
end

t 'x=1
if x == 1 {
    "yep"
elsif x == 2
    "boo"
else
    "nope"
}
' do |it|
    it == "\"yep\""
end

t 'x=2
y = if x == 1 {
    "yep"
elsif x == 2
    "boo"
else
    "nope"
}
y
' do |it|
    it == "\"boo\""
end

t 'x=2
z = 4
y = if x == 1 {
    "yep"
elsif x == 2
    if z == 4 { 1234 else 5678 }
else
    "nope"
}
y
' do |it|
    it == 1234
end

t 'x=2
z = 3
y = if x == 1 {
    "yep"
elsif x == 2
    if z == 4 { 1234 else 5678 }
else
    "nope"
}
y
' do |it|
    it == 5678
end

t 'x=1
if x == 4 { "no" elsif x == 2 "maybe" else "yes" }
' do |it|
    it == "\"yes\""
end

t '
x = 0
while x < 3 {
    x = x + 1
elswhile x < 6
    x = x + 2
else
    9
}
' do |it|
    it == 3
end

t '
Boo {
    id =;
    boo! { -> "boo!" }
}

Moo {
    &Boo
}

Moo.new
' do |it|
    it.is_a? Instance_Construct and it.scope.variables.keys.include? 'id' and it.scope.functions.keys.include? 'boo!'
end

t '
Boo {
    id =;
    boo! { -> "boo!" }
}

Moo > Boo {
}

Moo.new
' do |it|
    it.is_a? Instance_Construct and it.scope.variables.keys.include? 'id' and it.scope.functions.keys.include? 'boo!'
end

t '
Boo {
    bwah = "boo0!"
}

scare { &boo ->
    bwah
}

b = Boo.new
scare(b)
' do |it|
    it == '"boo0!"'
end

t '
Boo {
    full_scare! { times = 6 ->
        scream = "b"
        i = 0
        while i < times {
            scream = scream + "o"
            i = i + 1
        }
        scream
    }
}

scare { &boo ->
    full_scare!
}

b = Boo.new
scare(b)
' do |it|
    it == "\"\"\"\"\"\"\"b\"o\"o\"o\"o\"o\"o\"" # todo) update this test when
end

t '
Boo {
    scary = 1234
}

moo { boo -> boo.scary }
first = moo(Boo.new)

moo_with_comp { &boo_param ->
    scary
}
moo_with_comp(Boo.new) + moo_with_comp(b = Boo.new)
' do |it|
    it == 2468
end

