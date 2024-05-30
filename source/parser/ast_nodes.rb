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
      "StringLit(#{token.string})"
   end
end

class NumberLiteralNode < LiteralNode
   attr_accessor :token

   def number
      # todo: convert to number
      token&.string
   end

   def to_s
      "NumberLit(#{token.string.inspect})"
   end
end


class SelfDeclNode < AstNode
   attr_accessor :type, :compositions


   def initialize
      super
      @compositions = []
   end


   def to_s
      "SelfDecl(#{type.string}, comps: #{compositions.map(&:string)})"
   end
end


class VarAssignmentNode < AstNode
   attr_accessor :name, :type, :value


   def to_s
      "VarAssign(#{name.string}".tap do |str|
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
