# Turns string of code into tokens
class Parser
   require_relative '../lexer/token'
   require_relative 'ast_nodes'

   VAR_EXPLICIT_TYPE         = [IdentifierToken, ':', IdentifierToken]
   VAR_IMPLICIT_TYPE         = [IdentifierToken, ':=']
   VAR_UNTYPED_OR_ASSIGNMENT = [IdentifierToken, '=']
   METHOD_DECLARATION        = ['def', IdentifierToken]
   METHOD_CALL               = ['.', IdentifierToken]

   attr_accessor :i, :tokens


   class UnexpectedToken < RuntimeError
      def initialize message, token
         super(message || "Unexpected token `#{token.string}`")
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


   # todo; find the real precedence values. I'm not sure these are correct. Like why does parse_expression += 1 to precedence for the ^ operator?
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
      @i < (@tokens&.length || 0)
   end


   def assert condition, message = nil
      raise UnexpectedToken.new(message, curr) if condition == false
   end


   # original version of peek, I don't think it'll be useful now that #peek? exists
   def peek at = 1, length = 1
      @tokens[@i + at, length]
   end


   # note: make sure that skipping delimiters won't be problematic
   def peek? * expected
      remainder = @tokens[@i..]

      check = remainder&.reject do |token|
         token == DelimiterToken and token != ';' and token != "\n"
      end[..expected.length - 1]

      return false unless check and not check.empty? # all? returns true for an empty array [].all? so this early return is required

      check.each_with_index.all? do |token, index|
         # idea: support multiple checks, like `peek? Identifier, [':=', '=']`
         # if expected[index].is_a? Array
         #    expected[index].any? { |exp| token == exp }
         # else
         #    token == expected[index]
         # end
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
            # eg: 'self', ':', IdentifierToken

            @i += 1 while curr == DelimiterToken and curr != ';' # skip delimiters except ;

            assert expect
            result << curr
            @i += 1
         end
      end
   end


   # note: does the parser care if the compositions are using correct identifiers? what if I use float? I think this is that type checking phase Jon was talking about
   def parse_self_declaration
      # return nil unless peek? 'self', ':', IdentifierToken

      SelfDeclNode.new.tap do |node|
         tokens    = eat 'self', ':', IdentifierToken
         node.type = tokens.last

         if peek? '>', IdentifierToken
            node.compositions << eat('>', IdentifierToken).last

            while curr == ',' and peek[0] == IdentifierToken
               node.compositions << eat(',', IdentifierToken).last
            end

            # todo: useful error message for users
            assert curr != ',' # we should not have a comma without an identifier following it
         end
      end
   end


   def parse_typed_var_declaration
      VarAssignmentNode.new.tap do |node|
         tokens    = eat IdentifierToken, ':', IdentifierToken
         node.name = tokens[0]
         node.type = tokens[2]

         if peek? '='
            eat '='
            node.value = parse_expression
         end
      end
   end


   def parse_untyped_var_declaration_or_reassignment
      VarAssignmentNode.new.tap do |node|
         tokens     = eat IdentifierToken, '='
         node.name  = tokens[0]
         node.value = parse_expression
      end
   end


   def parse_inferred_var_declaration
      VarAssignmentNode.new.tap do |node|
         tokens    = eat IdentifierToken, ':='
         node.name = tokens[0]

         # todo: ensure that an expression is actually here

         # ( expression )
         # ""
         # number
         # identifier
         node.value = parse_expression
         # node.type = tokens[2]
      end
   end


   def parse_string_or_number_literal
      if curr == StringToken
         StringLiteralNode.new
      else
         NumberLiteralNode.new
      end.tap do |literal|
         literal.token = eat
      end
   end


   def parse_leaf
      if peek? '('
         eat '('
         expr = parse_expression
         eat ')'

         expr
      elsif peek? 'self', ':', IdentifierToken
         parse_self_declaration

      elsif peek? IdentifierToken, ':', IdentifierToken
         parse_typed_var_declaration

      elsif peek? IdentifierToken, ':='
         parse_inferred_var_declaration

      elsif peek? IdentifierToken, '='
         parse_untyped_var_declaration_or_reassignment

      elsif peek? StringToken or peek? NumberToken
         parse_string_or_number_literal

      elsif curr == DelimiterToken
         eat # don't care about delimiters that weren't already handled by the other cases
         nil

      else
         eat
      end
   end


   def parse_expression precedence = -100
      left = parse_leaf

      # basically if next is operator
      while tokens? and curr
         break # fix: make sure curr is a binary operator and not just any symbol because precedences only exist for binary operators. also, when curr_precedence is nil when curr is not an operator so it crashes.
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


   def parse until_token = EOFToken
      [].tap do |stmts|
         stmts << parse_expression while tokens? and curr != until_token and curr != EOFToken
      end.compact
   end
end
