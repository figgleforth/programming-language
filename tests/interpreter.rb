# require_relative '../source/parser/parser'
# require_relative '../source/lexer/lexer'
# require_relative '../source/interpreter/interpreter_old'
# require 'pp'
# require 'fileutils'
#
#
# def t(name, code, &block)
#     raise ArgumentError, '#t requires a code string' unless code.is_a?(String)
#     raise ArgumentError, '#t requires a block' unless block_given?
#
#     # Create or append to the file in examples
#     file_path = "examples/#{name}.em"
#     FileUtils.mkdir_p(File.dirname(file_path)) # Ensure the directory exists
#     File.open(file_path, 'a') { |file| file.puts "\n#{code}" }
#
#     # begin
#     #     exception = nil # store it so that I can check against the error message below
#     #     tokens    = Lexer.new(code).lex
#     #     ast       = Parser.new(tokens).to_ast
#     #     output    = Interpreter.new(ast).interpret!
#     # rescue Exception => e
#     #     exception = e
#     #     raise e
#     # end
#     #
#     # block_param  = exception || output
#     # block_result = block.call block_param
#     #
#     # if not block_result
#     #     raise "\n\n——————————— FAILED TEST\n#{code}\n——————————— #t it\n#{block_param.inspect}\n———————————\n"
#     # end
#
#     @tests_ran ||= 0
#     @tests_ran += 1
# end
#
#
# # def t code, &block
# #     raise ArgumentError, '#t requires a code string' unless code.is_a?(String)
# #     raise ArgumentError, '#t requires a block' unless block_given?
# #
# #     begin
# #         exception = nil # store it so that I can check against the error message below
# #         tokens    = Lexer.new(code).lex
# #         ast       = Parser.new(tokens).to_ast
# #         output    = Interpreter.new(ast).interpret!
# #     rescue Exception => e
# #         exception = e
# #         raise e
# #     end
# #
# #     block_param  = exception || output
# #     block_result = block.call block_param
# #
# #     if not block_result
# #         raise "\n\n——————————— FAILED TEST\n#{code}\n——————————— #t it\n#{block_param.inspect}\n———————————\n"
# #     end
# #
# #     @tests_ran ||= 0
# #     @tests_ran += 1
# # end
#
# # t File.read('./examples/sandbox.em').to_s do |it|
# #     # todo) update this test once this hurdle is crossed.
# #     it.is_a? RuntimeError and it.message == "Interpreter#evaluate when Binary_Expr, Ruby exception: undefined method `+=' for 2:Integer"
# # end
#
# t 'blocks', 'x { in -> in }
# x()' do |it|
#     it.is_a? Nil_Construct
# end
#
# # t '' do |it|
# #     it.nil?
# # end
#
# t 'expressions', '1' do |it|
#     it == 1 and it.is_a? Integer
# end
#
# t 'expressions', '-1' do |it|
#     it == -1 and it.is_a? Integer
# end
#
# t 'expressions', '48.15' do |it|
#     it == 48.15 and it.is_a? Float
# end
#
# t 'expressions', '16.' do |it|
#     it == 16.0 and it.is_a? Float
# end
#
# t 'expressions', '.23' do |it|
#     it == 0.23 and it.is_a? Float
# end
#
# t 'expressions', '2 + 3' do |it|
#     it == 5
# end
#
# t 'expressions', '4 - 5' do |it|
#     it == -1
# end
#
# t 'expressions', '6 * 7' do |it|
#     it == 42
# end
#
# t 'expressions', '8/9' do |it|
#     it == 0
# end
#
# t 'expressions', '10%11' do |it|
#     it == 10
# end
#
# t 'expressions', '-1 + +3' do |it|
#     it == 2
# end
#
# t 'expressions', '(1 + 2) * 3' do |it|
#     it == 9 and it.is_a? Integer
# end
#
# t 'expressions', '1/2' do |it|
#     it == 0
# end
#
# t 'expressions', '1/2.0' do |it|
#     it == 0.5
# end
#
# t 'expressions', '1.0/2' do |it|
#     it == 0.5
# end
#
# t 'expressions', '1.0/2.0' do |it|
#     it == 0.5
# end
#
# t 'expressions', 'true' do |it|
#     it == true
# end
#
# t 'expressions', '!true' do |it|
#     it == false
# end
#
# t 'expressions', 'false' do |it|
#     it == false
# end
#
# t 'expressions', '!false' do |it|
#     it == true
# end
#
# t 'expressions', 'true && false' do |it|
#     it == false
# end
#
# t 'expressions', 'true || false' do |it|
#     it == true
# end
#
# t 'expressions', 'x = 1' do |it|
#     it == 1
# end
#
# t 'expressions', ':lost' do |it|
#     it == ':lost'
# end
#
# t 'expressions', "'lost'" do |it|
#     it.is_a? String and it == '"lost"'
# end
#
# t 'expressions', "'lost' == :lost" do |it|
#     it == false
# end
#
# t 'expressions', ':lost == :lost' do |it|
#     it == true
# end
#
# t 'expressions', "'lost' == 'lost'" do |it|
#     it == true
# end
#
# t 'expressions', "a = 1 + 2" do |it|
#     it == 3
# end
#
# t 'expressions', "{ b = 8 }" do |it|
#     it == { 'b' => 8 }
# end
#
# t 'expressions', "b = 7
# b
# " do |it|
#     it == 7
# end
#
# t 'expressions', "
# a = 4815
# b = a" do |it|
#     it == 4815
# end
#
# t 'expressions', 'boo' do |it|
#     it.is_a? RuntimeError and it.message == 'undefined variable or function `boo` in scope: Global'
# end
#
# t 'expressions', "b = nil" do |it|
#     it.is_a? Nil_Construct
# end
#
# t 'expressions', "1, nil, 3" do |it|
#     it == 3
# end
#
# t 'expressions', "'b in a string', b, 4+2, nil" do |it|
#     it.is_a? RuntimeError and it.message == "undefined variable or function `b` in scope: Global"
# end
#
# t 'expressions', "'`b` interpolated into the string'" do |it|
#     it.is_a? String
# end
#
# t 'expressions', "x = 'the island'" do |it|
#     it.is_a? String
# end
#
# t 'functions', '{ a = 4 + 8, x, y = 1, z = "2" -> true }' do |it|
#     it == true
# end
#
# t 'expressions', "
# func { -> 4 }
# func2 { -> 6 }
# func() + func2()
# " do |it|
#     it == 10
# end
#
# t 'functions', 'func { -> 1 }' do |it|
#     it.is_a? Block_Expr
# end
#
# t 'expressions', '0..87' do |it|
#     it.is_a? Range_Construct
# end
#
# t 'expressions', '1.<10' do |it|
#     it.is_a? Range_Construct
# end
#
# # t 'abc?def' do |it|
# #     it.is_a? RuntimeError and it.message == 'Cannot have ? or ! or : in the middle of an identifier'
# # end
#
# # t 'abc!def' do |it|
# #     it.is_a? RuntimeError and it.message == 'Cannot have ? or ! or : in the middle of an identifier'
# # end
#
# # t 'abc:def' do |it|
# #     it.is_a? RuntimeError and it.message == 'undefined variable or function `abc` in scope: Global'
# # end
#
# t 'functions', 'f { x = 3 -> x*3 }
# f()' do |it|
#     it == 9
# end
#
# t 'functions', 'f { x = 3 -> x*3 }
# f(4)' do |it|
#     it == 12
# end
#
# t 'functions', 'x { in -> in }
# x()' do |it|
#     it.is_a? Nil_Construct
# end
#
# t 'functions', 'x { in = nil -> in }
# x()' do |it|
#     it.is_a? Nil_Construct
# end
#
# t 'functions', 'x { in = 1 -> in }
# x()' do |it|
#     it == 1
# end
#
# t 'functions', 'x = nil
# f { in -> in || x }
# f()
# ' do |it|
#     it.is_a? Nil_Construct
# end
#
# t 'functions', 'x = 3
# f { in -> in || x }
# f()
# ' do |it|
#     it == 3
# end
#
# t 'functions', 'x = 3
# f { in -> in || x }
# f(4)
# ' do |it|
#     it == 4
# end
#
# t 'expressions', 'SOME_CONSTANT' do |it|
#     it.is_a? RuntimeError and it.message == 'undefined constant `SOME_CONSTANT` in scope: Global'
# end
#
# t 'classes', 'Random' do |it|
#     it.is_a? RuntimeError and it.message == 'undefined class `Random` in scope: Global'
# end
#
# t 'classes', 'Random {}' do |it|
#     it.is_a? Class_Expr and it.name == 'Random'
# end
#
# t 'classes', 'Random {}
# Random
# ' do |it|
#     it.is_a? Class_Expr and it.name == 'Random'
# end
#
# t 'dictionaries', '{ x = 4 }' do |it|
#     it == { 'x' => 4 }
# end
#
# t 'dictionaries', '{ x: 4 }' do |it|
#     it == { 'x' => 4 }
# end
#
# t 'dictionaries', '{ x = { y = 48} }' do |it|
#     it == { 'x' => { 'y' => 48 } }
# end
#
# t 'classes', 'Random {}
# Random.new
# ' do |it|
#     it.is_a? Scopes::Instance_Scope and it.name == 'Random'
# end
#
# t 'conditionals', 'x=1
# if x > 2 {
#     "yep"
# else
#     "nope"
# }
# ' do |it|
#     it == "\"nope\""
# end
#
# t 'conditionals', 'x=1
# if x == 1 {
#     "yep"
# elsif x == 2
#     "boo"
# else
#     "nope"
# }
# ' do |it|
#     it == "\"yep\""
# end
#
# t 'conditionals', 'x=2
# y = if x == 1 {
#     "yep"
# elsif x == 2
#     "boo"
# else
#     "nope"
# }
# y
# ' do |it|
#     it == "\"boo\""
# end
#
# t 'conditionals', 'x=2
# z = 4
# y = if x == 1 {
#     "yep"
# elsif x == 2
#     if z == 4 { 1234 else 5678 }
# else
#     "nope"
# }
# y
# ' do |it|
#     it == 1234
# end
#
# t 'conditionals', 'x=2
# z = 3
# y = if x == 1 {
#     "yep"
# elsif x == 2
#     if z == 4 { 1234 else 5678 }
# else
#     "nope"
# }
# y
# ' do |it|
#     it == 5678
# end
#
# t 'conditionals', 'x=1
# if x == 4 { "no" elsif x == 2 "maybe" else "yes" }
# ' do |it|
#     it == "\"yes\""
# end
#
# t 'loops', '
# x = 1
# while x < 4 {
#     x = x + 1
# elswhile x < 6
#     x = x + 2
# else
#     9
# }
#
# x + 1
# ' do |it|
#     it == 5
# end
#
# t 'composition', '
# Boo {
#     id =;
#     boo! { -> "boo!" }
# }
#
# Moo {
#     &Boo
# }
#
# Moo.new
# ' do |it|
#     it.is_a? Scopes::Instance_Scope and it.declarations.keys.include? 'id' and it.declarations.keys.include? 'boo!'
# end
#
# t 'composition', '
# Boo {
#     id =;
#     boo! { -> "boo!" }
# }
#
# Moo > Boo {
# }
#
# Moo.new
# ' do |it|
#     it.is_a? Scopes::Instance_Scope and it.declarations.keys.include? 'id' and it.declarations.keys.include? 'boo!'
# end
#
# t 'composition', '
# Boo {
#     bwah = "boo0!"
# }
#
# scare { &boo ->
#     bwah
# }
#
# b = Boo.new
# scare(b)
# ' do |it|
#     # it == '"boo0!"'
#     # todo
#     it.is_a? RuntimeError and it.message == 'undefined variable or function `bwah` in scope: scare'
# end
#
# t 'composition', '
# Boo {
#     scream { length = 6 ->
#         phrase = "b"
#         i = 0
#         while i < length {
#             phrase = phrase + "o"
#             i = i + 1
#         }
#         phrase
#     }
# }
#
# go_boo { &boo ->
#     scream()
# }
#
# b = Boo.new
# go_boo(b)
# ' do |it|
#     # it == "\"\"\"\"\"\"\"b\"o\"o\"o\"o\"o\"o\""
#     # todo
#     it.is_a? RuntimeError and it.message == '#eval_block_call expected #get_from_scope to give Block_Expr, got nil'
# end
#
# t 'composition', '
# Boo {
#     scary = 1234
# }
#
# moo { boo -> boo.scary }
# first = moo(Boo.new)
#
# moo_with_comp { &boo_param ->
#     scary
# }
# moo_with_comp(Boo.new) + moo_with_comp(b = Boo.new)
# ' do |it|
#     # it == 2468
#     # todo
#     it.is_a? RuntimeError and it.message == 'undefined variable or function `scary` in scope: moo'
# end
#
# # t '
# # Boo {
# #     scream { ->
# #         "Boo!"
# #     }
# # }
# #
# # scare = Boo.new.scream
# # scare()
# # ' do |it|
# #     # it == "\"Boo!\""
# #     # todo
# #     it.is_a? RuntimeError and it.message == 'undefined variable or function `scream` in scope: Global'
# # end
#
# t 'classes', 'Dog {
#     bark -> "woof"
# }' do |it|
#     it.is_a? Class_Expr and it.block.expressions.one? and it.block.expressions.first.is_a? Block_Expr and it.block.expressions.first.name == 'bark'
# end
#
# t 'classes', 'Dog {
#     bark -> "woof"
# }
# Dog.new.bark
# ' do |it|
#     # it.is_a? Block_Expr
#     # todo
#     it.is_a? RuntimeError and it.message == 'undefined variable or function `bark` in scope: Global'
# end
#
# t 'classes', 'Dog {
#     bark -> "woof"
# }
# Dog.new.bark()
# ' do |it|
#     # it == "\"woof\""
#     # todo
#     it.is_a? RuntimeError and it.message == ' # eval_block_call expected #get_from_scope to give Block_Expr, got nil'
# end
