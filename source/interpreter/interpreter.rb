require_relative '../parser/ast'
require_relative 'runtime_scope'
require_relative 'constructs'


class Interpreter # evaluates AST and returns the result
    attr_accessor :expressions, :scopes


    def initialize expressions = []
        @expressions = expressions
        @scopes      = [Runtime_Scope.new] # default runtime scope
    end


    def interpret!
        output = nil
        expressions.each do |expr|
            output = evaluate expr # expressions.first
        end
        output
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


    # @return [Runtime_Scope, nil]
    def curr_scope
        @scopes.last
    end


    def set_method_construct identifier, construct
        # todo: does #add_method interfere with the Kernel
        # todo: I want methods to be able to have the same name but different arguments
        curr_scope.methods[identifier.to_s] = construct
    end


    def get_method_construct identifier
        body = curr_scope.methods[identifier.to_s]

        if not body
            depth = 0 # `start at the next scope and reverse the scopes array so we can traverse up the stack easier
            scopes.reverse!
            while body.nil?
                depth      += 1
                next_scope = scopes[depth]
                # puts "checking next_scope #{next_scope}"
                break unless next_scope
                body = next_scope.methods[identifier.to_s]
                puts "checking next_scope #{next_scope}: #{body.inspect}"
            end
            scopes.reverse! # put it back in the proper order
        end

        body
    end


    def set_variable_construct identifier, expression # todo: is member.to_s the key to use here?
        curr_scope.variables[identifier.to_s] = expression # not the result, so that the expression can be evaluated later
    end


    def get_variable_construct identifier
        # todo: should nil be a static object or just a string from the POV of the user? should it crash when something is nil?
        # todo: the double reverse is probably inefficient, so maybe just get the index of current scope and use it to traverse up the scope stack in the reverse order?
        value = curr_scope.variables[identifier.to_s]

        if not value
            depth = 0 # `start at the next scope and reverse the scopes array so we can traverse up the stack easier
            scopes.reverse!
            while value.nil?
                depth      += 1
                next_scope = scopes[depth]
                break unless next_scope
                value = next_scope.variables[identifier.to_s]
            end
            scopes.reverse! # put it back in the proper order
        end

        value
    end


    def evaluate expr # note: issues are raised here because the REPL catches these errors and prints them nicely in color
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
                expr.string.inspect # note: using #inspect so that the output contains the quotes

            when Symbol_Literal_Expr
                expr.to_ruby_symbol

            when Boolean_Literal_Expr
                expr.to_bool

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

            when Identifier_Expr
                construct = get_variable_construct expr.string
                if construct
                    # puts "construct.inspect #{construct.inspect}"
                    if construct.is_a? Variable_Construct and construct.expression.is_a? Block_Expr
                        construct.expression
                    else
                        evaluate construct.expression
                    end
                else
                    raise "Undefined `#{expr.string}`" # todo: improve error messaging
                end

            when Assignment_Expr
                # todo: when assigning blocks, should they be evaluated right away? Probably not

                Variable_Construct.new.tap do |it|
                    it.name       = expr.name
                    it.expression = expr.expression

                    set_variable_construct expr.name, it
                end

                if expr.expression.is_a? Block_Expr
                    # puts "not evaluating, just storing"
                else
                    evaluate expr.expression # todo: unless the expression is a block? I can't decide if it should evaluate right away. The naive answer is that it shouldn't. Right?
                end

            when Block_Expr
                # todo: compositions; args/params

                last_statement = nil # is the default return value of all blocks
                if expr.named? # store the block on the current scope
                    Method_Construct.new.tap do |it|
                        it.expressions = expr.expressions
                        it.name        = expr.name

                        set_method_construct expr.name, it
                        last_statement = it
                    end # todo: in pry, declaring a method prints its name as output. it does not evaluate it
                else
                    push_scope Runtime_Scope.new
                    # evaluate the block
                    expr.expressions.map do |block_expr|
                        last_statement ||= evaluate block_expr
                    end
                    pop_scope
                end
                last_statement

            when Function_Call_Expr
                construct      = get_method_construct expr.name
                if not construct
                    raise "Em – UNDEFINED #{expr.name}"
                end
                last_statement = nil # is the default return value of all blocks
                construct.expressions.map do |block_expr|
                    last_statement ||= evaluate block_expr
                end
                last_statement
            when Nil_Expr, nil
                nil

            else
                raise "Interpreting not implemented for #{expr.class}"
        end
    end
end
