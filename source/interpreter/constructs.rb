class Construct
end


class Variable_Construct < Construct
    attr_accessor :name, :expression, :result, :is_constant
    # @expression could be a Block_Expr or any other Ast
end


class Function_Construct < Construct
    attr_accessor :name, :block, :signature
end


class Class_Construct < Construct
    attr_accessor :name, :block, :base_class, :compositions
end

