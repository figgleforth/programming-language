class Token
   attr_accessor :string


   def initialize string = nil
      @string = string
   end


   # token == CommentToken
   # token == '#'
   def == other
      if other.is_a? Class
         other == self.class
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
      'EOF'
   end
end


class DelimiterToken < Token
   def to_s
      if string == ';'
         "   [;]"
      elsif string == "\s"
         "   [s]"
      else
         "   [n]"
      end
   end
end


class WhitespaceToken < Token
   def to_s
      self.object_id
      "\\s"
   end
end


class IdentifierToken < Token
   attr_accessor :symbol_literal


   def to_s
      if symbol_literal
         ":#{string}"
      else
         "#{string}"
      end
   end
end


class KeywordToken < Token
   def to_s
      "Keyword(#{string})"
   end
end


class StringToken < Token
   def to_s
      "String(#{string})"
   end


   def interpolated?
      string.include? '`'
   end
end


class NumberToken < Token
   def to_s
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


class SymbolToken < Token # special symbols of one or more characters. they are not identifiers, they are +, :, &, (, \n, etc. the lexer doesn't care what kind of symbol (newline, binary operator, unary operator, etc), just that it is one.
   BINARY_OPERATORS = %w(. + - * / % < > [ \\+= -= *= |= /= %= &= ^= <<= >>= !== === >== == != <= >= && || & | ^ << >> **)
   UNARY_OPERATORS  = %w(- + ~ !)

   def to_s
      "#{string}"
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


   def to_s
      # "Comment(#{string})"
      "Comment()"
   end
end

