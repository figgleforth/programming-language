class Token
    attr_accessor :string


    def initialize string = nil
        @string = string
    end


    # token == CommentToken
    # token == '#'
    def == other
        if other.is_a? Class
            other == self.class or self.is_a?(other)
        else
            other == string
        end
    end


    def to_s
        string || super
    end
end


class EOFToken < Token
    def to_s
        '\eof'
    end
end


class DelimiterToken < Token
    def to_s
        if string == ';'
            ";"
        elsif string == "\s"
            '\s'
        else
            '\n'
        end
    end
end


class WhitespaceToken < Token
    def to_s
        self.object_id
        "\\s"
    end
end


class Identifier_Token < Token
    require_relative 'lexer'


    def constant? # all upper, LIKE_THIS
        string&.chars&.all? { |c| c.upcase == c }
    end


    def object? # capitalized, Like_This or This
        string[0].upcase == string[0] and not constant?
    end


    def member? # all lower, some_method or some_variable
        string&.chars&.all? { |c| c.downcase == c }
    end


    def keyword?
        KEYWORDS.include? string
    end


    def builtin_type?
        TYPES.include? string
    end


    def to_s
        string
    end
end


class KeywordToken < Token
    def to_s
        "Keyword(#{string})"
    end
end


class String_Token < Token
    def to_s
        "String(#{string})"
    end


    def interpolated?
        string.include? '`'
    end
end


class SymbolToken < Token
    def to_s
        "Symbol(:#{string})"
    end
end


class Number_Token < Token
    def to_s
        # string
        "Num(#{string})"
    end


    def type_of_number
        if string[0] == '.'
            :float_decimal_beg
        elsif string[-1] == '.'
            :float_decimal_end
        elsif string&.include? '.'
            :float_decimal_mid
        else
            :integer
        end
    end


    # https://stackoverflow.com/a/18533211/1426880
    def string_to_float
        Float(string)
        i, f = string.to_i, string.to_f
        i == f ? i : f
    rescue ArgumentError
        self
    end
end


class AsciiToken < Token # special symbols of one or more characters. they are not identifiers, they are +, :, &, (, \n, etc. the lexer doesn't care what kind of symbol (newline, binary operator, unary operator, etc), just that it is one.
    BINARY_OPERATORS = %w(. + - * / % < > [ \\+= -= *= |= /= %= &= ^= <<= >>= !== === >== == != <= >= && || & | ^ << >> ** .? ./) # todo: it sucks having two binary operators lists. one at the top of lexer.rb and here. when you change this, you have to update the operator precedence in parser, and also lexer DOUBLE_SYMBOLS
    UNARY_OPERATORS  = %w(- + ~ !)


    def to_s
        # "#{string}"
        string
    end


    def binary?
        BINARY_OPERATORS.include? string
    end


    def unary?
        UNARY_OPERATORS.include? string
    end
end


class CommentToken < Token
    attr_accessor :multiline # may be useful for generating documentation

    def initialize string = nil, multiline = false
        super string
        @multiline = multiline
    end


    # this is required because Token== is custom so I can do Token == "}". Not good but oh well.
    def == other
        other.is_a? CommentToken
    end


    def to_s
        # "Comment(#{string})"
        "Comment()"
    end
end

