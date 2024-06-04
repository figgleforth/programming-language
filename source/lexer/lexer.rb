# Turns string of code into tokens
class Lexer
    require_relative 'token'

    KEYWORDS = %w(
    api obj def new end arg
    enum const private pri public pub static
    do if else for skip stop it is self when while
   )

    # in this specific order so multi character operators are matched first

    TRIPLE_SYMBOLS = %w(<<= >>= !== === >== ||=)
    DOUBLE_SYMBOLS = %w(<< >> == != <= >= += -= *= /= %= &= |= ^= := && || @@ ++ -- -> ** ::)
    SINGLE_SYMBOLS = %w(! ? ~ ^ = + - * / % < > ( ) : [ ] { } , . ; @ & |)

    SYMBOLS = [
        TRIPLE_SYMBOLS,
        DOUBLE_SYMBOLS,
        SINGLE_SYMBOLS
    ].flatten

    attr_accessor :i, :col, :row, :source, :tokens


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


        # def == other
        #    @string == other
        # end

        def == other
            if other.is_a? String
                other == @string
            else
                other == self.class
            end
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
            valid = %w(. _)

            while chars? and (curr.numeric? or valid.include?(curr.string))
                number << eat
                break if curr.newline? or curr.whitespace?
            end
        end
    end


    def eat_identifier
        ''.tap do |ident|
            valid = %w(! ?)
            while curr.identifier? or valid.include?(curr.string)
                ident << eat

                break if valid.include? ident.chars.last # prevent consecutive !! or ??
                break unless chars?
            end
        end
    end


    def eat_colon_symbol
        # eat :
        # eat_number_or_numeric_identifier

    end


    def eat_number_or_numeric_identifier
        number = eat_number

        # support 1st, 2nd, 3rd?, 4th!, etc identifier syntax
        if curr.alpha?
            IdentifierToken.new(number + eat_identifier)
        else
            NumberToken.new(number)
        end
    end


    def eat_oneline_comment
        ''.tap do |comment|
            eat '#' # eat the hash
            eat while curr.whitespace? # skip whitespace or tab before body

            while chars? and not curr.newline?
                comment << eat
            end

            eat "\n" # don't care to know if there's a newline after a comment
        end
    end


    # todo; stored value doesn't preserve newlines. maybe it should in case I want to generate documentation from these comments.
    # todo;
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
            eat "\n" while curr.newline? # don't care to know if there's a newline after a comment
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


    def lex input = nil
        @source = input if input

        raise 'Lexer.source is nil' unless source

        while chars?
            if curr.delimiter?
                # parser cares about ; and \n because that denotes the end of a statement or a pattern (eg: obj Ident \n)

                if curr == ';'
                    @tokens << DelimiterToken.new(eat) # ;
                    # reduce_delimiters while last == curr # eat subsequent ;
                    eat while curr.delimiter? #colon?
                elsif curr == "\n"
                    # care about \n and any following whitespaces
                    @tokens << DelimiterToken.new(eat) # \n
                    eat while curr.delimiter?

                    while curr.whitespace?
                        @tokens << DelimiterToken.new(eat) # \n
                        reduce_delimiters while last == curr # eat subsequent \s
                    end
                elsif curr == "\s"
                    eat while curr.whitespace?
                    reduce_delimiters while last == curr
                end

            elsif curr == '#'
                if peek(0, 3) == '###'
                    @tokens << CommentToken.new(eat_multiline_comment, true)
                else
                    @tokens << CommentToken.new(eat_oneline_comment)
                end

            elsif curr == '"' or curr == "'"
                @tokens << StringToken.new(eat_string)

            elsif curr.numeric?
                @tokens << eat_number_or_numeric_identifier

            elsif curr == '.' and peek&.numeric?
                @tokens << NumberToken.new(eat_number)

            elsif curr.identifier? or (curr == '_' and peek&.alphanumeric?)
                ident = eat_identifier

                if KEYWORDS.include? ident
                    @tokens << KeywordToken.new(ident)

                else
                    @tokens << IdentifierToken.new(ident)
                end

                if curr == "\n"
                    @tokens << DelimiterToken.new(eat)
                    eat while curr.delimiter?
                end
            elsif SYMBOLS.include? curr.string
                # fix: :style_symbols is including the inferred assignment operator := as well, but := should be a separate symbol. probably use SYMBOLS array
                # if char == ':' and not peek&.delimiter? # :style symbols
                #    eat ':'
                #
                #    ident                = eat_identifier
                #    token                = IdentifierToken.new(ident)
                #    token.symbol_literal = true
                #
                #    @tokens << token
                # else
                symbol = eat_symbol
                @tokens << SymbolToken.new(symbol)
                eat "\n" while curr.newline? and symbol == ';'
                eat "\n" while curr.newline? and symbol == '}'


            else
                raise_unknown_char # displays some source code with a caret pointing to the unknown character
            end
        end
        @tokens << EOFToken.new
    end

end
