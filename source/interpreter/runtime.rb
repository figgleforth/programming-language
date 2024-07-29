require_relative 'scopes'
require 'ostruct'
require 'securerandom'

CONTEXT_SYMBOL = 'scope'
SCOPE_KEY_TYPE = 'types'


class Reference
    # include Scopes
    attr_accessor :id


    def initialize
        @id = SecureRandom.uuid
    end


    def to_s
        # last 6 characters of the uuid, with a period in the middle
        "%{#{id[-5..]}}"
    end
end


class Runtime
    # todo) Runtime should be Runtime < Global < Hash itself. Then it can be the global scope but with a stack built in. In the future, this will be able to read code from files, and insert their declarations
    attr_accessor :stack, :expressions, :warnings, :errors, :references, :output


    def initialize expressions = []
        @expressions = expressions
        @references  = {}
        @warnings    = []
        @errors      = []
        @stack       = []
        preload_runtime
    end


    def preload_runtime
        push_scope (Scopes::Global.new.tap do |it|
        end), 'Em App'

        # @cleanup I'm sure there's a better way to do this
        [Scopes::String, Scopes::Array, Scopes::Hash].each do |atom|
            type              = atom.name.split('::').last
            instance          = Object.const_get(atom.to_s).new
            instance['types'] = [type]
            set type, instance
        end
    end


    def pp data
        puts PP.pp(data, '').chomp
    end


    def evaluate_expressions exprs = nil
        @expressions = exprs unless exprs.nil?
        @output      = nil
        expressions.inject(@output) do |_, expr|
            evaluate(expr)
        end
    end


    # region Scopes – push, pop, set, get

    def push_scope scope, name = nil
        scope.name = if name.is_a? Identifier_Token or name.is_a? Ascii_Token # mess
            name.string
        else
            name
        end if scope.respond_to? :name
        @stack << scope
        scope
    end


    # @param [Scopes::Scope] scope
    def compose_scope scope
        raise "trying to compose nil scope" if scope.nil?
        # puts "composing with #{scope}"
        curr_scope.compositions << scope
    end


    def pop_scope
        stack.pop unless stack.one?
    end


    def curr_scope
        stack.compact.last
    end


    def get_farthest_scope scope_type = nil
        return stack.first if stack.one?
        raise '#get_farthest_scope expected a scope type so it can create a hash of that type' if scope_type and not scope_type.is_a? Scopes::Scope

        # this merges two hashes into one hash. @todo get the reference to this, it was something off stackoverflow
        base_type = if scope_type
            scope_type
        else
            {}
        end
        [].tap do |it|
            stack.reverse_each do |scope|
                break if scope.is_a? Scopes::Static # stop looking, can't go further
                it << scope
                # all other blocks can be looked through
            end
        end.reduce(base_type, :merge)
    end


    def get identifier
        identifier = identifier.string if identifier.is_a? Identifier_Token

        value = nil

        curr_scope.compositions.each do |comp|
            # puts "comp baby! #{comp}"
            comp.get_scope_with identifier do |scope|
                value = scope[identifier]
                break
            end
        end if curr_scope.respond_to? :compositions

        stack.reverse_each do |it|
            it.get_scope_with identifier do |scope|
                value = scope[identifier]
                break
            end
        end unless value

        value = stack.first[identifier] if value.nil?
        raise "Undeclared '#{identifier}' in #{scope_signature curr_scope}" if value.nil?

        value = nil if value.is_a? Nil_Expr
        value
    end


    # todo) this should set on previous scope if it exists. meaning that you can't create local declarations if they have the same name as one accessible externally. it will and should overwrite those
    def set identifier, value = nil
        identifier = identifier.string if identifier.is_a? Identifier_Token
        # raise "#set expects a string identifier\ngot: #{identifier.inspect}" unless identifier.is_a? String

        # found = curr_scope.scope_with identifier do |scope|
        #     # calls this block with the first scope that has this identifier. Since scopes can be composed, this will check find the first composition, or self, that responds to the identifier. If none of the scopes do, then this block never calls. It also returns true after calling this block, otherwise false when no scope is found.
        #     push_scope scope
        #     scope[identifier] = value
        #     pop_scope
        # end

        found_scope = nil
        stack.reverse_each do |it|
            # try to overwrite the identifier in a scope if it exists
            found_scope = it.get_scope_with identifier do |scope|
                # calls this block with the first scope that has this identifier. Since scopes can be composed, this will check find the first composition, or self, that responds to the identifier. If none of the scopes do, then this block never calls. It also returns true after calling this block, otherwise false when no scope is found.
                # puts "\n\n\nfound the scope! #{scope.inspect}"
                push_scope scope
                scope[identifier] = value
                pop_scope
            end
            break if found_scope != nil
        end

        if found_scope == nil # then we never found or set the identifier, so the law of the land is that it gets declared on the global scope then
            curr_scope[identifier] = value
        end

        # puts "set #{identifier}= #{value}"

        return value || 'nil' # if found

        #

        # @stack.reverse_each do |scope|
        #     if scope.key? identifier
        #         scope[identifier] = value
        #         break
        #     end
        #
        #     break if scope.is_a? Scopes::Instance
        # end

        # if curr_scope.is_a? Array
        #     # overwrite the first scope behind us where the var is defined
        #     curr_scope.each do |scope|
        #         push_scope scope
        #         if get(identifier) != nil
        #             set identifier, value
        #             pop_scope
        #             break
        #         end
        #         pop_scope
        #
        #         # value = sub_scope[identifier]
        #         # break if sub_scope.key? identifier
        #         # break if scope.is_a? Scopes::Instance
        #         # break if value != nil
        #     end
        #     # break if scope.is_a? Scopes::Instance
        #     # break if value != nil
        # else
        #     curr_scope[identifier] = value
        # end
        # set identifier, value
        # curr_scope[identifier] = value
        # value || 'nil'
    end


    # endregion Scopes

    # This is the meat of the runtime
    def evaluate expr
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
            set expr.name, evaluate(expr.expression)
        end


        # @param [Scopes::Scope] scope
        def scope_signature scope # = curr_scope
            # if scope.key? 'types'
            #     "#{scope['types'].first}{#{scope.keys.join(',')}}"
            # else
            #     inst = if scope.is_a? Scopes::Instance
            #         "Instance."
            #     end
            #     "".tap do |it|
            #         it << inst.to_s
            #         it << scope.class.to_s.split('::').last
            #         it << "{#{scope.keys.join(',')}}"
            #         scope.compositions.each do |comp|
            #             it << scope_signature(comp)
            #         end
            #     end
            # end
            "".tap do |it|
                # it << inst.to_s
                if scope.is_a? Scopes::Peek
                    # puts "its a peek"
                end
                # puts "ut::::: #{scope.class} --- #{scope.inspect}"
                it << if scope[:name]
                    scope.name
                else
                    scope.class.to_s.split('::').last
                end

                it << " { #{scope.keys.join(', ')} }"
                if scope[:compositions]
                    scope.compositions.each do |comp|
                        it << scope_signature(comp)
                    end
                end
            end
        end


        def identifier expr # :is_keyword, #constant?, #class?, #member?
            # mess
            # note all unhandled tokens are treated as identifiers, so do whatever you want with those words and symbols here. This implies that any of these words and symbols could be used as member names, being that they're identifiers. So that allows overloading operators + / * etc, and if the Scope has a function with that operator defined, use that function. Otherwise fall back to the default binary operator evaluation.

            if expr.string == '_'
                return stack
            end

            # note intercept any symbols or identifiers or keywords that were not explicitly designated keywords in the parser
            # if expr.string == 'new' # note in case you want to intercept all calls to new. Or any identifier, really.
            # end

            value = get expr.string
            if value.is_a? Reference
                value = references[value.id]
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
                value = evaluate value
            end

            value = nil if value.is_a? Nil_Expr

            value
        end


        def binary expr # :operator, :left, :right
            receiver = evaluate expr.left

            if receiver.is_a? Reference
                receiver = references[receiver.id]
            end

            if receiver.is_a? Return_Expr
                receiver = evaluate receiver
            end

            # This handles dot operations on a static scope, which is the equivalent of a class blueprint. Calling new on the blueprint creates an opaque scope. Calling anything else on it just gets the static value from the Static_Scope. Keep in mind that you can technically change these static values. Which would also impact how future instances are created, the inside values could be different.
            if receiver.is_a? Scopes::Static and expr.operator == '.'
                # note) this is the right place to implement #tap #where etc
                if expr.right.string == 'new'
                    # todo) make copies of all members as well, we don't want any shared instances between the static class and the instance.
                    return receiver.dup.tap do |it|
                        it[SCOPE_KEY_TYPE] = receiver[SCOPE_KEY_TYPE] #.gsub('Static', 'Instance') # receiver[CONTEXT_SYMBOL] # Instance.name
                        it.each do |key, val|
                            if val.is_a? Block_Expr
                                ref                = Reference.new
                                references[ref.id] = val
                                it[key]            = ref
                            end

                            if val.is_a? Class_Expr and not receiver.is_a? Scopes::Global
                                ref                = Reference.new
                                references[ref.id] = val
                                it[key]            = ref
                            end
                        end
                    end

                elsif expr.right.is_a? Assignment_Expr
                    push_scope receiver
                    evaluate expr.right
                    return pop_scope

                elsif expr.right.is_a? Block_Call_Expr
                    push_scope receiver
                    value = evaluate expr.right
                    pop_scope
                    return value

                else
                    # puts "\n\n=========#{expr.inspect}"
                    # puts "receiver #{receiver.inspect}"
                    push_scope receiver
                    value = get expr.right.string
                    if not value
                        raise ".#{expr.right.string} not found in #{scope_signature(receiver)}"
                    end
                    pop_scope
                    return value

                end
            end

            if receiver.is_a? Scopes::Instance and expr.operator == '.'
                if expr.right.is_a? Block_Call_Expr
                    push_scope receiver
                    value = evaluate expr.right
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

            # if receiver.is_a?
            # Scopes::Instance and expr.operator == '.' and expr.right.is_a? Assignment_Expr
            #     push_scope receiver
            #     value = evaluate expr.right
            #     pop_scope
            #     return value
            # end

            # if receiver.is_a? Scopes::Instance and expr.operator == '.' and expr.right.is_a? Block_Call_Expr
            #     push_scope receiver
            #     value = evaluate expr.right
            #     pop_scope
            #     return value
            # end

            # if receiver.is_a? Scopes::Instance and expr.operator == '.'
            #     # the below is equivalent to `return receiver[expr.right.string]` but I want to leave it explicit like this, to show what's going on with pushing and popping scopes.
            #     @stack << receiver
            #     value = get expr.right.string
            #     pop_scope
            #     return value
            # end

            # if receiver.is_a? Block_Expr and expr.operator == '.' and expr.right.string == 'new'
            #     scope                        = push_scope Scopes::Block.new
            #     scope[CONTEXT_SYMBOL][:name] = receiver.name.string
            #     evaluate receiver
            #     return pop_scope
            # end
            #
            # if receiver.is_a? Block_Expr and expr.operator == '.'
            #     scope                        = push_scope Scopes::Block.new
            #     scope[CONTEXT_SYMBOL][:name] = receiver.name.string
            #     evaluate receiver
            #     return pop_scope
            # end
            #
            # if receiver.is_a? Scope and expr.operator == '.' and expr.right.string == 'new'
            #     # @stack << receiver
            #     # value = evaluate get(expr.right)
            #     # @stack.pop
            #     return receiver.dup
            # end
            #
            # if receiver.is_a? Scope and expr.operator == '.'
            #     @stack << receiver
            #     value = evaluate get(expr.right)
            #     @stack.pop
            #     return value
            # end

            if receiver.is_a? Hash and expr.operator == '.' # this adds support for dot notation for dictionaries
                push_scope receiver
                value = get expr.right.string if receiver.key? expr.right.string
                pop_scope
                return value
            end

            # special case for CONST.right
            # special case for Class.right, Class.new
            # special case for right == 'new'
            # metaprogram the rest
            # 7/28/24) when the operator ends in = but is 2-3 characters long, and maybe manually exclude the equality ones and only focus on the assignments. We can extract the operator before the =. += would extract +, and so on. Since these operators in Ruby are methods, they can be called like `left.send :+, right` so these can be totally automated!
            valid = %w(+= -= *= /= %= &= |= ^= ||= >>= <<=)
            if expr.operator.end_with? '=' and valid.include? expr.operator
                without_equals = expr.operator.gsub '=', ''
                if receiver.respond_to? :send
                    receiver.send without_equals, evaluate(expr.right)
                else
                    raise "Can't metaprogram `#{expr.operator}` in #binary"
                end
                return
            end

            case expr.operator
                when '.<', '..'
                    if expr.operator == '..'
                        evaluate(expr.left)..evaluate(expr.right)
                    elsif expr.operator == '.<'
                        evaluate(expr.left)...evaluate(expr.right)
                    end
                when '**'
                    # left must be an identifier in this instance
                    result = evaluate(expr.left) ** evaluate(expr.right)
                    set expr.left.string, result
                when '&&', 'and'
                    evaluate(expr.left) && evaluate(expr.right)
                when '||', 'or'
                    if expr.left.is_a? Nil_Expr
                        # puts "left is nil #{expr.inspect}"
                        return evaluate expr.right
                    elsif expr.right.is_a? Nil_Expr
                        # puts "right is nil #{expr.inspect}"
                        return evaluate expr.left
                    elsif expr.left.is_a? Nil_Expr and expr.right.is_a? Nil_Expr
                        # puts "both are nil"
                        return nil
                    else
                        left = evaluate(expr.left)
                        # left  = nil if left.is_a? Nil_Expr
                        right = evaluate(expr.right)
                        # right = nil if right.is_a? Nil_Expr

                        left || right
                    end
                else
                    # left = eval(expr.left)
                    if receiver.respond_to? :send
                        # puts "\n\nexpr.inspect"
                        # pp expr
                        # puts "\nreceiver"
                        # pp receiver
                        receiver.send expr.operator, evaluate(expr.right)
                    else
                        raise "Can't metaprogram `#{expr.operator}` in #binary"
                    end

            end
        end


        def class_expr expr # gets turned into a Static, which essentially becomes a blueprint for instances of this class. This evaluates the class body manually, rather than passing Class_Expr.block to #block in a generic fashion.
            # Class_Expr :name, :block, :base_class, :compositions

            class_scope = Scopes::Static.new
            set expr.name.string, class_scope

            push_scope class_scope # push a new scope and also set it as the class
            curr_scope[SCOPE_KEY_TYPE] = [expr.name.string]
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
                comp = evaluate(it.expression)
                curr_scope.merge! comp
                # puts "need to comp with\n#{comp}"
                raise "Undefined composition `#{it.identifier.string}`" unless comp
                # puts "compose with #{comp.inspect}\n\n"
                # this involves actual copying of guts.
                # 1) lookup the thing to compose, assert it's Static_Scope
                # 2) dup it, cope all keys and values to this scope (ignore any keys that shouldn't be duplicated)
                # reminder
                #   > Ident (inherits type)
                #   + Ident (only copies scope)
                #   - Ident (deletes scope members)
            end
            # curr_scope[CONTEXT_SYMBOL]['compositions'] = expr.block.compositions.map(&:name)

            expr.block.expressions.each do |it|
                next if it.is_a? Class_Composition_Expr
                # next if it.is_a? Block_Expr
                # todo) don't copy the Block_Exprs either. Or do, but change the
                evaluate it
            end
            scope              = pop_scope
            ref                = Reference.new
            references[ref.id] = scope
            # set expr.name.string, scope # moved to beginning of this function
        end


        # If a block is named then it's intended to be declared in a variable. If a block is not named, then it is intended to be evaluated right away.
        def block_expr x
            # puts "block_expr::::: #{x.inspect}"
            if x.named? # store the actual expression in a references table, and store declare this reference as the value to be given to the name
                ref = Reference.new.tap do |it|
                    # reference id should be a hash of its name, parameter names, and expressions. That way, two identical functions can be caught by the runtime. Currently it is being randomized in Reference#initialize
                    references[it.id] = x
                end

                set x.name, ref
            else
                block_call x
            end
        end


        def block_call expr # :name, :arguments
            args  = []
            block = if expr.is_a? Block_Call_Expr
                args = expr.arguments
                get expr.name # which should yield a Block_Expr
            elsif expr.is_a? Block_Expr
                expr
            else
                raise "#block_call received unknown expr #{expr.inspect}"
            end

            while block.is_a? Reference
                block = references[block.id]
            end

            if not block
                raise "No such method #{expr.name}"
            end

            # last = nil
            # push Transparent.Block.name

            # set each par/arg pair on the current scope
            # if param is composition, add it to some composition array
            # when #getting a var. if the composition responds to what you're getting, push it, get, pop it
            # we are never actually composing here

            # pop
            # last

            name = expr.name || 'Anon_Block'

            if not expr.name and args.count > 0
                raise "Anon block cannot be"
            end

            # puts "calling block #{name}"
            # puts "the block #{block.inspect}"
            # puts "stack"
            # puts stack.inspect
            # puts stack.first.class

            # puts "\n\nthe current scope before valuating block::::: #{expr.inspect}"
            # puts curr_scope.class
            # puts "and its compositions #{curr_scope.compositions}"

            scope = Scopes::Transparent.new
            push_scope scope, expr.to_s
            block.parameters.zip(args).each.with_index do |(par, arg), i|
                # pars =>   :name, :label, :type, :default_expression, :composition
                # args =>   :expression, :label

                # if arg present, then that should take the value of par.name
                # it not arg, then set par.name, eval(par.default_expression)

                if arg
                    set par.name, evaluate(arg.expression)
                else
                    if not par.default_expression
                        pop_scope
                        raise "##{name}(#{"•, " * i}???) requires an argument in position #{i} for parameter named #{par.name}"
                    end
                    set par.name, evaluate(par.default_expression)
                end

                if par.composition
                    instance = get par.name
                    # puts "the composition #{par.inspect}\n\ninstance: #{instance.inspect}"
                    # compose_scope instance
                    curr_scope.compositions << instance
                    # puts "\ncurr composition: #{curr_scope.compositions.inspect}"
                    set par.name, instance
                end
            end

            # puts "composed! #{curr_scope.compositions}"
            # puts "curr scope.class #{curr_scope.class}"

            last = nil
            block.expressions.each do |it|
                if it.is_a? Class_Composition_Expr # just like the params composition, except that we do it at eval time instead
                    instance = evaluate it.expression
                    curr_scope.compositions << instance
                    next
                end
                # puts "block call expr #{it.inspect}"
                last = evaluate it

                if last.is_a? Return_Expr
                    pop_scope
                    return evaluate last
                elsif it.is_a? Return_Expr
                    pop_scope
                    return it
                end
            end
            pop_scope
            last
        end


        def conditional expr
            if evaluate expr.condition
                evaluate expr.when_true
            else
                evaluate expr.when_false
            end
        end


        def while_expr expr # :condition, :when_true, :when_false
            # push_scope Scopes::Block.new
            output = nil
            while evaluate expr.condition
                output = evaluate expr.when_true
            end

            if expr.when_false.is_a? Conditional_Expr and output.nil?
                output = evaluate expr.when_false
            end

            # pop_scope
            output
        end


        def enum_expr expr
            raise "#enum_expr should not run right now. CONST are now handled as normal assignments"
        end


        # rename this, wtf is macro command lol.
        def command expr # :name, :expression
            case expr.name
                when '>~' # breakpoint snake
                    # I think a REPL needs to be started here, in the current scope. the repl should be identical to the repl.rb from the em cli. any code you run in this repl, is running in the actual workspace (the instance of the app), so you can make permanent changes. Powerful but dangerous.
                    return "PRETEND BREAKPOINT IN #{scope_signature}"
                when '>!'
                    value = evaluate(expr.expression)
                    puts value
                    return value
                when '>!!'
                    value = "!! #{evaluate(expr.expression)}"
                    puts value
                    return value
                when '>!!!'
                    value = "!!! #{evaluate(expr.expression)}"
                    puts value
                    return value
                when 'ls'
                    return scope_signature get_farthest_scope(curr_scope)
                when 'ls!'
                    return "".tap do |it|
                        # fix this visibility thing. It is broken. The idea is to get the stack and combine it into one

                        it << "——––--¦  DECLARATIONS VISIBLE TO ME\n"
                        it << scope_signature(get_farthest_scope(curr_scope))
                        it << "\n\n——––--¦  SCOPE AT TOP OF STACK\n"
                        it << scope_signature(curr_scope)
                        it << "\n\n——––--¦  STACK SCOPE SIGNATURES (#{stack.count})\n"
                        stack.reverse_each do |s|
                            it << "#{scope_signature(s)}\n"
                        end
                        it << "\n——––--¦  STACK (#{stack.count})\n"
                        it << "".tap do |str|
                            stack.reverse_each.map do |s|
                                formatted = PP.pp(s, '').chomp
                                formatted.split("\n").each do |part|
                                    str << "#{part}\n".to_s.gsub('"', '')
                                end
                            end
                        end
                        # it << "\n\s"
                        # it << "\n\n——––--¦"
                    end
                when 'cd'
                    destination = evaluate expr.expression
                    if destination.is_a? Scopes::Scope
                        # what if we push the destination, then compose it with a Peek. I believe #set updates on compositions first before checking self. If not, that should be a rule for it
                        scratch      = Scopes::Transparent.new
                        scratch.name = 'Transparent'
                        push_scope destination
                        curr_scope.compositions << scratch
                        return scope_signature get_farthest_scope(curr_scope)

                        # scope = Scopes::Peek.new.tap do |it|
                        #     it['types'] = destination['types'] # + [it.class.to_s.split('::').last]
                        # end
                        # push_scope scope
                        # compose_scope destination
                        # return scope_signature get_farthest_scope(curr_scope)
                    else
                        raise 'Can only cd into a scope!'
                    end

                when 'cd ..'
                    # since we composed above in cd, we need to erase compositions
                    curr_scope.compositions.pop
                    pop_scope # Transparent scope added in cd
                    return scope_signature get_farthest_scope(curr_scope)
                else
                    raise "Runtime#eval #command unhandled expr: #{expr.inspect}"
            end
        end


        def unary expr # :operator, :expression
            value = evaluate expr.expression
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
                value_results = expr.values.map { |val| evaluate val }
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
            when Class_Composition_Expr
                # raise "block compositions can only be done in params #{expr.inspect}"
                instance = get expr.name
                curr_scope.compositions << instance
            when Wormhole_Composition_Expr
                instance = get expr.name
                compose_scope instance
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
            when Return_Expr
                evaluate expr.expression
            when Command_Expr
                command expr
            when Nil_Expr
                nil # todo) if things break, it's because I added the nil here. But this makes more sense
                Nil_Expr
            when Raise_Expr
                # @cleanup
                if expr.condition != nil
                    result = evaluate expr.condition
                    if not result
                        # puts "with condition but it didn't return anything: #{result.inspect}"
                        raise("".tap do |it|
                            it << "\n\n~~~~ OOPS ~~~~\n"
                            message = evaluate expr.message_expression
                            if message
                                it << "#{message}"
                            else
                                it << "Evaluate any expression when oopsing: `oops expression`"
                            end
                            it << "\n~~~~ OOPS ~~~~\n"
                        end)
                    end
                else
                    raise("".tap do |it|
                        it << "\n\n~~~~ OOPS ~~~~\n"
                        message = evaluate expr.message_expression
                        if message
                            it << "#{message}"
                        else
                            it << "Evaluate any expression when oopsing: `oops expression`"
                        end
                        it << "\n~~~~ OOPS ~~~~\n"
                    end)
                end
            when nil
            else
                raise "Runtime#eval #{expr.inspect} not implemented"
        end
    end

end
