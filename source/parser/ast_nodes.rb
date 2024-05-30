class AstNode
   attr_accessor :tokens


   def initialize
      @tokens = []
   end
end

class SelfDeclNode < AstNode
   attr_accessor :type, :compositions


   def initialize
      super
      @compositions = []
   end

   def to_s
      "SelfDecl(type: #{type}, comps: #{compositions})"
   end
end
