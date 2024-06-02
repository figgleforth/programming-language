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
      "Str(#{token.string})"
   end
end


class NumberLiteralNode < LiteralNode
   attr_accessor :token


   def number
      # todo: convert to number
      token&.string
   end


   def to_s
      # token.string
      "Num(#{token.string})"
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
      # "Obj(#{type.string}, base: #{base_type&.string}, comps: #{compositions.map(&:string)}, stmts(#{statements.count}): #{statements.map(&:to_s)})"

      "Obj(#{type.string}".tap do |str|
         str << ", base: #{base_type.string}" if base_type
         str << ", comps(#{compositions.count}): #{compositions.map(&:to_s)}" unless compositions.empty?
         str << ", stmts(#{statements.count}): #{statements.map(&:to_s)}" unless statements.empty?
         str << ')'
      end
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
      # "Method(#{name}, return_type: #{return_type.to_s}, params(#{parameters.count}): #{parameters.map(&:to_s)}), stmts(#{statements.count}): #{statements.map(&:to_s)})"
      "Method(#{name}".tap do |str|
         str << ", returns: #{return_type}" if return_type
         str << ", params(#{parameters.count}): #{parameters.map(&:to_s)}" unless parameters.empty?
         str << ", stmts(#{statements.count}): #{statements.map(&:to_s)}" unless statements.empty?
         str << ')'
      end
   end
end

class MethodParamNode < AstNode
   attr_accessor :name, :label, :type


   def to_s
      "Param(#{name}".tap do |str|
         str << ", type: #{type}" if type
         str << ", label: #{label}" if label
         str << ')'
      end
   end
end


class VarAssignmentNode < AstNode
   attr_accessor :name, :type, :value

   def to_s
      "Var(#{name.string}".tap do |str|
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
      "UE(#{operator.string} #{operand})"
   end
end


class BinaryExprNode < AstNode
   attr_accessor :operator, :left, :right


   def to_s
      "BE(#{left} #{operator.string} #{right})"
   end
end

class IdentifierNode < AstNode
   attr_accessor :name

   def to_s
      "Ident(#{name})"
   end
end


class ExprNode < AstNode
   attr_accessor :token


   def to_s
      "Expr(#{token.string.inspect})"
   end
end
