# Turns string of code into tokens
class Parser
   attr_accessor :i, :tokens


   def initialize tokens = nil
      @tokens = tokens
      @i      = 0 # index of current token
   end


   # todo; find the real precedence values. I'm not sure these are correct. Like why does eat_expression += 1 to precedence for the ^ operator?
   def precedence_for token
      [
         [%w(( )), 10],
         [%w(.), 9],
         [%w(^), 8],
         [%w(* / %), 7],
         [%w(+ -), 6],
         [%w(> >= < <=), 5],
         [%w(==), 4],
         [%w(&&), 3],
         [%w(||), 2],
         [%w(=), 1]
      ].find do |chars, _|
         chars.include?(token.string)
      end&.at(1)
   end


   def last
      @tokens[@i - 1]
   end


   def curr
      raise 'Parser.tokens is nil' unless tokens
      @tokens[@i]
   end


   def tokens?
      @i < @tokens.length
   end


   def assert expected
      raise "EXPECTED \n\t#{expected}\n\nGOT\n\t#{curr}" unless curr == expected
   end


   def peek distance = 1, length = 1
      @tokens[@i + distance, length]
   end


   def expect * expected
      expected.each_with_index do |expect, i|
         raise "\n\nEXPECTED \n\t#{expected}\n\nGOT\n\t#{curr}" unless peek(i) == expected
      end
   end


   # Usage
   #
   # eat CommentToken
   # eat '#'
   def eat expected = nil
      # puts 'EATING  ', curr.inspect
      # puts "tokens? #{@tokens}"
      if expected and expected != peek
         raise "\n\nEXPECTED \n\t#{expected}\n\nGOT\n\t#{peek.inspect}"
      end

      @i += 1
      last
   end


   # Usage
   #
   # eat_many 2, [IdentifierToken, SymbolToken]
   # eat_many 2, IdentifierToken, SymbolToken
   #
   # or
   #
   # eat_many 2, ['test', ':']
   # eat_many 2, 'test', ':'
   def eat_many distance = 1, *expected
      expected = [] if expected.nil? or expected.empty?

      expect *expected
      [].tap do |arr|
         distance.times do |i|
            if peek(i) != expected[i]
               raise "EXPECTED #{expected} GOT #{arr.join}"
            end

            arr << eat(expected)
         end
      end
   end


   def eat_leaf
      eat
   end


   def eat_expression precedence = -100
      left = eat_leaf

      # basically if next is operator
      while tokens? and curr
         # fix: make sure curr is an operator and not just any symbol because precedences only exist for specific operators. when curr is not an operator, curr_precedence is nil so it crashes
         break unless curr == SymbolToken # OperatorToken

         curr_precedence = precedence_for curr
         break if curr_precedence < precedence

         operator            = curr
         operator_precedence = curr_precedence
         min_precedence      = operator_precedence

         eat SymbolToken # operator

         right = parse_expression min_precedence
         left  = BinaryExpr.new left, operator, right
      end

      left
   end


   def parse until_token = nil
      # puts "PARSE! #{tokens}"
      statements = []
      statements << eat_expression while tokens? and curr != until_token
      statements
   end
end
