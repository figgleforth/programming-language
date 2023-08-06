require './frontend/node'
require './scanner'

class Parser
   attr_reader :tokens, :program, :self_declaration_count

   def initialize file_to_read = nil
      scanner = Scanner.new file_to_read
      scanner.scan
      @self_declaration_count = 0
      @tokens                 = scanner.tokens
      @program                = Program.new(file_to_read)
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
      assert_curr_token type

      # fix) hopefully consuming all newlines doesn't cause issues
      eat until curr_token.type != type if type == :newline
      tokens
   end

   def peek number_of_tokens = 1, accumulate = false
      return @tokens[1..number_of_tokens] if accumulate
      @tokens[number_of_tokens]
   end

   def peek_until type, accumulate = false
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

   ### PARSING ###

   def requires_block?; end

   # todo) too complex, simplify it
   def manual_assignment?
      ident = curr_token.type == :identifier
      colon = peek(1).type == :colon
      type  = [:float_decimal_beg, :float_decimal_end, :float_decimal_mid, :integer, :builtin_type].include?(peek(2).type)

      # puts "peek 1", peek(1).inspect
      # puts "peek 2", peek(2).inspect
      # puts "peek 3", peek(3).inspect

      operator = peek(3)&.type == :assignment_operator

      Node.new(
        type:   :variable_assignment,
        name:   curr_token.word,
        tokens: [curr_token, peek(1), peek(2), peek(3)]
      ) if ident && colon && type && operator
   end

   def self_declaration?
      curr_token.type == :self_keyword && peek(1).type == :colon && peek(2).type == :identifier
   end

   def self_declaration!
      raise "Only one self declaration is allowed per file" if self_declaration_count >= 1

      identifier = eat(3).last # eats `self` `:` `identifier`
      node       = SelfDeclaration.new(identifier.word)

      if curr_token.type == :operator && curr_token.word == '+'
         compositions = eat_until_and_consume(:newline).reject { |token| token.type == :comma }
         raise "Compositions must be identifiers" unless compositions.all? { |token| token.type == :identifier }

         node.compositions = compositions.map do |token|
            # todo) make them into nodes?
            token.word
         end

         @self_declaration_count += 1
         @program.children << node
         puts "Program so far: ", program.inspect
      end
   end

   def self_reference?
   end

   def parse
      while !reached_end?
         if self_declaration?
            self_declaration!
         else
            eat # eat here or?
         end
      end
   end
end

parser = Parser.new './hatch/test2.is'

puts "Parsing... \n\n"
parser.parse
