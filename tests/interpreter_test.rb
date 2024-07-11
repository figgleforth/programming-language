# todo: use a real testing framework

require_relative '../source/parser/parser'
require_relative '../source/lexer/lexer'
require_relative '../source/interpreter/interpreter'

# !a
# -a + +b
# a ** b
# a * b / c % d
# a + b - c
# a << b >> c
# a < b <= c > d >= e
# a & b
# a ^ b
# a | b
# a && b
# a || b
# a = b
# a += b
# a -= b
# a *= b
# a /= b
# a %= b
# a &= b
# a |= b
# a ^= b

source = "
2+3
4-5
6*7
8/9
10%11
-1
-2.0
-1 + +3
(1 + 2) * 3
1.
2.
'lost'
1/2
1/2.0
1.0/2
1.0/2.0
true
!true
false
!false
x = 1
:lost
'lost' == :lost
:lost == :lost
'lost' == 'lost'

{ x }
{ a + \"LOST\" } # currently interprets as `NILLOST`, NIL being the placeholder for nil
a = 1 + 2
{ b = 7 }
b
b = a
b
b = nil
'b is next ', b, 4+2, nil
"

# source = File.read('tests/sandbox.em').to_s
lexer  = Lexer.new source
tokens = lexer.lex

parser      = Parser.new tokens
expressions = parser.parse_until

interp = Interpreter.new expressions
interp.interpret!
