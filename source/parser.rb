require_relative './frontend/nodes'
require_relative './frontend/token'
require_relative './frontend/token_types'
require_relative 'tokenizer'
require 'ostruct'

# Parses tokens into statements, it doesn't care about order, duplication, but it should care about syntax.
class Parser
  attr_reader :statements, :variables, :methods, :objects

  def initialize
    @statements = []
    @variables  = []
    @methods    = []
    @objects    = []
  end

  def next_token
    @tokens[0]
  end

  def eat tokens, times = 1
    tokens.shift times
  end

  def eat_until tokens, &block
    eat tokens, tokens.slice_before(&block).to_a.first.count
  end

  def eat_past tokens, &block
    eat tokens, tokens.slice_after(&block).to_a.first.count
  end

  def peek tokens, ahead = 1
    tokens.dup.shift ahead
  end

  def peek_until tokens, &block
    tokens.dup.slice_before(&block).to_a.first
  end

  def assert token, type
    raise "Expected #{token.inspect} to be #{type}" if token.type != type
  end

  def reached_end? tokens
    tokens.empty? || tokens[0].type == :eof
  end

  def method_call? tokens
    # some_method(
    tokens[0].type == :identifier && tokens[1].type == :open_paren
  end

  def inferred_assignment? tokens
    # some_var :=
    tokens[0].type == :identifier &&
      tokens[1].type == :inferred_assignment_operator
  end

  def explicit_assignment? tokens
    # some_var: type
    tokens[0].type == :identifier &&
      tokens[1].type == :colon &&
      (tokens[2].type == :identifier || tokens[2].type == :builtin_type)
  end

  def iam_declaration? tokens
    # iam (identifier || builtin_type)
    tokens[0].type == :keyword_iam &&
      (tokens[1].type == :identifier || tokens[1].type == :builtin_type)
  end

  def object_declaration? tokens
    # obj (identifier || builtin_type)
    tokens[0].type == :keyword_obj &&
      (tokens[1].type == :identifier || tokens[1].type == :builtin_type)
  end

  def operator? tokens
    # todo) rest of the operators, prefix, postfix, infix? (not sure what infix is)
    %w().include?(tokens[0].string) && tokens[0].type == :binary_operator
  end

  # endregion

  # region Eating

  # def eat_object_declaration tokens
  #    identifier = eat(tokens, 2).last # obj, identifier
  #    node = ObjectDeclaration.new
  #    node.name = identifier.word
  #    compositions = make_compositions_object tokens, identifier.word, :self
  #    node.compositions = compositions
  #
  #    @objects << node
  #    @statements << node
  #
  #    # todo) since @statements, etc is shared within this parser, I have to instantiate a new one here. I could refactor it so that I also pass @statements to the parser, but that's more work than I feel like doing right now
  #    parser = Parser.new
  #    tokens = parser.parse_statements(tokens, :end_keyword)
  #    node.statements = parser.statements
  #
  #    eat tokens # end keyword
  #
  #    tokens
  # end

  def eat_constructor_declaration tokens
    node = MethodDeclaration.new(eat(tokens).last, :new)

    @methods << node
    @statements << node

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
            param.label      = eat(tokens).last
            param.name_token = eat(tokens).last
            param.type       = eat(tokens, 2).last
          elsif tokens[0].type == :identifier && tokens[1].type == :colon # identifier: type (3 tokens)
            param.name_token = eat(tokens).last
            param.type       = eat(tokens, 2).last
          end

          if tokens[0].type == :equal
            param.default_value = eat(tokens, 2).last
          end

          eat(tokens) # ,
        end

        method_declaration.parameters << parameter
        eat(tokens) if tokens[0].type == :comma
      end
      method_declaration
    end

    data        = eat(tokens, 2) # def, identifier
    method_node = MethodDeclaration.new data.last, :def
    method_node = eat_signature method_node, tokens

    # at this point, the entire signature is consumed
    eat(tokens) if tokens[0].type == :newline

    parser                 = Parser.new
    method_node.statements = parser.to_statements tokens, :end_keyword

    assert tokens[0], :end_keyword
    eat(tokens)

    @methods << method_node
    @statements << method_node
    tokens
  end

  # given tokens, should return Call
  def eat_method_call tokens
    def eat_arguments tokens
      # at this point the ( has been consumed

      # possible tokens when labels are used:
      #   identifier: value, identifier: value, ...
      #   identifier: value, value, ...

      # possible tokens when labels are not used:
      #   value, value, ...

      # labeled arguments go first when mixed with unlabeled arguments

      # puts "#eat_arguments with: #{tokens.inspect}"
      args = []
      until reached_end?(tokens)
        if tokens[0].type == :close_paren && [:newline].include?(tokens[1].type)
          # todo) I don't want to break early if there's a function call, like method(other_method())
          break
        end

        args << Argument.new.tap do |arg|
          if tokens[0].type == :identifier && tokens[1].type == :colon
            # labeled argument
            arg.label = eat(tokens).last
            eat(tokens) # :
            arg.value = eat(tokens).last
          elsif method_call?(tokens) # tokens[0].type == :identifier && tokens[1].type == :open_paren
            tokens, method_call = eat_method_call tokens

            # rest are unlabeled arguments

            # method call
            # todo) abstract this away because method calls happen in many places, not just as an arg
            # eaten = eat tokens, 2
            # method_call = Call.new(eaten[0])

            puts "ARG method call: #{method_call.inspect}"
          elsif tokens[0].type == :number
            # number, bool, string
            arg.value = eat(tokens).last
            # puts "number arg: #{arg.inspect}"
          elsif tokens[0].type == :identifier
            # variable
            arg.value = eat(tokens).last
          else
            # puts "unknown tokens: #{tokens.inspect}"
            eat tokens
          end
        end

        # puts "tokens?? #{tokens.inspect}"
        eat(tokens) if tokens[0].type == :comma

        args
      end

      assert tokens[0], :close_paren
      # don't eat it here because that's not this method's job
      # puts "args: #{args.inspect}"

      [tokens, {}]
    end

    assert tokens[0], :identifier
    assert tokens[1], :open_paren
    eat tokens, 2 # identifier, (

    call = Call.new tokens[0]

    args = eat_arguments tokens
    # puts "parsed ARGS: #{args.inspect}"

    assert tokens[0], :close_paren
    eat tokens # )

    # puts "DONE!, tokens: #{tokens.inspect}"

    tokens
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
        curr_precedence = operator_precedences[tokens[0].string.to_sym]
        if tokens[0].type != :binary_operator || curr_precedence < precedence
          break
        end

        assert tokens[0], :binary_operator
        operator            = tokens[0]
        operator_precedence = curr_precedence
        min_precedence      = operator_precedence
        min_precedence      += 1 if operator.string == '^'

        eat(tokens)
        right = parse_expression tokens, min_precedence
        left  = BinaryExpression.new operator.string, left, right
      end

      left
    end

    identifier = data[0]
    node       = VariableDeclaration.new(identifier)
    node.type  = data[2].string unless data.last&.type == :inferred_assignment_operator

    node.value = parse_expression tokens

    @variables << node
    @statements << node
    tokens
  end

  # def make_compositions_object tokens, identifier, type
  #    compositions = []
  #
  #    if tokens[0].type == :binary_operator && tokens[0].word == '+'
  #       eat tokens
  #       # eat all the compositions, ignore commas and newlines
  #       compositions = eat_past(tokens) { |token| token.type == :newline }.reject { |token| token.type == :comma || token.type == :newline }
  #
  #       raise "Compositions must be identifiers" unless compositions.all? { |token| token.type == :identifier }
  #
  #       compositions.map! do |token|
  #          # todo) make them into nodes?
  #          # token.word
  #          Literal.new token
  #       end.to_a
  #    end
  #
  #    compositions
  # end

  # endregion

  # todo) parse_tokens_into_statements, return tokens and statements

  def add_node node
    @statements << node if node.identified?
  end

  # note: modifies `tokens`
  # rather than using a cursor to keep track of where we are in the tokens, eat tokens as we go
  def to_statements tokens, stop_at: nil
    puts "about to parse tokens: #{tokens.inspect}"
    # todo) figure out what's happening here

    until tokens.empty?
      if stop_at && tokens[0].type == stop_at
        return tokens
      end

      count = tokens.count

      if tokens[0].type == :number
        @statements << { type: :number_literal, string: tokens[0].string }
        # add_node NumberLiteral.new(tokens)
      end

      if tokens[0].type == :identifier
        @statements << { type: :identifier, string: tokens[0].string }
        # add_node NumberLiteral.new(tokens)
      end

      # iam identifier
      if tokens[0].type == :keyword_iam && tokens[1].type == :identifier
        @iam_object = {
          name:  tokens[1].string,
          scope: Parser.new
        }
        add_object @iam_object
      end

      # puts "tokens: #{tokens.inspect}"
      # order matters
      # add_node SelfDeclaration.new(tokens).parse
      # add_node ObjectDeclaration.new(tokens).parse

      if count == tokens.count
        # puts "Unhandled token: #{tokens[0].inspect}"
        eat tokens
        # raise "Infinite loop detected, tokens: #{tokens.inspect}"
      end
    end

    # parsers = %w(SelfDeclaration)
    #
    # until tokens.empty?
    #   parsers.each do |parser|
    #     parser = Object.const_get(parser)
    #     node   = parser.new(tokens).parse
    #
    #     if node
    #       add_node node
    #       break
    #     end
    #   end
    # end

    # until tokens.empty?
    #    valid = (
    #      SelfDeclaration.new(tokens).parse? #||
    #        # ObjectDeclaration.new(tokens) ||
    #        # MethodDeclaration.new(tokens) ||
    #        # VariableDeclaration.new(tokens) ||
    #        # VariableReference.new(tokens) ||
    #        # Literal.new(tokens)
    #    )
    #
    #    # the idea is that if at least one of the above returns true this loop, then nothing is raised and we continue the loop. these classes above can be ordered however they need to be. also they should all return true or false, so must add a method because #new returns the object, not true or false.
    #
    #    unless valid
    #       raise "Unknown token: #{tokens[0].inspect}"
    #    end
    # end
    #
    # todo) return parsed_statements

    tokens
  end
end
