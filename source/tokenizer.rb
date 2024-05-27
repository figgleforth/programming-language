# Usage
#
# tokenizer = Tokenizer.new 'source code'
# tokenizer = tokenizer.scan
# tokens = tokenizer.tokens
#
# or
#
# tokenizer = Tokenizer.new
# tokens = tokenizer.string_to_tokens 'source code'

class Tokenizer
  require_relative './helpers/tokenizer'

  class Caret
    attr_accessor :line_number, :char_number, :index, :character, :line

    def initialize
      @line_number = 1
      @char_number = 0
      @index       = 0
      @character   = ''
      @line        = ''
    end

    def advance_index
      @index += 1
    end

    def current_index
      @index
    end
  end


  attr_accessor :string, :caret, :tokens, :string
  attr_accessor :eof_becomes_token, :newlines_become_tokens

  def initialize string = nil
    @string          = string
    @chars           = string&.string || ''
    @caret           = Caret.new
    @tokens          = []
    @eof_becomes_token      = false
    @newlines_become_tokens = true
  end

  def puts_debug_info
    puts "—— TOKENIZER ——\n"
    puts "string: #{@string.inspect}"
    puts "chars: #{@chars.inspect}"
    puts "eof_becomes_token: #{@eof_becomes_token}"
    puts "newlines_become_tokens: #{@newlines_become_tokens}"
    puts "\n———————————————"
  end

  def string_to_tokens string
    @chars = string.string
    scan
    @tokens
  end

  def debug_print
    @tokens.each do |token|
      say "#{token.puts_debug_info.ljust(PRINT_PADDING)}"
    end
  end

  # https://stackoverflow.com/a/18533211/1426880
  def string_to_float str
    Float(str)
    i, f = str.to_i, str.to_f
    i == f ? i : f
  rescue ArgumentError
    str
  end

  def reached_end?
    @caret.index >= @chars.count
  end

  def char
    @chars[@caret.index]
  end

  def consecutive_newlines?
    [NEWLINE, NEWLINE_ESCAPED].include?(char) && [NEWLINE, NEWLINE_ESCAPED].include?(peek)
  end

  def peek ahead = 1, accumulate = false
    if accumulate
      characters = []
      ahead.times do |i|
        characters << @chars[@caret.index + i]
      end
      characters.join
    else
      @chars[@caret.index + ahead]
    end
  end

  def peek_until_newline
    characters = []

    distance = 0
    until reached_end?
      characters << peek(distance)
      break if newline?(char)
      distance += 1
    end

    characters.join
  end

  def peek_until_whitespace
    characters = []

    distance  = 0
    next_char = ''
    until reached_end? ## && peek(distance) != ' ' && peek(distance) != "\t" && peek(distance) != NEWLINE_ESCAPED
      characters << next_char
      distance  += 1
      next_char = peek(distance)
      break if whitespace?(next_char)
    end

    characters.join
  end

  def eat count = 1
    count.times do
      if char == NEWLINE_ESCAPED
        @caret.line_number += 1
        @caret.char_number = 0
        @caret.line        = ''
      else
        @caret.char_number += 1
        @caret.line        += char
      end

      @caret.advance_index
    end
  end

  def eat_until_newline
    characters = []

    until reached_end? || newline?(char)
      if !newline?(char)
        eat
        characters << char
      end
    end

    characters.join
  end

  def accumulate_number
    number = ""
    curr   = char

    while !reached_end? && (numeric?(curr) || curr == '.' || curr == '_')
      number << curr
      eat
      curr = char
      break if curr == NEWLINE
    end

    string_to_float(number).to_s
  end

  def accumulate_identifier
    identifier = ''

    while !reached_end? && continues_identifier?(char)
      identifier << char
      eat
    end

    identifier
  end

  def accumulate_string
    string = ''

    while !reached_end?
      string << char
      eat
      if ["'", '"'].include? char
        string << char
        eat
        break
      end
    end

    string
  end

  def type_of_number str
    if str[0] == '.'
      :float_decimal_beg
    elsif str[-1] == '.'
      :float_decimal_end
    elsif str.include?('.')
      :float_decimal_mid
    else
      :integer
    end
  end

  def add_token token
    @tokens << token
  end

  def tokenize type, word = ''
    LexerToken.new(type: type, string: word)
  end

  ### scanner loop)

  def identifier_to_token_type identifier
  end

  def scan
    while true
      curr_token = nil
      if reached_end?
        curr_token      = tokenize :eof, :eof
        curr_token.span = @caret.current_index..@caret.current_index
        @tokens << curr_token unless @eof_becomes_token
        break
      end

      start_position = @caret.current_index
      if maybe_identifier? char
        # todo) `else if` currently parses as two tokens but should parse as one single token
        # todo) separate `type!` and `type?`, I want the parser to deal with that
        #   - 11/26/23, what did I mean by that?

        start_position = @caret.current_index
        identifier     = accumulate_identifier
        end_position   = @caret.current_index

        if WORDS.include?(identifier)
          curr_token      = nil
          if identifier == 'iam'
            curr_token = tokenize :keyword_iam, identifier
            @tokens << curr_token
          elsif identifier == 'enum'
            curr_token = tokenize :keyword_enum, identifier
            @tokens << curr_token
          elsif identifier == 'new'
            curr_token = tokenize :new_keyword, identifier
            @tokens << curr_token
          elsif identifier == 'if'
            curr_token = tokenize :if_conditional, identifier
            @tokens << curr_token
          elsif identifier == 'else'
            curr_token = tokenize :else_conditional, identifier
            @tokens << curr_token
          elsif identifier == 'while'
            curr_token = tokenize :while_loop_keyword, identifier
            @tokens << curr_token
          elsif identifier == 'for'
            curr_token = tokenize :keyword_for, identifier
            @tokens << curr_token
          elsif identifier == 'it'
            curr_token = tokenize :keyword_loop_it, identifier
            @tokens << curr_token
          elsif identifier == 'at'
            curr_token = tokenize :keyword_loop_at, identifier
            @tokens << curr_token
          elsif identifier == 'obj'
            curr_token = tokenize :keyword_obj, identifier
            @tokens << curr_token
          elsif identifier == 'api'
            curr_token = tokenize :keyword_api, identifier
            @tokens << curr_token
          elsif identifier == 'def'
            curr_token = tokenize :keyword_def, identifier
            @tokens << curr_token
          elsif identifier == 'stop'
            curr_token = tokenize :keyword_loop_stop, identifier
            @tokens << curr_token
          elsif identifier == 'next'
            curr_token = tokenize :keyword_loop_next, identifier
            @tokens << curr_token
          elsif identifier == 'end'
            curr_token = tokenize :end_keyword, identifier
            @tokens << curr_token
            # token.span = start_position..end_position
          elsif identifier == 'return'
            curr_token = tokenize :method_return, identifier
            @tokens << curr_token
          elsif identifier == 'when'
            curr_token = tokenize :when_declaration, identifier
            @tokens << curr_token
          elsif identifier == 'is'
            curr_token = tokenize :when_is, identifier
            @tokens << curr_token
          else
            puts "unknown keyword", identifier
          end
          curr_token.span = start_position..@caret.current_index if !curr_token.nil?
        elsif BUILTIN_TYPES.include?(identifier)
          # start_position = @caret.current_index
          curr_token = tokenize :builtin_type, identifier
          @tokens << curr_token
          curr_token.span = start_position..end_position
        else
          # start_position = @caret.current_index
          # puts "identifier", identifier
          curr_token = tokenize :identifier, identifier
          # puts "token", token.inspect
          @tokens << curr_token
          curr_token.span = start_position..end_position
        end
      elsif maybe_number? char
        # start_position  = @caret.current_index
        number          = accumulate_number
        curr_token      = tokenize type_of_number(number), number
        curr_token.type = :number
        @tokens << curr_token
        end_position    = @caret.current_index
        curr_token.span = start_position..end_position
      elsif maybe_symbol? char
        if char == '.'
          if maybe_number?(peek)
            # start_position = @caret.current_index
            number     = accumulate_number
            curr_token = tokenize type_of_number(number), number
            @tokens << curr_token
            end_position    = @caret.current_index
            curr_token.span = start_position..end_position
          else
            # start_position = @caret.current_index
            curr_token = tokenize :dot, '.'
            @tokens << curr_token
            eat
            end_position    = @caret.current_index
            curr_token.span = start_position..end_position
          end
        elsif char == '|' && peek == '|' && peek(2) == '='
          # start_position = @caret.current_index
          curr_token = tokenize :symbol, "||="
          @tokens << curr_token
          eat 3
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '|' && peek == '|'
          # start_position = @caret.current_index
          curr_token = tokenize :symbol, "||"
          @tokens << curr_token
          eat 2
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
          # elsif char == '|' && peek != '|'
          # todo) handle single | as a symbol
        elsif char == '!' && peek == '!'
          # start_position = @caret.current_index
          curr_token = tokenize :symbol, "!!"
          @tokens << curr_token
          eat 2
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '!' && peek != '!'
          # start_position = @caret.current_index
          curr_token = tokenize :exclamation_mark, "!"
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '&' && peek == '&'
          # start_position = @caret.current_index
          eat 2
          identifier = accumulate_identifier
          curr_token = tokenize :symbol, '&&' + identifier
          @tokens << curr_token
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '@' && peek == '@'
          # start_position = @caret.current_index
          eat 2
          identifier = accumulate_identifier
          curr_token = tokenize :identifier, '@@' + identifier
          @tokens << curr_token
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '@' && maybe_identifier?(peek)
          # start_position = @caret.current_index
          eat # for the @ symbol
          identifier = '@' + accumulate_identifier
          ident_type = if LOGGING.include?(identifier)
            "print_#{identifier[1..]}".to_sym
          else
            :identifier
          end

          curr_token      = tokenize ident_type, identifier
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '#'
          comment    = eat_until_newline
          curr_token = tokenize :comment, comment
          @tokens << curr_token
        elsif char == ':' && peek == '='
          # start_position = @caret.current_index
          curr_token = tokenize :inferred_assignment_operator, ":="
          @tokens << curr_token
          eat 2
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '=' && peek != '='
          # todo) could `peek != '='` miss any edge cases?
          # start_position = @caret.current_index
          curr_token = tokenize :equal, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == ';'
          # start_position = @caret.current_index
          curr_token = tokenize :semicolon, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == ':'
          # start_position = @caret.current_index
          curr_token = tokenize :colon, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == ','
          # start_position = @caret.current_index
          curr_token = tokenize :comma, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '('
          # start_position = @caret.current_index
          curr_token = tokenize :open_paren, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '['
          # start_position = @caret.current_index
          curr_token = tokenize :open_square_bracket, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '{'
          # start_position = @caret.current_index
          curr_token = tokenize :open_curly_bracket, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == ')'
          # start_position = @caret.current_index
          curr_token = tokenize :close_paren, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == ']'
          # start_position = @caret.current_index
          curr_token = tokenize :close_square_bracket, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '}'
          # start_position = @caret.current_index
          curr_token = tokenize :close_curly_bracket, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '=' && peek == '>'
          # start_position = @caret.current_index
          curr_token = tokenize :assignment_with_computed_expression, "=>"
          @tokens << curr_token
          eat 2
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position

        elsif char == '=' && peek == '='
          # start_position = @caret.current_index
          curr_token = tokenize :equality_operator, '=='
          @tokens << curr_token
          eat 2
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '+' && peek == '='
          # start_position = @caret.current_index
          curr_token = tokenize :increment_operator, '+='
          @tokens << curr_token
          eat 2
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '+' || char == '-' || char == '*' || char == '/' || char == '%' || char == '^'
          # start_position = @caret.current_index
          curr_token = tokenize :binary_operator, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '?'
          # start_position = @caret.current_index
          curr_token = tokenize :question_mark, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '<' && peek == '~'
          # start_position = @caret.current_index
          curr_token = tokenize :read_input, '<~'
          @tokens << curr_token
          eat 2
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        elsif char == '\'' || char == '"'
          # todo) handle interpolation
          # start_position = @caret.current_index
          buffer = accumulate_string

          if buffer.include? "`"
            curr_token = tokenize :interpolated_string, buffer
            @tokens << curr_token
          else
            curr_token = tokenize :string, buffer
            @tokens << curr_token
          end

          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        else
          # start_position = @caret.current_index
          curr_token = tokenize :unknown_symbol, char
          @tokens << curr_token
          eat
          end_position    = @caret.current_index
          curr_token.span = start_position..end_position
        end
      elsif char == NEWLINE
        # start_position = @caret.current_index

        curr_token = tokenize :newline, char unless peek(-1) == NEWLINE

        eat and next unless curr_token
        @tokens << curr_token if @newlines_become_tokens

        # while consecutive_newlines? && !reached_end?
        while !reached_end? && peek == NEWLINE
          eat
        end

        eat if char == NEWLINE

        end_position    = @caret.current_index
        curr_token.span = start_position..end_position
      elsif char == ' ' || char == "\t"
        # start_position = @caret.current_index
        eat
        # end_position = @caret.current_index
      else
        say "OOPS: #{char.inspect}"
        eat
      end
    end
  end
end
