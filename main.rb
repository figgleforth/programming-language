require './frontend/language.rb'
require './frontend/token.rb'

@tokens   = []
@words    = []
@language = Language.new

File.open('./language/test.lang').read.each_line.with_index do |code_on_this_line, line_number|

  @words = code_on_this_line.split ' '

  @words.each_with_index do |word, index|
    # returns the index of the first char of the word within the line
    index_start = code_on_this_line.index word
    index_end   = index_start + word.length - 1

    token                  = Token.new
    token.char_range       = index_start..index_end
    token.start_char       = word[0]
    token.end_char         = word[-1]
    token.second_char      = word[1]
    token.second_last_char = word[-2]
    token.previous_word    = @words[index - 1]
    token.next_word        = @words[index + 1]
    token.original_word    = word
    token.word             = word
    token.line_code        = code_on_this_line
    token.line_number      = line_number
    token.line_length      = code_on_this_line.length - 1
    token.word_number      = index
    token.word_length      = word.length - 1
    token.is_pre_type      = @language.pre_type.include? token.end_char
    token.is_type          = @language.types.include? token.original_word
    token.is_key_symbol    = @language.symbols.include? token.original_word
    token.is_key_word      = @language.keywords.include? token.original_word
    token.is_operator      = @language.operators.include? token.original_word

    # check if is_literal using regex
    token.is_literal = /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/ =~ token.original_word

    # here we can determine the token type  based on the properties above
    if token.is_pre_type
      token.word       = token.original_word[0..-2]
      token.token_type = TokenType.new(name: :identifier)
    end

    if token.is_type
      token.token_type = TokenType.new(name: :type)
    end

    if token.is_operator
      token.token_type = TokenType.new(name: :operator)
    end

    if token.is_literal
      token.token_type = TokenType.new(name: :literal)
    end

    @tokens << token
  end
end

puts @tokens
