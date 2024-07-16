# Turns string of code into tokens
class Lexer
    require_relative 'tokens'

    KEYWORDS = %w(
        new end ini req
        enum const private pri public pub static
        do if else for skip stop it is self when while
        where map tap
        return nil
    )

    UNUSED_KEYWORDS = %w(api obj def fun new end arg imp)
    TYPES           = %w(int float array dictionary hash dict bool string any)

    TRIPLE_SYMBOLS = %w(<<= >>= ||= !== === ...)
    DOUBLE_SYMBOLS = %w(<< >> == != <= >= += -= *= /= %= &= |= ^= && || + - -> :: * ** ?? .? .. .< =;)
    SINGLE_SYMBOLS = %w(! ? ~ ^ = + - * / % < > ( ) : [ ] { } , . ; @ & |)

    MACROS = %w(%s %S %v %V %w %W %d)

    # in this specific order so multi character operators are matched first
    SYMBOLS = [
      TRIPLE_SYMBOLS,
      DOUBLE_SYMBOLS,
      SINGLE_SYMBOLS
    ].flatten

    attr_accessor :i, :col, :row, :source, :buffer


    def initialize source = nil
        @source = source
        @tokens = []
        @i      = 0 # index of current char in source string
        @col    = 0 # short for column
        @row    = 1 # short for line
    end


    def source= str
        @source = str
        @tokens = []
        @i      = 0 # index of current char in source string
        @col    = 0 # short for column
        @row    = 1 # short for line
    end


    class UnknownChar < RuntimeError
        def initialize char
            super "Unknown char `#{char}`"
        end
    end


    class Char
        attr_accessor :string


        def initialize str
            @string = str
        end


        def whitespace?
            @string == "\t" or @string == "\s"
        end


        def newline?
            @string == "\n"
        end


        def carriage_return?
            @string == "\r"
        end


        def colon?
            @string == ';'
        end


        def delimiter?
            colon? or newline? or whitespace? or carriage_return?
        end


        def numeric?
            !!(@string =~ /\A[0-9]+\z/)
        end


        def alpha?
            !!(@string =~ /\A[a-zA-Z]+\z/)
        end


        def alphanumeric?
            !!(@string =~ /\A[a-zA-Z0-9]+\z/)
        end


        def symbol?
            !!(@string =~ /\A[^a-zA-Z0-9\s]+\z/)
        end


        def identifier?
            alphanumeric? or @string == '_'
        end


        def == other
            if other.is_a? String
                other == @string
            else
                other == self.class
            end
        end


        def to_s
            string.inspect
        end
    end


    def raise_unknown_char
        exception = UnknownChar.new curr.string
        padding   = 4

        context       = peek(-padding, padding).string
        context_space = ' ' * context.size
        message       = "#{context}#{peek(0, 5).string}\n#{context_space}^"

        puts
        puts exception
        puts message
        puts

        raise exception
    end


    def chars?
        @i < source.length
    end


    def curr
        Char.new source[@i]
    end


    def peek distance = 1, length = 1
        Char.new source[@i + distance, length]
    end


    def last
        source[@i - 1]
    end


    def eat expected = nil
        if curr.newline?
            @row += 1
            @col = 0
        else
            @col += 1
        end

        @i += 1

        if expected and expected != last
            raise "Expected '#{expected}' but got '#{last}'"
        end

        last
    end


    def eat_many distance = 1, expected_chars = nil
        ''.tap do |str|
            distance.times do
                str << eat
            end

            if expected_chars and expected_chars != str
                raise "Expected '#{expected_chars}' but got '#{str}'"
            end
        end
    end


    def eat_number
        ''.tap do |number|
            valid         = %w(. _)
            decimal_found = false

            while chars? and (curr.numeric? or valid.include?(curr.string))
                number << eat
                last_number_char = number[-1]
                decimal_found    = true if last_number_char == '.'

                if curr == '.' and (peek(1) == '.' or peek(1) == '<')
                    break # because these are the range operators .. and .<
                end

                raise "Number #{number} already contains a period. curr #{curr.inspect}" if decimal_found and curr == '.'
                break if curr.newline? or curr.whitespace?
            end
        end
    end


    def eat_identifier
        ''.tap do |ident|
            valid = %w(! ?)
            while curr.identifier? or valid.include?(curr.string)
                ident << eat
                last_char = ident[-1]

                if valid.include? last_char and curr.identifier?
                    raise 'Cannot have ? or ! or : in the middle of an identifier'
                end

                break if curr == last_char and valid.include? last_char # prevent consecutive !! or ??
                break if curr == ':'
                break unless chars?
            end
        end
    end


    def eat_oneline_comment
        ''.tap do |comment|
            eat '#' # eat the hash
            eat while curr.whitespace? # skip whitespace or tab before body

            while chars? and not curr.newline?
                comment << eat
            end
        end
    end


    # note: stored value doesn't preserve newlines. maybe it should in case I want to generate documentation from these comments.
    def eat_multiline_comment
        ''.tap do |comment|
            marker = '###'
            eat_many 3, marker
            eat while curr.whitespace? or curr.newline?

            while chars? and peek(0, 3) != marker
                comment << eat
                eat while curr.newline?
            end

            eat_many 3, marker
            # bug: if you comment out a ## comment line, it becomes ### which then expects a closing ###. Not sure if I should add `if peek(0, 3) == marker`
        end
    end


    def eat_string
        ''.tap do |str|
            quote = eat

            while chars? and curr != quote
                str << eat
            end

            eat quote # eat the ending quote
        end
    end


    def eat_symbol
        ''.tap do |symbol|
            if TRIPLE_SYMBOLS.include? peek(0, 3)&.string
                symbol << eat_many(3)
            elsif DOUBLE_SYMBOLS.include? peek(0, 2)&.string
                symbol << eat_many(2)
            else
                symbol << eat
            end
        end
    end


    def reduce_delimiters
        eat while curr.delimiter?
    end


    def lowercase? c
        c.downcase == c
    end


    def uppercase? c
        c.upcase == c
    end


    def lex input = nil
        @source = input if input

        raise 'Lexer.source is nil' unless source

        while chars?
            if curr.delimiter?
                # parser cares about ; and \n

                if curr == ';'
                    @tokens << Delimiter_Token.new(eat) # ;
                    # reduce_delimiters while last == curr # eat subsequent ;
                    eat while curr.delimiter? # colon?
                elsif curr == "\n"
                    # care about \n and any following whitespaces
                    @tokens << Delimiter_Token.new(eat) # \n
                    eat while curr.delimiter?

                    while curr.whitespace?
                        @tokens << Delimiter_Token.new(eat) # \n
                        reduce_delimiters while last == curr # eat subsequent \s
                    end
                elsif curr == "\s" or curr == "\t" # aka curr.whitespace?
                    eat while curr.whitespace?
                    reduce_delimiters while last == curr

                end

            elsif MACROS.include? peek(0, 2)&.string # %s, %S, etc
                @tokens << Macro_Token.new(eat_many(2))

            elsif curr == '#'
                if peek(0, 3) == '###'
                    eat_multiline_comment
                else
                    eat_oneline_comment
                end

            elsif curr == '"' or curr == "'"
                @tokens << String_Token.new(eat_string)

            elsif curr.numeric?
                @tokens << Number_Token.new(eat_number)

            elsif curr == '.' and peek&.numeric?
                @tokens << Number_Token.new(eat_number)

            elsif curr == '&' and peek.alpha?
                eat '&'
                @tokens << Identifier_Token.new("&#{eat_identifier}")

            elsif curr == '@' and peek.alpha? # at operators, like @before @after hooks
                ident = eat '@'
                ident += eat_identifier
                if curr == '='
                    ident += eat
                end
                @tokens << Keyword_Token.new(ident)

            elsif curr.identifier? or (curr == '_' and peek&.alphanumeric?)
                ident = eat_identifier

                if KEYWORDS.include? ident
                    @tokens << Keyword_Token.new(ident)
                elsif %w(true false).include? ident
                    @tokens << Boolean_Token.new(ident)
                else
                    @tokens << Identifier_Token.new(ident)
                end

            elsif curr == ':' and peek.alpha?
                eat ':'
                ident = eat_identifier
                token = Symbol_Token.new(ident)
                @tokens << token

            elsif SYMBOLS.include? curr.string
                symbol = eat_symbol
                @tokens << Ascii_Token.new(symbol)

            else
                raise_unknown_char # displays some source code with a caret pointing to the unknown character
            end
        end
        @tokens << EOF_Token.new
    end

end
