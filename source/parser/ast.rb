# :short_form, :string
class Ast
    attr_accessor :short_form, :string


    def initialize
        # @short_form = true
    end


    # curr == CommentToken, curr == '#', curr == '=', etc
    def == other
        other == self.class or self.is_a?(other)
    end
end


# { .. } is always a block, whether its a class body, function body, or just a block just in the middle of a bunch of statements using {}. I think a block in the middle that declares params should probably fail because nothing is calling the block, it's essentially just grouping code together/
class Block_Expr < Ast
    attr_accessor :name, :expressions, :compositions


    def initialize
        @expressions  = []
        @compositions = []
        @short_form   = true
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


    def to_s
        base = short_form ? '' : 'block'
        "#{base}".tap do |str|
            str << '{' unless short_form
            str << "comps(#{composition_expressions.count}): #{composition_expressions.map(&:to_s)}, " unless composition_expressions.empty?
            str << "exprs(#{non_composition_expressions.count}): #{non_composition_expressions.map(&:to_s)}" unless non_composition_expressions.empty?
            str << '}' unless short_form
        end
    end
end


class Function_Expr < Block_Expr
    # Block_Expr  :name, :expressions, :compositions
    attr_accessor :parameters


    def initialize
        super
        @parameters = []
        @short_form = false
    end


    def to_s
        base = short_form ? '' : 'fun'
        "#{base}{#{name}".tap do |str|
            str << " params(#{parameters.count}): #{parameters.map(&:to_s)}" unless parameters.empty?
            if not short_form
                str << ", comps(#{composition_expressions.count}): #{composition_expressions.map(&:to_s)}, " unless composition_expressions.empty?
                str << ", exprs(#{non_composition_expressions.count}): #{non_composition_expressions.map(&:to_s)}" unless non_composition_expressions.empty?
            end
            str << '}'
        end
    end
end


class Object_Expr < Ast
    attr_accessor :name, :block, :parent


    def compositions
        block.compositions
    end


    def to_s
        "obj{#{name}".tap do |str|
            str << " > #{parent}" if parent
            if not short_form
                str << ", " + block.to_s if block
            end
            str << '}'
        end
    end
end


class Number_Literal_Expr < Ast

    def initialize
        super
        @short_form = true
    end


    def number
        # @todo convert to number
        string
    end


    def to_s
        long  = "Num(#{string})"
        short = "#{string}"
        short_form ? short : long
    end


    # https://stackoverflow.com/a/18533211/1426880
    def string_to_float
        Float(string)
        i, f = string.to_i, string.to_f
        i == f ? i : f
    rescue ArgumentError
        self
    end


    def evaluate
        string_to_float
    end
end


class Symbol_Literal_Expr < Ast
    def to_s
        long  = "Sym(:#{string})"
        short = ":#{string}"
        short_form ? short : long
    end


    def evaluate
        ":#{string}"
    end
end


class String_Literal_Expr < Ast
    def to_s
        long  = "Str(#{string})"
        short = "#{string}"
        short_form ? short : long
    end


    def evaluate
        string
    end
end


class Array_Literal_Expr < Ast
    attr_accessor :values


    def initialize
        super
        @values = []
    end


    def to_s
        "[#{values.map(&:to_s).join(',')}]"
    end
end


# todo: make use of this eventually rather than putting just an array into the :expressions attribute that some classes declared
class Comma_Separated_Expr < Ast
    attr_accessor :expressions


    def initialize
        super
        @expressions = []
    end


    def to_s
        "comma_separated(".tap do |str|
            expressions.each_with_index do |expr, i|
                str << expr.expressions[0].to_s
                str << ', ' unless i == blocks.count - 1
            end
            str << ')'
        end
    end
end


class Function_Param_Expr < Ast
    attr_accessor :name, :label, :type, :default_value, :merge_scope


    def to_s
        "#{short_form ? '' : 'Param'}(".tap do |str|
            str << '&' if merge_scope
            str << "#{name}"
            str << "=#{default_value&.to_s || 'nil'}"
            str << ", type: #{type}" if type
            str << ", label: #{label}" if label
            str << ')'
        end
    end
end


class Function_Arg_Expr < Ast
    attr_accessor :expression, :label


    def to_s
        "#{short_form ? '' : 'Arg'}(".tap do |str|
            str << "label: #{label}, " if label
            str << expression.to_s
            str << ')'
        end
    end
end


