class Lexer
  attr_accessor :source_code
  attr_accessor :tokens
  attr_accessor :curr_line
  attr_accessor :curr_column
  attr_accessor :curr_word

  def initialize(code)
    @source_code = code
    @tokens      = []
  end

  def start!
    puts "Starting..."
    @source_code.each_line.with_index do |line_source, line|
      # year: int = 2023
      @curr_line = line

      words = line_source.split(' ')
      parse_words(words)
    end

    @tokens << Token.new(TokenType::EOF, 'EOF', @curr_line)

    @tokens.each do |token|
      puts token.inspect
    end
  end

  # ["year:", "int", "=", "2023"]
  def parse_words(words)
    words.each.with_index do |word, index|
      @line = index
      parse_word(word)
    end
  end

  # year:, or int, or =, or 2023
  def parse_word(word)
    @curr_word = word

    first = word[0]
    last  = word[-1]

    case word
    when /^[a-zA-Z]/ # starts with a character

      # this word may have a : as the last character, which means the next word will be the type of this word

      if last == ':'
        word = word[0..-2] if last == ':' # remove the :

        @tokens << Token.new(
          TokenType::IDENTIFIER,
          word,
          @curr_line
        )
      else
        if TokenType::Keywords.include?(word)
          @tokens << Token.new(
            TokenType::KEYWORD,
            word,
            @curr_line
          )
        elsif TokenType::Types.include?(word)
          @tokens << Token.new(
            TokenType::TYPE,
            word,
            @curr_line
          )
        else
          @tokens << Token.new(
            TokenType::IDENTIFIER,
            word,
            @curr_line
          )
        end
      end
    when '='
      @tokens << Token.new(
        TokenType::OPERATOR,
        word,
        @curr_line
      )
    when '('
      last_token = @tokens.last
      if last_token&.type == TokenType::IDENTIFIER
        # this is a function call
      else
        # this is a grouping
      end
    else
      # puts "word", part
    end

  end
end
