# Turns string of code into tokens
class Lexer
   require_relative 'helpers/lexer'
   require_relative 'frontend/token'

   attr_accessor :i, :x, :y, :source, :char, :tokens


   def initialize source
      @source = source
      @char   = @source[0]
      @tokens = []
      @i      = 0 # index of current character in source string
      @x      = 0 # short for column
      @y      = 1 # short for line
   end


   def reached_end?
      i >= @source.length
   end


   def current_char
      @char = @source[i]
   end


   def eat
      if newline?(char)
         @y += 1
         @x = 0
      else
         @x += 1
      end

      @i += 1
      @source[i - 1]
   end


   def eat_many distance = 1
      str = ''
      distance.times do
         str += eat
      end

      str
   end


   def peek distance = 1, length = 1
      @source[i + distance, length]
   end


   def eat_number
      valid  = %w(. _ ,)
      number = ''

      while (numeric?(char) or valid.include?(char)) and not reached_end?
         number << char
         eat
         break if newline?(char) or whitespace?(char)
      end

      number
   end


   def eat_identifier
      valid      = %w(! ?)
      identifier = ''

      while identifier?(char) or valid.include?(char)
         if reached_end?
            puts "Reached end while parsing identifier"
            break
         end

         identifier += char
         eat

         # can't check against `char` because it was eaten. could peek(-1) but nah
         break if valid.include? identifier.chars.last
      end

      identifier
   end


   def eat_number_or_identifier
      number = eat_number

      # support 1st, 2nd, 3rd?, 4th!, etc identifier syntax
      if alpha?(char)
         word = number + eat_identifier
         IdentifierToken.create(word)
      else
         NumberToken.new(number)
      end
   end


   def eat_special_character
      if Token.is? peek(0, 3)
         eat_many(3) # triple symbols like ||=
      elsif OperatorToken.is? peek(0, 3)
         eat_many(3) # triple symbols like ||=
      elsif Token.is? peek(0, 2)
         eat_many(2) # double symbols like +=
      elsif OperatorToken.is? peek(0, 2)
         eat_many(2) # double symbols like +=
      else
         eat
      end
   end


   def eat_multiline_comment
      eat_many(3) # eat triple backtick

      eat while whitespace?(char) or newline?(char)

      comment = ''

      while not reached_end? and peek(0, 3) != '```'
         comment += eat
      end

      eat_many(3) # eat ending triple backtick

      comment
   end


   def eat_single_comment
      eat # eat the hash

      # skip whitespace or tab before body
      eat while whitespace?(char)

      comment = ''

      while not reached_end? and not newline?(char)
         comment += eat
      end

      comment
   end


   def eat_string
      starting_quote = eat

      str = ''

      until reached_end? or char == starting_quote
         str += eat
      end

      raise 'Expected ending quote' unless char == starting_quote

      eat # eat the ending quote

      str
   end


   def make_tokens
      until reached_end?
         if %W(' ").include? char
            tokens << StringToken.new(eat_string)

         elsif numeric?(char) or (char == '.' and numeric?(peek))
            tokens << eat_number_or_identifier

         elsif identifier?(char) or (char == '_' and alphanumeric?(peek))
            tokens << IdentifierToken.create(eat_identifier)

         elsif Token.is?(peek(0, 3))
            tokens << Token.new(eat_many(3))

         elsif OperatorToken.is?(peek(0, 3))
            tokens << OperatorToken.new(eat_many(3))

         elsif Token.is?(peek(0, 2))
            tokens << Token.new(eat_many(2))

         elsif OperatorToken.is?(peek(0, 2))
            tokens << OperatorToken.new(eat_many(2))

         elsif Token.is?(char)
            tokens << Token.new(eat)

         elsif OperatorToken.is?(char)
            tokens << OperatorToken.new(eat)

         elsif peek(0, 3) == '```' # multi line comment
            tokens << BlockCommentToken.new(eat_multiline_comment)

         elsif char == '#' # single line comment
            tokens << CommentToken.new(eat_single_comment)

         elsif newline?(char)
            tokens << NewlineToken.new(eat)

         else
            raise "\n\nUnexpected #{char} at line #{y} col #{x}\n\n\t#{source[i, 3]}"
         end

         eat while whitespace?(char) # or newline?(char)
      end

      tokens
   end


   alias_method :char, :current_char
end
