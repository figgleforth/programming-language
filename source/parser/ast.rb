class Ast
    attr_accessor :token


    def to_s
        "Ast"
    end


    # token == CommentToken
    # token == '#'
    def == other
        other == self.class or self.is_a?(other)
    end
end


class Program < Ast
    attr_accessor :expressions


    def initialize
        @expressions = []
    end


    def to_s
        ''.tap do |program|
            expressions.each do |expr|
                program << "#{expr}\n\n"
            end
        end
    end
end


class Ast_Expression < Ast
    attr_accessor :short_form,
                  :inferred_type


    def initialize
        # @short_form = true
        @short_form = false
    end


    def == other
        other == self.class
    end


    def evaluate
        puts "UNHANDLED EVALUATE\n\t#{self.inspect}\n\n"
        self
    end
end


class SymbolExpr < Ast_Expression
    def to_s
        long  = "Sym(:#{token.string})"
        short = ":#{token.string}"
        short_form ? short : long
    end


    def evaluate
        ":#{token.string}"
    end
end


class StringExpr < Ast_Expression
    def to_s
        long  = "Str(#{inspect})"
        short = "#{token.string}"
        short_form ? short : long
    end


    def evaluate
        token.string
    end
end


class NumberExpr < Ast_Expression
    def number
        # @todo convert to number
        token.string
    end


    def to_s
        long  = "Num(#{token.string})"
        short = "#{token.string}"
        short_form ? short : long
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


class ObjectExpr < Ast_Expression
    attr_accessor :type, :compositions, :statements


    def initialize
        super
        @type         = nil
        @compositions = []
        @statements   = []
    end


    def to_s
        (short_form ? "#{type}(" : ":> #{type}(").tap do |str|
            str << "comps(#{compositions.count}): #{compositions.map(&:to_s)}, " unless compositions.empty?
            str << "exprs(#{statements.count}): #{statements.map(&:to_s)}" unless statements.empty?
            str << ')'
        end
    end
end


class FunctionExpr < Ast_Expression
    attr_accessor :name, :return_type, :parameters, :statements, :ambiguous_params_or_return


    def initialize
        super
        @parameters                 = []
        @statements                 = []
        @short_form                 = true
        @ambiguous_params_or_return = false
    end


    def to_s
        short = ":: #{name}(".tap do |str|
            if ambiguous_params_or_return
                str << "params/return: #{return_type}"
            else
                str << "return: #{return_type || 'nil'}"
                str << ", params(#{parameters.count}): #{parameters.map(&:to_s)}" unless parameters.empty?
            end

            str << ", stmts(#{statements.count}): #{statements.map(&:to_s)}" unless statements.empty?
            str << ')'
        end

        short_form ? short : inspect
    end
end


class CommaSeparatedExpr < Ast_Expression
    attr_accessor :expressions,
                  :count


    def expressions= val
        @expressions = val
        @count       = val.count
    end
end


class FunctionParamExpr < Ast_Expression
    attr_accessor :name, :label, :type


    def to_s
        "#{short_form ? '' : 'Param'}(name: #{name}".tap do |str|
            str << ", type: #{type}" if type
            str << ", label: #{label}" if label
            str << ')'
        end
    end
end


class FunctionArgExpr < Ast_Expression
    attr_accessor :expression, :label


    def to_s
        "#{short_form ? '' : 'Arg'}(#{expression.to_s}".tap do |str|
            str << ", label: #{label}" if label
            str << ')'
        end
    end
end


class FunctionCallExpr < Ast_Expression
    attr_accessor :function_name, :arguments


    def initialize
        super
        @arguments = []
    end


    def to_s
        "#{short_form ? '' : 'FunCall'}(name: #{function_name}".tap do |str|
            str << ", args(#{arguments.count}): #{arguments.map(&:to_s)}" unless arguments.empty?
            str << ')'
        end
    end

end


class AssignmentExpr < Ast_Expression
    attr_accessor :name, :type, :expression


    def to_s
        "@#{name.string}".tap do |str|
            if type
                str << ": #{type.string}"
            end

            str << " = #{expression ? expression : expression.inspect}"
        end
    end


    def evaluate
        expression&.evaluate
    end
end


class UnaryExpr < Ast_Expression
    require_relative '../lexer/tokens'
    attr_accessor :operator, :expression


    def to_s
        long  = "UE(#{operator.string}#{expression})"
        short = "(#{operator.string}#{expression})"
        short_form ? short : long
    end


    def evaluate
        case operator.string
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
                raise "UnaryExpr(#{operator.string.inspect}) not implemented"
        end
    end
end


class BinaryExpr < Ast_Expression
    attr_accessor :operator, :left, :right


    def to_s
        long  = "BE(#{left} #{operator.string} #{right})"
        short = "(#{left}#{operator.string}#{right})"
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


class IdentifierExpr < Ast_Expression
    require_relative '../lexer/lexer'

    def identifier
        token.string
    end


    def to_s
        short_form ? token.string : "Ident(#{token.string})"
    end


    def evaluate
        if Lexer::KEYWORDS.include? token.string
            return nil if token.string == 'nil'
            return true if token.string == 'true'
            return false if token.string == 'false'
        else
            token.string
        end
    end
end
