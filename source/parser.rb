require_relative 'frontend/ast'
require_relative 'tokenizer'
require 'ostruct'

# Parses tokens into statements, it doesn't care about order, duplication, but it should care about syntax.
class Parser
   attr_reader :tokens, :statements


   def initialize tokens
      @tokens     = tokens
      @statements = []
   end


   ## region HELPERS

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


   def last_statement
      statements.last
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


   def peek_many distance = 1, length = 1
      tokens[distance, length]
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
      if curr == CommentToken or curr == BlockCommentToken
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


   # todo; infer type from expression
   def parse_variables
      if curr == IdentifierToken
         if peek === Token.equals.value
            # identifier =
            Assignment.new.tap do |var|
               var.keypath = eat
               eat # =
               var.value = parse_expression
            end
         elsif peek === Token.colon.value
            if peek(2) == IdentifierToken or peek(2) == KeywordToken
               # identifier, :, identifier
               t = eat_many 3

               Assignment.new.tap do |var|
                  var.keypath = t[0]
                  var.type    = t[2]

                  if curr === Token.equals.value
                     eat # =
                     var.value = parse_expression
                  end
               end
            elsif peek(2) === Token.equals.value
               t = eat_many 3
               # identifier :=

               Assignment.new.tap do |var|
                  var.keypath = t[0]
                  var.value   = parse_expression
                  # todo
               end
            else
               raise 'Expected identifier or :='
            end
         elsif peek == NewlineToken
            # identifier \n
            Statement.new eat
         else
            Assignment.new.tap do |ass|
               ass.keypath = []

               while curr == IdentifierToken and peek === Token.dot.value
                  # identifier, .
                  ass.keypath << eat
                  eat # .
               end

               ass.keypath << eat
               eat # =
               ass.value = parse_expression
            end
         end
      end
   end


   def parse_paren_expr
      if curr === Token.open_paren.value
         eat # (
         node = parse_expression 1
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
      while curr == NewlineToken
         eat
         nil
      end
   end


   def parse_methods
      return unless curr == KeywordToken and curr.value === 'def'

      eat # def

      if peek == NewlineToken # no params and no return type
         MethodDefinition.new.tap do |m|
            m.identifier = eat 2 # ident, newline
            m.body       = parse KeywordToken, 'end'
            eat # end
         end
      elsif peek === Token.open_paren.value # params and no return type

         Statement.new eat
      elsif peek === Token.arrow.value # no params and return type
         MethodDefinition.new.tap do |m|
            m.identifier = eat 2 # ident, ->
            m.return_type = eat
            m.body       = parse KeywordToken, 'end'
            eat # end
         end
      else
         puts "CURR #{curr} PEEK #{peek}"
         # params and return type
         Statement.new eat
      end

   end


   ## endregion

   # this looks fancy but it just returns the first non-nil value
   def parse_leaf
      parse_newlines or
        parse_string or
        parse_number or
        parse_comment or
        parse_methods or
        parse_variables or
        parse_paren_expr or
        parse_newlines
   end


   def parse stop_at = EOFToken, stop_at_value = nil

      parsed_statements = []
      until reached_end? or (curr == stop_at or curr === stop_at_value)
         if stop_at and (curr == stop_at or curr === stop_at_value)
            return statements
         end

         parsed_statements << parse_expression
         statements << parsed_statements.last
      end

      statements.compact
      parsed_statements.compact
   end


   alias_method :parse_block, :parse
end
