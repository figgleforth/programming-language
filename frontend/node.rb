class HatchObject
    attr_accessor :filename, :statements, :variables, :functions, :objects, :name, :explicitly_declared

    # infers the name of the program from the filename. ex: file_name.rb => File_Name, the reason for the underscore is to prevent naming collisions and to not hog identifiers for automated things like this.
    def initialize(filename, children = [])
        @filename            = filename
        @statements          = children
        @variables           = []
        @functions = []
        @objects             = []
        @name                = filename
        @explicitly_declared = false
    end

    def convert_file_name_to_name_of_object!
        @name = @name.split('/').last.split('.').first.gsub(/(?:^|_)([a-z])/) { |match| match.upcase } # eg) file_name to File_Name
    end

    def inspect
        type = explicitly_declared ? 'Explicit' : 'Inferred'
        str = "#{type}HatchObject(#{name})" + "\n\tVariables: #{variables.map(&:inspect).inspect}\n\tFunctions: #{functions.map(&:inspect).inspect}\n\tObjects: #{objects.map(&:inspect).inspect}\n\tStatements:\n\t\t#{statements.map(&:inspect).join("\n\t\t")}"
    end
end

class Compositions
    attr_accessor :compositions

    def initialize(compositions = [])
        @compositions = compositions
    end

    def inspect
        str   = ""
        comps = compositions.map(&:inspect).join(', ').gsub('"', '')
        str   += "Compositions[#{comps}]"
    end
end

class MethodDeclaration
    attr_accessor :token, :keyword # def, new
    attr_accessor :parameters, :statements, :returns

    def initialize(token, keyword = :def, parameters = [])
        @token      = token
        @keyword    = keyword
        @parameters = parameters
    end

    def inspect
        str = "MethodDeclaration(#{token.inspect} ;; Returns(#{returns&.inspect}) ;; Parameters[#{parameters.map(&:inspect).join(" +|+ ")}] ;; Statements[#{statements.map(&:inspect).join(" ;; ")}]"
    end
end

class Call
    attr_accessor :name, :parameters

    def initialize(name, parameters = [])
        @name       = name
        @parameters = parameters
    end

    def inspect
        params = parameters.map(&:inspect).join(', ')
        return "Call(#{name} with Parameters[#{params})]" unless params.empty?
        "Call(#{name})"
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

class VariableReference
    attr_accessor :name

    def initialize(name)
        @name = name
    end

    def inspect
        "VariableRef(#{name})"
    end
end

class BinaryExpression
    attr_accessor :binary_operator, :left, :right

    def initialize(operator, left, right)
        @binary_operator = operator
        @left            = left
        @right           = right
    end

    def inspect
        "BinaryExpression(#{left.inspect} #{binary_operator} #{right.inspect})"
    end
end

class Value
    attr_accessor :token, :type # :variable, :method

    def initialize(token, type = :variable)
        @token = token
        @type  = type
    end

    def inspect
        if type == :variable
            "Variable(#{token.word})"
        else
            "Method(#{token.word})"
        end
    end
end

class Param
    attr_accessor :name, :type, :label

    def initialize(name: nil, type: nil, label: nil)
        @name  = name
        @type  = type
        @label = label
    end

    def inspect
        prefix = label.nil? ? '' : "#{label.inspect}"
        "Param(label(#{prefix.inspect}), name(#{name.inspect}), type(#{type.inspect}))"
    end
end

class Composition
    attr_accessor :name

    def initialize(name)
        @name = name
    end

    def inspect
        "Composition(#{name})"
    end
end
