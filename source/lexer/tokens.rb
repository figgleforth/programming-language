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
      '[ eof ]'
   end
end


class DelimiterToken < Token
   def to_s
      if string == ';'
         "[ ; ]"
      elsif string == "\s"
         "[ ' ' ]"
      else
         "[ \\n ]"
      end
   end
end


class WhitespaceToken < Token
   def to_s
      "\\s"
   end
end


class IdentifierToken < Token
   def to_s
      "Ident(#{string})"
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
end


class SymbolToken < Token # special symbols of one or more characters. they are not identifiers, they are +, :, &, (, \n, etc. the lexer doesn't care what kind of symbol (newline, binary operator, unary operator, etc), just that it is one.
   def to_s
      "[ #{string} ]"
   end
end


class CommentToken < Token
   attr_accessor :multiline # may be useful for generating documentation

   def initialize string = nil, multiline = false
      super string
      @multiline = multiline
   end


   def to_s
      "Comment(#{string})"
   end
end

