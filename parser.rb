require './frontend/node'
require './scanner'

class Parser
    attr_reader :tokens, :program, :ast, :self_declaration_count

    def initialize file_to_read = nil
        scanner = Scanner.new file_to_read
        scanner.scan
        @self_declaration_count = 0
        @ast                    = []
        @tokens                 = scanner.tokens
        @program                = Program.new(file_to_read)
    end

    # region Helpers
    def already_defined_a_self_declaration?
        @self_declaration_count > 0 || @ast.any? do |node|
            node.a?(ObjectDeclaration) && node.type == :self
        end
    end

    def reached_end?
        @tokens.empty?
    end

    def curr_token
        @tokens[0]
    end

    def assert_curr_token type
        raise "Expected #{type} but found #{curr_token.type}" if curr_token.type != type
    end

    def peek number_of_tokens = 1, accumulate = false
        return @tokens[1..number_of_tokens] if accumulate
        @tokens[number_of_tokens]
    end

    def peek_until type
        tokens = []

        distance = 1
        curr     = peek(distance)
        while !reached_end? && curr.type != type
            tokens << curr
            distance += 1
            curr     = peek(distance)
        end

        # If the loop ends due to reaching the end of input, and the last token is not :block_end, add the :block_end token to the tokens list.
        tokens << curr if curr.type == :block_end && !reached_end? && curr.type != type

        tokens
    end

    def node_for_object_declaration identifier, type
        node = ObjectDeclaration.new(identifier, type)

        if curr_token.type == :binary_operator && curr_token.word == '+'
            compositions = eat_until_and_consume(:newline).reject { |token| token.type == :comma }

            # todo) improve this error
            raise "Compositions must be identifiers" unless compositions.all? { |token| token.type == :identifier }

            node.compositions = compositions.map do |token|
                # todo) make them into nodes?
                token.word
            end
        end

        node
    end

    # endregion

    # region Identifying

    def assignment?
        inferred_assignment? || explicit_assignment?
    end

    def inferred_assignment?
        curr_token.type == :identifier &&
          peek(1).type == :inferred_assignment_operator
    end

    # todo) too complex, simplify it
    def explicit_assignment?
        curr_token.type == :identifier &&
          peek(1).type == :colon &&
          (peek(2).type == :identifier || peek(2).type == :builtin_type)
    end

    def object_declaration?
        curr_token.type == :object_keyword && peek(1).type == :identifier
    end

    def self_declaration?
        curr_token.type == :self_keyword && peek(1).type == :colon && peek(2).type == :object_keyword && peek(3).type == :identifier
    end

    def operator?
        # todo) rest of the operators
        %w().include?(curr_token.word) && curr_token.type == :binary_operator
    end

    # endregion

    # region Eating
    def eat number_of_tokens = 1
        tokens = @tokens[0..number_of_tokens - 1]
        number_of_tokens.times { @tokens.shift }
        tokens # in case I want to do something with them
    end

    def eat_until_and_stop_at type
        tokens = []
        while !reached_end? && curr_token.type != type
            eat
            tokens << curr_token if curr_token.type != type
        end
        tokens
    end

    def eat_until_and_consume type
        tokens = eat_until_and_stop_at type

        # puts "previous tokens: #{tokens.last(2)}"
        # puts "curr_token.type: #{curr_token.type}"
        # puts "expected type: #{type}"
        assert_curr_token type

        # fix) hopefully consuming all newlines doesn't cause issues
        eat until curr_token.type != type if type == :newline
        tokens
    end

    def eat_object_declaration
        # eats `obj` `identifier`
        identifier = eat(2).last
        node       = node_for_object_declaration :self, identifier.word
        @program.statements << node
    end

    def eat_self_declaration
        raise "Only one self declaration is allowed per file" if already_defined_a_self_declaration?

        # self, :, obj, identifier
        identifier = eat(4).last

        node = node_for_object_declaration :self, identifier.word

        @ast << node
        @program.statements << node
        @self_declaration_count += 1
    end

    def eat_constructor
        # curr_token.type == :new_keyword
        node = ProcedureDeclaration.new(eat.last.word, :new)
        # puts "constructor", node.inspect
        # eat
        @program.statements << node
    end

    def eat_method
        # curr_token.type == :new_keyword
        node = ProcedureDeclaration.new(eat.last.word, :def)
        # puts "method", node.inspect

        @program.statements << node
    end

    # this is called precedent climbing. I basically copied https://eli.thegreenplace.net/2012/08/02/parsing-expressions-by-precedence-climbing
    def eat_assignment
        data = if explicit_assignment?
                   # identifier, :, identifier/type, =
                   eat 4
               elsif inferred_assignment?
                   # identifier, :=
                   eat 2
               end

        def parse_atom
            if curr_token.type == :open_paren
                eat
                value = parse_expression 1
                assert_curr_token :close_paren
                eat
                value
            elsif curr_token.type == :binary_operator
                assert_curr_token :binary_operator
            elsif curr_token.type == :number
                value = curr_token
                eat
                Literal.new(value.word.to_i)
            elsif curr_token.type == :identifier
                raise 'Implement identifier parsing within expression'
            end
        end

        def parse_expression(precedence = 0)
            operator_precedences = {
              '+': 1,
              '-': 1,
              '*': 2,
              '/': 2,
              '%': 2,
              '^': 3
            }

            left = parse_atom

            while true
                curr_precedence = operator_precedences[curr_token.word.to_sym]
                if curr_token.type != :binary_operator || curr_precedence < precedence
                    break
                end

                assert_curr_token :binary_operator
                operator            = curr_token
                operator_precedence = curr_precedence
                min_precedence      = operator_precedence
                min_precedence      += 1 if operator.word == '^'

                eat
                right = parse_expression min_precedence
                left  = BinaryExpression.new operator.word, left, right
            end

            left
        end

        identifier = data[0]
        node       = VariableDeclaration.new(identifier.word)
        node.type  = data[2].word unless data.last&.type == :inferred_assignment_operator

        node.value = parse_expression

        @ast << node
        @program.statements << node
    end
    # endregion

    def parse
        until reached_end?
            if self_declaration?
                eat_self_declaration
            elsif object_declaration?
                eat_object_declaration
            elsif assignment?
                eat_assignment
            elsif curr_token.type == :new_keyword
                eat_constructor
            elsif curr_token.type == :def_keyword
                eat_method
            elsif [:newline, :eof].include?(curr_token.type)
                eat
            else
                puts 'Eating unrecognized token', curr_token.inspect
                eat # eat here or?
            end
        end
    end
end

parser = Parser.new './hatch/parse_test.is'

parser.parse
puts parser.program.inspect
