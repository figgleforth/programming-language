# require_relative '../source/lexer/lexer'
# require_relative '../source/parser/parser'
# require_relative '../source/parser/exprs'
# require 'pp'
# require 'fileutils'
#
# # the goal is that when #t runs, it will write to, or append to, a new file in autogen/examples/<name>.em
# # to achieve this:
# # 1) modify #t declaration such that it takes a 'name' param between the `code` and `&block`. the `name` param is going to represent the .em file that the test belongs in
# # 2) #t should then see if autogen/examples/<name>.em exists, if so, it should append \n and the test to that file. if it doesn't exist, create it
# # 3) update each call to #t below and give it a unique value for the name argument, that summarizes the test being run. if you find certain tests to be relevant, give them the same name so they end up in the same file
#
# def t(name, code, &block)
#     raise ArgumentError, '#t requires a code string' unless code.is_a?(String)
#     raise ArgumentError, '#t requires a block' unless block_given?
#
#     # Create or append to the file in autogen/examples
#     file_path = "examples/#{name}.em"
#     FileUtils.mkdir_p(File.dirname(file_path)) # Ensure the directory exists
#     File.open(file_path, 'a') { |file| file.puts "\n#{code}" }
#
#     begin
#         tokens = Lexer.new(code).lex
#         ast    = Parser.new(tokens).to_ast
#     rescue Exception => e
#         puts "\n\nFAILED TEST\n———————————\n#{code}\n———————————\n\n"
#         raise e
#     end
#
#     block_result = block.call ast.last # test only the first expression parse since this test only cares about single expressions
#
#     if not block_result
#         parser_output = [ast].flatten.map { |a| PP.pp(a, "").chomp }
#         puts "\n\n——————————— FAILED TEST\n#{code}\n——————————— #to_ast\n", parser_output, "———————————"
#         raise 'Failed parse test'
#     end
#
#     @tests_ran ||= 0
#     @tests_ran += 1
# end
#
#
# # t('sandbox', File.read('./example/sandbox.em').to_s) do |it|
# #     it.is_a? Infixed_Expr and it.right.is_a? Identifier_Expr and it.operator == '['
# # end
#
# t('conditional_basic', 'if abc {
# }') do |it|
#     it.is_a? Conditional_Expr and it.condition.is_a? Identifier_Expr and it.when_true.is_a? Func_Expr
# end
#
# t('conditional_one_expr', 'if abc {
#     def
# }') do |it|
#     it.is_a? Conditional_Expr and it.condition.is_a? Identifier_Expr and it.when_true.is_a? Func_Expr and it.when_true.expressions.one?
# end
#
# t('conditional_else', 'if abc {
# else
#     whatever
# }') do |it|
#     it.is_a? Conditional_Expr and it.condition.is_a? Identifier_Expr and it.when_true.is_a? Func_Expr and it.when_false.is_a? Func_Expr and it.when_false.expressions.one?
# end
#
# t('conditional_elsif_else', 'if abc {
#     boo
#     hoo
#     moo
# elsif whatever
#     yay
#     nay
# else
#     123
# }') do |it|
#     it.is_a? Conditional_Expr and it.condition.is_a? Identifier_Expr and it.when_true.is_a? Func_Expr and it.when_false.is_a? Conditional_Expr and it.when_false.condition.is_a? Identifier_Expr and it.when_false.condition.string == 'whatever' and it.when_false.when_false.expressions.one? and it.when_false.when_true.expressions.count == 2 and it.when_true.expressions.count == 3
# end
#
# t('conditional_with_expr', 'if 4 + 8 {
# }') do |it|
#     it.is_a? Conditional_Expr and it.condition.is_a? Infixed_Expr and it.when_true.is_a? Func_Expr
# end
#
# t('conditional_complex', 'if abc {
#     xyz
# elsif 100
#     yay!
# else
# }') do |it|
#     it.is_a? Conditional_Expr and
#       it.condition.is_a? Identifier_Expr and
#       it.when_true.is_a? Func_Expr and
#       it.when_false.is_a? Conditional_Expr and
#       it.when_false.condition.is_a? Number_Literal_Expr and
#       it.when_false.when_true.is_a? Func_Expr and
#       it.when_false.when_true.expressions.one? and
#       it.when_false.when_false.expressions.none? and
#       it.when_false.when_false.is_a? Func_Expr
# end
#
# t('number_literal_int', '42') do |it|
#     it.is_a? Number_Literal_Expr and
#       it.string == '42' and
#       it.type == :int and
#       it.decimal_position.nil?
# end
#
# t('number_literal_float_middle', '42.0') do |it|
#     it.is_a? Number_Literal_Expr and
#       it.string == '42.0' and
#       it.type == :float and
#       it.decimal_position == :middle
# end
#
# t('number_literal_float_end', '42.') do |it|
#     it.is_a? Number_Literal_Expr and
#       it.string == '42.' and
#       it.type == :float and
#       it.decimal_position == :end
# end
#
# t('number_literal_float_start', '.42') do |it|
#     it.is_a? Number_Literal_Expr and
#       it.string == '.42' and
#       it.type == :float and
#       it.decimal_position == :start
# end
#
# t('string_literal_double', '"double"') do |it|
#     it.is_a? String_Literal_Expr
# end
#
# t('string_literal_single', "'single'") do |it|
#     it.is_a? String_Literal_Expr
# end
#
# t('string_literal_interpolated', '"`interpolated`"') do |it|
#     it.is_a? String_Literal_Expr and it.interpolated
# end
#
# t('array_literal_empty', '[]') do |it|
#     it.is_a? Array_Expr and it.elements.empty?
# end
#
# t('array_literal_nested', '[[]]') do |it|
#     it.is_a? Array_Expr and it.elements.one? and
#       it.elements[0].is_a? Array_Expr
# end
#
# t('array_literal_numbers', '[1, 2, 3]') do |it|
#     it.is_a? Array_Expr and it.elements.count == 3 and
#       it.elements.all? { |e| e.is_a?(Number_Literal_Expr) }
# end
#
# t('array_literal_mixed', '[a, b + c]') do |it|
#     it.is_a? Array_Expr and it.elements.count == 2 and
#       it.elements[0].is_a? Identifier_Expr and
#       it.elements[1].is_a? Infixed_Expr
# end
#
# t('identifier_member', 'x') do |it|
#     it.is_a? Identifier_Expr and it.member? and not it.class? and not it.constant?
# end
#
# t('assignment_empty', 'x =;') do |it|
#     it.is_a? Assignment_Expr
# end
#
# t('assignment_number', 'x = 0') do |it|
#     it.is_a? Assignment_Expr and
#       it.expression.is_a? Number_Literal_Expr and
#       it.expression.string == '0'
# end
#
# t('assignment_enum', 'x = ENUM.VALUE') do |it|
#     it.is_a? Assignment_Expr and
#       it.expression.is_a? Infixed_Expr and
#       it.expression.left.is_a? Identifier_Expr and
#       it.expression.right.is_a? Identifier_Expr
# end
#
# t('dictionary_literal_empty', '{}') do |it|
#     it.is_a? Dictionary_Literal_Expr and it.keys.none? and it.values.none?
# end
#
# t('dictionary_literal_single_key', '{ x }') do |it|
#     it.is_a? Dictionary_Literal_Expr and it.keys.one? and it.values.none?
# end
#
# t('dictionary_literal_multiple_keys', '{ x y }') do |it|
#     it.is_a? Dictionary_Literal_Expr and it.keys.count == 2 and it.values.none?
# end
#
# t('dictionary_literal_keys_commas', '{ x, y }') do |it|
#     it.is_a? Dictionary_Literal_Expr and it.keys.count == 2 and it.values.none?
# end
#
# t('dictionary_literal_keys_values', '{ x, y: 0 }') do |it|
#     it.is_a? Dictionary_Literal_Expr and it.keys.count == 2 and it.values.count == 2 and it.values[0].nil? and it.values[1].is_a? Number_Literal_Expr
# end
#
# t('dictionary_literal_complex', '{ x, y: 0, z = "oo" }') do |it|
#     it.is_a? Dictionary_Literal_Expr and it.keys.count == 3 and it.values.count == 3 and it.values[0].nil? and it.values[1].is_a? Number_Literal_Expr and it.values[2].is_a? String_Literal_Expr
# end
#
# t('dictionary_literal_multiline', '{ a:
#     "value on the next line"
# }') do |it|
#     it.is_a? Dictionary_Literal_Expr and it.keys.one? and it.values.one?
# end
#
# t('dictionary_literal_variety', '{ a: 123, b: {},
# c: Abc{}, d: "lost" }') do |it|
#     it.is_a? Dictionary_Literal_Expr and it.keys.count == 4 and it.values.count == 4 and it.keys[2] == 'c'
# end
#
# t('assignment_empty_dict', 'x = {}') do |it|
#     it.is_a? Assignment_Expr and
#       it.expression.is_a? Dictionary_Literal_Expr and it.expression.keys.none? and it.expression.values.none?
# end
#
# t('assignment_block', 'x = { -> }') do |it|
#     it.is_a? Assignment_Expr and
#       it.expression.is_a? Func_Expr and
#       it.expression.expressions.empty? and
#       it.expression.compositions.empty? and
#       it.expression.parameters.empty?
# end
#
# t('assignment_class', 'x = Abc {}') do |it|
#     it.is_a? Assignment_Expr and
#       it.expression.is_a? Class_Decl and
#       it.expression.block.expressions.empty? and
#       it.expression.block.compositions.empty? and
#       it.expression.compositions.empty?
# end
#
# t('block_expr_empty', 'x { -> }') do |it|
#     it.is_a? Func_Expr and
#       it.expressions.empty? and
#       it.compositions.empty? and
#       it.parameters.empty? and
#       it.named?
# end
#
# t('block_expr_before_hook', 'x { ->
#     @before check_x
# }') do |it|
#     it.is_a? Func_Expr and
#       it.expressions.one? and
#       it.compositions.empty? and
#       it.parameters.empty? and
#       it.named? and it.before_hook_expressions.one?
# end
#
# t('block_expr_with_expr', 'x { -> 42 }') do |it|
#     it.is_a? Func_Expr and
#       it.expressions.one? and
#       it.expressions.first.is_a? Number_Literal_Expr and
#       it.compositions.empty? and
#       it.parameters.empty? and
#       it.named?
# end
#
# t('block_expr_with_param', 'x { in -> }') do |it|
#     it.is_a? Func_Expr and
#       it.named? and
#       it.expressions.empty? and
#       it.compositions.empty? and
#       it.parameters.one? and
#       it.parameters[0].is_a? Param_Decl and it.parameters[0].name == 'in'
# end
#
# t('block_expr_multiple_params', 'x { in, out -> 42, 24 }') do |it|
#     it.is_a? Func_Expr and
#       it.named? and
#       it.expressions.count == 2 and
#       it.compositions.empty? and
#       it.parameters.count == 2 and it.parameters[1].name == 'out'
# end
#
# t('block_expr_composed_param', 'x { &in -> }') do |it|
#     it.is_a? Func_Expr and
#       it.expressions.empty? and
#       it.compositions.one? and
#       it.parameters.one? and
#       it.parameters[0].composition and
#       it.named?
# end
#
# t('block_expr_complex_params', '
# test { abc &this = 1, def that, like = "dharma", &whatever  -> }
# ') do |it|
#     it.is_a? Func_Expr and
#       it.expressions.empty? and
#       it.compositions.count == 2 and
#       it.parameters.count == 4 and
#       it.parameters[0].default_expression.is_a? Number_Literal_Expr and it.parameters[0].default_expression.string == '1' and
#       it.parameters[2].default_expression.is_a? String_Literal_Expr and it.parameters[2].default_expression.string == 'dharma' and
#       it.parameters[0].composition and
#       not it.parameters[1].composition and
#       not it.parameters[2].composition and
#       it.parameters[3].composition and
#       it.named?
# end
#
# t('block_expr_binary_param', 'func { param1, param2 = 14 * 3 / 16.09 -> }') do |it|
#     it.is_a? Func_Expr and
#       it.parameters.count == 2 and it.parameters[1].default_expression.is_a? Infixed_Expr and
#       it.expressions.empty? and
#       it.named?
# end
#
# t('binary_expr_simple', 'x + y') do |it|
#     it.is_a? Infixed_Expr and it.left.is_a? Identifier_Expr and it.right.is_a? Identifier_Expr
# end
#
# t('binary_expr_nested', 'x + y * z') do |it|
#     it.is_a? Infixed_Expr and it.left.is_a? Identifier_Expr and it.right.is_a? Infixed_Expr
# end
#
# t('binary_expr_complex', 'a + (b * c) - d') do |it|
#     it.is_a? Infixed_Expr and
#       it.left.is_a? Infixed_Expr and
#       it.right.is_a? Identifier_Expr and
#       it.left.right.is_a? Infixed_Expr
# end
#
# t('identifier_constant', 'SOME_CONSTANT') do |it|
#     it.is_a? Identifier_Expr and not it.member? and not it.class? and it.constant?
# end
#
# t('enum_expr_empty', 'ENUM {}') do |it|
#     it.is_a? Enum_Expr
# end
#
# t('enum_expr_single_constant', 'ENUM {
#     ONE
# }') do |it|
#     it.is_a? Enum_Expr and it.constants.one?
# end
#
# t('enum_expr_constant_with_value', 'ENUM {
#     ONE = 1
# }') do |it|
#     it.is_a? Enum_Expr and
#       it.constants.one? and
#       it.constants[0].is_a? Assignment_Expr and it.constants[0].expression.is_a? Number_Literal_Expr
# end
#
# t('enum_expr_nested', 'ENUM {
#     ONE {
#         TWO = 2
#     }
# }') do |it|
#     it.is_a? Enum_Expr and
#       it.constants.one? and
#       it.constants[0].is_a? Enum_Expr and
#       it.constants[0].constants.one? and
#       it.constants[0].constants[0].is_a? Assignment_Expr
# end
#
# t('enum_expr_assignment', 'ENUM = 1') do |it|
#     it.is_a? Assignment_Expr
# end
#
# t('class_expr_empty', 'Abc {}') do |it|
#     it.is_a? Class_Decl and
#       it.block.expressions.empty? and
#       it.block.compositions.empty?
# end
#
# t('class_expr_with_base', 'Abc > Xyz {}') do |it|
#     it.is_a? Class_Decl and
#       it.block.expressions.empty? and
#       it.block.compositions.empty? and
#       it.base_class == 'Xyz'
# end
#
# t('composition_expr_base', '> Xyz') do |it|
#     it.is_a? Composition_Expr and it.operator == '>'
# end
#
# t('composition_expr_add', '+ Abc') do |it|
#     it.is_a? Composition_Expr and it.operator == '+'
# end
#
# t('composition_expr_subtract', '- Xyz') do |it|
#     it.is_a? Composition_Expr and it.operator == '-'
# end
#
# t('composition_expr_inline', '+Boo') do |it|
#     it.is_a? Composition_Expr and it.operator == '+'
# end
#
# t('class_with_composition', 'Abc { > Xyz }') do |it|
#     it.is_a? Class_Decl and it.block.compositions.one?
# end
#
# t('class_with_alias_composition', 'Abc { > Xyz as xyz }') do |it|
#     it.is_a? Class_Decl and it.block.compositions.one? and it.block.compositions[0].alias_identifier
# end
#
# t('class_with_multiple_compositions', 'Abc { > Xyz, - Xyz }') do |it|
#     it.is_a? Class_Decl and it.block.compositions.count == 2 and it.block.compositions.all? { |c| c.alias_identifier.nil? }
# end
#
# t('binary_expr_new', 'Abc.new') do |it|
#     it.is_a? Infixed_Expr
# end
#
# t('binary_expr_block', 'Abc.what { -> 123 }') do |it|
#     it.is_a? Infixed_Expr and it.right.is_a? Func_Expr and it.right.named?
# end
#
# t('binary_expr_conditional_self', 'self.?something') do |it|
#     it.is_a? Infixed_Expr
# end
#
# t('conditional_expr_number', 'if 1234 {
#     5678
# }') do |it|
#     it.is_a? Conditional_Expr and
#       it.condition.is_a? Number_Literal_Expr and
#       it.when_true.is_a? Func_Expr and
#       it.when_false.nil?
# end
#
# t('conditional_with_empty_else', 'if a {
# else
# }') do |it|
#     it.is_a? Conditional_Expr and
#       it.condition.is_a? Identifier_Expr and it.when_true.is_a? Func_Expr and
#       it.when_false.is_a? Func_Expr
# end
#
# t('conditional_complex_with_elsif', 'if a {
# elsif 100
#     yay!
# else
# }') do |it|
#     it.is_a? Conditional_Expr and
#       it.condition.is_a? Identifier_Expr and
#       it.when_true.is_a? Func_Expr and
#       it.when_false.is_a? Conditional_Expr and
#       it.when_false.condition.is_a? Number_Literal_Expr and
#       it.when_false.when_true.is_a? Func_Expr and
#       it.when_false.when_true.expressions.one? and
#       it.when_false.when_false.expressions.none? and
#       it.when_false.when_false.is_a? Func_Expr
# end
#
# t('while_expr_empty', 'while a {
# }') do |it|
#     it.is_a? While_Expr and
#       it.condition.is_a? Identifier_Expr and
#       it.when_true.is_a? Func_Expr and
#       it.when_false.nil?
# end
#
# t('while_expr_with_binary', 'while 4 * 8 {
# }') do |it|
#     it.is_a? While_Expr and
#       it.condition.is_a? Infixed_Expr and
#       it.when_true.is_a? Func_Expr and
#       it.when_false.nil?
# end
#
# t('while_expr_with_elswhile', 'while a {
# elswhile "b"
# }') do |it|
#     it.is_a? While_Expr and
#       it.condition.is_a? Identifier_Expr and
#       it.when_true.is_a? Func_Expr and
#       it.when_false.is_a? While_Expr and
#       it.when_false.condition.is_a? String_Literal_Expr
# end
#
# t('while_expr_complex', 'while a {
# elswhile 100
#     yay!
# else
#     1
#     2
#     3
#     4
# }') do |it|
#     it.is_a? While_Expr and
#       it.condition.is_a? Identifier_Expr and
#       it.when_true.is_a? Func_Expr and
#       it.when_false.is_a? While_Expr and
#       it.when_false.condition.is_a? Number_Literal_Expr and
#       it.when_false.when_true.is_a? Func_Expr and
#       it.when_false.when_true.expressions.one? and
#       it.when_false.when_false.expressions.count == 4 and
#       it.when_false.when_false.is_a? Func_Expr
# end
#
# t('while_expr_complex_binary', 'while a > b {
#     x + y
# }') do |it|
#     it.is_a? While_Expr and
#       it.condition.is_a? Infixed_Expr and
#       it.when_true.is_a? Func_Expr and
#       it.when_true.expressions.first.is_a? Infixed_Expr
# end
#
# t('block_call_empty', 'call()') do |it|
#     it.is_a? Block_Call_Expr and it.arguments.empty?
# end
#
# t('block_call_single_arg', 'call(a)') do |it|
#     it.is_a? Block_Call_Expr and it.arguments.one? and
#       it.arguments[0].expression.is_a? Identifier_Expr and it.arguments[0].expression.string == 'a'
# end
#
# t('block_call_multiple_args', 'call(a, 1, "asf")') do |it|
#     it.is_a? Block_Call_Expr and it.arguments.count == 3
# end
#
# t('block_call_with_label', 'call(with: a, 1, "asf")') do |it|
#     it.is_a? Block_Call_Expr and it.arguments.count == 3 and it.arguments[0].label == 'with'
# end
#
# t('block_call_mixed_labels', 'call(a: 1, b, c: "str", 42)') do |it|
#     it.is_a? Block_Call_Expr and
#       it.arguments.count == 4 and
#       it.arguments[0].label == 'a' and
#       it.arguments[1].label.nil? and
#       it.arguments[2].label == 'c' and
#       it.arguments[3].label.nil?
# end
#
# t('block_call_complex', 'imaginary(object: Xyz {}, enum: BWAH {}, func: whatever {}, nothing, {})') do |it|
#     it.is_a? Block_Call_Expr and it.arguments.count == 5 and it.arguments[0].label and it.arguments[1].label and it.arguments[2].label and it.arguments[3].label.nil? and it.arguments.last.expression.is_a? Dictionary_Literal_Expr
# end
#
# t('symbol_literal', ':test') do |it|
#     it.is_a? Symbol_Literal_Expr
# end
#
# t('class_with_composition_expr', 'Abc { + Xyz }') do |it|
#     it.is_a? Class_Decl and
#       it.compositions.count == 1
# end
#
# t('block_expr_single_line', '{ -> one_line_block }') do |it|
#     it.is_a? Func_Expr and it.parameters.count == 0 and
#       not it.expressions.empty? and
#       not it.named?
# end
#
# t('block_expr_with_param_and_expr', '{ input -> one_line_block }') do |it|
#     it.is_a? Func_Expr and it.parameters.count == 1 and
#       not it.expressions.empty? and
#       not it.named?
# end
#
# t('block_expr_with_multiline_expr', '{ ->
#     jack
#     locke
# }') do |it|
#     it.is_a? Func_Expr and it.parameters.count == 0 and
#       it.expressions.count == 2 and
#       not it.named?
# end
#
# t('binary_expr_with_each_block', '[].each { -> }') do |it|
#     it.is_a? Infixed_Expr and it.left.is_a? Array_Expr and
#       it.right.is_a? Func_Expr and it.right.name == 'each'
# end
#
# t('binary_expr_with_each_block_string', '"".each { -> }') do |it|
#     it.is_a? Infixed_Expr and it.right.is_a? Func_Expr and it.right.name == 'each' and it.left.is_a? String_Literal_Expr
# end
#
# t('binary_expr_with_tap_block', '[].tap { ->
#     it
#     at
# }') do |it|
#     it.is_a? Infixed_Expr and it.left.is_a? Array_Expr and
#       it.right.is_a? Func_Expr and it.right.name == 'tap' and it.right.expressions.count == 2
# end
#
# t('binary_expr_with_map_block', '[].map { -> }') do |it|
#     it.is_a? Infixed_Expr and it.right.is_a? Func_Expr and it.right.name == 'map' and it.left.is_a? Array_Expr and it.right.expressions.count == 0
# end
#
# t('binary_expr_with_where_block', '[].where { -> it == nil }') do |it|
#     it.is_a? Infixed_Expr and it.right.is_a? Func_Expr and it.right.name == 'where' and it.left.is_a? Array_Expr and it.right.expressions.count == 1 and it.right.expressions[0].is_a? Infixed_Expr
# end
#
# t('block_expr_tap', 'tap { -> }') do |it|
#     it.is_a? Func_Expr and it.name == 'tap'
# end
#
# t('block_expr_where', "where { -> }") do |it|
#     it.is_a? Func_Expr and it.name == 'where'
# end
#
# t('block_expr_each', "each { -> }") do |it|
#     it.is_a? Func_Expr and it.name == 'each'
# end
#
# t('block_expr_map', "map { -> }") do |it|
#     it.is_a? Func_Expr and it.name == 'map'
# end
#
# t('macro_expr', '%s(boo hoo)') do |it|
#     it.is_a? Macro_Expr and it.identifiers == %w(boo hoo)
# end
#
# t('macro_expr_uppercase', '%S(boo hoo)') do |it|
#     it.is_a? Macro_Expr and it.identifiers == %w(BOO HOO)
# end
#
# t('boolean_literal_true', 'true') do |it|
#     it.is_a? Boolean_Literal_Expr and it.to_bool == true
# end
#
# t('boolean_literal_false', 'false') do |it|
#     it.is_a? Boolean_Literal_Expr and it.to_bool == false
# end
#
# t('binary_expr_boolean_and', 'true && false') do |it|
#     it.is_a? Infixed_Expr and it.left.is_a? Boolean_Literal_Expr and it.right.is_a? Boolean_Literal_Expr
# end
#
# t('binary_expr_boolean_or', 'true || false') do |it|
#     it.is_a? Infixed_Expr and it.left.is_a? Boolean_Literal_Expr and it.right.is_a? Boolean_Literal_Expr
# end
#
# t('binary_expr_range', '0..87') do |it|
#     it.is_a? Infixed_Expr and it.left.is_a? Number_Literal_Expr and it.left.string == '0' and it.right.is_a? Number_Literal_Expr and it.right.string == '87' and it.operator == '..'
# end
#
# t('binary_expr_less_than', '1.<10') do |it|
#     it.is_a? Infixed_Expr and it.left.is_a? Number_Literal_Expr and it.left.string == '1' and it.right.is_a? Number_Literal_Expr and it.right.string == '10' and it.operator == '.<'
# end
#
# t('binary_expr_float_range', '0.1..0.5') do |it|
#     it.is_a? Infixed_Expr and it.left.is_a? Number_Literal_Expr and it.left.string == '0.1' and it.right.is_a? Number_Literal_Expr and it.right.string == '0.5' and it.operator == '..'
# end
#
# t('binary_expr_mixed_range', '.7..7.8') do |it|
#     it.is_a? Infixed_Expr and it.left.is_a? Number_Literal_Expr and it.left.string == '.7' and it.right.is_a? Number_Literal_Expr and it.right.string == '7.8' and it.operator == '..'
# end
#
# t('binary_expr_with_each', '(1..2).each { -> } ') do |it|
#     it.is_a? Infixed_Expr and it.left.is_a? Infixed_Expr and it.operator == '.' and it.right.is_a? Func_Expr and it.right.named?
# end
#
# t('conditional_with_empty_else_2', 'if abc {
#     else
# } ') do |it|
#     it.is_a? Conditional_Expr and
#       it.condition.is_a? Identifier_Expr and
#       it.when_true.is_a? Func_Expr and
#       it.when_false.is_a? Func_Expr
# end
#
# t('block_expr_with_number', 'curse -> 4815162342 ') do |it|
#     it.is_a? Func_Expr and it.expressions.one? and it.expressions[0].is_a? Number_Literal_Expr
# end
#
# t('class_with_block', 'Dog {
#     bark -> "woof"
# } ') do |it|
#     it.is_a? Class_Decl
# end
#
# # require_relative '../source/lexer/lexer'
# # require_relative '../source/parser/parser'
# # require_relative '../source/parser/exprs'
# # require 'pp'
# #
# # # the goal is that when #t runs, it will write to, or append to, a new file in autogen/examples/<name>.em
# # # to achieve this:
# # # 1) modify #t declaration such that it takes a 'name' param between the `code` and `&block`. the `name` param is going to represent the .em file that the test belongs in
# # # 2) #t should then see if autogen/examples/<name>.em exists, if so, it should append \n and the test to that file. if it doesn't exist, create it
# # # 3) update each call to #t below and give it a unique value for the name argument, that summarizes the test being run. if you find certain tests to be relevant, give them the same name so they end up in the same file
# #
# # def t code, &block
# #     raise ArgumentError, '#t requires a code string' unless code.is_a?(String)
# #     raise ArgumentError, '#t requires a block' unless block_given?
# #
# #     begin
# #         tokens = Lexer.new(code).lex
# #         ast    = Parser.new(tokens).to_ast
# #     rescue Exception => e
# #         puts "\n\nFAILED TEST\n———————————\n#{code}\n———————————\n\n"
# #         raise e
# #     end
# #
# #     block_result = block.call ast.last # test only the first expression parse since this test only cares about single expressions
# #
# #     if not block_result
# #         parser_output = [ast].flatten.map { |a| PP.pp(a, "").chomp }
# #         puts "\n\n——————————— FAILED TEST\n#{code}\n——————————— #to_ast\n", parser_output, "———————————"
# #         raise 'Failed parse test'
# #     end
# #
# #     @tests_ran ||= 0
# #     @tests_ran += 1
# # end
# #
# #
# # t File.read('./example/sandbox.em').to_s do |it|
# #     # note) it param is the last expression parsed from sandbox.em
# #     it.is_a? Infixed_Expr and it.right.is_a? Identifier_Expr and it.operator == '['
# # end
# #
# # t 'if abc {
# # }' do |it|
# #     it === Conditional_Expr and it.condition === Identifier_Expr and it.when_true === Func_Expr
# # end
# #
# # t 'if abc {
# #     def
# # }' do |it|
# #     it === Conditional_Expr and it.condition === Identifier_Expr and it.when_true === Func_Expr and it.when_true.expressions.one?
# # end
# #
# # t 'if abc {
# # else
# #     whatever
# # }' do |it|
# #     # puts "it #{it.inspect}"
# #     it === Conditional_Expr and it.condition === Identifier_Expr and it.when_true === Func_Expr and it.when_false === Func_Expr and it.when_false.expressions.one?
# # end
# #
# # t 'if abc {
# #     boo
# #     hoo
# #     moo
# # elsif whatever
# #     yay
# #     nay
# # else
# #     123
# # }' do |it|
# #     # puts "it #{it.inspect}"
# #     it === Conditional_Expr and it.condition === Identifier_Expr and it.when_true === Func_Expr and it.when_false === Conditional_Expr and it.when_false.condition === Identifier_Expr and it.when_false.condition.string == 'whatever' and it.when_false.when_false.expressions.one? and it.when_false.when_true.expressions.count == 2 and it.when_true.expressions.count == 3
# # end
# #
# # t 'if 4 + 8 {
# # }' do |it|
# #     it === Conditional_Expr and it.condition === Infixed_Expr and it.when_true === Func_Expr
# # end
# #
# # t 'if abc {
# #     xyz
# # elsif 100
# #     yay!
# # else
# # }' do |it|
# #     it.is_a? Conditional_Expr and
# #       it.condition.is_a? Identifier_Expr and
# #       it.when_true.is_a? Func_Expr and
# #       it.when_false.is_a? Conditional_Expr and
# #       it.when_false.condition.is_a? Number_Literal_Expr and
# #       it.when_false.when_true.is_a? Func_Expr and
# #       it.when_false.when_true.expressions.one? and
# #       it.when_false.when_false.expressions.none? and
# #       it.when_false.when_false.is_a? Func_Expr
# # end
# #
# # t '42' do |it|
# #     it.is_a? Number_Literal_Expr and
# #       it.string == '42' and
# #       it.type == :int and
# #       it.decimal_position == nil
# # end
# #
# # t '42.0' do |it|
# #     it.is_a? Number_Literal_Expr and
# #       it.string == '42.0' and
# #       it.type == :float and
# #       it.decimal_position == :middle
# # end
# #
# # t '42.' do |it|
# #     it.is_a? Number_Literal_Expr and
# #       it.string == '42.' and
# #       it.type == :float and
# #       it.decimal_position == :end
# # end
# #
# # t '.42' do |it|
# #     it.is_a? Number_Literal_Expr and
# #       it.string == '.42' and
# #       it.type == :float and
# #       it.decimal_position == :start
# # end
# #
# # t '"double"' do |it|
# #     it.is_a? String_Literal_Expr
# # end
# #
# # t "'single'" do |it|
# #     it.is_a? String_Literal_Expr
# # end
# #
# # t '"`interpolated`"' do |it|
# #     it.is_a? String_Literal_Expr and it.interpolated
# # end
# #
# # t '[]' do |it|
# #     it.is_a? Array_Expr and it.elements.empty?
# # end
# #
# # t '[[]]' do |it|
# #     it.is_a? Array_Expr and it.elements.one? and
# #       it.elements[0].is_a? Array_Expr
# # end
# #
# # t '[1, 2, 3]' do |it|
# #     it.is_a? Array_Expr and it.elements.count == 3 and
# #       it.elements.all? { |e| e.is_a?(Number_Literal_Expr) }
# # end
# #
# # t '[a, b + c]' do |it|
# #     it.is_a? Array_Expr and it.elements.count == 2 and
# #       it.elements[0].is_a? Identifier_Expr and
# #       it.elements[1].is_a? Infixed_Expr
# # end
# #
# # t 'x' do |it|
# #     it.is_a? Identifier_Expr and it.member? and not it.class? and not it.constant?
# # end
# #
# # t 'x =;' do |it|
# #     it.is_a? Assignment_Expr
# # end
# #
# # t 'x = 0' do |it|
# #     it.is_a? Assignment_Expr and
# #       it.expression.is_a? Number_Literal_Expr and
# #       it.expression.string == '0'
# # end
# #
# # t 'x = ENUM.VALUE' do |it|
# #     it.is_a? Assignment_Expr and
# #       it.expression.is_a? Infixed_Expr and
# #       it.expression.left.is_a? Identifier_Expr and
# #       it.expression.right.is_a? Identifier_Expr
# # end
# #
# # t '{}' do |it|
# #     it.is_a? Dictionary_Literal_Expr and it.keys.none? and it.values.none?
# # end
# #
# # t '{ x }' do |it|
# #     it.is_a? Dictionary_Literal_Expr and it.keys.one? and it.values.none?
# # end
# #
# # t '{ x y }' do |it|
# #     it.is_a? Dictionary_Literal_Expr and it.keys.count == 2 and it.values.none?
# # end
# #
# # t '{ x, y }' do |it|
# #     it.is_a? Dictionary_Literal_Expr and it.keys.count == 2 and it.values.none?
# # end
# #
# # t '{ x, y: 0 }' do |it|
# #     it.is_a? Dictionary_Literal_Expr and it.keys.count == 2 and it.values.count == 2 and it.values[0].nil? and it.values[1].is_a? Number_Literal_Expr
# # end
# #
# # t '{ x, y: 0, z = "oo" }' do |it|
# #     it.is_a? Dictionary_Literal_Expr and it.keys.count == 3 and it.values.count == 3 and it.values[0].nil? and it.values[1].is_a? Number_Literal_Expr and it.values[2].is_a? String_Literal_Expr
# # end
# #
# # t '{ a:
# #     "value on the next line"
# # }' do |it|
# #     it.is_a? Dictionary_Literal_Expr and it.keys.one? and it.values.one?
# # end
# #
# # t '{ a: 123, b: {},
# # c: Abc{}, d: "lost" }' do |it|
# #     it.is_a? Dictionary_Literal_Expr and it.keys.count == 4 and it.values.count == 4 and it.keys[2] == 'c'
# # end
# #
# # t 'x = {}' do |it|
# #     it.is_a? Assignment_Expr and
# #       it.expression.is_a? Dictionary_Literal_Expr and it.expression.keys.none? and it.expression.values.none?
# # end
# #
# # t 'x = { -> }' do |it|
# #     it.is_a? Assignment_Expr and
# #       it.expression.is_a? Func_Expr and
# #       it.expression.expressions.empty? and
# #       it.expression.compositions.empty? and
# #       it.expression.parameters.empty?
# # end
# #
# # t 'x = Abc {}' do |it|
# #     it.is_a? Assignment_Expr and
# #       it.expression.is_a? Class_Decl and
# #       it.expression.block.expressions.empty? and
# #       it.expression.block.compositions.empty? and
# #       it.expression.compositions.empty?
# # end
# #
# # t 'x { -> }' do |it|
# #     it.is_a? Func_Expr and
# #       it.expressions.empty? and
# #       it.compositions.empty? and
# #       it.parameters.empty? and
# #       it.named?
# # end
# #
# # t 'x { ->
# #     @before check_x
# # }' do |it|
# #     it.is_a? Func_Expr and
# #       it.expressions.one? and
# #       it.compositions.empty? and
# #       it.parameters.empty? and
# #       it.named? and it.before_hook_expressions.one?
# # end
# #
# # t 'x { -> 42 }' do |it|
# #     it.is_a? Func_Expr and
# #       it.expressions.one? and
# #       it.expressions.first.is_a? Number_Literal_Expr and
# #       it.compositions.empty? and
# #       it.parameters.empty? and
# #       it.named?
# # end
# #
# # t 'x { in -> }' do |it|
# #     it.is_a? Func_Expr and
# #       it.named? and
# #       it.expressions.empty? and
# #       it.compositions.empty? and
# #       it.parameters.one? and
# #       it.parameters[0].is_a? Param_Decl and it.parameters[0].name == 'in'
# # end
# #
# # t 'x { in, out -> 42, 24 }' do |it|
# #     it.is_a? Func_Expr and
# #       it.named? and
# #       it.expressions.count == 2 and
# #       it.compositions.empty? and
# #       it.parameters.count == 2 and it.parameters[1].name == 'out'
# # end
# #
# # t 'x { &in -> }' do |it|
# #     it.is_a? Func_Expr and
# #       it.expressions.empty? and
# #       it.compositions.one? and
# #       it.parameters.one? and
# #       it.parameters[0].composition and
# #       it.named?
# # end
# #
# # t '
# # test { abc &this = 1, def that, like = "dharma", &whatever  -> }
# # ' do |it|
# #     it.is_a? Func_Expr and
# #       it.expressions.empty? and
# #       it.compositions.count == 2 and
# #       it.parameters.count == 4 and
# #       it.parameters[0].default_expression.is_a? Number_Literal_Expr and it.parameters[0].default_expression.string == '1' and
# #       it.parameters[2].default_expression.is_a? String_Literal_Expr and it.parameters[2].default_expression.string == 'dharma' and
# #       it.parameters[0].composition and
# #       not it.parameters[1].composition and
# #       not it.parameters[2].composition and
# #       it.parameters[3].composition and
# #       it.named?
# # end
# #
# # t 'func { param1, param2 = 14 * 3 / 16.09 -> }' do |it|
# #     it.is_a? Func_Expr and
# #       it.parameters.count == 2 and it.parameters[1].default_expression.is_a? Infixed_Expr and
# #       it.expressions.empty? and
# #       it.named?
# # end
# #
# # t 'x + y' do |it|
# #     it.is_a? Infixed_Expr and it.left.is_a? Identifier_Expr and it.right.is_a? Identifier_Expr
# # end
# #
# # t 'x + y * z' do |it|
# #     it.is_a? Infixed_Expr and it.left.is_a? Identifier_Expr and it.right.is_a? Infixed_Expr
# # end
# #
# # t 'a + (b * c) - d' do |it|
# #     it.is_a? Infixed_Expr and
# #       it.left.is_a? Infixed_Expr and
# #       it.right.is_a? Identifier_Expr and
# #       it.left.right.is_a? Infixed_Expr
# # end
# #
# # t 'SOME_CONSTANT' do |it|
# #     it.is_a? Identifier_Expr and not it.member? and not it.class? and it.constant?
# # end
# #
# # t 'ENUM {}' do |it|
# #     it.is_a? Enum_Expr
# # end
# #
# # t 'ENUM {
# #     ONE
# # }' do |it|
# #     it.is_a? Enum_Expr and it.constants.one?
# # end
# #
# # t 'ENUM {
# #     ONE = 1
# # }' do |it|
# #     it.is_a? Enum_Expr and
# #       it.constants.one? and
# #       it.constants[0].is_a? Assignment_Expr and it.constants[0].expression.is_a? Number_Literal_Expr
# # end
# #
# # t 'ENUM {
# #     ONE {
# #         TWO = 2
# #     }
# # }' do |it|
# #     it.is_a? Enum_Expr and
# #       it.constants.one? and
# #       it.constants[0].is_a? Enum_Expr and
# #       it.constants[0].constants.one? and
# #       it.constants[0].constants[0].is_a? Assignment_Expr
# # end
# #
# # t 'ENUM = 1' do |it|
# #     it.is_a? Assignment_Expr
# # end
# #
# # t 'Abc {}' do |it|
# #     it.is_a? Class_Decl and
# #       it.block.expressions.empty? and
# #       it.block.compositions.empty?
# # end
# #
# # t 'Abc > Xyz {}' do |it|
# #     it.is_a? Class_Decl and
# #       it.block.expressions.empty? and
# #       it.block.compositions.empty? and
# #       it.base_class == 'Xyz'
# # end
# #
# # t '> Xyz' do |it|
# #     it.is_a? Composition_Expr and it.operator == '>'
# # end
# #
# # t '+ Abc' do |it|
# #     it.is_a? Composition_Expr and it.operator == '+'
# # end
# #
# # t '- Xyz' do |it|
# #     it.is_a? Composition_Expr and it.operator == '-'
# # end
# #
# # t '+Boo' do |it|
# #     it.is_a? Composition_Expr and it.operator == '+'
# # end
# #
# # t 'Abc { > Xyz }' do |it|
# #     it.is_a? Class_Decl and it.block.compositions.one?
# # end
# #
# # t 'Abc { > Xyz as xyz }' do |it|
# #     it.is_a? Class_Decl and it.block.compositions.one? and it.block.compositions[0].alias_identifier
# # end
# #
# # t 'Abc { > Xyz, - Xyz }' do |it|
# #     it.is_a? Class_Decl and it.block.compositions.count == 2 and it.block.compositions.all? { |c| c.alias_identifier.nil? }
# # end
# #
# # t 'Abc.new' do |it|
# #     it.is_a? Infixed_Expr
# # end
# #
# # t 'Abc.what { -> 123 }' do |it|
# #     it.is_a? Infixed_Expr and it.right.is_a? Func_Expr and it.right.named?
# # end
# #
# # t 'self.?something' do |it|
# #     it.is_a? Infixed_Expr
# # end
# #
# # t 'if 1234 {
# #     5678
# # }' do |it|
# #     it.is_a? Conditional_Expr and
# #       it.condition.is_a? Number_Literal_Expr and
# #       it.when_true.is_a? Func_Expr and
# #       it.when_false.nil?
# # end
# #
# # t 'if a {
# # else
# # }' do |it|
# #     it.is_a? Conditional_Expr and
# #       it.condition.is_a? Identifier_Expr and
# #       it.when_true.is_a? Func_Expr and
# #       it.when_false.is_a? Func_Expr
# # end
# #
# # t 'if a {
# # elsif 100
# #     yay!
# # else
# # }' do |it|
# #     it.is_a? Conditional_Expr and
# #       it.condition.is_a? Identifier_Expr and
# #       it.when_true.is_a? Func_Expr and
# #       it.when_false.is_a? Conditional_Expr and
# #       it.when_false.condition.is_a? Number_Literal_Expr and
# #       it.when_false.when_true.is_a? Func_Expr and
# #       it.when_false.when_true.expressions.one? and
# #       it.when_false.when_false.expressions.none? and
# #       it.when_false.when_false.is_a? Func_Expr
# # end
# #
# # t 'while a {
# # }' do |it|
# #     it.is_a? While_Expr and
# #       it.condition.is_a? Identifier_Expr and
# #       it.when_true.is_a? Func_Expr and
# #       it.when_false.nil?
# # end
# #
# # t 'while 4 * 8 {
# # }' do |it|
# #     it.is_a? While_Expr and
# #       it.condition.is_a? Infixed_Expr and
# #       it.when_true.is_a? Func_Expr and
# #       it.when_false.nil?
# # end
# #
# # t 'while a {
# # elswhile "b"
# # }' do |it|
# #     it.is_a? While_Expr and
# #       it.condition.is_a? Identifier_Expr and
# #       it.when_true.is_a? Func_Expr and
# #       it.when_false.is_a? While_Expr and
# #       it.when_false.condition.is_a? String_Literal_Expr
# # end
# #
# # t 'while a {
# # elswhile 100
# #     yay!
# # else
# #     1
# #     2
# #     3
# #     4
# # }' do |it|
# #     it.is_a? While_Expr and
# #       it.condition.is_a? Identifier_Expr and
# #       it.when_true.is_a? Func_Expr and
# #       it.when_false.is_a? While_Expr and
# #       it.when_false.condition.is_a? Number_Literal_Expr and
# #       it.when_false.when_true.is_a? Func_Expr and
# #       it.when_false.when_true.expressions.one? and
# #       it.when_false.when_false.expressions.count == 4 and
# #       it.when_false.when_false.is_a? Func_Expr
# # end
# #
# # t 'while a > b {
# #     x + y
# # }' do |it|
# #     it.is_a? While_Expr and
# #       it.condition.is_a? Infixed_Expr and
# #       it.when_true.is_a? Func_Expr and
# #       it.when_true.expressions.first.is_a? Infixed_Expr
# # end
# #
# # t 'call()' do |it|
# #     it.is_a? Block_Call_Expr and it.arguments.empty?
# # end
# #
# # t 'call(a)' do |it|
# #     it.is_a? Block_Call_Expr and it.arguments.one? and
# #       it.arguments[0].expression.is_a? Identifier_Expr and it.arguments[0].expression.string == 'a'
# # end
# #
# # t 'call(a, 1, "asf")' do |it|
# #     it.is_a? Block_Call_Expr and it.arguments.count == 3
# # end
# #
# # t 'call(with: a, 1, "asf")' do |it|
# #     it.is_a? Block_Call_Expr and it.arguments.count == 3 and it.arguments[0].label == 'with'
# # end
# #
# # t 'call(a: 1, b, c: "str", 42)' do |it|
# #     it.is_a? Block_Call_Expr and
# #       it.arguments.count == 4 and
# #       it.arguments[0].label == 'a' and
# #       it.arguments[1].label.nil? and
# #       it.arguments[2].label == 'c' and
# #       it.arguments[3].label.nil?
# # end
# #
# # t 'imaginary(object: Xyz {}, enum: BWAH {}, func: whatever {}, nothing, {})' do |it|
# #     it.is_a? Block_Call_Expr and it.arguments.count == 5 and it.arguments[0].label and it.arguments[1].label and it.arguments[2].label and it.arguments[3].label.nil? and it.arguments.last.expression.is_a? Dictionary_Literal_Expr
# # end
# #
# # t ':test' do |it|
# #     it.is_a? Symbol_Literal_Expr
# # end
# #
# # t 'Abc { + Xyz }' do |it|
# #     it.is_a? Class_Decl and
# #       it.compositions.count == 1
# # end
# #
# # t '{ -> one_line_block }' do |it|
# #     it.is_a? Func_Expr and it.parameters.count == 0 and
# #       not it.expressions.empty? and
# #       not it.named?
# # end
# #
# # t '{ input -> one_line_block }' do |it|
# #     it.is_a? Func_Expr and it.parameters.count == 1 and
# #       not it.expressions.empty? and
# #       not it.named?
# # end
# #
# # t '{ ->
# #     jack
# #     locke
# # }' do |it|
# #     it.is_a? Func_Expr and it.parameters.count == 0 and
# #       it.expressions.count == 2 and
# #       not it.named?
# # end
# #
# # t '[].each { -> }' do |it|
# #     it.is_a? Infixed_Expr and it.left.is_a? Array_Expr and
# #       it.right.is_a? Func_Expr and it.right.name == 'each'
# # end
# #
# # t '"".each { -> }' do |it|
# #     it.is_a? Infixed_Expr and it.right.is_a? Func_Expr and it.right.name == 'each' and it.left.is_a? String_Literal_Expr
# # end
# #
# # t '[].tap { ->
# #     it
# #     at
# # }' do |it|
# #     it.is_a? Infixed_Expr and it.left.is_a? Array_Expr and
# #       it.right.is_a? Func_Expr and it.right.name == 'tap' and it.right.expressions.count == 2
# # end
# #
# # t '[].map { -> }' do |it|
# #     it.is_a? Infixed_Expr and it.right.is_a? Func_Expr and it.right.name == 'map' and it.left.is_a? Array_Expr and it.right.expressions.count == 0
# # end
# #
# # t '[].where { -> it == nil }' do |it|
# #     it.is_a? Infixed_Expr and it.right.is_a? Func_Expr and it.right.name == 'where' and it.left.is_a? Array_Expr and it.right.expressions.count == 1 and it.right.expressions[0].is_a? Infixed_Expr
# # end
# #
# # t 'tap { -> }' do |it|
# #     it.is_a? Func_Expr and it.name == 'tap'
# # end
# #
# # t "where { -> }" do |it|
# #     it.is_a? Func_Expr and it.name == 'where'
# # end
# #
# # t "each { -> }" do |it|
# #     it.is_a? Func_Expr and it.name == 'each'
# # end
# #
# # t "map { -> }" do |it|
# #     it.is_a? Func_Expr and it.name == 'map'
# # end
# #
# # t '%s(boo hoo)' do |it|
# #     it.is_a? Macro_Expr and it.identifiers == %w(boo hoo)
# # end
# #
# # t '%S(boo hoo)' do |it|
# #     it.is_a? Macro_Expr and it.identifiers == %w(BOO HOO)
# # end
# #
# # t 'true' do |it|
# #     it.is_a? Boolean_Literal_Expr and it.to_bool == true
# # end
# #
# # t 'false' do |it|
# #     it.is_a? Boolean_Literal_Expr and it.to_bool == false
# # end
# #
# # t 'true && false' do |it|
# #     it.is_a? Infixed_Expr and it.left.is_a? Boolean_Literal_Expr and it.right.is_a? Boolean_Literal_Expr
# # end
# #
# # t 'true || false' do |it|
# #     it.is_a? Infixed_Expr and it.left.is_a? Boolean_Literal_Expr and it.right.is_a? Boolean_Literal_Expr
# # end
# #
# # t '0..87' do |it|
# #     it.is_a? Infixed_Expr and it.left.is_a? Number_Literal_Expr and it.left.string == '0' and it.right.is_a? Number_Literal_Expr and it.right.string == '87' and it.operator == '..'
# # end
# #
# # t '1.<10' do |it|
# #     it.is_a? Infixed_Expr and it.left.is_a? Number_Literal_Expr and it.left.string == '1' and it.right.is_a? Number_Literal_Expr and it.right.string == '10' and it.operator == '.<'
# # end
# #
# # t '0.1..0.5' do |it|
# #     it.is_a? Infixed_Expr and it.left.is_a? Number_Literal_Expr and it.left.string == '0.1' and it.right.is_a? Number_Literal_Expr and it.right.string == '0.5' and it.operator == '..'
# # end
# #
# # t '.7..7.8' do |it|
# #     it.is_a? Infixed_Expr and it.left.is_a? Number_Literal_Expr and it.left.string == '.7' and it.right.is_a? Number_Literal_Expr and it.right.string == '7.8' and it.operator == '..'
# # end
# #
# # t '(1..2).each { -> }' do |it|
# #     it.is_a? Infixed_Expr and it.left.is_a? Infixed_Expr and it.operator == '.' and it.right.is_a? Func_Expr and it.right.named?
# # end
# #
# # t 'if abc {
# # else
# # }' do |it|
# #     it.is_a? Conditional_Expr and
# #       it.condition.is_a? Identifier_Expr and
# #       it.when_true.is_a? Func_Expr and
# #       it.when_false.is_a? Func_Expr
# # end
# #
# # t 'curse -> 4815162342' do |it|
# #     it.is_a? Func_Expr and it.expressions.one? and it.expressions[0].is_a? Number_Literal_Expr
# # end
# #
# # t 'Dog {
# #     bark -> "woof"
# # }' do |it|
# #     it.is_a? Class_Decl
# # end
