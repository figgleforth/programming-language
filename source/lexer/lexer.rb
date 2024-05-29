# Turns string of code into tokens
class Lexer
   require_relative 'tokens'
   require_relative 'reserved'

   attr_accessor :i, :col, :row, :source, :tokens


   def initialize source
      @source = source
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
         @string == ' ' or @string == "\t"
      end


      def newline?
         @string == "\n"
      end


      def colon?
         @string == ';'
      end


      def delimiter?
         colon? or newline? or whitespace?
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
         @string == other
      end
   end


   def raise_unknown_char
      exception = UnknownChar.new char.string
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


   def char
      Char.new source[@i]
   end


   def peek distance = 1, length = 1
      Char.new source[@i + distance, length]
   end


   def last
      source[@i - 1]
   end


   def eat expected = nil
      if char.newline?
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

         while chars? and (char.numeric? or valid.include?(char.string))
            number << eat
            break if char.newline? or char.whitespace?
         end
      end
   end


   def eat_identifier
      ''.tap do |ident|
         valid = %w(! ?)
         while char.identifier? or valid.include?(char.string)
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
      if char.alpha?
         IdentifierToken.new(number + eat_identifier)
      else
         NumberToken.new(number)
      end
   end


   def eat_oneline_comment
      ''.tap do |comment|
         eat '#' # eat the hash
         eat while char.whitespace? # skip whitespace or tab before body

         while chars? and not char.newline?
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
         eat while char.whitespace? or char.newline?

         while chars? and peek(0, 3) != marker
            comment << eat
            eat while char.newline?
         end

         eat_many 3, marker
         eat "\n" while char.newline? # don't care to know if there's a newline after a comment
      end
   end


   def eat_string
      ''.tap do |str|
         quote = eat

         while chars? and char != quote
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


   def tokenize
      @tokens = []
      while chars?
         if char.delimiter?
            @tokens << DelimiterToken.new(eat) # \n or ;, but not space
            eat while char.delimiter? # don't care about consecutive delimiters

         elsif char == '#'
            if peek(0, 3) == '###'
               @tokens << CommentToken.new(eat_multiline_comment, true)
            else
               @tokens << CommentToken.new(eat_oneline_comment)
            end

         elsif char == '"' or char == "'"
            @tokens << StringToken.new(eat_string)

         elsif char.numeric?
            @tokens << eat_number_or_numeric_identifier

         elsif char == '.' and peek&.numeric?
            @tokens << NumberToken.new(eat_number)

         elsif char.identifier? or (char == '_' and peek&.alphanumeric?)
            ident = eat_identifier

            # todo check for keywords
            if KEYWORDS.include? ident
               @tokens << KeywordToken.new(ident)

               eat "\n" while char.newline? and ident == 'end' # don't care about newlines after `end` because it's basically a delimiter
            else
               @tokens << IdentifierToken.new(ident)
            end

         elsif SYMBOLS.include? char.string
            if char == ':' and not peek&.delimiter? # :style symbols
               eat ':'

               ident                = eat_identifier
               token                = IdentifierToken.new(ident)
               token.symbol_literal = true

               @tokens << token
            else
               symbol = eat_symbol
               @tokens << SymbolToken.new(symbol)
               eat "\n" while char.newline? and symbol == ';' # don't care about newlines after `end` because it's basically a delimiter
            end

         else
            raise_unknown_char # displays some source code with a caret pointing to the unknown character
         end
      end
      @tokens << EOFToken.new
   end

end
