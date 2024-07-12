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


    def pretty
        string || super
    end


    def to_s
        string
    end
end


class EOF_Token < Token
    def pretty
        '\eof'
    end
end


class Delimiter_Token < Token
    def pretty
        if string == ';'
            ";"
        elsif string == "\s"
            '\s'
        else
            '\n'
        end
    end
end


class Whitespace_Token < Token
    def pretty
        self.object_id
        "\\s"
    end
end


class Identifier_Token < Token
    require_relative 'lexer'

    # note: I remove the _ and & here because identifiers can be parsed with those because of specific language features. But the purpose is so that the #all? tests in each method here don't fail, since upcasing & and _ yields the same value so it makes the identifier a constant, object, and member simultaneously. Originally I thought this felt wrong, but after writing out the purpose here, it's fine to stay.
    def constant? # all upper, LIKE_THIS
        test = string.gsub('_', '').gsub('&', '')
        test&.chars&.all? { |c| c.upcase == c }
    end


    def object? # capitalized, Like_This or This
        test = string.gsub('_', '').gsub('&', '')
        test[0].upcase == test[0] and not constant?
    end


    def member? # all lower, some_method or some_variable
        test = string.gsub('_', '').gsub('&', '')
        test&.chars&.all? { |c| c.downcase == c }
    end


    def composition?
        string[0] == '&'
    end


    def keyword?
        KEYWORDS.include? string
    end


    def builtin_type?
        TYPES.include? string
    end


    def pretty
        string
    end
end


class Keyword_Token < Identifier_Token
    def pretty
        "Keyword(#{string})"
    end


    def at_operator?
        string[0] == '@'
    end


    def ends_with_equals?
        string[-1] == '='
    end
end


class String_Token < Token
    def pretty
        "String(#{string})"
    end


    def interpolated?
        string.include? '`'
    end
end


class Symbol_Token < Token
    def pretty
        "Symbol(:#{string})"
    end
end


class Boolean_Token < Token
    def pretty
        "Bool(:#{string})"
    end
end


class Number_Token < Token
    def pretty
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


class Ascii_Token < Token # special symbols of one or more characters. they are not identifiers, they are +, :, &, (, \n, etc. the lexer doesn't care what kind of symbol (newline, binary operator, unary operator, etc), just that it is one.
    BINARY_OPERATORS = %w(. + - * / % < > += -= *= |= /= %= &= ^= <<= >>= !== === >== == != <= >= && || & | ^ << >> ** ./ .? ..) # todo: it sucks having two binary operators lists. one at the top of lexer.rb and here. when you change this, you have to update the operator precedence in parser, and also lexer DOUBLE_SYMBOLS
    UNARY_OPERATORS  = %w(- + ~ !)


    def pretty
        # "#{string}"
        string
    end


    def binary?
        BINARY_OPERATORS.include? string
    end


    def unary?
        UNARY_OPERATORS.include? string
    end


    def composition?
        %w(+: -:).include? string
    end
end


class Comment_Token < Token
    attr_accessor :multiline # may be useful for generating documentation

    def initialize string = nil, multiline = false
        super string
        @multiline = multiline
    end


    # this is required because Token== is custom so I can do Token == "}". Not good but oh well.
    def == other
        other.is_a? Comment_Token
    end


    def pretty
        # "Comment(#{string})"
        "Comment()"
    end
end


class Macro_Token < Token # %s(), %S(), %d(), etc
end
