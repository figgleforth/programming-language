require_relative 'scopes'
require 'ostruct'
CONTEXT_SYMBOL = '@'


class Runtime # todo) should be a scope Hash itself. This should be the global scope. It can then read as many files as it needs, and insert all of their data into it.
    attr_accessor :stack, :expressions, :warnings, :errors


    def initialize expressions = []
        @expressions = expressions
        @warnings    = []
        @errors      = []
        @stack       = []
        push_scope (Global.new.tap do |it|
            # it[CONTEXT_SYMBOL] = Global.name
            it[CONTEXT_SYMBOL] = Global.name
        end), 'My_Application'
    end


    def pp data
        puts PP.pp(data, '').chomp
    end


    def evaluate
        output = nil
        expressions.inject(output) do |_, expr|
            eval(expr)
        end
    end


    # region Scopes – push, pop, set, get

    def push_scope scope, name = nil
        name = name.string if name.is_a? Identifier_Token
        @stack << scope
        scope
    end


    def compose_scope scope
        if curr_scope.is_a? Array
            curr_scope.prepend scope
        else
            push_scope [scope, pop_scope]
        end
    end


    def pop_scope
        @stack.pop
    end


    def curr_scope
        @stack.last
    end


    def get identifier
        identifier = identifier.string if identifier.is_a? Identifier_Token

        value = nil
        @stack.reverse_each do |scope|
            if scope.is_a? Array
                scope.each do |sub_scope|
                    value = sub_scope[identifier]
                    break if sub_scope.key? identifier
                end
            else
                value = scope[identifier]
                break if scope.key? identifier # rather than `if value` because the value could be nil
                break if scope.is_a? Instance
            end
        end
        value = @stack.first[identifier] if value.nil? # falls back to the first scope in the stack, aka the global scope, if no value found traversing up to the nearest opaque scope
        value
    end


    def set identifier, value = nil
        raise "#set expects a string identifier\ngot: #{identifier.inspect}" unless identifier.is_a? String

        @stack.reverse_each do |scope|
            if scope.key? identifier
                scope[identifier] = value
                return value
            end

            break if scope.is_a? Instance
        end

        # if it wasn't found, then just set it on the current scope
        curr_scope[identifier] = value
        value || 'nil'
    end


    # endregion Scopes

    # This is the meat of the runtime
    def eval expr
        def number expr # :type, :decimal_position
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


        def assignment expr # :name, :type, :expression
            # note) this handles CONST as well
            set expr.name.string, eval(expr.expression)
        end


        def scope_signature scope
            "#{scope[:type]}.#{scope[CONTEXT_SYMBOL]}{#{scope.keys.join(',')}}"
        end


        def identifier expr # :is_keyword, #constant?, #class?, #member?
            if ['@', '%'].include? expr.string
                pp curr_scope
                return
            end

            if expr.string == '_'
                return curr_scope
            end

            if expr.string == 'new'
                puts "trying to init"
            end

            value = get expr.string
            if not value
                name = if curr_scope.key? CONTEXT_SYMBOL
                    curr_scope[:name]
                elsif curr_scope.key? 'name'
                    curr_scope[:type]
                end
                raise "`#{expr.string}` not found in #{scope_signature(curr_scope)}\n"
            end

            if value.is_a? Assignment_Expr
                if value.interpreted_value != nil # value.interpreted_value can be boolean true or false, so check against nil instead
                    value.interpreted_value
                elsif value.expression.is_a? Block_Expr
                    value.expression
                else
                    value
                end
            end

            if value.is_a? Expr and not value.is_a? Block_Expr and not value.is_a? Class_Expr
                return eval value
            end
            value
        end


        def binary expr # :operator, :left, :right
            receiver = eval expr.left

            # This handles dot operations on a static scope, which is the equivalent of a class blueprint. Calling new on the blueprint creates an opaque scope. Calling anything else on it just gets the static value from the Static_Scope. Keep in mind that you can technically change these static values. Which would also impact how future instances are created, the inside values could be different.
            if receiver.is_a? Static and expr.operator == '.'
                if expr.right.string == 'new'
                    return receiver.dup.tap do |it|
                        it[CONTEXT_SYMBOL] = Instance.name
                        it.each do |key, val|
                            if val.is_a? Block_Expr
                                it[key] = "Block_Ref(#{expr.left.string}.#{key})" # todo) Block_Ref. how do I map instance.funk to Static.funk. Maybe Instance needs to look like
                                # {
                                #   @ = {
                                #       type: <name of the class>,
                                #       scope: Instance/Static/Global
                                #   }
                                # }
                                # Use @ to store any information that would be helpful. So in this case, a Block_Ref could mean that this is a function that needs to be called, but on scope `@.type` instead of current scope.
                            end
                        end
                    end

                elsif expr.right.is_a? Assignment_Expr
                    push_scope receiver
                    eval expr.right
                    return pop_scope

                elsif expr.right.is_a? Block_Call_Expr
                    push_scope receiver
                    value = eval expr.right
                    pop_scope
                    return value

                else
                    push_scope receiver
                    value = get expr.right.string
                    if not value
                        raise ".#{expr.right.string} not found in #{scope_signature(receiver)}"
                    end
                    pop_scope
                    return value

                end
            end

            if receiver.is_a? Instance and expr.operator == '.'
                if expr.right.is_a? Block_Call_Expr
                    push_scope receiver
                    value = eval expr.right
                    pop_scope
                    return value
                else
                    push_scope receiver
                    value = get expr.right.string
                    if not value
                        raise ".#{expr.right.string} not found in #{scope_signature(receiver)}"
                    end
                    pop_scope
                    return value
                end
            end

            # check if receiver is Instance

            # other potential patterns
            # { static } . new          instantiation
            # { static } . boo          get boo from static
            # { static } . boo=         set boo on static
            # { scope } . tap           tap on any scope
            # literal . tap             tap on any literal
            # { scope } . <str>         dot call anything on scope is basically like scope[str]. the <str> could be evaluated to { scope } in which case you could get:
            # { scope } . { scope }     which is fine too, cause there could be two nested scopes.

            # if receiver.is_a? Instance and expr.operator == '.' and expr.right.is_a? Assignment_Expr
            #     push_scope receiver
            #     value = eval expr.right
            #     pop_scope
            #     return value
            # end

            # if receiver.is_a? Instance and expr.operator == '.' and expr.right.is_a? Block_Call_Expr
            #     push_scope receiver
            #     value = eval expr.right
            #     pop_scope
            #     return value
            # end

            # if receiver.is_a? Instance and expr.operator == '.'
            #     # the below is equivalent to `return receiver[expr.right.string]` but I want to leave it explicit like this, to show what's going on with pushing and popping scopes.
            #     @stack << receiver
            #     value = get expr.right.string
            #     pop_scope
            #     return value
            # end

            # if receiver.is_a? Block_Expr and expr.operator == '.' and expr.right.string == 'new'
            #     scope                        = push_scope Block.new
            #     scope[CONTEXT_SYMBOL][:name] = receiver.name.string
            #     eval receiver
            #     return pop_scope
            # end
            #
            # if receiver.is_a? Block_Expr and expr.operator == '.'
            #     scope                        = push_scope Block.new
            #     scope[CONTEXT_SYMBOL][:name] = receiver.name.string
            #     eval receiver
            #     return pop_scope
            # end
            #
            # if receiver.is_a? Scope and expr.operator == '.' and expr.right.string == 'new'
            #     # @stack << receiver
            #     # value = eval get(expr.right)
            #     # @stack.pop
            #     return receiver.dup
            # end
            #
            # if receiver.is_a? Scope and expr.operator == '.'
            #     @stack << receiver
            #     value = eval get(expr.right)
            #     @stack.pop
            #     return value
            # end

            if receiver.is_a? Hash and expr.operator == '.' # this adds support for dot notation for dictionaries
                push_scope receiver
                value = get expr.right.string
                pop_scope
                return value
            end

            # special case for CONST.right
            # special case for Class.right, Class.new
            # special case for right == 'new'
            # metaprogram the rest
            case expr.operator
                when '+'
                    # puts "+ing"
                    # puts expr.inspect
                    eval(expr.left) + eval(expr.right)
                when '&&'
                    eval(expr.left) && eval(expr.right)
                when '||'
                    eval(expr.left) || eval(expr.right)
                else
                    # pp expr
                    left = eval(expr.left)
                    if left.respond_to? :send
                        left.send expr.operator, eval(expr.right)
                    else
                        raise "Can't metaprogram `#{expr.operator}` in #binary"
                    end

            end
        end


        def class_expr expr # gets turned into a Static, which essentially becomes a blueprint for instances of this class. This evaluates the class body manually, rather than passing Class_Expr.block to #block in a generic fashion.
            # Class_Expr :name, :block, :base_class, :compositions

            push_scope Static.new
            curr_scope[CONTEXT_SYMBOL] = Static.name
            # curr_scope[:type]          = [expr.name.string]
            expr.block.compositions.each do |it|
                # Composition_Expr :operator, :expression, :alias_identifier
                case it.operator
                    when '>'
                    when '+'
                    when '-'
                    else
                        raise "Unknown operator #{it.operator} for composition #{it.inspect}"
                end
                # puts "it! #{it.inspect}"
                comp = eval(it.expression)
                comp.delete('@') # note) comp.delete('@') to remove the @ key
                curr_scope.merge! comp
                # puts "need to comp with\n#{comp}"
                raise "Undefined composition `#{it.identifier.string}`" unless comp
                # puts "compose with #{comp.inspect}\n\n"
                # this involves actual copying of guts.
                # 1) lookup the thing to compose, assert it's Static_Scope
                # 2) dup it, cope all keys and values to this scope (ignore '@' or '_' or whatever. It should be '@'
                # reminder
                #   > Ident (inherits type)
                #   + Ident (only copies scope)
                #   - Ident (deletes scope members)
            end
            # curr_scope[CONTEXT_SYMBOL]['compositions'] = expr.block.compositions.map(&:name)

            expr.block.expressions.each do |it|
                next if it.is_a? Composition_Expr
                # next if it.is_a? Block_Expr
                # todo) don't copy the Block_Exprs either. Or do, but change the
                eval it
            end
            scope = pop_scope
            set expr.name.string, scope
        end


        def block_expr expr # :name, :expressions, :compositions, :parameters, :signature, :is_operator_overload
            last = nil
            if expr.function_declaration? # store the block on the current scope so it can be called later
                # puts "named function! #{expr.inspect}"
                last = set expr.name.string, expr
            else
                # anon block
                push_scope Block.new # apparently class body is a Block_Expr, which makes sense. So if I push a Block, then all the declarations here are lost when the scope pops. So maybe I need do handle this manually inside class_expr? and then let this generic block_expr be handled here
                expr.parameters.each do |it|
                    # Block_Param_Decl_Expr
                    set it.name, eval(it.default_expression)
                end

                expr.compositions.map do |it|
                    # ident = it.identifier.string
                    # if it.operator == '&'
                    #     if it.identifier.string[0]&.chars&.all? { |c| c.downcase == c }
                    #         raise 'Cannot compose with members yet'
                    #     elsif it.identifier.string[0]&.chars&.all? { |c| c.upcase == c }
                    #         guts = get_from_scope ident
                    #         eval guts.block
                    #     end
                    # elsif it.operator == '~'
                    #     # note) implement ~, and raise error message when composition doesn't exist
                    # else
                    #     raise "Interpreter#evaluate: Unknown composition operator #{it.inspect}"
                    # end
                end

                expr.expressions.map do |it|
                    next if it.is_a? Composition_Expr # these are explicitly handled above because expressions might depend compositions being present
                    last = eval it
                end
                pop_scope
            end
            last
        end


        def block_call expr # :name, :arguments
            block = get expr.name.string
            last  = nil

            # note) compositions – I think it involves pushing any compositions onto the stack before pushing this scope.
            push_scope Block.new, expr.name
            params_and_args = block.parameters.zip(expr.arguments)

            params_and_args.each do |(param, arg)|
                # arg   :expression, :label
                # param :name, :label, :type, :default_expression, :composition

                argument = if arg
                    eval arg.expression
                else
                    eval param.default_expression
                end

                set param.name.string, argument
            end

            block.expressions.each do |it|
                last = eval it
            end

            pop_scope
            last
        end


        def conditional expr
            if eval expr.condition
                eval expr.when_true
            else
                eval expr.when_false
            end
        end


        def while_expr expr # :condition, :when_true, :when_false
            # push_scope Block.new
            output = nil
            while eval expr.condition
                output = eval expr.when_true
            end

            if expr.when_false.is_a? Conditional_Expr and output.nil?
                output = eval expr.when_false
            end

            # pop_scope
            output
        end


        def enum_expr expr # :name, :constants
            puts "ENUJM #{expr.inspect}"
            raise "#enum_expr should not run right now. CONST are now handled as normal assignments"
        end


        def macro_command expr # :name, :expression
            if not expr.expression
                puts and return
            end

            case expr.name
                when '>~' # breakpoint snake
                    # I think a REPL needs to be started here, in the current scope. the repl should be identical to the repl.rb from the em cli. any code you run in this repl, is running in the actual workspace (the instance of the app), so you can make permanent changes. Powerful but dangerous.
                    puts "PRETEND BREAKPOINT !!!"
                    pp curr_scope
                    puts "!!! PRETEND BREAKPOINT\n\n"
                when '>!'
                    puts eval(expr.expression)
                when '>!!'
                    puts "WARNING // WARNING // WARNING //"
                    pp eval(expr.expression)
                    puts "// WARNING // WARNING // WARNING"
                when '>!!!'
                    puts "ERROR // ERROR // ERROR //"
                    pp eval(expr.expression)
                    puts "ERROR // ERROR // ERROR //"
                else
                    raise "Runtime#eval #macro_command unhandled expr: #{expr.inspect}"
            end
        end


        def unary expr # :operator, :expression
            value = eval expr.expression
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


        case expr
            when Assignment_Expr
                assignment expr
            when Binary_Expr
                binary expr
            when Unary_Expr
                unary expr
            when Dictionary_Literal_Expr
                # reference: https://rosettacode.org/wiki/Hash_from_two_arrays
                value_results = expr.values.map { |val| eval val }
                Hash[expr.keys.zip(value_results)]

            when Conditional_Expr
                conditional expr
            when While_Expr
                while_expr expr
            when Class_Expr
                class_expr expr
            when Block_Expr
                block_expr expr
            when Block_Call_Expr
                block_call expr
            when Identifier_Expr
                identifier expr
            when Number_Literal_Expr
                number expr
            when String_Literal_Expr
                expr.string
            when Symbol_Literal_Expr
                expr.to_symbol
            when Boolean_Literal_Expr
                expr.to_bool
            when Enum_Expr
                enum_expr expr
            when Macro_Command_Expr
                macro_command expr
            when Nil_Expr
                Nil_Expr
            when nil
            else
                raise "Runtime#eval #{expr.inspect} not implemented"
        end
    end

end
