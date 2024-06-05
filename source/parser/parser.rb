# Turns string of code into tokens
class Parser
    require_relative '../lexer/tokens'
    require_relative 'nodes'

    attr_accessor :i, :tokens, :statements


    def initialize tokens = nil
        @statements = []
        @tokens     = tokens
        @i          = 0 # index of current token
    end


    PRECEDENCES = [
        %w(( )),
        %w([ ]),
        %w(!),
        %w(- +), # Unary minus and plus
        %w(**), # Exponentiation
        %w(* / %), # Multiplicative
        %w(+ -), # Additive
        %w(<< >>), # Shift
        %w(< <= > >=), # Relational
        %w(== != === !==), # Equality
        %w(&), # Bitwise AND
        %w(^), # Bitwise XOR
        %w(|), # Bitwise OR
        %w(&&), # Logical AND
        %w(||), # Logical OR
        %w(?:), # Ternary
        %w(= += -= *= /= %= &= |= ^= <<= >>=), # Assignment
        %w(,), # Comma
        %w(.),
    ]


    def precedence_for token
        # PRECEDENCES.find do |_, chars|
        #     chars.include?(token.string)
        # end&.at(0)
        PRECEDENCES.find_index do |chars|
            chars.include?(token.string)
        end
    end


    def last
        @tokens[@i - 1]
    end


    def curr
        raise 'Parser.tokens is nil' unless tokens
        @tokens[@i]
    end


    def remainder
        @tokens[@i..]
    end


    def tokens?
        @i < (@tokens&.length || 0)
    end


    def assert_token token, expected
        raise "Expected #{expected} but got #{token}" unless token == expected
    end


    def assert_condition token, condition
        raise "Unexpected #{token}" if condition == false
    end


    # original version of peek, I don't think it'll be useful now that #peek? exists
    def peek at = 1, length = 1
        @tokens[@i + at, length]
    end


    def peek? * expected
        return false unless remainder

        check = remainder&.reject do |token|
            # reject delimiters except ; and \n
            token == DelimiterToken and token != ';' and token != "\n"
        end[..expected.length - 1]

        return false unless check and not check.empty? # all? returns true for an empty array [].all? so this early return is required

        check.each_with_index.all? do |token, index|
            if expected[index].is_a? Array
                expected[index].any? { |exp| token == exp }
            else
                token == expected[index]
            end
        end
    end


    def eat * expected
        if expected.nil? or expected.empty? or expected.one?
            @i += 1
            return last
        end

        [].tap do |result|
            expected.each do |expect|
                # eg: 'obj', IdentifierToken

                @i += 1 while curr == DelimiterToken and curr != ';' # skip delimiters except ;

                assert_token curr, expect
                result << curr
                @i += 1
            end
        end
    end


    def parse_statements precedence = 0
        left = parse_leaf
        return left unless left

        while tokens? and curr
            break unless curr == SymbolToken and curr.binary?
            # break if curr == SymbolToken and curr.unary?

            curr_prec = precedence_for curr
            break if curr_prec <= precedence

            left = BinaryExprNode.new.tap do |node|
                node.left     = left
                node.operator = eat SymbolToken

                # @todo is this the right way to handle this? what if I want expressions on the next line? maybe some keyword like `\`?
                raise 'Expected expression' if peek? "\n"

                node.right = parse_statements curr_prec
                eat if curr == ']'
            end
        end

        left
    end


    def parse_typed_var_declaration
        VarAssignmentNode.new.tap do |node|
            tokens    = eat IdentifierToken, ':', IdentifierToken
            node.name = tokens[0]
            node.type = tokens[2]

            # eat while curr == "\s"


            if peek? '='
                eat '='
                node.value = parse_statements
            end
        end
    end


    def parse_untyped_var_declaration_or_reassignment
        VarAssignmentNode.new.tap do |node|
            tokens = eat IdentifierToken, '='
            raise 'Expected expression' if peek? "\n"

            node.name  = tokens[0]
            node.value = parse_statements
        end
    end


    def parse_inferred_var_declaration
        VarAssignmentNode.new.tap do |node|
            tokens = eat IdentifierToken, ':='
            raise 'Expected expression' if peek? "\n"

            node.name = tokens[0]

            # ( expression )
            # ""
            # number
            # identifier
            node.value = parse_statements
            # node.type = tokens[2]
        end
    end


    def parse_string_or_number_literal
        if curr == StringToken
            StringLiteralNode.new
        else
            NumberLiteralNode.new
        end.tap do |literal|
            literal.token = eat
        end
    end


    def parse_unary_expr
        UnaryExprNode.new.tap do |node|
            node.operator = eat SymbolToken
            node.operand  = parse_statements precedence_for(node.operator)
        end
    end


    def parse_object_declaration
        # if first statement of program then it's top-level object declaration
        #    obj Ident > Ident (imp Ident, ...) ({) \n
        #    (imp Ident, ...)
        #
        # otherwise
        #    obj Ident > Ident (imp Ident, ...) ({) \n
        #       (imp Ident, ...)
        #    }
        ObjectDeclNode.new.tap do |node|
            node.type = eat('obj', IdentifierToken).last

            if peek? '>', IdentifierToken
                node.base_type = eat('>', IdentifierToken).last
            end

            eat while curr == DelimiterToken # { or \n or both

            # compositions
            while peek? 'imp'
                node.compositions << eat('imp', IdentifierToken).last

                while curr == ',' and peek[0] == IdentifierToken
                    node.compositions << eat(',', IdentifierToken).last
                end

                raise "Unexpected `,` without additional compositions" if curr == ','
                eat while curr == DelimiterToken # { or \n or both
            end

            # body or empty obj termination
            if peek? %w(; }) # delimiter for empty object
                eat
            else
                eat while curr == DelimiterToken # { or \n or both
                node.statements = parse_block
                eat if peek? %w(} end)
            end
        end
    end


    def parse_block until_token = %w(} end)
        parser = Parser.new remainder
        stmts  = parser.parse until_token
        @i     += parser.i
        stmts
    end


    def parse_function_call
        def parse_args
            # Ident: Expr (,)
            # Expr (,)
            [].tap do |params|
                while peek?(Token) and curr != ')'
                    params << FuncArgNode.new.tap do |param|
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


        FuncCallNode.new.tap do |node|
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
                    params << FuncParamNode.new.tap do |param|
                        if peek? IdentifierToken, IdentifierToken
                            param.label = eat IdentifierToken
                            param.name  = eat IdentifierToken
                        else
                            param.name = eat IdentifierToken
                        end

                        if peek? ':'
                            eat ':'
                            param.type = eat IdentifierToken
                        else
                            # untyped param
                        end

                        if peek? ',' and not peek?(',', IdentifierToken)
                            raise 'Expecting param after comma in function param declaration'
                        elsif peek? ','
                            eat
                        end

                        # eat ',' if peek? ','
                    end
                end
            end
        end


        def parse_return_type
            if peek? %w(: -> >> ::), IdentifierToken
                eat # : or -> or >> or ::
                eat IdentifierToken
            end
        end


        FuncDeclNode.new.tap do |node|
            node.name = eat('fun', IdentifierToken).last

            if peek? %w(: -> >> ::), IdentifierToken
                node.return_type = parse_return_type

            elsif peek? '(' # params
                eat '('
                node.parameters = parse_params
                eat ')'
                node.return_type = parse_return_type

            elsif peek? IdentifierToken
                node.parameters  = parse_params
                node.return_type = parse_return_type

            end

            if peek? "\n" or peek? "{"
                eat while peek? DelimiterToken or peek? '{'
                node.statements = parse_block

            end

            if peek? %w(; } end)
                eat
            else
                raise 'Expected } or end' unless curr == '}' or curr == 'end'
            end
        end
    end


    def parse_leaf
        if peek? '('
            eat '('
            parse_statements.tap do
                eat ')'
            end

        elsif peek? %w({ }) # for blocks that are not handled as part of other constructs. like just a random block surrounded by { and }
            eat and nil

        elsif peek? CommentToken
            eat and nil

        elsif peek? SymbolToken and curr.respond_to?(:unary?) and curr.unary? # %w(- + ~ !)
            parse_unary_expr

        elsif peek? 'fun', IdentifierToken
            parse_function_declaration

        elsif peek? 'obj', IdentifierToken
            parse_object_declaration

        elsif peek? IdentifierToken, ':='
            parse_inferred_var_declaration

        elsif peek? IdentifierToken, ':', IdentifierToken
            parse_typed_var_declaration

        elsif peek? IdentifierToken, '='
            parse_untyped_var_declaration_or_reassignment

        elsif peek? IdentifierToken, '('
            # @todo function calls without parens
            parse_function_call

        elsif peek? StringToken or peek? NumberToken
            parse_string_or_number_literal

        elsif peek? DelimiterToken # don't care about delimiters that weren't already handled by the other cases
            eat and nil

        elsif peek? IdentifierToken
            IdentExprNode.new.tap do |node|
                node.name = eat IdentifierToken
            end

        else
            raise "\n\nUnhandled `#{curr}` in code:\n\n#{remainder.map(&:to_s)}"
        end
    end


    def parse until_token = EOFToken
        @statements = []
        while tokens? and curr != EOFToken
            if until_token.is_a? Array
                break if until_token.any? do |t|
                    curr == t
                end
            else
                break if curr == until_token
            end

            @statements << parse_statements
        end
        @statements.compact
    end
end
