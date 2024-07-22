# :short_form, :string
class Expr
    attr_accessor :short_form, :string, :tokens


    def tokens
        @tokens ||= []
    end


    # curr == CommentToken, curr == '#', curr == '=', etc
    def == other
        other == self.class or self.is_a?(other)
    end


    def === other
        other == self.class or self.is_a?(other)
    end
end


# { .. } is always a block, whether its a class body, function body, or just a block just in the middle of a bunch of statements using {}. I think a block in the middle that declares params should probably fail because nothing is calling the block, it's essentially just grouping code together/
class Block_Expr < Expr
    attr_accessor :name, :expressions, :compositions, :parameters, :signature, :is_operator_overload


    def initialize
        @parameters   = []
        @expressions  = []
        @compositions = []
        @short_form   = true
    end


    def before_hook_expressions # any expressions that are `@before some_function`
        expressions.select do |s|
            s.is_a? Block_Hook_Expr
        end
    end


    def non_composition_expressions
        expressions.select do |s|
            s != Composition_Expr
        end
    end


    def composition_expressions
        expressions.select do |s|
            s == Composition_Expr
        end
    end


    def named?
        not name.nil?
    end


    def signature # to support multiple methods with the same name, each method needs to be able to be represented as a signature. Naive idea: name+block.parameters.names.join(,)
        @signature ||= "#{name}".tap do |it|
            parameters.each do |param|
                # it: Function_Param_Expr
                # maybe also use compositions in the signature for better control over signature equality
                it << "#{param.label}:#{param.name}=#{param.default_expression}"
            end
        end
    end


    def pretty
        base = short_form ? '' : 'block'
        "#{base}".tap do |str|
            str << '{' unless short_form
            str << "params(#{parameters.count}): #{parameters.map(&:pretty)}, " unless parameters.empty?
            str << "comps(#{composition_expressions.count}): #{composition_expressions.map(&:pretty)}, " unless composition_expressions.empty?
            str << "exprs(#{non_composition_expressions.count}): #{non_composition_expressions.map(&:pretty)}" unless non_composition_expressions.empty?
            str << '}' unless short_form
        end
    end
end


class Block_Param_Decl_Expr < Expr
    attr_accessor :name, :label, :type, :default_expression, :composition


    def initialize
        super
        @composition        = false
        @default_expression = nil
        @name               = nil
        @label              = nil
        @type               = nil
    end


    def pretty
        "#{short_form ? '' : 'Param'}(".tap do |str|
            str << '&' if composition
            str << "#{name}"
            str << "=#{default_expression&.pretty || 'nil'}"
            str << ", type: #{type}" if type
            str << ", label: #{label}" if label
            str << ')'
        end
    end
end


class Block_Arg_Expr < Expr
    attr_accessor :expression, :label


    def pretty
        "#{short_form ? '' : 'Arg'}(".tap do |str|
            str << "label: #{label}, " if label
            str << expression.to_s
            str << ')'
        end
    end
end


class Block_Call_Expr < Expr
    attr_accessor :name, :arguments


    def initialize
        super
        @arguments = []
    end


    def pretty
        "#{short_form ? '' : 'fun_call'}(name: #{name}".tap do |str|
            str << ", #{arguments.map(&:pretty)}" if arguments
            str << ')'
        end
    end

end


class Class_Expr < Expr
    attr_accessor :name, :block, :base_class, :compositions


    def initialize
        super
        @compositions = []
    end


    def pretty
        "obj{#{name}".tap do |str|
            str << " > #{base_class}" if base_class
            if not short_form
                str << ", " + block.to_s if block
            end
            str << '}'
        end
    end
end


class Number_Literal_Expr < Expr
    attr_accessor :type, :decimal_position


    def initialize
        super
        @short_form = true
    end


    def string= val
        @string = val
        if val[0] == '.'
            @type             = :float
            @decimal_position = :start
        elsif val[-1] == '.'
            @type             = :float
            @decimal_position = :end
        elsif val&.include? '.'
            @type             = :float
            @decimal_position = :middle
        else
            @type = :int
        end
    end


    def pretty
        long  = "Num(#{string})"
        short = "#{string}"
        short_form ? short : long
    end


    # Useful reading
    # https://stackoverflow.com/a/18533211/1426880
    # https://stackoverflow.com/a/1235891/1426880
end


class Symbol_Literal_Expr < Expr
    def pretty
        long  = "Sym(:#{string})"
        short = ":#{string}"
        short_form ? short : long
    end


    def to_symbol
        ":#{string}"
    end
end


class Boolean_Literal_Expr < Expr
    def pretty
        long  = "Bool(:#{string})"
        short = ":#{string}"
        short_form ? short : long
    end


    def to_bool
        return true if string == "true"
        return false if string == "false"
        raise "Boolean_Literal_Expr should be either true or false, but is #{string.inspect}"
    end
end


class String_Literal_Expr < Expr
    attr_accessor :interpolated


    def string= val
        @string       = val
        @interpolated = val.include? '`' # todo: is there a better way?
    end


    def to_string
        "\"#{string}\""
    end


    def pretty
        long  = "Str(#{string})"
        short = "#{string}"
        short_form ? short : long
    end
