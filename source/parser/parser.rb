# Turns string of code into tokens
class Parser
    require_relative '../lexer/tokens'
    require_relative 'ast'

    attr_accessor :i, :buffer, :statements


    def initialize buffer = []
        @statements = []
        @buffer     = buffer
        @i          = 0 # index of current token
    end


    def to_ast
        Ast_Block.new.tap do |block|
            block.expressions = parse_until EOFToken
        end
    end


    # region Parsing Helpers

    # makes a new Parser and sets its tokens to the current remainder
    def new_parser_with_remainder_as_buffer
        Parser.new remainder
    end


    def debug
        "UNHANDLED TOKEN:\n\t#{curr.inspect}
        REMAINING:\n\t#{remainder.map(&:to_s)}
        PARSED SO FAR:\n\t#{statements}"
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
        raise 'Parser.tokens is nil' unless buffer

        index = ahead.clamp(0, @buffer.count)
        @buffer[@i + index]
    end


    # looks ahead `count` tokens, without consuming them. cannot peek backwards
    def peek_many count = 2
        raise 'Parser.tokens is nil' unless buffer

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
                raise "\n\nExpected #{sequence[0]} but got #{eaten}\n\ncurrent:\n\t#{curr.inspect}\n\nprev:\n\t#{@buffer[@i - 1].inspect}\n\nremainder:\n\t#{remainder.map(&:to_s)}\n\nexpressions:\n\t#{statements}" unless eaten == sequence[0]
            end
            @i    += 1
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
                    progress  = "\n\nPARSED SO FAR:\n\t#{statements[3..]}"
                    raise "#{current}#{remaining}#{progress}" unless curr == expected
                end

                result << curr
                @i += 1
            end
        end
    end


    # endregion

    # region Sequence Parsing

    def parse_block until_token = '}'
        parser = new_parser_with_remainder_as_buffer
        stmts  = parser.parse_until until_token
        @i     += parser.i
        stmts || []
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

            if curr? ';'
                eat ';'
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
                progress  = "PARSED SO FAR:\n\t#{statements}"
                raise "\n\n#{current}\n\n#{unhandled}\n\n#{remaining}\n\n#{progress}"
            end

        end
    end


    def make_enum_ast
        Enum_Expr.new.tap do |node|
            node.name = eat(Identifier_Token).string
            eat '{'

            eat_past_newlines

            # IDENT (= expr), ...
            # IDENT, ...
            # todo: nested enums like A { B {} }
            until curr? '}'
                if curr? Identifier_Token and not curr.constant?
                    raise 'Enums must be completely capitalized'
                end

                node.constants << Enum_Constant.new.tap do |constant|
                    eat_past_newlines
                    constant.name = eat Identifier_Token
                    if curr? '=' and eat '='
                        if not curr? [Number_Token, String_Token]
                            raise "Enum constants can only have string or number values"
                        end
                        constant.expression = parse_block(%W(, \n))[0]
                    end
                    eat_past_newlines
                end

                eat if curr? %W(, \n)
            end

            eat '}'
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
            node.operator   = eat AsciiToken
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
                        end.first
                    end

                    eat if curr? ','
                end
            end
        end


        # todo) how to handle spaces in place of parens like Ruby?
        Function_Call_Expr.new.tap do |node|
            node.function_name = eat Identifier_Token
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
                while curr? Identifier_Token
                    node.compositions << eat(Identifier_Token).string

                    if curr? ','
                        if not curr? ',', Identifier_Token
                            raise "Unexpected `,` without additional `inc`s" if curr == ','
                        end
                        eat ','
                    end
                end
            end

            eat '{'
            block = parse_block '}'

            node.expressions = block.select do |s|
                s != Merge_Scope_Identifier_Expr
            end

            node.merge_scopes = block.select do |s|
                s == Merge_Scope_Identifier_Expr
            end

            eat '}'
        end
    end


    def make_function_ast
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
                            param.default_value = parse_block(%W{, \n -> ::})[0]
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


        # ident { (params -> or ::) ... }
        Function_Expr.new.tap do |node|
            if curr? Identifier_Token
                node.name = eat(Identifier_Token, '{')[0].string
            elsif curr? '{' # anonymous function
                eat '{'
            end

            eat_past_newlines

            has_params      = (peek_until '}').any? do |t|
                t == '->' or t == '::'
            end

            node.parameters = parse_params if has_params

            eat '->' if curr? '->'
            eat '::' if curr? '::'

            eat_past_newlines

            node.expressions = parse_block '}'
            eat '}'
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

        elsif curr? Identifier_Token and curr.object? # Capitalized identifier
            make_object_ast

        elsif curr? Identifier_Token, %w({ =) and curr.member? # lowercase identifier

            if curr? Identifier_Token, '{'
                make_function_ast
            elsif curr? Identifier_Token, '='
                make_assignment_ast
            end

        elsif curr? Identifier_Token, '=' and curr.constant? # UPPERCASE identifier
            raise 'CONST = currently not supported yet'

        elsif curr? Identifier_Token, '{' and curr.constant? # UPPERCASE identifier
            make_enum_ast

        elsif curr? Identifier_Token, '(' # todo: function calls
            raise 'function calls are not supported yet'
            # it could either be a function call or a function declaration. it depends on whether (> ident (:= fun)) is present on the same line and immediately after the closing parens.
            # Something to think about is, could there ever be a case where a function call expression inside another expression, like a parenthesized list, cannot be differentiated from a function declaration?

            # rough idea:
            # 1) parse parenthesized expression
            # 2) peek?(> ident) or peek?(:= fun) ? declaration : call

            # make_function_ast
            # make_function_call_ast
            # eat and nil

        elsif curr? '&', Identifier_Token
            Merge_Scope_Identifier_Expr.new.tap do |node|
                node.identifier = eat('&', Identifier_Token)[1].string
            end

        elsif curr? AsciiToken and curr.respond_to?(:unary?) and curr.unary? # %w(- + ~ !)
            make_unary_expr_ast

        elsif curr? String_Token or curr? Number_Token
            make_string_or_number_literal_ast

        elsif curr? CommentToken
            eat and nil

        elsif curr? %W(, ; \n)
            # allows for comma separated statements, a nil statement
            eat and nil

        elsif curr? SymbolToken
            Symbol_Literal_Expr.new.tap do |node|
                node.token = eat
            end

        elsif curr? [Identifier_Token, '@']
            Identifier_Expr.new.tap do |node|
                node.token = eat
            end

        else
            unhandled = "UNHANDLED TOKEN:\n\t#{curr.inspect}"
            remaining = "REMAINING:\n\t#{remainder.map(&:to_s)}"
            progress  = "PARSED SO FAR:\n\t#{statements}"
            raise "\n\n#{unhandled}\n\n#{remaining}\n\n#{progress}"
        end
    end


    # endregion

    def parse_expression starting_precedence = 0
        left = make_ast
        return if not left # \n are eaten and return nil, so we have to terminate this expression early. Otherwise negative numbers are sometimes parsed as BE( - NUM) insteadof UE(-NUM)

        # if token after left is a binary operator, then we build a binary expression
        while tokens?
            break unless curr == AsciiToken and curr.binary?

            curr_operator_prec = precedence_for curr
            break if curr_operator_prec <= starting_precedence

            left = Binary_Expr.new.tap do |node|
                node.left     = left
                node.operator = eat AsciiToken

                # todo: handle multiline statements? I think usually it's a backslash that the lexer treats like a "skip newline" thing, so it basically combines the two lines. I'm leaving the comment here because I'm more likely to be working in this class than in the lexer.
                raise 'Expected expression' if curr? "\n"

                node.right = parse_expression curr_operator_prec
                # eat if curr == ']' # todo: is this fine? it feels wrong
            end
        end

        left
    end


    def parse_until until_token = EOFToken
        statements.tap do |s|
            while tokens? and curr != EOFToken
                if until_token.is_a? Array
                    break if until_token.any? do |t|
                        curr == t
                    end
                else
                    break if curr == until_token
                end

                if (expr = parse_expression)
                    s << expr
                end
            end
        end.compact
    end
end
