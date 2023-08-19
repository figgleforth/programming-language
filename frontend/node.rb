class Program
    attr_accessor :filename, :statements, :name

    # infers the name of the program from the filename. ex: file_name.rb => File_Name, the reason for the underscore is to prevent naming collisions and to not hog identifiers for automated things like this.
    def initialize(filename, children = [])
        @filename   = filename
        @statements = children
        @name       = filename.split('/').last.split('.').first.gsub(/(?:^|_)([a-z])/) { |match| match.upcase } # converts file_name to File_Name
    end

    def inspect
        str = "Program(#{name})"
        str += "\n\t" + statements.map(&:inspect).join("\n\t")
    end
end

class ObjectDeclaration
    attr_accessor :name, :compositions, :type

    def initialize(name, type = :object, compositions = [])
        @name         = name
        @compositions = compositions
        @type         = type
    end

    def inspect
        str   = "Object(#{type}(#{name}))"
        comps = compositions.map(&:inspect).join(', ').gsub('"', '')
        str   += "\n\t\tCompositions(#{comps})"
    end
end

class ProcedureDeclaration
    attr_accessor :name, :keyword # def, new
    attr_accessor :parameters, :statements

    def initialize(name, keyword = :def, parameters = [])
        @name       = name
        @keyword    = keyword
        @parameters = parameters
    end

    def inspect
        str = "Procedure(#{name})"
        str += "\n\t\tParameters(#{parameters.map(&:inspect).join(', ')})"
    end
end

class VariableDeclaration
    attr_accessor :name, :type, :value
    attr_accessor :visibility

    def initialize(name, type = nil, value = nil, visibility = :public)
        @name       = name
        @type       = type
        @value      = value
        @visibility = visibility
    end

    def inspect
        "Variable(#{name}: #{type} = #{value.inspect})"
    end

    def inferred?
        value.nil?
    end
end

class BinaryExpression
    attr_accessor :binary_operator, :left, :right

    def initialize(operator, left, right)
        @binary_operator = operator
        @left     = left
        @right    = right
    end

    def inspect
        "BinaryExpression(#{left.inspect} #{binary_operator} #{right.inspect})"
    end
end

class Literal
    attr_accessor :value

    def initialize(value)
        @value = value
    end

    def inspect
        "Literal(#{value.inspect})"
    end
end
