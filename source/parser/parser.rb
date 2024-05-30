# Turns string of code into tokens
class Parser
   attr_accessor :i, :tokens


   class UnexpectedToken < RuntimeError
      def initialize token
         super "Unexpected token `#{token}`"
      end
   end


   def initialize tokens = nil
      @tokens = tokens
      @i      = 0 # index of current token
   end


   def tokens= t
      @tokens = t.select { |token| token != CommentToken }
      @i      = 0
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
      raise UnexpectedToken unless curr == expected
   end


   # original version of peek, I don't think it'll be useful now that #peek? exists
   def peek at = 1, length = 1
      @tokens[@i + at, length]
   end


   # todo: make sure that skipping delimiters won't be problematic
   def peek? * expected
      ahead = @tokens&.reject do |token|
         # ignore \s \t \n but not ;
         token == DelimiterToken and token != ';'
      end[..expected.length - 1]

      ahead.each_with_index.all? do |token, index|
         token == expected[index]
      end
   end


   def eat * expected
      if expected.empty? or expected.one?
         @i += 1
         return last
      end

      [].tap do |result|
         expected.each do |expect|
            @i += 1 while curr == DelimiterToken and curr != ';'
            assert expect
            result << curr
            @i += 1
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
         # fix: make sure curr is a binary operator and not just any symbol because precedences only exist for binary operators. also, when curr_precedence is nil when curr is not an operator so it crashes.
         break unless curr == SymbolToken # OperatorToken

         curr_precedence = precedence_for curr
         break if curr_precedence < precedence

         operator            = curr
         operator_precedence = curr_precedence
         min_precedence      = operator_precedence

         eat SymbolToken # operator

         right = eat_expression min_precedence
         left  = BinaryExpr.new left, operator, right
      end

      left
   end


   def parse until_token = nil
      statements = []
      statements << eat_expression while tokens? and curr != until_token
      statements
   end
end
