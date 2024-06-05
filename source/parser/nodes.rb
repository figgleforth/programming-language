class Ast_Node
    attr_accessor :short_form


    def initialize
        @short_form = false
    end


    def == other
        other == self.class
    end


    def evaluate
        puts "Trying to evaluate self #{self}"
        raise NotImplementedError
    end
end


class StringLiteralNode < Ast_Node
    attr_accessor :token


    def to_s
        "Str(#{token.string})"
    end


    def evaluate
        token.string
    end
end


class NumberLiteralNode < Ast_Node
    attr_accessor :token


    def number
        # @todo convert to number
        token&.string
    end


    def to_s
        # "Num(#{token.string})"
        token.string
    end


    # https://stackoverflow.com/a/18533211/1426880
    def string_to_float
        Float(token.string)
        i, f = token.string.to_i, token.string.to_f
        i == f ? i : f
    rescue ArgumentError
        self
    end


    def evaluate
        string_to_float
    end
end


class ObjectDeclNode < Ast_Node
    attr_accessor :type, :base_type, :compositions, :statements, :is_top_level


    def initialize
        super
        @compositions = []
        @statements   = []
        @is_top_level = false
    end


    def to_s
        # "Obj(#{type.string}, base: #{base_type&.string}, comps: #{compositions.map(&:string)}, stmts(#{statements.count}): #{statements.map(&:to_s)})"

        "Obj(#{type.string}".tap do |str|
            str << ", base: #{base_type.string}" if base_type
            str << ", comps(#{compositions.count}): #{compositions.map(&:to_s)}" unless compositions.empty?
            str << ", stmts(#{statements.count}): #{statements.map(&:to_s)}" unless statements.empty?
            str << ')'
        end
    end
end


class FuncDeclNode < Ast_Node
    attr_accessor :name, :return_type, :parameters, :statements


    def initialize
        super
        @parameters = []
        @statements = []
    end


    def to_s
        # "Method(#{name}, return_type: #{return_type.to_s}, params(#{parameters.count}): #{parameters.map(&:to_s)}), stmts(#{statements.count}): #{statements.map(&:to_s)})"
        "Func(#{name}".tap do |str|
            str << ", returns: #{return_type}" if return_type
            str << ", params(#{parameters.count}): #{parameters.map(&:to_s)}" unless parameters.empty?
            str << ", stmts(#{statements.count}): #{statements.map(&:to_s)}" unless statements.empty?
            str << ')'
        end
    end
end


class FuncParamNode < Ast_Node
    attr_accessor :name, :label, :type


    def to_s
        "Param(name: #{name}".tap do |str|
            str << ", type: #{type}" if type
            str << ", label: #{label}" if label
            str << ')'
        end
    end
end


class FuncArgNode < Ast_Node
    attr_accessor :expression, :label


    def to_s
        "#{short_form ? '' : 'Arg'}(#{expression.to_s}".tap do |str|
            str << ", label: #{label}" if label
            str << ')'
        end
    end
end


class FuncCallNode < Ast_Node
    attr_accessor :function_name, :arguments


    def initialize
        super
        @arguments = []
    end


    def to_s
        "#{short_form ? '' : 'FuncCall'}(name: #{function_name}".tap do |str|
            str << ", args(#{arguments.count}): #{arguments.map(&:to_s)}" unless arguments.empty?
            str << ')'
        end
    end
end


class VarAssignmentNode < Ast_Node
    attr_accessor :name, :type, :value


    def to_s
        "#{short_form ? '' : 'Var'}(#{name.string}".tap do |str|
            if type
                str << ": #{type.string}"
            end

            str << " = #{value ? value : value.inspect}"

            str << ")"
        end
    end


    def evaluate
        value&.evaluate
    end
end


class UnaryExprNode < Ast_Node
    require_relative '../lexer/tokens'
    attr_accessor :operator, :operand


    def to_s
        long  = "UE(#{operator.string}#{operand})"
        short = "(#{operator.string}#{operand})"
        short_form ? short : long
    end


    def evaluate
        case operator.string
            when '-'
                operand.evaluate * -1
            when '+'
                operand.evaluate * +1
            when '~'
                raise 'Dunno how to ~'
            when '!'
                not operand.evaluate
            else
                puts "what??? #{operator}"
                raise "UnaryExprNode(#{operator.string.inspect}) not implemented"
        end
    end
end


class BinaryExprNode < Ast_Node
    attr_accessor :operator, :left, :right


    def to_s
        long  = "BE(#{left} #{operator.string} #{right})"
        short = "(#{left} #{operator.string} #{right})"
        short_form ? short : long
    end


    def evaluate
        if right.evaluate == nil or right.evaluate == 'nil'
            raise "BinaryExprNode trying to `#{operator.string}` with nil"
        end

        case operator.string
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
                raise "BinaryExprNode(#{operator.string.inspect}) not implemented"
        end
    end
end


class IdentExprNode < Ast_Node
    require_relative '../lexer/lexer'
    attr_accessor :name


    def to_s
        short_form ? "#{name}" : "IdentExpr(#{name})"
    end


    def evaluate
        if Lexer::KEYWORDS.include? name
            return nil if name == 'nil'
            return true if name == 'true'
            return false if name == 'false'
        else
            name
        end
    end
end
