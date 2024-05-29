require_relative 'frontend/t'
require_relative 'tokenizer'
require 'ostruct'

# Parses tokens into statements, it doesn't care about order, duplication, but it should care about syntax.
class ParserOld
   attr_reader :tokens, :statements, :last


   def initialize tokens
      @tokens     = tokens
      @statements = []
   end


   ## region HELPERS

   def assert_tok token
      raise "EXPECTED #{token} got #{curr}" unless curr == token
   end


   def assert_val value
      raise "EXPECTED #{value} got #{curr}" unless curr == value
   end

   def assert expected
      raise "EXPECTED #{expected} got #{curr}" unless cur == expected
   end


   def debug lookahead = 2
      str = "LAST #{last.inspect}"
      (lookahead + 1).times do |i|
         if i == 0
            str += "\n\tCURR    #{peek(i)}"
         else
            str += "\n\t\tPEEK_#{i}  #{peek(i)}"
         end
      end
      puts
      puts str
   end


   def get_prec token
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
         chars.include?(token.value)
      end&.at(1)
   end


   def eat token_count = 1
      tokens.shift(token_count)[0]
   end


   def eat_many token_count = 1
      [].tap do |a|
         token_count.times do
            a << eat
         end
      end
   end


   def expect * expected
      expected.each_with_index do |type, i|
         raise "Expected #{type} got #{peek(i)}" unless peek(i) == type
      end
   end


   def eat_until & block
      eat tokens.slice_before(&block).to_a.first.count
   end


   def eat_past & block
      eat tokens.slice_after(&block).to_a.first.count
   end


   def curr
      tokens[0]
   end


   def peek distance = 1
      tokens[distance]
   end



   def peek_until & block
      tokens.dup.slice_before(&block).to_a.first
   end


   def reached_end?
      tokens.empty? or tokens[0].type == :eof
   end


   ## endregion

   ## region PARSING

   def parse_comment
      if curr == CommentTok or curr == BlockCommentToken
         Comment.new eat
      end
   end


   def parse_expression precedence = -1000
      left = parse_leaf

      # basically if next is operator
      until reached_end?
         break unless curr == OperatorToken

         curr_precedence = get_prec curr
         break if curr_precedence < precedence

         operator            = curr
         operator_precedence = curr_precedence
         min_precedence      = operator_precedence
         min_precedence      += 1 if operator.value == '^'

         eat # operator

         right = parse_expression min_precedence
         left  = BinaryExpr.new left, operator, right
      end

      left
   end

   def parse_variables
      if curr == IdentifierTok
         if peek == LexerToken.equals.value
            # identifier =
            Ast_Assignment.new.tap do |var|
               assert_tok IdentifierTok
               var.left = eat

               assert_val '='
               eat # =
               var.value = parse_expression

               assert_tok DelimiterToken
            end
         elsif peek == LexerToken.colon.value
            if peek(2) == IdentifierTok or peek(2) == KeywordToken
               # identifier, :, identifier
               t = eat_many 3

               Ast_Assignment.new.tap do |var|
                  var.left = t[0]
                  var.type    = t[2]

                  if curr == LexerToken.equals.value
                     assert_val '='
                     eat # =
                     var.value = parse_expression
                     puts "(identifier : identifier) value = #{var.value}"
                  end
               end
            elsif peek(2) == LexerToken.equals.value
               t = eat_many 3
               # identifier :=

               Ast_Assignment.new.tap do |var|
                  var.left = t[0]
                  var.value   = parse_expression
                  puts "(identifier :=) value = #{var.value}"
                  # todo
               end
            else
               raise 'Expected identifier or :='
            end
            # elsif peek == NewlineToken
            #    # identifier \n
            #    Statement.new eat
         else
            Ast_Assignment.new.tap do |ass|
               ass.left = []

               while curr == IdentifierTok and peek == LexerToken.dot.value
                  # identifier, .
                  ass.left << eat
                  assert_val '.'
                  eat # .
               end

               ass.keypath << eat

               raise "Expected = or newline" unless curr == LexerToken.equals.value or curr == DelimiterToken

               if curr == LexerToken.equals.value
                  eat # =
                  assert_val '='
                  ass.value = parse_expression
                  puts "(identifier.identifier...) value = #{var.value}"
               end
            end
         end
      end
   end


   def parse_paren_expr
      if curr == LexerToken.open_paren.value
         assert_val '('
         eat # (
         node = parse_expression 1

         assert_val ')'
         eat # )
         node
      end
   end


   def parse_string
      if curr == StringToken
         StringLiteral.new eat
      end
   end


   def parse_number
      if curr == NumberToken
         NumberLiteral.new eat
      end
   end


   def parse_newlines
      while curr == DelimiterToken
         eat
         nil
      end
   end


   def parse_method
      return unless curr == KeywordToken and curr.value == 'def'

      assert_val 'def'
      eat # def

      if peek == DelimiterToken # no params and no return type
         MethodDefinition.new.tap do |m|
            assert_tok IdentifierTok
            m.identifier = eat # ident
            m.body       = parse 'end'
            assert_val 'end'
            eat # end
         end
      elsif peek == LexerToken.open_paren.value # params and no return type
         Statement.new eat
      elsif peek == LexerToken.arrow.value # no params and return type
         MethodDefinition.new.tap do |m|
            m.identifier  = eat 2 # ident, ->
            m.return_type = eat
            m.body        = parse 'end'
            eat # end
         end
      else
         debug
         # params and return type
         Statement.new eat
      end

   end


   def parse_literal
      if curr == IdentifierTok
         assert_tok IdentifierTok
         Ast_Literal.new eat
      end
   end


   ## endregion

   # this looks fancy but it just returns the first non-nil value
   def parse_leaf
      parse_newlines or
        parse_comment or
        parse_string or
        parse_number or
        parse_variables or
        parse_literal or
        parse_method or
        parse_paren_expr # or
      # parse_newlines
   end


   # def parse stop_at = EOFToken, stop_at_value = nil
   def parse stop_at = nil
      parsed_statements = []
      until reached_end? # or curr == stop_at
         break if curr == stop_at

         parsed_statements << parse_expression
         statements << parsed_statements.last
         last = parsed_statements.last
      end

      statements.compact
      parsed_statements.compact
   end
end
