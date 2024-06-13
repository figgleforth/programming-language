class Ast
    attr_accessor :token, :string


    def to_s
        "Ast"
    end


    # token == CommentToken
    # token == '#'
    def == other
        other == self.class or self.is_a?(other)
    end
end


class Ast_Block < Ast
    attr_accessor :expressions, :merge_scopes


    def initialize
        @expressions  = []
        @merge_scopes = []
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
        @short_form = true
        # @short_form = false
    end


    def == other
        other == self.class
    end


    def evaluate
        puts "UNHANDLED EVALUATE\n\t#{self.inspect}\n\n"
        self
    end
end


class Symbol_Literal_Expr < Ast_Expression
    def to_s
        long  = "Sym(:#{token.string})"
        short = ":#{token.string}"
        short_form ? short : long
    end


    def evaluate
        ":#{token.string}"
    end
end


class String_Literal_Expr < Ast_Expression
    def to_s
        long  = "Str(#{string})"
        short = "#{string}"
        short_form ? short : long
    end


    def evaluate
        string
    end
end


class Number_Literal_Expr < Ast_Expression

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


class Object_Expr < Ast_Expression
    attr_accessor :name, :compositions, :expressions, :merge_scopes


    def initialize
        super
        @name         = 'Object'
        @compositions = []
        @statements   = []
        @merge_scopes = []
    end


    def non_merge_scope_statements
        expressions.select do |s|
            s != Merge_Scope_Identifier_Expr
        end
    end


    def merge_scope_statements
        expressions.select do |s|
            s == Merge_Scope_Identifier_Expr
        end
    end


    def to_s
        if short_form
            "obj{#{name}}"
        else
            "obj{#{name}, ".tap do |str|
                str << "comps(#{compositions.count}): #{compositions.map(&:to_s)}, " unless compositions.empty?
                str << "merges(#{merge_scopes.count}): #{merge_scopes.map(&:to_s)}, " unless merge_scopes.empty?
                str << "exprs(#{expressions.count}): #{expressions.map(&:to_s)}" unless expressions.empty?
                str << '}'
            end
        end
    end
end


class Function_Expr < Ast_Expression
    attr_accessor :name, :return_type, :parameters, :expressions


    def initialize
        super
        @parameters  = []
        @expressions = []
        @short_form  = true
    end


    def non_merge_scope_statements
        expressions.select do |s|
            s != Merge_Scope_Identifier_Expr
        end
    end


    def merge_scope_statements
        expressions.select do |s|
            s == Merge_Scope_Identifier_Expr
        end
    end


    def to_s
        short = "fun{#{name}".tap do |str|
            str << " params(#{parameters.count}): #{parameters.map(&:to_s)}" unless parameters.empty?
            str << " merges(#{merge_scope_statements.count}): #{merge_scope_statements.map(&:to_s)}" unless merge_scope_statements.empty?
            str << '}'

            str << " stmts(#{non_merge_scope_statements.count}): #{non_merge_scope_statements.map(&:to_s)}" unless non_merge_scope_statements.empty?
            str << '}'
        end

        short_form ? short : inspect
    end
end


# todo: make use of this eventually rather than putting just an array into the :expressions attribute that some classes declared
class Comma_Separated_Expr < Ast_Expression
    attr_accessor :expressions,
                  :count


    def expressions= val
        @expressions = val
        @count       = val.count
    end
end


class Function_Param_Expr < Ast_Expression
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


class Function_Arg_Expr < Ast_Expression
    attr_accessor :expression, :label


    def to_s
        "#{short_form ? '' : 'Arg'}(#{expression.to_s}".tap do |str|
            str << ", label: #{label}" if label
            str << ')'
        end
    end
end


class Function_Call_Expr < Ast_Expression
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


class Assignment_Expr < Ast_Expression
    attr_accessor :name, :type, :expression


    def to_s
        long  = "mem(#{name}=#{expression})"
        short = "(#{name}=#{expression})"
        short_form ? short : long
    end


    def evaluate
        expression&.evaluate
    end
end


class Unary_Expr < Ast_Expression
    require_relative '../lexer/tokens'
    attr_accessor :operator, :expression


    def initialize
        super
        @short_form = true
    end


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
                raise "Unary_Expr(#{operator.string.inspect}) not implemented"
        end
    end
end


class Binary_Expr < Ast_Expression
    attr_accessor :operator, :left, :right


    def initialize
        super
        # @short_form = true
    end


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


class Identifier_Expr < Ast_Expression
    require_relative '../lexer/lexer'


    def identifier
        token.string
    end


    def to_s
        short_form ? token.string : "Ident(#{token.string})"
    end
end


class Enum_Collection_Expr < Ast_Expression
    attr_accessor :name, :constants


    def initialize
        super
        @constants = []
    end


    def to_s
        if short_form
            "enum{#{name}, constants(#{constants.count})}"
        else
            "enum{#{name}, constants(#{constants.count}): #{constants.map(&:to_s)}"
        end
    end
end


class Enum_Constant_Expr < Ast_Expression
    attr_accessor :name, :value


    def to_s
        "#{name} = #{value}"
    end
end


# todo: come up with a better name
class Merge_Scope_Identifier_Expr < Identifier_Expr
    # the &ident operator. merges the scope of the ident into the current scope
    attr_accessor :identifier


    def to_s
        if short_form
            "&#{identifier}"
        else
            "&scope(#{identifier})"
        end
    end
end


class Conditional_Expr < Ast_Expression
    attr_accessor :condition, :expr_when_true, :expr_when_false


    def to_s
        "if #{condition}".tap do |str|
            if expr_when_true
                str << " #{expr_when_true.map(&:to_s)}"
            end
            if expr_when_false
                if expr_when_false.is_a? Conditional_Expr
                    str << " else #{expr_when_false}"
                else
                    str << " else #{expr_when_false.map(&:to_s)}"
                end
            end
        end
    end
end
