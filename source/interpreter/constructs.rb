class Construct
end


class Variable_Construct < Construct
    attr_accessor :name, :expression, :value, :is_constant
end


class Method_Construct < Construct
    attr_accessor :name, :block
end


class Class_Construct < Construct
    attr_accessor :name, :block, :base_class, :compositions
end

