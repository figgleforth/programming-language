# Turns string of code into tokens
class Parser
    require_relative '../lexer/tokens'
    require_relative 'ast'

    attr_accessor :i, :buffer, :parsed_expressions


    def initialize buffer = []
        @parsed_expressions = []
        @buffer             = buffer
        @i                  = 0 # index of current token
    end


    def to_ast
        Program.new.tap do |program|
            program.expressions = parse_until(EOFToken)
        end
    end


    # region Parsing Helpers

    # makes a new Parser and sets its tokens to the current remainder
    def new_parser_with_remainder_as_buffer
        Parser.new remainder
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
            [19, %w(.)],
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
    def peek? * sequence
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
                raise "\n\nExpected #{sequence[0]} but got #{eaten}\n\ncurrent:\n\t#{curr.inspect}\n\nprev:\n\t#{@buffer[@i - 1].inspect}\n\nremainder:\n\t#{remainder.map(&:to_s)}\n\nexpressions:\n\t#{parsed_expressions}" unless eaten == sequence[0]
            end
            @i    += 1
            return eaten
        end

        [].tap do |result|
            # sequence =
            #   eat '}'
            #   eat %w(} end)
            sequence.each do |expected|
                raise "Expected #{expected} but got #{curr}" unless curr == expected

                result << curr
                @i += 1
            end
        end
    end


    # endregion

    # region Sequence Parsing

    def make_typed_var_decl_ast
        AssignmentExpr.new.tap do |node|
            tokens    = eat IdentifierToken, ':', IdentifierToken
            node.name = tokens[0]
            node.type = tokens[2]

            if peek? '='
                eat '='

                if peek? %W(; \n)
                    raise "Expected expression after ="
                end
                node.value = parse_expression
            end
        end
    end


    def make_assignment_ast
        AssignmentExpr.new.tap do |node|
            tokens = eat IdentifierToken, '='

            if peek? %W(; \n)
                code = (tokens << curr).join(' ')
                raise "Expected expression after `#{tokens[1]}` but got `#{curr}` in\n\n```\n#{code}\n```"
            end

            node.name  = tokens[0]
            node.value = parse_expression
        end
    end


    def parse_inferred_var_declaration
        AssignmentExpr.new.tap do |node|
            tokens = eat IdentifierToken, ':='
            raise 'Expected expression' if peek? "\n"

            node.name  = tokens[0]
            node.value = parse_expression
            # node.type= is done in a different stage
        end
    end


    def parse_string_or_number_literal
        if curr == StringToken
            StringExpr.new
        else
            NumberExpr.new
        end.tap do |literal|
            literal.token = eat
        end
    end


    def parse_unary_expr
        UnaryExpr.new.tap do |node|
            node.operator   = eat SymbolToken
            node.expression = parse_expression 6 # this cannot use #precedence_for because it would return the same precedence as the binary operators of the same symbol, but we need to be able to be distinguish between the unary. there's probably a better way to do this, but who cares.
        end
    end


    def parse_object_declaration
        # if first statement of program then it's top-level object declaration
        #    obj Ident > Ident (inc Ident, ...) ({) \n
        #    (inc Ident, ...)
        #
        # otherwise
        #    obj Ident > Ident (inc Ident, ...) ({) \n
        #       (inc Ident, ...)
        #    }
        ObjectExpr.new.tap do |node|
            node.type = eat('obj', IdentifierToken).last&.string

            if peek? '>', IdentifierToken

                node.base_type = eat('>', IdentifierToken).last&.string
            end

            eat while peek? %W({ \n) # if we see \n or { then there needs to be a body. otherwise ; is expected

            # api compositions
            while peek? 'inc' and eat
                puts "curr #{curr} ident? #{curr == IdentifierToken}"
                node.compositions << eat(IdentifierToken)

                while peek? ',', IdentifierToken
                    node.compositions << eat(',', IdentifierToken).last
                end

                raise "Unexpected `,` without additional `inc`s" if curr == ','
                eat while curr == "\n"
            end

            # body or empty obj termination
            if peek? %w(; }) # empty object, no body
                eat
            else
                node.statements = parse_block %w(} end)

                if peek? %w(} end)
                    eat
                else
                    raise "expected obj to be closed with } or end" unless parsed_expressions.empty?
                end
            end
        end
    end


    def parse_block until_token = %w(} end)
        parser = new_parser_with_remainder_as_buffer
        stmts  = parser.parse_until until_token
        @i     += parser.i
        stmts || []
    end


    def make_function_call_ast
        def parse_args
            # Ident: Expr (,)
            # Expr (,)
            [].tap do |params|
                while peek?(Token) and curr != ')'
                    params << FunctionArgExpr.new.tap do |param|
                        if peek? IdentifierToken, ':' #, Token
                            param.label = eat IdentifierToken
                            eat ':'
                        end

                        param.expression = if peek? Token, ','
                            parse_block ','
                        elsif peek? Token, ')'
                            parse_block ')'
                        else
                            parse_block %w[, )]
                        end.first
                    end

                    eat if peek? ','
                end
            end
        end

        # todo) how to handle spaces in place of parens like Ruby?
        FunctionCallExpr.new.tap do |node|
            node.function_name = eat IdentifierToken
            eat '('
            node.arguments = parse_args
            eat ')'
        end
    end


    def parse_function_declaration
        def parse_params
            [].tap do |params|
                # Ident : Ident (,)
                # Ident Ident : Ident ... first ident here is a label
                while peek? IdentifierToken
                    params << FunctionParamExpr.new.tap do |param|
                        if peek? IdentifierToken, IdentifierToken
                            param.label = eat IdentifierToken
                        end

                        param.name = eat IdentifierToken

                        if peek? ':' # without this it's an untyped param
                            eat ':'
                            param.type = eat IdentifierToken
                        end

                        if peek? ',' and not peek?(',', IdentifierToken)
                            raise 'Expecting param after comma in function param declaration'
                        elsif peek? ','
                            eat
                        end
                    end
                end
            end
        end


        def parse_return_type
            if peek? %w(: -> >>), IdentifierToken
                eat # : or -> or >> are allowed
            end
            eat IdentifierToken
        end


        # Functions require parens when params are present
        #   fun ident ( params ) type \n (...) end
        #   fun ident type \n (...) end

        FunctionExpr.new.tap do |node|
            eat # fun/def. I like both so both are allowed

            # ident or operator overload
            if peek? [SymbolToken, IdentifierToken]
                node.name = eat
            else
                raise "Unexpected fun ident #{curr.inspect}"
            end

            if peek? '('
                eat '('
                node.parameters = parse_params
                eat ')'
            end

            # ...) ->/>> ident
            # ...) ->/>> ident

            if not peek? "\n" # body
                node.return_type = parse_return_type
            end

            if peek? %W({ \n)
                eat while peek? %W({ \n)
                node.statements = parse_block %w(} end)
                eat while peek? %W(\n)
            end

            if peek? %w(; } end)
                eat
            else
                # if not peek? "\n" # body
                #     node.return_type = parse_return_type
                # end
                #
                # if peek? %W({ \n)
                #     eat while peek? %W({ \n)
                #     node.statements = parse_block %w(} end)
                #     eat while peek? %W(\n)
                # else
                #     raise "expected fun to be closed with ; or } or end"
                # end

                raise "expected fun to be closed with ; or } or end"
            end
        end
    end


    # endregion

    # Ident := obj (> Base) ... \n }/end
    def make_object_ast is_api_decl = false
        ObjectExpr.new.tap do |node|
            node.is_api = is_api_decl

            node.type = eat(IdentifierToken).string

            if peek? '>', IdentifierToken
                node.base_type = eat('>', IdentifierToken).last&.string
            end

            eat ':='
            keyword = is_api_decl ? 'api' : 'obj'
            eat keyword

            eat while peek? "\n" # if we see \n or { then there needs to be a body. otherwise ; is expected

            # api compositions
            while peek? 'inc' and eat
                node.compositions << eat(IdentifierToken)

                while peek? ',', IdentifierToken
                    node.compositions << eat(',', IdentifierToken).last
                end

                raise "Unexpected `,` without additional `inc`s" if curr == ','
                eat while curr == "\n"
            end

            if peek? %w(; } end) # body or empty object termination
                eat
            else
                node.statements = parse_block %w(} end)

                if peek? %w(} end)
                    eat
                else
                    raise "expected obj to be closed with } or end" unless parsed_expressions.empty?
                end
            end
        end
    end


    def make_function_ast
        FunctionExpr.new.tap do |node|
            # Ident := fun
            node.name = eat(IdentifierToken, ':=', 'fun')[0].string

            # todo) function params

            eat if peek? '{'
            eat while peek? "\n" # if we see \n or { then there needs to be a body. otherwise ; is expected

            if peek? %w(; } end) # body or empty function termination
                eat
            else
                node.statements = parse_block %w(} end)

                if peek? %w(} end)
                    eat
                else
                    raise "expected fun to be closed with } or end"
                end
            end
        end
    end


    # any nils returned are effectively discarded because the array of parsed expressions is later compacted to get rid of nils.
    def make_ast
        if peek? '('
            open_paren = eat '('
            precedence = precedence_for(open_paren)
            parse_expression(precedence).tap do
                eat ')'
            end

        elsif peek?(IdentifierToken, '>', IdentifierToken, ':=', 'obj') or peek?(IdentifierToken, ':=', 'obj')
            make_object_ast

        elsif peek?(IdentifierToken, '>', IdentifierToken, ':=', 'api') or peek?(IdentifierToken, ':=', 'api')
            make_object_ast true

        elsif peek? IdentifierToken, ':=', :fun
            make_function_ast

        elsif peek? IdentifierToken, ':', IdentifierToken
            make_typed_var_decl_ast

        elsif peek? IdentifierToken, '='
            make_assignment_ast

        elsif peek? IdentifierToken, '('
            make_function_call_ast

        elsif peek? SymbolToken and curr.respond_to?(:unary?) and curr.unary? # %w(- + ~ !)
            parse_unary_expr

        elsif peek? StringToken or peek? NumberToken
            parse_string_or_number_literal

        elsif peek? [CommentToken, DelimiterToken]
            eat and nil

        elsif peek? ',' # allows for comma separated statements
            eat and nil

        elsif peek? [IdentifierToken, '@']
            IdentifierExpr.new.tap do |node|
                node.name = eat.string
            end

        else
            raise "\n\nUnhandled:\n\t#{curr.inspect}\n\nRemainder:\n\t#{remainder.map(&:to_s)}\n\nParsed Expressions:\n\t#{parsed_expressions}"
        end
    end


    def parse_expression starting_precedence = 0
        left = make_ast # parse_ast

        # if token after left is a binary operator, then we build a binary expression
        while tokens?
            break unless curr == SymbolToken and curr.binary?

            curr_operator_prec = precedence_for curr
            break if curr_operator_prec <= starting_precedence

            left = BinaryExpr.new.tap do |node|
                node.left     = left
                node.operator = eat SymbolToken

                # todo: handle multiline statements?
                raise 'Expected expression' if peek? "\n"

                node.right = parse_expression curr_operator_prec
                eat if curr == ']' # todo: is this fine? it gives me a creepy feeling.
            end
        end

        left
    end


    def parse_until until_token = EOFToken
        expressions = []
        while tokens? and curr != EOFToken
            if until_token.is_a? Array
                break if until_token.any? do |t|
                    curr == t
                end
            else
                break if curr == until_token
            end

            expr = parse_expression
            if expr
                expressions << expr
                parsed_expressions << expr # this is used to determine whether the first encountered obj declaration requires a closing } or end keyword
            end
        end
        expressions.compact
    end
end
