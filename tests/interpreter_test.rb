require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'
require_relative '../source/interpreter/interpreter'

puts "\nRunning interpreter tests...\n\n"


def t code, &block
    raise ArgumentError, '#t requires a code string' unless code.is_a?(String)
    raise ArgumentError, '#t requires a block' unless block_given?
    @tests_ran ||= 0

    tokens       = Lexer.new(code).lex
    ast          = Parser.new(tokens).to_ast
    output       = Interpreter.new(ast).interpret!
    block_result = block.call output

    if not block_result
        raise "\n\nFAILED TEST\n———————————\n#{code}\n———————————\n#{output}"
    end

    @tests_ran += 1
end


t '' do |it|
    it.is_a? Runtime_Scope
end

# 2+3
# 4-5
# 6*7
# 8/9
# 10%11
# -1
# -2.0
# -1 + +3
# (1 + 2) * 3
# 1.
# 2.
# 'lost'
# 1/2
# 1/2.0
# 1.0/2
# 1.0/2.0
# true
# !true
# false
# !false
# x = 1
# :lost
# 'lost' == :lost
# :lost == :lost
# 'lost' == 'lost'
#
# { x }
# { a + \"LOST\" } # currently interprets as `NILLOST`, NIL being the placeholder for nil
# a = 1 + 2
# { b = 7 }
# b
# b = a
# b
# b = nil
# 'b in a string', b, 4+2, nil
# '`b` interpolated into the string'