class Function_Call_Expr < Ast
    attr_accessor :name, :arguments


    def initialize
        super
        @arguments = []
    end


    def to_s
        "#{short_form ? '' : 'fun_call'}(name: #{name}".tap do |str|
            str << ", #{arguments.map(&:to_s)}" if arguments
            str << ')'
        end
    end

end


class Assignment_Expr < Ast
    attr_accessor :name, :type, :expression


    def to_s
        "#{name}=#{expression || 'nil'}"
    end


    def evaluate
        expression&.evaluate
    end
end


class Unary_Expr < Ast
    require_relative '../lexer/tokens'
    attr_accessor :operator, :expression


    def initialize
        super
        @short_form = true
    end


    def to_s
        long  = "UE(#{operator}#{expression})"
        short = "(#{operator}#{expression})"
        short_form ? short : long
    end


    def evaluate
        case operator
            when '-'
                expression.evaluate * -1
            when '+'
                expression.evaluate * +1
            when '~'
                raise 'Dunno how to ~'
            when '!'
                not expression.evaluate
            else
                puts "what??? #{operator}"
                raise "Unary_Expr(#{operator.inspect}) not implemented"
        end
    end
end


class Subscript_Expr < Ast
    attr_accessor :left, :index_expression


    def to_s
        if index_expression
            "#{left}[#{index_expression}]"
        else
            "#{left}[nil]"
        end
    end
end


class Binary_Expr < Ast
    attr_accessor :operator, :left, :right


    def initialize
        super
        # @short_form = true
    end


    def to_s
        long  = "BE(#{left} '#{operator}' #{right}"
        short = "(#{left} #{operator} #{right}"
        str   = short_form ? short : long
        str   += ']' if operator == '['
        str   += ')'
        str
    end


    def evaluate
        if right.evaluate == nil or right.evaluate == 'nil'
            raise "BinaryExprNode trying to `#{operator}` with nil"
        end

        case operator
            when '+'
                left.evaluate + right.evaluate
            when '-'
                left.evaluate - right.evaluate
            when '*'
                left.evaluate * right.evaluate
            when '/'
                left.evaluate / right.evaluate
            when '%'
                left.evaluate % right.evaluate
            when '&&'
                left.evaluate && right.evaluate
            else
                raise "BinaryExprNode(#{operator.inspect}) not implemented"
        end
    end
end


class Identifier_Expr < Ast
    require_relative '../lexer/lexer'


    def initialize
        super
        # @short_form = true
    end


    def identifier
        string
    end


    def to_s
        short_form ? string : "id(#{string})"
    end
end


class Enum_Collection_Expr < Ast
    attr_accessor :name, :constants


    def initialize
        super
        @constants = []
    end


    def to_s
        if short_form
            "enum{#{name}, consts(#{constants.count})}"
        else
            "enum{#{name}, consts(#{constants.count}): #{constants.map(&:to_s)}"
        end
    end
end


class Enum_Constant_Expr < Ast
    attr_accessor :name, :value


    def to_s
        "#{name} = #{value || 'nil'}"
    end
end


class Composition_Expr < Identifier_Expr
    # the &ident operator. merges the scope of the ident into the current scope
    attr_accessor :operator, :identifier, :name


    def initialize
        super
        @short_form = false
    end


    def to_s
        if short_form
            "#{operator}#{identifier}#{name ? " = #{name}" : ''}"
        else
            "comp(#{operator}#{identifier}#{name ? " = #{name}" : ''})"
        end
    end
end


class Conditional_Expr < Ast
    attr_accessor :condition, :expr_when_true, :expr_when_false


    def to_s
        "if #{condition}".tap do |str|
            if expr_when_true
                str << " then #{expr_when_true.expressions.map(&:to_s)}"
            end
            if expr_when_false
                if expr_when_false.is_a? Conditional_Expr
                    str << " else #{expr_when_false.to_s}"
                else
                    str << " else #{expr_when_false.expressions.map(&:to_s)}"
                end
            end
        end
    end
end


class While_Expr < Ast
    attr_accessor :condition, :expr_when_true, :expr_when_false


    def to_s
        "while #{condition}".tap do |str|
            if expr_when_true
                str << " then #{expr_when_true.expressions.map(&:to_s)}"
            end
            if expr_when_false
                if expr_when_false.is_a? While_Expr
                    str << " else #{expr_when_false.to_s}"
                else
                    str << " else #{expr_when_false.expressions.map(&:to_s)}"
                end
            end
        end
    end
end
