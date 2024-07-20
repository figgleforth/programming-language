class Construct
end


class Variable_Construct < Construct
    attr_accessor :name, :expression, :interpreted_value, :is_constant
    # @expression could be a Block_Expr or any other Ast
end


class Block_Construct < Construct
    attr_accessor :name, :block, :signature
end


class Class_Construct < Construct
    attr_accessor :name, :block, :base_class, :compositions
    # block is a Block_Expr representing the AST of the class's body
    # base_class is a string identifier representing the base class
end


class Instance_Construct < Construct
    attr_accessor :scope, :class_construct
    # todo: don't store the class_construct here. It's already stored in the scope under :classes, so just look it up when needed
end


class Range_Construct < Construct
    attr_accessor :left, :operator, :right
end


class Nil_Construct < Construct
    attr_accessor :expression
end
