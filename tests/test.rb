require_relative '../source/lexer/lexer'
require_relative '../source/parser/parser'
require_relative '../source/parser/ast'

puts "\nRunning tests:\n\n"


def t code, &block
    raise ArgumentError, 'x requires a code string' unless code.is_a?(String)
    raise ArgumentError, 'x requires a block' unless block_given?


    def assert condition = false, message = 'ASSERT FAILED'
        raise message unless condition
    end


    tokens = Lexer.new(code).lex
    ast    = Parser.new(tokens).to_ast

    puts code
    block_result  = block.call ast
    parser_output = [ast].flatten.map { |a| a.inspect }

    assert block_result, "\n\nFAILED TEST\n———————————\n#{code}\n———————————\n#{parser_output}"
end


t '42' do |it|
    it.is_a? Number_Literal_Expr and
        it.string == '42' and
        it.type == :int and
        it.decimal_position == nil
end

t '42.0' do |it|
    it.is_a? Number_Literal_Expr and
        it.string == '42.0' and
        it.type == :float and
        it.decimal_position == :middle
end

t '42.' do |it|
    it.is_a? Number_Literal_Expr and
        it.string == '42.' and
        it.type == :float and
        it.decimal_position == :end
end

t '.42' do |it|
    it.is_a? Number_Literal_Expr and
        it.string == '.42' and
        it.type == :float and
        it.decimal_position == :start
end

t '"double"' do |it|
    it.is_a? String_Literal_Expr
end

t "'single'" do |it|
    it.is_a? String_Literal_Expr
end

t '"`interpolated`"' do |it|
    it.is_a? String_Literal_Expr and it.interpolated
end

t 'x' do |it|
    it.is_a? Identifier_Expr
end

t 'x =;' do |it|
    it.is_a? Assignment_Expr
end

t 'x = 0' do |it|
    it.is_a? Assignment_Expr and
        it.expression.is_a? Number_Literal_Expr and
        it.expression.string == '0'
end

t 'x {}' do |it|
    it.is_a? Function_Expr and
        it.expressions.empty? and
        it.compositions.empty? and
        it.parameters.empty?
end

t 'x { 42 }' do |it|
    it.is_a? Function_Expr and
        it.expressions.one? and
        it.expressions.first.is_a? Number_Literal_Expr and
        it.compositions.empty? and
        it.parameters.empty?
end

t 'x + y' do |it|
    it.is_a? Binary_Expr and it.left.is_a? Identifier_Expr and it.right.is_a? Identifier_Expr
end

t 'ENUM {}' do |it|
    it.is_a? Enum_Collection_Expr
end

t 'ENUM {
    ONE
}' do |it|
    it.is_a? Enum_Collection_Expr and it.constants.one?
end

t 'ENUM {
    ONE = 1
}' do |it|
    it.is_a? Enum_Collection_Expr and
        it.constants.one? and
        it.constants[0].value.is_a? Number_Literal_Expr
end

t 'ENUM = 1' do |it|
    it.is_a? Enum_Constant_Expr
end

t 'Abc {}' do |it|
    it.is_a? Class_Expr and
        it.block.expressions.empty? and
        it.block.compositions.empty?
end

t '{}' do |it|
    it.is_a? Function_Expr and
        it.expressions.empty? and
        it.compositions.empty? and
        it.parameters.empty?
end