end


class Dictionary_Literal_Expr < Expr
    attr_accessor :keys, :values


    def initialize
        super
        @keys   = []
        @values = []
    end


    def pretty
        "Dictionary(keys: #{@keys.join(',')}, values: #{@values.join(',')})"
    end
end


class Array_Literal_Expr < Expr
    attr_accessor :elements


    def initialize
        super
        @elements = []
    end


    def pretty
        "[#{elements.map(&:to_s).join(',')}]"
    end
end


class Comma_Separated_Expr < Expr
    attr_accessor :expressions


    def initialize
        super
        @expressions = []
    end


    def pretty
        "comma_separated(".tap do |str|
            expressions.each_with_index do |expr, i|
                str << expr.expressions[0].to_s
                str << ', ' unless i == blocks.count - 1
            end
            str << ')'
        end
    end
end


class Assignment_Expr < Expr
    attr_accessor :name, :type, :expression


    def pretty
        "#{name}=#{expression&.pretty || 'nil'}"
    end


    def == other
        other.is_a?(Assignment_Expr) and name == other.name and expression == other.expression
    end
end


class Unary_Expr < Expr
    require_relative '../lexer/tokens'
    attr_accessor :operator, :expression


    def initialize
        super
        @short_form = true
    end


    def pretty
        long  = "UE(#{operator}#{expression})"
        short = "(#{operator}#{expression})"
        short_form ? short : long
    end
end


class Subscript_Expr < Expr
    attr_accessor :left, :index_expression


    def pretty
        if index_expression
            "#{left}[#{index_expression}]"
        else
            "#{left}[nil]"
        end
    end
end


class Binary_Expr < Expr
    attr_accessor :operator, :left, :right


    def initialize
        super
        # @short_form = true
    end


    def pretty
        long  = "BE(#{left} '#{operator}' #{right}"
        short = "(#{left} #{operator} #{right}"
        str   = short_form ? short : long
        str   += ']' if operator == '['
        str   += ')'
        str
    end
end


class Identifier_Expr < Expr
    attr_accessor :is_keyword


    def identifier
        string
    end


    def constant? # all upper, LIKE_THIS
        test = string&.gsub('_', '')&.gsub('&', '')
        test&.chars&.all? { |c| c.upcase == c }
    end


    def class? # capitalized, Like_This or This
        test = string&.gsub('_', '')&.gsub('&', '')
        test[0]&.upcase == test[0] and not constant?
    end


    def member? # all lower, some_method or some_variable
        test = string&.gsub('_', '')&.gsub('&', '')
        test&.chars&.all? { |c| c.downcase == c }
    end


    def == other
        other.is_a?(Identifier_Expr) and other.string == string
    end


    def pretty
        short_form ? string : "id(#{string})"
    end
end


class Enum_Collection_Expr < Expr
    attr_accessor :name, :constants


    def initialize
        super
        @constants = []
    end


    def pretty
        if short_form
            "enum{#{name}, consts(#{constants.count})}"
        else
            "enum{#{name}, consts(#{constants.count}): #{constants.map(&:pretty)}"
        end
    end
end


class Enum_Constant_Expr < Expr
    attr_accessor :name, :value


    def pretty
        "#{name} = #{value || 'nil'}"
    end
end


class At_Operator_Expr < Expr
    attr_accessor :identifier, :expression


    def pretty
        identifier
    end
end


class Block_Hook_Expr < At_Operator_Expr
    attr_accessor :target_function_identifier
end


class Composition_Expr < Identifier_Expr
    attr_accessor :operator, :identifier, :alias_identifier


    def initialize
        super
        @short_form = false
    end


    def pretty
        if short_form
            "#{operator}#{identifier}#{alias_identifier ? " = #{alias_identifier}" : ''}"
        else
            "comp(#{operator}#{identifier}#{alias_identifier ? " = #{alias_identifier}" : ''})"
        end
    end
end


class Conditional_Expr < Expr
    attr_accessor :condition, :when_true, :when_false


    def pretty
        "if #{condition}".tap do |str|
            if when_true
                str << " then #{when_true.expressions.map(&:pretty)}"
            end
            if when_false
                if when_false.is_a? Conditional_Expr
                    str << " else #{when_false.to_s}"
                else
                    str << " else #{when_false.expressions.map(&:pretty)}"
                end
            end
        end
    end
end


class While_Expr < Expr
    attr_accessor :condition, :when_true, :when_false


    def pretty
        "while #{condition}".tap do |str|
            if when_true
                str << " then #{when_true.expressions.map(&:pretty)}"
            end
            if when_false
                if when_false.is_a? While_Expr
                    str << " else #{when_false.to_s}"
                else
                    str << " else #{when_false.expressions.map(&:pretty)}"
                end
            end
        end
    end
end


class Macro_Expr < Expr
    attr_accessor :name, # %s, %S, %v, %V, etc
                  :identifiers # the body between the parens

    def initialize
        super
        @identifiers = []
    end


    def pretty
        "#{name}(#{identifiers.join(' ')})"
    end
end


class Macro_Command_Expr < Macro_Expr
    attr_accessor :name,
                  :expression
end


class Nil_Expr < Expr
end
