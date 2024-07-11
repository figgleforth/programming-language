require_relative '../parser/ast'
require_relative 'runtime_scope'


class Interpreter # evaluates AST and returns the result
    attr_accessor :expressions, :scopes


    def initialize expressions
        @expressions = expressions
        @scopes      = [Runtime_Scope.new]
    end


    def interpret!
        expressions.each do |expr|
            value = evaluate(expr)
            next unless value
            puts value
        end
        pop_scope
    end


    def depth
        @scopes.count
    end


    def push_scope scope
        @scopes << scope
    end


    def pop_scope
        curr_scope.decrease_depth if curr_scope
        @scopes.pop
    end


    def curr_scope
        @scopes.last
    end


    def evaluate expr
        case expr
            when Number_Literal_Expr
                if expr.type == :int
                    Integer(expr.string)
                elsif expr.type == :float
                    if expr.decimal_position == :end
                        Float(expr.string + '0')
                    else
                        Float(expr.string)
                    end # no need to explicitly check :beginning decimal position (.1) because Float(string) can parse that
                end

            when String_Literal_Expr
                expr.string

            when Symbol_Literal_Expr
                expr.to_ruby_symbol

            when Boolean_Literal_Expr
                expr.to_bool

            when Identifier_Expr
                get_member expr.string
            when Unary_Expr
                value = evaluate(expr.expression)
                case expr.operator
                    when '-'
                        -value
                    when '+'
                        +value
                    when '~'
                        ~value
                    when '!'
                        !value
                    else
                        raise "#evaluate Unary_Expr(#{operator.inspect}) is not implemented"
                end

            when Binary_Expr
                left  = evaluate expr.left
                right = evaluate expr.right
                case expr.operator
                    when '+'
                        left + right
                    when '-'
                        left - right
                    when '*'
                        left * right
                    when '/'
                        left / right
                    when '%'
                        left % right
                    when '**'
                        left ** right
                    when '<<'
                        left << right
                    when '>>'
                        left >> right
                    when '=='
                        left == right
                    else
                        raise "Binary_Expr unknown operator #{expr.operator}"
                end

            when Assignment_Expr
                value = evaluate(expr.expression)
                set_member_in_curr_scope expr.name, value
                value

            when Block_Expr
                # TODO compositions; args/params
                push_scope Runtime_Scope.new
                expr.expressions.map do |block_expr|
                    stmt = evaluate block_expr
                    puts(stmt ? stmt : 'nil')
                end
                pop_scope
                nil

            when nil
                raise "nil expr passed to evaluate"
            else
                raise "Unrecognized ast #{expr.inspect}"
        end
    end


    def set_member_in_curr_scope member, value
        # TODO is member.to_s the key to use here?
        if curr_scope.members[member.to_s]
            puts "%% OVERWRITE #{member} = #{value} %%" # TODO maybe make some warning buffer, something like push_warning
        end
        curr_scope.members[member.to_s] = value
    end


    def get_member member
        # TODO nested scopes, and that they should be able to access members of the global scope and the scope enclosing it
        # TODO should nil be a static object or just a string from the POV of the user?
        # TODO should it crash when something is nil?
        value = curr_scope.members[member.to_s]

        if not value
            depth = 0 # `start at the next scope and reverse the scopes array so we can traverse up the stack easier
            scopes.reverse!
            while value.nil?
                depth      += 1
                next_scope = scopes[depth]
                break unless next_scope
                value = next_scope.members[member.to_s]
            end
            scopes.reverse! # put it back in the proper order. TODO I imagine the double reverse isn't performant, so maybe just get the index of current scope and use it to traverse up the scope stack in the reverse order
        end

        value || 'NIL'
    end
end
