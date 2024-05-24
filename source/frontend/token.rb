class Token
   attr_accessor :value, :x, :y

   def initialize value
      @value = value
   end

   def position
      [@x, @y]
   end

   def type
      self.class
   end

   def to_s
      "#{type}(#{@value})"
   end

   def == other
      self.class == other
   end

   def === other
      value == other
   end
end

# class TokenReader
#    attr_accessor :tokens
#    def initialize tokens
#       @tokens = tokens
#    end
#
#    def variable_assignment?
#       tokens[0] == Identifier and tokens[1]&.value == '='
#    end
#
#    def comment?
#       tokens[0] == Comment
#    end
# end

class EOF < Token
   def initialize
      super 'eof'
   end
end

class Str < Token
   def to_s
      "String(#{value})"
   end
end

class Newline < Token
end

class Comment < Token
   def to_s
      "Comment(#{@value})"
   end
end

class MultilineComment < Comment
   def to_s
      "MultilineComment(#{@value.inspect})"
   end
end

class Number < Token
end

class Identifier < Token
   def self.create word
      return Keyword.new(word) if KEYWORDS.include? word
      Identifier.new word
   end
end

class Keyword < Identifier
   require_relative 'tokens'

   KEYWORDS.each do |word|
      define_method("#{word}?") do
         @value == word
      end
   end

   def keyword?
      KEYWORDS.include? value
   end

   def to_s
      return super unless keyword?
      "Keyword(#{@value})"
   end
end

# comment hash # and string quotes are not special characters
class Special < Token
   SPECIAL_CHARACTERS = {
     triple_dot:          '...',
     or_or_equals:        '||=',

     double_plus:         '++',
     double_minus:        '--',
     plus_equals:         '+=',
     minus_equals:        '-=',
     star_equals:         '*=',
     slash_equals:        '/=',
     equals_equals:       '==',
     less_than_equals:    '<=',
     greater_than_equals: '>=',
     double_less_than:    '<<',
     double_greater_than: '>>',
     not_equals:          '!=',
     double_or:           '||',
     double_dot:          '..',
     double_and:          '&&',

     dot:                 '.',
     plus:                '+',
     minus:               '-',
     star:                '*',
     slash:               '/',
     percent:             '%',
     caret:               '^',
     ampersand:           '&',
     equals:              '=',
     less_than:           '<',
     greater_than:        '>',
     exclamation:         '!',
     question:            '?',
     at:                  '@',
     or:                  '|',
     open_paren:          '(',
     close_paren:         ')',
     open_square:         '[',
     close_square:        ']',
     open_curly:          '{',
     close_curly:         '}',
     comma:               ',',
     colon:               ':',
     semicolon:           ';',
   }
   SPECIAL_CHARACTERS.each do |name, symbol|
      define_method("#{name}?") do
         @value == symbol
      end

      define_singleton_method(name) do
         new(symbol)
      end
   end

   def to_s
      "Symbol(#{@value})"
   end
end

# frozen_string_literal: true

class OperatorToken < Token
   OPERATORS = {
     plus:                '+',
     minus:               '-',
     star:                '*',
     slash:               '/',
     percent:             '%',
     ampersand:           '&',
     pipe:                '|',
     caret:               '^',
     equals:              '=',
     not_equals:          '!=',
     less_than:           '<',
     greater_than:        '>',
     less_than_equals:    '<=',
     greater_than_equals: '>=',
     double_equals:       '==',
     plus_equals:         '+=',
     minus_equals:        '-=',
     star_equals:         '*=',
     slash_equals:        '/=',
     percent_equals:      '%=',
     double_ampersand:    '&&',
     double_pipe:         '||',
     double_plus:         '++',
     double_minus:        '--',
     shift_left:          '<<',
     shift_right:         '>>',
     arrow:               '->',
     double_colon:        '::'
   }.freeze

   # usage: OperatorToken.plus, etc
   OPERATORS.each do |name, symbol|
      define_singleton_method(name) do
         @instances         ||= {}
         @instances[symbol] ||= new(symbol)
      end
   end

   def to_s
      "Operator(#{@value})"
   end
end

class BinaryOperator < OperatorToken
   Operators = {
     plus:         '+',
     minus:        '-',
     star:         '*',
     slash:        '/',
     percent:      '%',
     caret:        '^',
     less_than:    '<',
     greater_than: '>',
     double_or:    '||',
     or:           '|',
   }

   Operators.each do |name, symbol|
      define_method("#{name}?") do
         @value == symbol
      end

      define_singleton_method(name) do
         new(symbol)
      end
   end

   def to_s
      "BinaryOperator(#{@value})"
   end
end

class UnaryOperator < OperatorToken
   Operators = {
     plus_plus:   '++',
     minus_minus: '--',
     minus:       '-',
     plus:        '+',
     not:         '!',
     bit_not:     '~',
   }

   Operators.each do |name, symbol|
      define_method("#{name}?") do
         @value == symbol
      end

      define_singleton_method(name) do
         new(symbol)
      end
   end

   def to_s
      "BinaryOperator(#{@value})"
   end
end
