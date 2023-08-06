require './helpers'
require './frontend/token_types'

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

class Scanner
    attr_accessor :chars, :caret, :tokens, :source_code_file

    def initialize file_to_read = nil
        raise 'Forgot to give the Scanner a file!' if file_to_read.nil?

        @source_code_file = file_to_read
        @chars            = chars_from_source_file file_to_read
        @caret            = Caret.new
        @tokens           = []
    end

    def debug_print
        puts 'Tokens:'
        @tokens.each do |token|
            say "#{token.debug.ljust(PRINT_PADDING)}"
        end
    end

    def reached_end?
        @caret.index >= @chars.count
    end

    def char
        @chars[@caret.index]
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
        while !reached_end?
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
        while !reached_end? ## && peek(distance) != ' ' && peek(distance) != "\t" && peek(distance) != NEWLINE_ESCAPED
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

        while !reached_end?
            characters << char
            eat
            if newline?(char)
                eat # ignores /n for comment lines so that comments don't turn into a bunch of newlines
                break
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

        # strip trailing 0s after decimal
        if number.include?('.')
            number = number.reverse.sub(/0+/, '').reverse
        end

        number
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
        Token.new(type: type, word: word)
    end

    ### scanner loop)

    def scan
        while true
            if reached_end?
                token      = tokenize :eof
                token.span = @caret.current_index..@caret.current_index
                add_token token
                break
            end

            start_position = @caret.current_index
            if maybe_identifier? char
                # todo) handle `else if` as a single identifier
                # todo)
                #   separate type! and type?, I want the parser to deal with that
                #   else if parses as two

                start_position = @caret.current_index
                identifier     = accumulate_identifier

                if WORDS.include?(identifier)
                    token      = nil
                    if identifier == 'self'
                        # if peek == ':'
                            token = tokenize :self_keyword, identifier
                            add_token token
                            end_position = @caret.current_index
                        # else
                        #     token = tokenize :self_reference, identifier
                        # end
                        # token.span   = start_position..end_position
                    elsif identifier == 'enum'
                        token = tokenize :enum_declaration, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'new'
                        token = tokenize :object_initializer, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'if'
                        token = tokenize :if_conditional, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'else'
                        token = tokenize :else_conditional, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'while'
                        token = tokenize :while_loop_declaration, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'for'
                        token = tokenize :for_loop_declaration, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'it'
                        token = tokenize :loop_current_item_it, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'at'
                        token = tokenize :loop_current_index_at, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'obj'
                        token = tokenize :object_declaration, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'api'
                        token = tokenize :api_declaration, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'def'
                        token = tokenize :method_definition, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'stop'
                        token = tokenize :loop_stop, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'next'
                        token = tokenize :loop_next, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'end'
                        token = tokenize :block_end, identifier
                        add_token token
                        end_position = @caret.current_index
                        # token.span = start_position..end_position
                    elsif identifier == 'return'
                        token = tokenize :method_return, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'when'
                        token = tokenize :when_declaration, identifier
                        add_token token
                        end_position = @caret.current_index
                    elsif identifier == 'is'
                        token = tokenize :when_is, identifier
                        add_token token
                        end_position = @caret.current_index
                    else
                        puts "unknown keyword", identifier
                    end
                    token.span = start_position..@caret.current_index if !token.nil?
                elsif BUILTIN_TYPES.include?(identifier)
                    # start_position = @caret.current_index
                    token = tokenize :builtin_type, identifier
                    add_token token
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                else
                    # start_position = @caret.current_index
                    token = tokenize :identifier, identifier
                    add_token token
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                end
            elsif maybe_number? char
                start_position = @caret.current_index
                number         = accumulate_number
                token          = tokenize type_of_number(number), number
                token.type     = :number_literal
                add_token token
                end_position = @caret.current_index
                token.span   = start_position..end_position
            elsif maybe_symbol? char
                if char == '.'
                    if maybe_number?(peek)
                        start_position = @caret.current_index
                        number         = accumulate_number
                        token          = tokenize type_of_number(number), number
                        add_token token
                        end_position = @caret.current_index
                        token.span   = start_position..end_position
                    else
                        start_position = @caret.current_index
                        token          = tokenize :dot, '.'
                        add_token token
                        eat
                        end_position = @caret.current_index
                        token.span   = start_position..end_position
                    end
                elsif char == '|' && peek == '|' && peek(2) == '='
                    start_position = @caret.current_index
                    token          = tokenize :symbol, "||="
                    add_token token
                    eat 3
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '|' && peek == '|'
                    start_position = @caret.current_index
                    token          = tokenize :symbol, "||"
                    add_token token
                    eat 2
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                    # elsif char == '|' && peek != '|'
                    # todo) handle single | as a symbol
                elsif char == '!' && peek == '!'
                    start_position = @caret.current_index
                    token          = tokenize :symbol, "!!"
                    add_token token
                    eat 2
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '!' && peek != '!'
                    start_position = @caret.current_index
                    token          = tokenize :exclamation_mark, "!"
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '&' && peek == '&'
                    start_position = @caret.current_index
                    eat 2
                    identifier = accumulate_identifier
                    token      = tokenize :symbol, '&&' + identifier
                    add_token token
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '@' && peek == '@'
                    start_position = @caret.current_index
                    eat 2
                    identifier = accumulate_identifier
                    token      = tokenize :identifier, '@@' + identifier
                    add_token token
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '@' && maybe_identifier?(peek)
                    start_position = @caret.current_index
                    eat # for the @ symbol
                    identifier = '@' + accumulate_identifier
                    ident_type = if LOGGING.include?(identifier)
                                     "print_#{identifier[1..]}".to_sym
                                 else
                                     :identifier
                                 end

                    token        = tokenize ident_type, identifier
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '#'
                    eat_until_newline
                elsif char == ':' && peek == '='
                    start_position = @caret.current_index
                    token          = tokenize :inferred_assignment, ":="
                    add_token token
                    eat 2
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == ';'
                    start_position = @caret.current_index
                    token          = tokenize :semicolon, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == ':'
                    start_position = @caret.current_index
                    token          = tokenize :colon, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == ','
                    start_position = @caret.current_index
                    token          = tokenize :comma, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '('
                    start_position = @caret.current_index
                    token          = tokenize :open_paren, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '['
                    start_position = @caret.current_index
                    token          = tokenize :open_square_bracket, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '{'
                    start_position = @caret.current_index
                    token          = tokenize :open_curly_bracket, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == ')'
                    start_position = @caret.current_index
                    token          = tokenize :close_paren, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == ']'
                    start_position = @caret.current_index
                    token          = tokenize :close_square_bracket, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '}'
                    start_position = @caret.current_index
                    token          = tokenize :close_curly_bracket, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '=' && peek == '>'
                    start_position = @caret.current_index
                    token          = tokenize :assignment_with_computed_expression, "=>"
                    add_token token
                    eat 2
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '=' && peek != '='
                    # todo) could `peek != '='` miss any edge cases?
                    start_position = @caret.current_index
                    token          = tokenize :assignment_operator, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '=' && peek == '='
                    start_position = @caret.current_index
                    token          = tokenize :equality_operator, '=='
                    add_token token
                    eat 2
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '+' && peek == '='
                    start_position = @caret.current_index
                    token          = tokenize :increment_operator, '+='
                    add_token token
                    eat 2
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '+' || char == '-' || char == '*' || char == '/' || char == '%' || char == '^'
                    start_position = @caret.current_index
                    token          = tokenize :operator, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '?'
                    start_position = @caret.current_index
                    token          = tokenize :question_mark, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '<' && peek == '~'
                    start_position = @caret.current_index
                    token          = tokenize :read_input, '<~'
                    add_token token
                    eat 2
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                elsif char == '\'' || char == '"'
                    # todo) handle interpolation
                    start_position = @caret.current_index
                    buffer         = accumulate_string

                    if buffer.include? "`"
                        token = tokenize :interpolated_string, buffer
                        add_token token
                    else
                        token = tokenize :string, buffer
                        add_token token
                    end

                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                else
                    start_position = @caret.current_index
                    token          = tokenize :unknown_symbol, char
                    add_token token
                    eat
                    end_position = @caret.current_index
                    token.span   = start_position..end_position
                end
            elsif char == NEWLINE_ESCAPED || char == NEWLINE
                start_position = @caret.current_index
                token          = tokenize :newline, char unless peek(-1) == NEWLINE_ESCAPED

                # todo) skip consequent newlines
                # while peek == NEWLINE_ESCAPED
                #   eat
                # end
                add_token token
                # todo) if there is a comment between two newlines, it still logs newline twice. the goal is to aggregate all newlines into one newline token
                eat
                end_position = @caret.current_index
                token.span   = start_position..end_position
            elsif char == ' ' || char == "\t"
                start_position = @caret.current_index
                eat
                end_position = @caret.current_index
            else
                say "OOPS: #{char}"
                eat
            end
        end
    end
end

scanner = Scanner.new './hatch/test2.is'
scanner.scan
scanner.debug_print
