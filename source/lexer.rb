# Turns string of code into tokens
class Lexer
   require_relative 'lexer/methods'

   attr_accessor :i, :col, :row, :source, :tokens


   def initialize source
      @source = source
      @tokens = []
      @i      = 0 # index of current char in source string
      @col    = 0 # short for column
      @row    = 1 # short for line
   end
end
