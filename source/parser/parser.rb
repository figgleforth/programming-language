# Turns string of code into tokens
class Parser
   require_relative '../lexer/token'
   require_relative 'nodes'

   attr_accessor :i, :tokens, :statements


   def initialize tokens = nil
      @statements = []
      @tokens     = tokens
      @i          = 0 # index of current token
   end


   # https://doc.comsol.com/5.5/doc/com.comsol.help.comsol/comsol_ref_definitions.12.022.html
   PRECEDENCES = [
      [%w(( ) { } .), 1],
      [%w(^), 2],
      [%w(! - +), 3],
      [%w([ ]), 4],
      [%w(* /), 5],
      [%w(+ -), 6],
      [%w(< <= > >=), 7],
      [%w(>== === !=== == !-), 8],
      [%w(&&), 9],
      [%w(||), 10],
      [%w(,), 11],
   ]


   def precedence_for token
      PRECEDENCES.find do |chars, _|
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


   def remainder
      @tokens[@i..]
   end


   def tokens?
      @i < (@tokens&.length || 0)
   end


   def assert_token token, expected
      raise "Expected #{expected} but got #{token}" unless token == expected
   end


   def assert_condition token, condition
      raise "Unexpected #{token}" unless condition
   end


   # original version of peek, I don't think it'll be useful now that #peek? exists
   def peek at = 1, length = 1
      @tokens[@i + at, length]
   end


   def peek? * expected
      return false unless remainder

      check = remainder&.reject do |token|
         # reject delimiters except ; and \n
         token == DelimiterToken and token != ';' and token != "\n"
      end[..expected.length - 1]

      return false unless check and not check.empty? # all? returns true for an empty array [].all? so this early return is required

      check.each_with_index.all? do |token, index|
         if expected[index].is_a? Array
            expected[index].any? { |exp| token == exp }
         else
            token == expected[index]
         end
      end
   end


   def eat * expected
      if expected.nil? or expected.empty? or expected.one?
         @i += 1
         return last
      end

      [].tap do |result|
         expected.each do |expect|
            # eg: 'obj', IdentifierToken

            @i += 1 while curr == DelimiterToken and curr != ';' # skip delimiters except ;

            assert_token curr, expect
            result << curr
            @i += 1
         end
      end
   end


   def parse_statements precedence = 0
      left = parse_leaf

      while tokens? and curr
         break unless curr == SymbolToken and curr.binary?

         curr_prec = precedence_for curr
         break if curr_prec <= precedence

         left = BinaryExprNode.new.tap do |node|
            node.left     = left
            node.operator = eat SymbolToken
            node.right    = parse_statements curr_prec
         end
      end

      left
   end


   def parse_typed_var_declaration
      VarAssignmentNode.new.tap do |node|
         tokens    = eat IdentifierToken, ':', IdentifierToken
         node.name = tokens[0]
         node.type = tokens[2]

         if peek? '='
            eat '='
            node.value = parse_statements
         end
      end
   end


   def parse_untyped_var_declaration_or_reassignment
      VarAssignmentNode.new.tap do |node|
         tokens     = eat IdentifierToken, '='
         node.name  = tokens[0]
         node.value = parse_statements
      end
   end


   def parse_inferred_var_declaration
      VarAssignmentNode.new.tap do |node|
         tokens    = eat IdentifierToken, ':='
         node.name = tokens[0]

         # ( expression )
         # ""
         # number
         # identifier
         node.value = parse_statements
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


   def parse_unary_expr
      UnaryExprNode.new.tap do |node|
         node.operator = eat SymbolToken
         node.operand  = parse_statements precedence_for(node.operator)
      end
   end


   def parse_object_declaration
      # if first statement of program then it's top-level object declaration
      #    obj Ident > Ident (imp Ident, ...) ({) \n
      #    (imp Ident, ...)
      #
      # otherwise
      #    obj Ident > Ident (imp Ident, ...) ({) \n
      #       (imp Ident, ...)
      #    }
      ObjectDeclNode.new.tap do |node|
         node.type = eat('obj', IdentifierToken).last

         if peek? '>', IdentifierToken
            node.base_type = eat('>', IdentifierToken).last
            eat while curr == DelimiterToken # { or \n or both
         end

         # compositions
         while peek? 'imp'
            node.compositions << eat('imp', IdentifierToken).last

            while curr == ',' and peek[0] == IdentifierToken
               node.compositions << eat(',', IdentifierToken).last
            end

            raise "Unexpected `,` without additional compositions" if curr == ','
            eat while curr == DelimiterToken # { or \n or both
         end

         # body or empty obj termination
         if peek? %w(; }) # delimiter for empty object
            eat
         else
            eat while curr == DelimiterToken # { or \n or both
            node.statements = parse_block
            eat if peek? '}'
         end
      end
   end


   def parse_block until_token = '}'
      parser = Parser.new remainder
      stmts  = parser.parse until_token
      @i     += parser.i
      stmts
   end


   def parse_method_declaration
      def parse_method_params until_token = ')'
         parse_block until_token
      end


      MethodDeclNode.new.tap do |node|
         node.name = eat('def', IdentifierToken).last

         # no params, no return
         if peek? "\n"
            eat "\n"
            node.statements = parse_block

            # no params, return
         elsif peek? %w(: ->), IdentifierToken
            eat # : or ->
            node.return_type = eat IdentifierToken

         elsif peek? '('
            eat '('
            node.parameters = parse_method_params
            eat ')'

            if peek? %w(: ->), IdentifierToken
               eat # : or ->
               node.return_type = eat IdentifierToken
            end
         elsif peek? IdentifierToken

         else
            eat
         end

         # eat "\n" while peek? "\n"

         # puts "CURR #{curr} ? #{not peek?(';')}"

         # if peek? ';' # blank obj
         # node.statements = parse_block
         # end

      end
   end


   def parse_leaf
      if peek? '('
         eat '('
         parse_statements.tap do
            eat ')'
         end

      elsif peek? %w({ }) # for blocks that are not handled as part of other constructs. like just a random block surrounded by { and }
         eat and nil

      elsif peek? CommentToken
         eat and nil

      elsif peek? SymbolToken and curr.unary? # %w(- + ~ !)
         parse_unary_expr

      elsif peek? 'def', IdentifierToken
         parse_method_declaration

      elsif peek? 'obj', IdentifierToken
         parse_object_declaration

      elsif peek? IdentifierToken, ':', IdentifierToken
         parse_typed_var_declaration

      elsif peek? IdentifierToken, ':='
         parse_inferred_var_declaration

      elsif peek? IdentifierToken, '='
         parse_untyped_var_declaration_or_reassignment

      elsif peek? StringToken or peek? NumberToken
         parse_string_or_number_literal

      elsif curr == DelimiterToken
         eat and nil # don't care about delimiters that weren't already handled by the other cases

      else
         ExprNode.new.tap do |node|
            node.token = eat
         end
      end
   end


   def parse until_token = EOFToken
      @statements = []
      @statements << parse_statements while tokens? and curr != until_token and curr != EOFToken
      @statements.compact
   end
end
