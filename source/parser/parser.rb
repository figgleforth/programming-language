# Turns string of code into tokens
class Parser
    require_relative '../lexer/tokens'
    require_relative 'ast'

    attr_accessor :i, :buffer, :expressions, :eaten_this_iteration


    def initialize buffer = []
        @i                    = 0 # index of current token
        @buffer               = buffer
        @expressions          = []
        @eaten_this_iteration = []
    end


    def to_ast
        parse_until EOF_Token
    end


    # region Parsing Helpers

    # makes a new Parser and sets its tokens to the current remainder
    def new_parser_with_remainder_as_buffer
        Parser.new remainder
    end


    def debug
        count     = [3, remainder.count].min
        remaining = remainder.count > count ? remainder[-count..].map(&:to_s) : []

        count = [3, expressions.count].min
        stmts = expressions.count > count ? expressions[-count..].map(&:to_s) : []

        "\n\nUNHANDLED TOKEN:\n\t#{curr.inspect}
        \n\nREMAINING:\n\t#{remaining}
        \n\nEATEN THIS ITERATION of #parse_expre:\n\t#{@eaten_this_iteration.map(&:to_s)}"
    end


    # array of precedences and symbols for that precedence. if the token provided matches one of the operator symbols then its precedence is returned. todo: audit operators
    def precedence_for token
        [
            [0, %w(( ))],
            [1, %w([ ])],
            [2, %w(!)],
            [3, %w(- +)], # Additive
            [4, %w(**)], # Exponentiation
            [5, %w(* / %)], # Multiplicative
            # 6 is reserved for unary + -
            [7, %w(<< >>)], # Shift
            [8, %w(< <= > >=)], # Relational
            [9, %w(== != === !==)], # Equality
            [10, %w(&)], # Bitwise AND
            [11, %w(^)], # Bitwise XOR
            [12, %w(|)], # Bitwise OR
            [13, %w(&&)], # Logical AND
            [14, %w(||)], # Logical OR
            [15, %w(?:)], # Ternary
            [17, %w(= += -= *= /= %= &= |= ^= <<= >>=)], # Assignment
            [18, %w(,)],
            [19, %w(. ./)],
        ].find do |_, chars|
            chars.include?(token.string)
        end&.at(0)
    end


    # buffer[i - 1]
    def prev
        peek -1
    end


    # buffer[i]
    def curr
        peek 0
    end


    # buffer[i..]
    def remainder
        @buffer[@i..]
    end


    # whether there are tokens remaining to be parsed
    def tokens?
        @i < (@buffer&.length || 0)
    end


    def eat_past_newlines
        eat while curr? "\n"
    end


    # looks at token without eating, can look backwards as well but peek index is clamped to buffer. if accumulated, returns an array of tokens. otherwise returns a single token
    def peek ahead = 0
        raise 'Parser.buffer is nil' unless buffer

        index = ahead.clamp(0, @buffer.count)
        @buffer[@i + index]
    end


    # looks ahead `count` tokens, without consuming them. cannot peek backwards
    def peek_many count = 2
        raise 'Parser.buffer is nil' unless buffer

        remainder.slice 0, count
    end


    # slices buffer until specified token, so it isn't included in the result. doesn't actually consume the buffer, you still have to do that by calling eat. easier to iterate this than fuck with the actual pointer in the buffer
    def peek_until token = "\n"
        remainder.slice_before do |t|
            t == token
        end.to_a.first
    end


    # slices buffer past specified token, so it is included in the result. doesn't actually consume the buffer, you still have to do that by calling eat. easier to iterate this than fuck with the actual pointer in the buffer
    def peek_past token = "\n"
        remainder.slice_after do |t|
            t == token
        end.to_a.first
    end


    # uses peek_until to get count of tokens until specified token, then adds that count to the buffer pointer @i
    def eat_until token = "\n"
        @i += peek_until(token).count
    end


    # uses peek_past to get count of tokens until it passes specified token, then adds that count to the buffer pointer @i
    def eat_past token = "\n"
        @i += peek_past(token).count
    end


    # checks whether the remainder buffer contains the exact sequence of tokens. if one of the arguments is an array then that token in the sequence can be either of the two. eg: ident, [:, =, :=]
    def curr? * sequence
        remainder.slice(0, sequence.count).each_with_index.all? do |token, index|
            if sequence[index].is_a? Array
                sequence[index].any? do |sequence_element|
                    if sequence_element.is_a? Symbol
                        token == sequence_element.to_s
                    else
                        token == sequence_element
                    end
                end
            else
                if sequence[index].is_a? Symbol
                    token == sequence[index].to_s
                else
                    token == sequence[index]
                end
            end
        end
    end


    # eats a specific sequence of tokens, either Token class or exact string. eg: eat StringLiteralToken, eat '.'. etc
    # idea: support sequence of elements where an element can be one of many, like the sequence [IdentifierToken, [:=, =]]
    def eat * sequence
        if sequence.nil? or sequence.empty? or sequence.one?
            eaten = curr
            if sequence&.one?
                raise debug unless eaten == sequence[0]
            end
            @i    += 1
            eaten_this_iteration << eaten
            return eaten
        end

        [].tap do |result|
            # Usage:
            #   sequence =
            #     eat '}'
            #     eat %w(} end)
            sequence.each do |expected|
                unless curr == expected
                    current   = "\n\nExpected #{expected} but got #{curr}"
                    remaining = "\n\nREMAINING:\n\t#{remainder.map(&:to_s)}"
                    progress  = "\n\nPARSED SO FAR:\n\t#{expressions[3..]}"
                    raise "#{current}#{remaining}#{progress}" unless curr == expected
                end

                eaten = curr
                result << eaten
                eaten_this_iteration << eaten
                @i += 1
            end
        end
    end


    # endregion

    # region Sequence Parsing

    def parse_block until_token = '}'
        Block_Expr.new.tap do |block|
            parser            = new_parser_with_remainder_as_buffer
            stmts             = parser.parse_until until_token
            @i                += parser.i
            block.expressions = stmts
        end
    end


    def make_typed_var_decl_ast
        Assignment_Expr.new.tap do |node|
            tokens    = eat Identifier_Token, ':', Identifier_Token
            node.name = tokens[0].string
            node.type = tokens[2]

            if curr? '='
                eat '='

                if curr? %W(; \n)
                    raise "Expected expression after ="
                end
                node.expression = parse_expression
            end
        end
    end


    def make_assignment_ast
        Assignment_Expr.new.tap do |node|
            node.name = eat(Identifier_Token).string

            if curr? '=;'
                eat '=;'
            elsif curr? '=' and eat '='
                if curr? "\n"
                    code = (buffer << curr).join(' ')
                    raise "Expected expression after `#{buffer[1]}` but got `#{curr}` in\n\n```\n#{code}\n```"
                else
                    node.expression = parse_expression
                end
            else
                current   = "Expected = with an expression or ; to terminate the var declaration"
                unhandled = "UNHANDLED TOKEN:\n\t#{curr.inspect}"
                remaining = "REMAINING:\n\t#{remainder.map(&:to_s)}"
                progress  = "PARSED SO FAR:\n\t#{expressions}"
                raise "\n\n#{current}\n\n#{unhandled}\n\n#{remaining}\n\n#{progress}"
            end
        end
    end


    def make_enum_ast
        # if = then Enum_Constant_Expr   -> eat the smallest unit CONST = val
        # if { then Enum_Collection_Expr -> eat { then make_enum_ast until }
        if curr? Identifier_Token, '{'
            Enum_Collection_Expr.new.tap do |node|
                node.name = eat(Identifier_Token).string
                eat '{'
                eat_past_newlines
                until curr? '}'
                    node.constants << make_enum_ast
                    node.constants.compact!
                end
                eat '}'
            end
        elsif curr? Identifier_Token
            Enum_Constant_Expr.new.tap do |node|
                node.name = eat(Identifier_Token).string

                if curr? '=' and eat '='
                    # note: allow stateless methods as well?
                    node.value = parse_block(%W(, \n)).expressions[0]
                end
                eat_past_newlines
            end
        elsif curr? ',' and eat ','
            eat_past_newlines
        else
            raise debug
        end
    end


    def make_string_or_number_literal_ast
        if curr == String_Token
            String_Literal_Expr.new
        else
            Number_Literal_Expr.new
        end.tap do |literal|
            literal.string = eat.string
        end
    end


    def make_unary_expr_ast
        Unary_Expr.new.tap do |node|
            node.operator   = eat(Ascii_Token).string
            node.expression = parse_expression 6 # this cannot use #precedence_for because it would return the same precedence as the binary operators of the same symbol, but we need to be able to be distinguish between the unary. there's probably a better way to do this, but who cares.
        end
    end


    def make_function_call_ast
        def parse_args
            # Ident: Expr (,)
            # Expr (,)
            [].tap do |params|
                while curr?(Token) and curr != ')'
                    params << Function_Arg_Expr.new.tap do |param|
                        if curr? Identifier_Token, ':' #, Token
                            param.label = eat Identifier_Token
                            eat ':'
                        end

                        param.expression = if curr? Token, ','
                            parse_block ','
                        elsif curr? Token, ')'
                            parse_block ')'
                        else
                            parse_block %w[, )]
                        end.expressions[0]
                    end

                    eat if curr? ','
                end
            end
        end


        # todo: make use of this. maybe this will help prevent this from parsing `go(wtf =;)` to `fun_call(name: go, ["Arg(set(wtf=))"])`. this makes no sense
        def make_comma_separated_params
            Comma_Separated_Expr.new.tap do |node|
                node.blocks << parse_block(%w(, \)))
                while curr? ','
                    eat ','
                    node.blocks << parse_block(%w(, \)))
                end
            end
        end


        # todo) how to handle spaces in place of parens like Ruby?
        Function_Call_Expr.new.tap do |node|
            node.name = eat Identifier_Token
            eat '('
            node.arguments = parse_args
            eat ')'
        end
    end


    # Ident ( > Ident (, Ident) )
    #   { ... }
    def make_object_ast is_api_decl = false
        Object_Expr.new.tap do |node|
            node.name = eat(Identifier_Token).string

            if curr? '>' and eat '>'
                node.parent = eat Identifier_Token
            end

            eat '{'
            node.block = parse_block '}'

            # todo: raise 'Duplicate merge scope' unless node.compositions.map(&:identifier).count == node.compositions.count

            eat '}'
        end
    end


    def parse_params
        [].tap do |params|
            # Ident : Ident (,)
            # Ident Ident : Ident ... first ident here is a label
            while curr? Identifier_Token or curr? '&', Identifier_Token
                params << Function_Param_Expr.new.tap do |param|
                    if curr? '&', Identifier_Token
                        eat '&'
                        param.merge_scope = true
                    end

                    if curr? Identifier_Token, Identifier_Token
                        param.label = eat Identifier_Token
                    end

                    param.name = eat Identifier_Token

                    if curr? '=' and eat '='
                        param.default_value = parse_block(%W{, \n -> ::}).expressions[0]
                    end

                    if curr? ',' and not (curr?(',', Identifier_Token) or curr?(',', '&', Identifier_Token))
                        raise 'Expecting param after comma in function param declaration'
                    elsif curr? ','
                        eat
                    end
                end
            end
        end
    end


    def make_function_ast

        # ident { (params -> or ::) ... }
        Function_Expr.new.tap do |node|
            if curr? Identifier_Token
                node.name = eat(Identifier_Token, '{')[0].string
            elsif curr? '{' # anonymous function
                eat '{'
            end

            has_params = (peek_until '}').any? do |t|
                t == '->' or t == '::'
            end

            eat_past_newlines
            node.parameters = parse_params if has_params

            eat '->' if curr? '->'
            eat '::' if curr? '::'

            block = parse_block '}'
            eat '}'

            node.compositions = block.compositions
            node.expressions  = block.expressions
        end
    end


    def make_if_else_ast
        Conditional_Expr.new.tap do |it|
            eat 'if' if curr? 'if'
            it.condition      = parse_block("\n").expressions[0]
            it.expr_when_true = parse_block %w(} else elsif elif ef)

            if curr? 'else'
                eat 'else'
                it.expr_when_false = parse_block '}'
                eat '}'
            elsif curr? '}'
                eat '}'
            elsif curr? 'elsif' or curr? 'elif' or curr? 'ef'
                while curr? 'elsif' or curr? 'elif' or curr? 'ef'
                    eat # elsif or elif or ef
                    raise 'Expected condition in the elsif' if curr? "\n" or curr? ";"
                    it.expr_when_false = make_if_else_ast
                end
            else
                raise "\n\nYou messed your if/elsif/else up\n" + debug
            end
        end
    end


    def make_while_ast
        While_Expr.new.tap do |it|
            eat 'while' if curr? 'while'
            it.condition      = parse_block("\n").expressions[0]
            it.expr_when_true = parse_block %w(elswhile else })

            if curr? 'else'
                eat 'else'
                it.expr_when_false = parse_block '}'
                eat '}'
            elsif curr? '}'
                eat '}'
            elsif curr? 'elswhile'
                while curr? 'elswhile'
                    eat # elswhile
                    raise 'Expected condition in the elswhile' if curr? "\n" or curr? ";"
                    it.expr_when_false = make_while_ast
                end
            else
                raise "\n\nYou messed your while/elswhile/else up\n" + debug
            end
        end
    end


    # any nils returned are effectively discarded because the array of parsed expressions is later compacted to get rid of nils.
    def make_ast
        if curr? '{'
            make_function_ast

        elsif curr? '('
            paren      = eat '('
            precedence = precedence_for paren
            parse_expression(precedence).tap do
                eat ')'
            end

        elsif curr? 'while'
            make_while_ast

        elsif curr? 'if'
            make_if_else_ast

        elsif curr? Identifier_Token, '=;'
            make_assignment_ast

        elsif curr? Identifier_Token and curr.object? and not curr? Identifier_Token, '.' # Capitalized identifier. I'm explicitly ignoring the dot here because otherwise all object identifiers will expect an { next
            make_object_ast

        elsif curr? Identifier_Token, %w({ =) and curr.member? # lowercase identifier

            if curr? Identifier_Token, '{'
                make_function_ast
            elsif curr? Identifier_Token, '='
                make_assignment_ast
            end

        elsif (curr? Identifier_Token, '{' or curr? Identifier_Token, '=') and curr.constant? # UPPERCASE identifier
            make_enum_ast

        elsif curr? Identifier_Token, '(' # todo: function calls
            make_function_call_ast

        elsif curr? %w(~ &), Identifier_Token
            Composition_Expr.new.tap do |node|
                node.operator   = eat.string
                node.identifier = eat.string
            end

        elsif curr? Ascii_Token and curr.respond_to?(:unary?) and curr.unary? # %w(- + ~ !)
            make_unary_expr_ast

        elsif curr? String_Token or curr? Number_Token
            make_string_or_number_literal_ast

        elsif curr? Comment_Token
            eat and nil

        elsif curr? %W(, \n) # ignoring the comma allows for expressions separated by commas
            eat and nil

        elsif curr? Symbol_Token
            Symbol_Literal_Expr.new.tap do |node|
                node.string = eat.string
            end

        elsif curr? [Identifier_Token, '@']
            Identifier_Expr.new.tap do |node|
                node.string = eat.string
            end

        else
            raise debug
        end
    end


    # endregion

    def parse_expression starting_precedence = 0
        left = make_ast
        return if not left # \n are eaten and return nil, so we have to terminate this expression early. Otherwise negative numbers are sometimes parsed as BE( - NUM) insteadof UE(-NUM)

        # if token after left is a binary operator, then we build a binary expression
        while tokens?
            if curr? Ascii_Token and curr.binary?
                curr_operator_prec = precedence_for(curr)
                break if curr_operator_prec <= starting_precedence

                left = Binary_Expr.new.tap do |node|
                    node.left     = left
                    node.operator = eat(Ascii_Token).string

                    raise 'Expected expression' if curr? "\n"

                    node.right = parse_expression curr_operator_prec
                end
            elsif curr? '['
                eat '['
                left = Subscript_Expr.new.tap do |node|
                    node.left  = left
                    node.index_expression = parse_expression
                end
                eat ']'
            else
                break
            end
        end

        left
    end


    def parse_until until_token = EOF_Token
        expressions.tap do |s|
            while tokens? and curr != EOF_Token
                if until_token.is_a? Array
                    break if until_token.any? do |t|
                        curr == t
                    end
                else
                    break if curr == until_token
                end

                eaten_this_iteration = []
                if (expr = parse_expression)
                    s << expr
                end
            end
        end.compact
    end
end
