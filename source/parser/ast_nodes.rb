class AstNode
   attr_accessor :tokens


   def initialize
      @tokens = []
   end
end


class LiteralNode < AstNode
end


class StringLiteralNode < LiteralNode
   attr_accessor :token


   def string
      token
   end


   def to_s
      "STR(#{token.string})"
   end
end


class NumberLiteralNode < LiteralNode
   attr_accessor :token


   def number
      # todo: convert to number
      token&.string
   end


   def to_s
      # "NUM(#{token.string})"
      token.string
   end
end


class SelfDeclNode < AstNode
   attr_accessor :type, :compositions


   def initialize
      super
      @compositions = []
   end


   def to_s
      "SELF(#{type.string}, comps: #{compositions.map(&:string)})"
   end
end


class VarAssignmentNode < AstNode
   attr_accessor :name, :type, :value


   def to_s
      "VAR(#{name.string}".tap do |str|
         if type
            str << ": #{type.string}"
         end

         if value
            str << " = #{value}"
         end

         str << ")"
      end
   end
end


class UnaryExprNode < AstNode
   attr_accessor :operator, :operand

   def to_s
      "(#{operator.string} #{operand})"
   end
end

class BinaryExprNode < AstNode
   attr_accessor :operator, :left, :right

   def to_s
      "(#{left} #{operator.string} #{right})"
   end
end

class ExprNode < AstNode
   attr_accessor :token

   def to_s
      "Expr(#{token.string})"
   end
end
