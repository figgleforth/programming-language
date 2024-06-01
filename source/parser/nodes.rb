class AstNode
   attr_accessor :tokens


   def initialize
      @tokens = []
   end


   def == other
      other == self.class
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


class ObjectDeclNode < AstNode
   attr_accessor :type, :base_type, :compositions, :statements, :is_top_level


   def initialize
      super
      @compositions          = []
      @statements            = []
      @is_top_level = false
   end


   def to_s
      "Obj(#{type.string}, base: #{base_type&.string}, comps: #{compositions.map(&:string)}, stmts(#{statements.count}): #{statements.map(&:to_s)})"
   end
end


class MethodDeclNode < AstNode
   attr_accessor :name, :return_type, :parameters, :statements


   def initialize
      super
      @parameters = []
      @statements = []
   end


   def to_s
      "Method(#{name}, return_type: #{return_type}, params(#{parameters.count}): #{parameters.map(&:string)}), stmts(#{statements.count}): #{statements.map(&:to_s)})"
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
      "UNKNOWN(#{token.string.inspect})"
   end
end
