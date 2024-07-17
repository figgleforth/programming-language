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

    def get_from_scope type, identifier
        value = curr_scope.send(type)[identifier.to_s]

        if not value
            # start at the next scope and reverse the scopes array so we can traverse up the stack easier
            depth = 0
            scopes.reverse!
            while value.nil?
                depth      += 1
                next_scope = scopes[depth]
                break unless next_scope
                value = next_scope.send(type)[identifier.to_s]
            end
            scopes.reverse! # put it back in the proper order
        end

        value
    end


    # Sets a value (likely a Construct or literal value) on the current scope
    # @return [any] The value passed in
    def set_on_scope type, identifier, value
        curr_scope.send(type)[identifier.to_s] = value
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
                left  = nil if left.is_a? Nil_Construct # this has to handle Nil_Construct as well because Ruby doesn't allow `nil.send('||', right)'. FYI, setting it to nil here because Nil_Construct || right will always return Nil_Construct.

                # I think Ruby metaprogramming is the ideal implementation here, to avoid a giant case expression for every single operator. So the general solution is `left.send expr.operator, right`, but booleans (TrueClass/FalseClass) do not respond to #send so that won't work as is. So the new solution is to handle booleans and ranges manually, and metaprogram the rest. See scratch_59.txt
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
                    when '<='
                        left <= right
                    when '>='
                        left >= right
                    when '<'
                        left < right
                    when '>'
                        left > right
                    when '=='
                        left == right
                    when '||'
                        left || right
                    when '&&'
                        left && right
                    when '.<', '..'
                        Range_Construct.new.tap do |it|
                            it.left     = left
                            it.right    = right
                            it.operator = expr.operator
                        end
                    when '.'
                        #
                    else
                        begin
                            left.send expr.operator, right
                        rescue Exception => e
                            raise "Interpreter#evaluate when Binary_Expr, Ruby exception: #{e}"
                        end

                end

            when Dictionary_Literal_Expr
                # reference: https://rosettacode.org/wiki/Hash_from_two_arrays#Ruby
                value_results = expr.values.map { |val| evaluate val }
                Hash[expr.keys.zip(value_results)]

            when Identifier_Expr
                # Walk up the different types of constructs – check for variable first, then function, then class. Alternate way of looking up, just an idea:
                #   if identifier is member, look up in variables first then functions
                #   if identifier is class, look up classes

                lookup_hash = %i(variables functions classes) # used in #get_from_scope to Runtime_Scope.send lookup_hash
                value       = nil
                while value.nil?
                    hash = lookup_hash.shift
                    break unless hash
                    value = get_from_scope hash, expr.string
                end

                if value.nil?
                    # Some identifiers will be undefined by default, like the #new function on classes.
                    # todo: improve error messaging
                    if expr.member?
                        raise "Undefined variable or function `#{expr.string}`"
                    elsif expr.constant?
                        raise "Undefined constant `#{expr.string}`"
                    else
                        raise "Undefined class `#{expr.string}`"
                    end
                end

                if value.is_a? Variable_Construct
                    if value.result != nil # value.result can be boolean true or false, so check if nil instead
                        value.result
                    elsif value.expression.is_a? Block_Expr
                        value.expression
                    end
                elsif value.is_a? Block_Construct or value.is_a? Class_Construct
                    value
                elsif value.is_a? Construct
                    evaluate value.expression
                else
                    value
                end

            when Assignment_Expr
                return_value = nil
                Variable_Construct.new.tap do |it|
                    it.name       = expr.name
                    it.expression = expr.expression
                    return_value  = expr.expression

                    if not expr.expression.is_a? Block_Expr # only evaluate non-blocks
                        it.result    = evaluate(expr.expression)
                        return_value = it.result
                    end

                    if expr.expression.is_a? Identifier_Expr # in case the variable is a all caps constant
                        it.is_constant = expr.expression.constant?
                    end

                    set_on_scope :variables, it.name, it
                end
                return_value

            when Block_Expr
                last_statement = nil # the default return value of all blocks
                if expr.named? # store the block on the current scope
                    last_statement = Block_Construct.new.tap do |it|
                        it.block     = expr
                        it.name      = expr.name
                        it.signature = expr.signature

                        set_on_scope :functions, it.name, it
                    end
                else
                    # evaluate the block since it wasn't named, and therefor isn't being stored
                    # todo: generalize Block_Call_Expr then use here instead for consistency
                    push_scope Runtime_Scope.new
                    expr.parameters.each do |it|
                        # Block_Param_Decl_Expr
                        set_on_scope :variables, it.name, evaluate(it.default_value)
                    end

                    expr.expressions.map do |expr_inside_block|
                        last_statement = evaluate expr_inside_block
                    end
                    pop_scope
                end
                last_statement

            when Block_Call_Expr
                # Come up with a way to create block signatures. This should allow for functions to share names but declare different params. The signature is not a hash, it could be a string like func1 { a -> } to 'func1->a'. Or something like that, not sure yet.

                last_statement = nil # is the default return value of all blocks

                construct = get_from_scope :functions, expr.name
                if construct # is a Block_Construct
                    push_scope Runtime_Scope.new

                    # evaluates argument expression if present, otherwise the declared param expression
                    construct.block.parameters.zip(expr.arguments).each do |(param, argument)|
                        # Block_Param_Decl_Expr and Block_Arg_Expr
                        value = if argument
                            evaluate argument.expression
                        else
                            evaluate param.default_value
                        end

                        set_on_scope :variables, param.name, value
                    end

                    construct.block.expressions.each do |expr_inside_block|
                        last_statement = evaluate expr_inside_block # expressions.first
                    end
                    pop_scope
                else
                    # when blocks are stored in variables, they can be evaluated later as long as a method by the same name doesn't already exist? This doesn't seem right
                    construct = get_from_scope :variables, expr.name
                    if construct and construct.expression.is_a? Block_Expr
                        push_scope Runtime_Scope.new
                        construct.expression.expressions.map do |block_expr|
                            last_statement = evaluate block_expr
                        end
                        pop_scope
                    else
                        raise "Undefined `#{expr.name}`"
                    end

                end

                last_statement

            when Class_Expr
                # Class_Expr and Class_Construct attributes
                # :name, :block, :base_class, :compositions

                Class_Construct.new.tap do |it|
                    it.name         = expr.name
                    it.block        = expr.block
                    it.base_class   = expr.base_class
                    it.compositions = expr.compositions
                    set_on_scope :classes, it.name, it
                end

            when Nil_Expr, nil
                Nil_Construct.new

            else
                raise "Interpreting not implemented for #{expr.class}"
        end
    end
end
