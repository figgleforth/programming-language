require_relative 'frontend/node'
require_relative 'scanner'
require_relative 'parser_helper'
require 'ostruct'

class Parser
    include ParserHelper

    attr_reader :tokens, :statements, :variables, :methods, :objects

    def initialize
        @statements = []
        @tokens = []
        @variables = []
        @methods = []
        @objects = []
    end

    # def start! file_to_read = nil
    #     @parsed_source          = ObjectDeclaration.new
    #     @parsed_source.filename = file_to_read
    #
    #     scanner = Scanner.new file_to_read
    #     scanner.scan
    #     @tokens = parse scanner.tokens
    # end

    # region Identifying

    def inferred_assignment? tokens
        tokens[0].type == :identifier &&
          tokens[1].type == :inferred_assignment_operator
    end

    # todo) too complex, simplify it
    def explicit_assignment? tokens
        tokens[0].type == :identifier &&
          tokens[1].type == :colon &&
          (tokens[2].type == :identifier || tokens[2].type == :builtin_type)
    end

    def object_declaration? tokens
        tokens[0].type == :object_keyword && tokens[1].type == :identifier
    end

    def self_declaration? tokens
        tokens[0].type == :self_keyword && tokens[1].type == :colon && tokens[2].type == :object_keyword && tokens[3].type == :identifier
    end

    def operator? tokens
        # todo) rest of the operators
        %w().include?(tokens[0].word) && tokens[0].type == :binary_operator
    end

    # endregion

    # region Eating

    def eat_object_declaration tokens
        identifier = eat(tokens, 2).last # obj, identifier
        node = ObjectDeclaration.new
        node.name = identifier.word
        compositions = make_compositions_object tokens, identifier.word, :self
        node.compositions = compositions
        if @scoped_statements
            @scoped_statements << node
        else
            @objects << node
            @statements << node
        end

        # todo) since @statements, etc is shared within this parser, I have to instantiate a new one here. I could refactor it so that I also pass @statements to the parser, but that's more work than I feel like doing right now
        parser = Parser.new
        tokens = parser.parse(tokens, :end_keyword)
        node.statements = parser.statements

        eat tokens # end keyword

        tokens
    end

    def eat_self_declaration tokens
        # raise "Only one self declaration is allowed per file" if @parsed_source.explicitly_declared
        # self, :, obj, identifier
        identifier = eat(tokens, 4).last
        self_declaration = SelfDeclaration.new identifier.word
        self_declaration.compositions = make_compositions_object tokens, :self, identifier.word

        statements << self_declaration
        tokens
    end

    def eat_constructor_declaration tokens
        node = MethodDeclaration.new(eat(tokens).last, :new)
        if @scoped_statements
            @scoped_statements << node
        else
            @methods << node
            @statements << node
        end
        tokens
    end

    def eat_method_declaration tokens
        def eat_signature(method_declaration, tokens)
            # possible upcoming tokens:
            #  : return_type(params...)
            #  : return_type
            #  : (params...)
            #  \n

            # if  : then signature exists
            # if \n then no signature

            if tokens[0].type == :newline
                eat(tokens) and return method_declaration
            end

            eat(tokens) # :

            if [:identifier, :builtin_type].include?(tokens[0].type)
                method_declaration.returns = eat(tokens).last
            end

            # puts "method declaration so far: #{method_declaration.inspect}"
            # puts "tokens: #{tokens.inspect}"

            # possible upcoming tokens:
            #  (params...)
            #  \n

            if tokens[0].type == :newline
                eat(tokens) and return method_declaration
            end

            assert tokens[0], :open_paren
            eat(tokens) # (

            # these should now be the params
            # Eat 2
            # If first and last are identifier then first must be label
            # If last is : then there is no label
            #
            # If label, eat 2 to get to type
            # If not label, eat 1 to get to type

            until reached_end? tokens
                break if [:close_paren, :newline, :eof].include?(tokens[0].type)

                parameter = Param.new.tap do |param|
                    if tokens[0].type == :identifier && tokens[1].type == :identifier # label identifier: type (4 tokens)
                        param.label = eat(tokens).last
                        param.name_token = eat(tokens).last
                        param.type = eat(tokens, 2).last
                    elsif tokens[0].type == :identifier && tokens[1].type == :colon # identifier: type (3 tokens)
                        param.name = eat(tokens).last
                        param.type = eat(tokens, 2).last
                    end

                    if tokens[0].type == :assignment_operator
                        param.default_value = eat(tokens, 2).last
                    end

                    eat(tokens) # ,
                end

                method_declaration.parameters << parameter
                eat(tokens) if tokens[0].type == :comma
            end
            method_declaration
        end

        data = eat(tokens, 2) # def, identifier
        method_node = MethodDeclaration.new data.last, :def
        method_node = eat_signature method_node, tokens

        # at this point, the entire signature is consumed

        eat(tokens) if tokens[0].type == :newline

        # parse the body of the method
        # this is where scope comes in? GPT, I need your help. I'm not sure how to do this. Basically at this point we are parsing the body of a method. How do I
        @scoped_statements = []
        parse tokens, :end_keyword # recurse through parse again, but this time when adding to statements, we check if a scoped_statement array exists and add to it instead of the regular statements.
        method_node.statements = @scoped_statements
        @scoped_statements = nil
        # have to set this to nil to prevent the next method from adding to the scoped statements. todo) abstract

        assert tokens[0], :end_keyword
        eat(tokens)

        # puts "method node: #{method_node.inspect}"

        if @scoped_statements
            @scoped_statements << method_node
        else
            @methods << method_node
            @statements << method_node
        end
        tokens
    end

    def eat_method_call tokens
        puts "function call"
        eat tokens, 2 # identifier, (
    end

    # this is called precedent climbing. I basically copied https://eli.thegreenplace.net/2012/08/02/parsing-expressions-by-precedence-climbing
    def eat_assignment tokens
        data = if explicit_assignment?(tokens)
                   # identifier, :, identifier/type, =
                   eat tokens, 4
               elsif inferred_assignment?(tokens)
                   # identifier, :=
                   eat tokens, 2
               end

        def parse_atom tokens
            if tokens[0].type == :open_paren
                eat(tokens)
                value = parse_expression tokens, 1
                assert tokens[0], :close_paren
                eat(tokens)
                value
            elsif tokens[0].type == :binary_operator
                assert tokens[0], :binary_operator
            elsif tokens[0].type == :number
                value = tokens[0]
                eat(tokens)
                Literal.new(value)
            elsif tokens[0].type == :identifier
                value = VariableReference.new(tokens[0])
                if tokens[1].type == :open_paren
                    method = tokens[0]
                    eat 2 # identifier, (
                    value = Literal.new(method, :method)
                end
                value
            end
        end

        def parse_expression(tokens, precedence = 0)
            operator_precedences = {
              '+': 1,
              '-': 1,
              '*': 2,
              '/': 2,
              '%': 2,
              '^': 3
            }

            left = parse_atom tokens

            while true
                curr_precedence = operator_precedences[tokens[0].word.to_sym]
                if tokens[0].type != :binary_operator || curr_precedence < precedence
                    break
                end

                assert tokens[0], :binary_operator
                operator = tokens[0]
                operator_precedence = curr_precedence
                min_precedence = operator_precedence
                min_precedence += 1 if operator.word == '^'

                eat(tokens)
                right = parse_expression tokens, min_precedence
                left = BinaryExpression.new operator.word, left, right
            end

            left
        end

        identifier = data[0]
        node = VariableDeclaration.new(identifier)
        node.type = data[2].word unless data.last&.type == :inferred_assignment_operator

        node.value = parse_expression tokens

        if @scoped_statements
            @scoped_statements << node
        else
            @variables << node
            @statements << node
        end
        tokens
    end

    def make_compositions_object tokens, identifier, type
        node = Compositions.new

        if tokens[0].type == :binary_operator && tokens[0].word == '+'
            eat tokens
            # eat all the compositions, ignore commas and newlines
            compositions = eat_past(tokens) { |token| token.type == :newline }.reject { |token| token.type == :comma || token.type == :newline }

            raise "Compositions must be identifiers" unless compositions.all? { |token| token.type == :identifier }

            node.compositions = compositions.map do |token|
                # todo) make them into nodes?
                # Composition.new token.word
                token.word
            end.to_a
        end

        node
    end

    # endregion

    def parse tokens, stop_at_token = nil
        until tokens.empty?
            if stop_at_token && tokens[0].type == stop_at_token
                return tokens
            end
            if self_declaration? tokens
                tokens = eat_self_declaration(tokens)
            elsif object_declaration? tokens
                tokens = eat_object_declaration(tokens)
            elsif inferred_assignment?(tokens) || explicit_assignment?(tokens)
                tokens = eat_assignment(tokens)
            elsif tokens[0].type == :new_keyword
                tokens = eat_constructor_declaration(tokens)
            elsif tokens[0].type == :def_keyword && tokens[1].type == :identifier
                tokens = eat_method_declaration tokens
            elsif [:newline, :eof].include?(tokens[0].type)
                eat(tokens)
            elsif tokens[0].type == :identifier && tokens[1].type == :open_paren
                tokens = eat_method_call(tokens)
            elsif tokens[0].type == :identifier
                eat(tokens)
            elsif tokens[0].type == :end_keyword
                return tokens
            else
                puts "Not sure what this token is: #{tokens[0].inspect}"
                # puts "Ate unknown token:\t #{eat(tokens).last.inspect}"
                # eat # eat here or?
            end
        end
        tokens
    end
end

scanner = Scanner.new('./hatch/parse_test.is')
scanner.scan
tokens = scanner.tokens

parsed_object = ObjectDeclaration.new
parsed_object.filename = scanner.file_to_read

parser = Parser.new
tokens = parser.parse(tokens, :eof)
parsed_object.statements = parser.statements

puts parsed_object.statements.map(&:inspect).join("\n\n")

#
# parser.start! './hatch/parse_test.is'
# puts parser.parsed_source.inspect

# def start! file_to_read = nil
#     @parsed_source          = ObjectDeclaration.new
#     @parsed_source.filename = file_to_read
#
#     scanner = Scanner.new file_to_read
#     scanner.scan
#     @tokens = parse scanner.tokens
# end
