class Construct
end


class Variable_Construct < Construct
    attr_accessor :name, :expression
end


class Method_Construct < Construct
    attr_accessor :name, :expressions
end


class Class_Construct < Construct
    attr_accessor :name
end


class Nil_Construct < Construct
end
