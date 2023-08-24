class SelfDeclaration
    attr_accessor :name, :compositions

    def initialize(name, compositions = [])
        @name = name
        @compositions = compositions
    end

    def inspect
        "Self{#{name} + #{compositions.compositions.join(',')}}"
    end

    def to_s
    end
end

class ObjectDeclaration
    attr_accessor :name, :filename, :statements, :variables, :functions, :objects, :name, :explicitly_declared, :compositions

    # infers the name of the program from the filename. ex: file_name.rb => File_Name, the reason for the underscore is to prevent naming collisions and to not hog identifiers for automated things like this.
    def initialize()
        @name = 'Unnamed Object'
        @statements = []
        @variables = []
        @functions = []
        @objects = []
        @compositions = []
        @name = name
        @explicitly_declared = true
    end

    def filename=(fn)
        @filename = fn
        convert_file_name_to_name_of_object!
    end

    def convert_file_name_to_name_of_object!
        return unless @filename
        @explicitly_declared = false
        @name = @filename.split('/').last.split('.').first.gsub(/(?:^|_)([a-z])/) { |match| match.upcase } # eg) file_name to File_Name
    end

    def inspect
        "Object{#{name}, statements[#{statements.map(&:inspect).join(" ;; ")}]}"
    end
end

class Compositions
    attr_accessor :compositions

    def initialize(compositions = [])
        @compositions = compositions
    end

    # def inspect
    #     str = ""
    #     comps = compositions.map(&:inspect).join(', ').gsub('"', '')
    #     str += "[#{comps}]"
    # end
end

class MethodDeclaration
    attr_accessor :token, :keyword # def, new
    attr_accessor :parameters, :statements, :returns

    def initialize(token, keyword = :def, parameters = [])
        @token = token
        @keyword = keyword
        @parameters = parameters
    end

    def inspect
        "Method{#{token.inspect} ;; returns(#{returns&.inspect}) ;; params[#{parameters.map(&:inspect).join(',')}] ;; statements[#{statements.map(&:inspect).join(" ;; ")}]}"
    end
end

class Call
    attr_accessor :name, :parameters

    def initialize(name, parameters = [])
        @name = name
        @parameters = parameters
    end

    def inspect
        params = parameters.map(&:inspect).join(', ')
        return "Call(#{name} with Parameters[#{params})]" unless params.empty?
        "Call::(#{name})"
    end
end

class VariableDeclaration
    attr_accessor :token, :type, :value
    attr_accessor :visibility

    def initialize(token, type = nil, value = nil, visibility = :public)
        @token = token
        @type = type
        @value = value
        @visibility = visibility
    end

    def inspect
        "Variable{#{token.word}: #{type} = #{value.inspect}}"
    end

    def inferred?
        value.nil?
    end
end

class VariableReference
    attr_accessor :token

    def initialize(token)
        @token = token
    end

    def inspect
        "VariableRef::(#{token.inspect})"
    end
end

class BinaryExpression
    attr_accessor :binary_operator, :left, :right

    def initialize(operator, left, right)
        @binary_operator = operator
        @left = left
        @right = right
    end

    def inspect
        "BinaryExpr{#{left.inspect} #{binary_operator} #{right.inspect}}"
    end
end

class Literal
    attr_accessor :token, :type # :variable, :method

    def initialize(token, type = :variable)
        @token = token
        @type = type
    end

    def inspect
        if type == :variable
            "Literal(#{token.word})"
        else
            "MethodLiteral(#{token.word})"
        end
    end
end

class Param
    attr_accessor :name_token, :type, :label, :default_value

    def initialize(name_token: nil, type: nil, label: nil)
        @name_token = name_token
        @type = type
        @label = label
    end

    def inspect
        prefix = label.nil? ? '' : "#{label.word}"
        "Param{label(#{prefix}), name(#{name_token.word}), type(#{type.word}), default(#{default_value&.inspect})}"
    end
end

class Composition
    attr_accessor :name

    def initialize(name)
        @name = name
    end

    def inspect
        "Comp(#{name})"
    end
end
