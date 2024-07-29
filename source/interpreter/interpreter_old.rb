require_relative '../parser/exprs'
require_relative 'scopes'
require_relative 'constructs'
require 'pp'


class Interpreter # evaluates AST and returns the result
    include Scopes
    attr_accessor :expressions, :scopes, :scope_by_identifier


    def initialize expressions = []
        @expressions         = expressions
        @scopes              = [Instance.new] # default scope
        @scope_by_identifier = {}
    end


    def interpret!
        output = nil
        expressions.each do |expr|
            output = evaluate expr
        end
        output
    end


    def push_scope scope
        @scopes << scope
    end


    def pop_scope
        @scopes.pop
    end


    # @return [Scope, nil]

    def curr_scope
        @scopes.last
    end


    # @return [Scope]

    def global_scope
        @scopes.first
    end


    # region Get constructs

    # Works just like #get_from_scope but it returns a tuple [value, scope]
    def get_scope_info_for_ident identifier
        value = curr_scope[identifier.to_s]
        scope = curr_scope

        if not value # start at the next scope and traverse up the stack of scopes
            scopes.reverse_each.with_index do |next_scope, index|
                value = next_scope[identifier.to_s]
                if value
                    scope = next_scope
                end
            end
        end

        [value, scope]
    end


    def get_from_scope identifier
        value = curr_scope[identifier.to_s]

        if not value # start at the next scope and traverse up the stack of scopes
            scopes.reverse_each.with_index do |next_scope, index|
                value = next_scope[identifier.to_s]
                break if value
            end
        end

        value
    end


    # Sets a value (likely a Construct or literal value) on the current scope
    # @return [any] The value passed in
    def set_on_scope identifier, value, desired_scope = nil
        if desired_scope
            @scope_by_identifier[identifier] = desired_scope
            desired_scope[identifier.to_s]   = value
        else
            @scope_by_identifier[identifier] = curr_scope
            curr_scope[identifier.to_s]      = value
        end
    end


    # endregion

    def merge_scope_into_current scope
        curr_scope.merge scope
    end


    def eval_macro_command expr
        if expr.expression
            if expr.name == '>~' # breakpoint snake
                # I think a REPL needs to be started here, in the current scope. the repl should be identical to the repl.rb from the em cli. any code you run in this repl, is running in the actual workspace (the instance of the app), so you can make permanent changes. Powerful but dangerous.
                puts "~ PRETEND BREAKPOINT ~"
            elsif expr.name == '>!' # log level
                puts evaluate(expr.expression)
            elsif expr.name == '>!!' # warning
                puts "WARNING: #{evaluate(expr.expression)}"
            elsif expr.name == '>!!!' # error
                puts "ERROR: #{evaluate(expr.expression)}"
            end
        else
            puts ''
        end
    end


    def eval_class_declaration expr
        set_on_scope expr.name, expr
    end


    def eval_assignment expr
        return_value = nil
        Assignment_Construct.new.tap do |it|
            it.name       = expr.name
            it.expression = expr.expression
            return_value  = expr.expression

            # only evaluate expressions that are not blocks. blocks can be executed later
            if not expr.expression.is_a? Block_Expr
                it.interpreted_value = evaluate(expr.expression)

                return_value = it.interpreted_value
            end

            if expr.expression.is_a? Identifier_Expr # in case the variable is a all caps constant
                it.is_constant = expr.expression.constant?
            end

            existing = @scope_by_identifier[it.name]
            if existing
                push_scope existing
                set_on_scope it.name, return_value
                pop_scope
                # end
                # value, scope = get_scope_info_for_ident it.name
                # if value and scope != curr_scope
                #     # set_on_scope return_value, scope_of(existing)
                #     scope[it.name] = return_value
                #     puts "#{it.name} already exists with value #{value}"
            else
                set_on_scope it.name, return_value
            end
        end
        return_value
    end


    # note) Come up with a way to create block signatures. This should allow for functions to share names but declare different params. The signature is not a hash, it could be a string like `greeting { name -> name }` to 'greeting(name)'.
    # Since we know the strings of the param identifiers, they should be used in the signature. So can labels, so for example `greeting { for name -> name }` could be `greeting(for)`. The label should be used in place of the param name since that is the externally visible identifier for this param anyway, so it should be in the signature.
    # This would allow for methods with shared names but different params, so `greeting { from name -> name }` becomes `greeting(from)`. And now there are two funcs with the same name greeting(for) and greeting(from). The interpreter can decide which to call based on the label. greeting(for: 'Locke') or greeting(from: 'Locke)'
    def eval_block_call expr # Block_Call_Expr :name, :arguments
        block = get_from_scope expr.name
        raise "#eval_block_call expected #get_from_scope to give Block_Expr, got #{block.inspect}" unless block.is_a? Block_Expr

        # puts "\n\n#{expr.name}: #{block.inspect}"
        # puts "args: #{expr.arguments.inspect}"
        # push_scope Scope.new(expr.name)
        last_statement = nil # is the default return value of all blocks

        # block.compositions.each do |comp|
        #     puts "get #{get_from_scope(comp).inspect}"
        #     set_on_scope comp, get_from_scope(comp)
        # end

        params_and_args = block.parameters.zip(expr.arguments)
        # if any param is composition, and it has an arg
        #   arg looks like #<Block_Arg_Expr: @expression=#<Identifier_Expr: @string="b", @is_keyword=false>>

        push_scope Scope.new(expr.name) # for the block being called
        # evaluates argument expression if present, otherwise the declared param expression
        params_and_args.each do |(param, arg)|
            # Block_Param_Decl_Expr and Block_Arg_Expr

            arg_value = if arg
                get_from_scope arg.expression.string
            end

            if param.composition and arg_value
                # puts "existing and its comp #{arg_value.inspect}"
                set_on_scope arg.expression.string, arg_value
            end

            default_value = evaluate param.default_expression
            set_on_scope param.name, default_value

            value = if arg
                evaluate arg.expression
            else
                default_value
            end

            # if an arg like Boo.new is evaluated, it's value is an Instance_Construct so I need to merge its guts, which are located at instance_construct.scope
            # currently though, I'm re-evaluating the block that was originally used to evaluate `value` here. So this seems bad. I want the actual instance to be in this scope, not a copy of it. So this needs to probably merge scopes or something.
            if value.is_a? Instance_Construct
                # merge_scope_into_current value.scope
                evaluate value.class_construct.block
            end

            set_on_scope param.name, value
        end

        block.expressions.each do |expr_inside_block|
            last_statement = evaluate expr_inside_block
        end
        pop_scope

        last_statement
    end


    def eval_block expr
        last_statement = nil # the default return value of all blocks
        if expr.named? # store the block on the current scope so it can be called later
            last_statement = expr.tap do |it|
                set_on_scope it.name, it # Block_Expr
            end
        else
            # anonymous block
            # evaluate the block since it wasn't named, and therefor isn't being stored
            # push_scope Scope.new
            expr.parameters.each do |it|
                # Block_Param_Decl_Expr
                set_on_scope it.name, evaluate(it.default_expression)
            end

            expr.compositions.map do |it|
                ident = it.identifier.string
                if it.operator == '&'
                    if it.identifier.string[0]&.chars&.all? { |c| c.downcase == c }
                        raise 'Cannot compose with members yet'
                    elsif it.identifier.string[0]&.chars&.all? { |c| c.upcase == c }
                        guts = get_from_scope ident
                        evaluate guts.block
                    end
                elsif it.operator == '~'
                    # todo) implement ~, and raise error message when composition doesn't exist
                else
                    raise "Interpreter#evaluate: Unknown composition operator #{it.inspect}"
                end
            end

            expr.expressions.map do |it|
                next if it.is_a? Class_Composition_Expr # these are explicitly handled above because expressions might depend compositions being present
                last_statement = evaluate it
            end
            # pop_scope
        end
        last_statement
    end


    def eval_number_literal expr
        if expr.type == :int
            Integer(expr.string)
        elsif expr.type == :float
            if expr.decimal_position == :end
                Float(expr.string + '0')
            else
                Float(expr.string)
            end # no need to explicitly check :beginning decimal position (.1) because Float(string) can parse that
        end
    end


    def eval_unary expr
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
    end


    def eval_binary expr
        left = evaluate expr.left

        if left.is_a? Enum_Construct and expr.operator == '.' # enum constructs have their own scope so the scope is pushed on the stack before evaluating the enum expressions
            push_scope left.scope
            result = get_from_scope expr.right.string
            pop_scope

            if result.is_a? Assignment_Construct
                result = result.interpreted_value
            end

            return result
        end

        # instantiate when Class_Expr . 'new'
        if left.is_a? Class_Expr and expr.right.string == 'new'
            return Instance.new.tap do |it|
                it.name = left.name
                push_scope it # because #evaluate operates on the current scope, so this ensures that the block/body of the class is evaluated in its own scope
                # todo) should this here be a Static?

                if left.base_class
                    guts = get_from_scope left.base_class
                    evaluate guts.block
                end

                evaluate left.block
                pop_scope
                # it.scope      = pop_scope
                # it.scope.name = left.name
                set_on_scope left.name, it
            end
        end

        if left.is_a? Class_Expr and expr.operator == '.'
            raise 'Calling class functions or variables is not implemented'
        end

        # if left is an Instance_Construct, it should have a scope to push and evaluate on. By pushing its existing scope, the changes made to the instance are permanent.
        if left.is_a? Instance_Construct and expr.operator == '.'
            push_scope left.scope
            result = evaluate expr.right
            pop_scope
            return result
        end

        if left.is_a? Hash and expr.operator == '.' # allowing for dot access on a hash
            # todo) hashes might have builtin funcs, so those should probably take precedence

            if left.has_key? expr.right.string
                return left[expr.right.string]
            end

            raise "Dictionary does not have key #{expr.right.string}"
        end

        right = evaluate expr.right
        left  = nil if left.is_a? Nil_Construct # this has to handle Nil_Construct as well because Ruby doesn't allow `nil.send('||', right)'. FYI, setting it to nil here because `Nil_Construct || right` will always return Nil_Construct.

        # I think Ruby metaprogramming is the ideal implementation here, to avoid a giant case expression for every single operator. So the general solution is `left.send expr.operator, right`, but booleans (TrueClass/FalseClass) do not respond to #send so that won't work for that specific case. So then the new solution is to handle booleans and ranges manually, and metaprogram the rest. See scratch_59.txt
        case expr.operator
            when '+'
                if expr.left.is_a? String_Literal_Expr # because I'm relying on Ruby to concat strings, the right hand must be a string as well. So when we encounter a left that's a string, then let's just automatically convert the right to a string
                    "\"#{expr.left.string}#{right}\""

                elsif expr.right.is_a? String_Literal_Expr
                    "\"#{left}#{expr.right.string}\""

                else
                    left + right
                end

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
            when '.?'
                if left.respond_to? expr.right.string
                    left.send expr.right.string
                else
                    Nil_Construct.new
                end
            when '.<', '..'
                Range_Construct.new.tap do |it|
                    it.left     = left
                    it.right    = right
                    it.operator = expr.operator
                end
            when '.'
                raise "Interpreter#evaluate not implemented when Binary_Expr operator is '.'"
            else
                begin
                    left.send expr.operator, right
                rescue Exception => e
                    raise "Interpreter#evaluate when Binary_Expr, Ruby exception: #{e}"
                end

        end
    end


    def eval_while expr
        # these are kinda trippy. They loop until the condition is satisfied, and also return the last expression that was evaluated as a return value.
        output = nil
        while evaluate expr.condition
            output = evaluate expr.when_true
        end

        if expr.when_false.is_a? Conditional_Expr and output.nil?
            output = evaluate expr.when_false
        end

        output
    end


    def eval_identifier expr
        # walk up the different types of constructs – check for variable first, then function, then class. Alternate way of looking up, just an idea:
        #   if identifier is member, look up in variables first then functions
        #   if identifier is class, look up classes

        if expr.string == '@'
            return PP.pp(curr_scope.keys.zip(curr_scope.values), '').chomp
        end

        lookup_hash = %i(variables functions classes) # used in #get_from_scope to Runtime_Scope.send lookup_hash
        value       = nil
        while value.nil?
            hash = lookup_hash.shift
            break unless hash
            value = get_from_scope expr.string
        end

        if value.nil?
            # Some identifiers will be undefined by default, like the #new function on classes.
            # todo: improve error messaging
            if expr.member?
                raise "undefined variable or function `#{expr.string}` in scope: #{curr_scope.inspect}"
            elsif expr.constant?
                raise "undefined constant `#{expr.string}` in scope: #{curr_scope.inspect}"
            else
                raise "undefined class `#{expr.string}` in scope: #{curr_scope.inspect}"
            end
        end

        # todo: operator overloading! if `.` then get_from_scope(left, right). if `[]` or any other binary operator, get_from_scope(left, :functions, operator) otherwise fall back to internal implementation of those functions. Maybe we should skip the middleman and just have it be a runtime scope

        if value.is_a? Assignment_Construct
            if value.interpreted_value != nil # value.interpreted_value can be boolean true or false, so check if nil instead
                value.interpreted_value
            elsif value.expression.is_a? Block_Expr
                value.expression
            else
                value
            end
        elsif value.is_a? Enum_Construct
            value
        elsif value.is_a? Block_Expr
            value
        elsif value.is_a? Class_Expr
            value
        elsif value.is_a? Instance_Construct
            value
        elsif value.is_a? Construct
            evaluate value.expression
        else
            value
        end
    end


    def eval_enum expr # Enum_Expr :name, :constants
        Enum_Construct.new.tap do |it|
            it.name  = expr.name
            it.scope = Scope.new it.name

            push_scope it.scope
            expr.constants.each do |constant|
                raise "#eval_enum expected Assignment_Expr or Enum_Expr, but got #{constant.inspect}" unless constant.is_a? Assignment_Expr or constant.is_a? Enum_Expr
                evaluate constant # note) these are evaluated/declared on the Enum_Construct's scope
            end
            pop_scope

            set_on_scope it.name, it
        end
    end


    def evaluate expr # note: issues are raised here because the REPL catches these errors and prints them nicely in color
        case expr
            when Binary_Expr # create instances when dot operator with `new`
                eval_binary expr

            when Identifier_Expr
                eval_identifier expr

            when Number_Literal_Expr
                eval_number_literal expr

            when String_Literal_Expr
                expr.to_string # quotes are appended and prepended to the output in #to_string

            when Symbol_Literal_Expr
                expr.to_symbol # colon is prepended to the output in #to_symbol

            when Boolean_Literal_Expr
                expr.to_bool

            when Unary_Expr
                eval_unary expr

            when Dictionary_Literal_Expr
                # reference: https://rosettacode.org/wiki/Hash_from_two_arrays#Ruby
                value_results = expr.values.map { |val| evaluate val }
                Hash[expr.keys.zip(value_results)]

            when Conditional_Expr
                if evaluate expr.condition
                    evaluate expr.when_true
                else
                    evaluate expr.when_false
                end

            when While_Expr
                eval_while expr

            when Assignment_Expr
                eval_assignment expr

            when Block_Expr
                eval_block expr

            when Block_Call_Expr
                eval_block_call expr

            when Class_Expr
                eval_class_declaration expr

            when Command_Expr
                eval_macro_command expr

            when Enum_Expr
                eval_enum expr

            when Nil_Expr, nil
                Nil_Construct.new

            else
                raise "Interpreting not implemented for #{expr.class}"
        end
    end
end
