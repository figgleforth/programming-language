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


    # @return [Runtime_Scope]
    def global_scope
        @scopes.first || Runtime_Scope.new
    end


    # region Get constructs
    # todo: generalize these getters
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


    def get_class_construct identifier
        construct = curr_scope.classes[identifier.to_s]

        if not construct
            depth = 0 # `start at the next scope and reverse the scopes array so we can traverse up the stack easier
            scopes.reverse!
            while construct.nil?
                depth      += 1
                next_scope = scopes[depth]
                # puts "checking next_scope #{next_scope}"
                break unless next_scope
                construct = next_scope.classes[identifier.to_s]
                puts "checking next_scope #{next_scope}: #{construct.inspect}"
            end
            scopes.reverse! # put it back in the proper order
        end

        construct
    end


    def set_construct type, identifier, construct
        case type
            when :variable
                curr_scope.variables[identifier.to_s] = construct
            when :method
                curr_scope.methods[identifier.to_s] = construct
            when :class
                curr_scope.classes[identifier.to_s] = construct
            else
                raise "#set_construct – unknown type #{type.inspect}"
        end
    end


    # endregion

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

            when Dictionary_Literal_Expr
                # reference: https://rosettacode.org/wiki/Hash_from_two_arrays#Ruby
                value_results = expr.values.map do |val|
                    evaluate val
                end
                Hash[expr.keys.zip(value_results)]

            when Identifier_Expr
                # walk up the construct types at any identifier. todo: I don't care to differentiate between the types of identifiers at this point, or do I? What if there are name collisions?
                construct = get_variable_construct expr.string
                if not construct
                    construct = get_method_construct expr.string
                end
                if not construct
                    construct = get_class_construct expr.string
                end

                if not construct
                    raise "Undefined `#{expr.string}`" # todo: improve error messaging
                end

                if construct.is_a? Variable_Construct
                    if construct.value
                        construct.value
                    elsif construct.expression.is_a? Block_Expr
                        construct.expression
                    end
                elsif construct.is_a? Method_Construct
                    construct
                elsif construct.is_a? Class_Construct
                    construct
                else
                    evaluate construct.expression
                end

            when Assignment_Expr
                return_value = nil
                Variable_Construct.new.tap do |it|
                    it.name       = expr.name
                    it.expression = expr.expression
                    return_value  = expr.expression

                    if not expr.expression.is_a? Block_Expr # don't evaluate blocks yet so that they
                        it.value     = evaluate(expr.expression)
                        return_value = it.value
                    end

                    if expr.expression.is_a? Identifier_Expr # in case the variable is a all caps constant
                        it.is_constant = expr.expression.constant?
                    end

                    set_construct :variable, it.name, it
                end
                return_value

            when Block_Expr
                # todo: compositions; args/params

                last_statement = nil # is the default return value of all blocks
                if expr.named? # store the block on the current scope
                    Method_Construct.new.tap do |it|
                        it.block = expr
                        it.name  = expr.name

                        set_construct :method, it.name, it
                        last_statement = it
                    end # todo: in pry, declaring a method prints its name as output. it does not evaluate it
                else
                    # evaluate the block since it wasn't named, and therefor isn't being stored
                    push_scope Runtime_Scope.new
                    expr.expressions.map do |block_expr|
                        last_statement ||= evaluate block_expr
                    end
                    pop_scope
                end
                last_statement

            when Function_Call_Expr
                last_statement = nil # is the default return value of all blocks

                construct = get_method_construct expr.name
                if construct
                    construct.block.expressions.each do |block_expr|
                        last_statement ||= evaluate block_expr # expressions.first
                    end
                else
                    # when blocks are stored in variables, they can be evaluated later as long as a method by the same name doesn't already exist? This doesn't seem right
                    construct = get_variable_construct expr.name
                    if construct and construct.expression.is_a? Block_Expr
                        construct.expression.expressions.map do |block_expr|
                            last_statement ||= evaluate block_expr
                        end
                    else
                        raise "Undefined `#{expr.name}`"
                    end

                end

                last_statement

            when Class_Expr
                # store the construct, then use it whenever a class must be initialized.
                construct = Class_Construct.new.tap do |it|
                    # todo: don't just copy all the properties. Prepare a Class Construct that is the result of these properties
                    it.name         = expr.name
                    it.block        = expr.block
                    it.base_class   = expr.base_class
                    it.compositions = expr.compositions
                    set_construct :class, it.name, it
                end

            when Nil_Expr, nil
                nil

            else
                raise "Interpreting not implemented for #{expr.class}"
        end
    end
end
