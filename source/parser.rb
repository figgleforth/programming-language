require_relative './frontend/node'
require_relative './frontend/token'
require_relative './frontend/tokens'
require_relative 'tokenizer'
require 'ostruct'

# Parses tokens into statements, it doesn't care about order, duplication, but it should care about syntax.
class Parser
   attr_reader :tokens

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

   def initialize tokens
      @tokens = tokens
   end

   def eat token_count = 1
      tokens.shift(token_count)[0]
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

   def peek ahead = 1
      tokens[ahead]
   end

   def peek_until & block
      tokens.dup.slice_before(&block).to_a.first
   end

   def reached_end?
      tokens.empty? or tokens[0].type == :eof
   end

   def parse_leaf
      if curr == Identifier and peek(1) === '='
         node       = VariableAssignment.new
         node.left  = eat 2 # ident, =
         node.right = parse_expression
         node
      elsif curr == Identifier and peek(1) === '.' and peek(2) == Identifier
         node      = MemberCall.new
         node.left = eat # foo

         # foo.bar.baz.etc =
         while curr === '.' and peek(1) == Identifier
            eat # .
            node.right     = eat # identifier
            new_node       = MemberCall.new
            new_node.left  = node
            new_node.right = node.right
            node           = new_node
         end

         if curr === '='
            eat # =
            assignment       = VariableAssignment.new
            assignment.left  = node
            assignment.right = parse_expression
            assignment
         else
            node
         end
      elsif curr == Keyword and curr === 'def'
         eat # def
         node      = MethodDeclaration.new
         node.name = eat # ident
         node.body = parse_block Keyword, 'end'

         eat # end

         # if ( then params present
         # if -> then return type present

         node
      elsif curr === '('
         eat # (
         node = parse_expression 1
         eat # )
         node
      elsif curr == OperatorToken
         eat
      elsif curr == Number
         # todo; NumberLiteralNode
         eat
      elsif curr == Comment or curr == MultilineComment
         # todo; generate documentation
         node       = CommentNode.new
         node.token = eat
         node
      else
         eat
      end
   end

   def parse_expression precedence = -1000
      operator_precedences = {
        '+': 1,
        '-': 1,
        '*': 2,
        '/': 2,
        '%': 2,
        '^': 3
      }

      left = parse_leaf

      # basically if next is operator
      until reached_end?
         break unless curr == OperatorToken
         # curr_precedence = PRECEDENCES[curr.value.to_sym]
         curr_precedence = get_prec(curr)
         break if curr_precedence < precedence

         operator            = curr
         operator_precedence = curr_precedence
         min_precedence      = operator_precedence
         min_precedence      += 1 if operator.value == '^'

         eat

         right = parse_expression min_precedence
         left  = BinaryExpr.new left, operator, right
      end

      left
   end

   def parse stop_at = EOF, value = nil
      puts if stop_at == EOF

      stmts = []
      until reached_end?
         if stop_at and (curr == stop_at or curr === value)
            return stmts
         end

         stmts << parse_expression
      end

      stmts
   end

   alias_method :parse_block, :parse
end
