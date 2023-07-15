require './frontend/language.rb'
require './frontend/token.rb'

@tokens   = []
@words    = []
@language = Language.new

def is_literal?(word)
  /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/ =~ word
end

File.open('./language/test.lang').read.each_line.with_index do |code_on_this_line, line_number|

  @words = code_on_this_line.split ' '

  @words.each_with_index do |word, index|
    # returns the index of the first char of the word within the line
    index_start = code_on_this_line.index word
    index_end   = index_start + word.length - 1

    token               = Token.new
    token.char_range    = index_start..index_end
    token.start_char    = word[0]
    token.end_char      = word[-1]
    token.previous_word = @words[index - 1]
    token.next_word     = @words[index + 1]
    token.original_word = word
    token.word          = word
    token.line_code     = code_on_this_line
    token.line_number   = line_number
    token.line_length   = code_on_this_line.length - 1
    token.word_number   = index
    token.word_length   = word.length - 1

    is_block_operator   = @language.block_operators.include? token.original_word
    is_comment          = @language.comments.include? token.original_word
    is_identifier       = @language.identifiers.include? token.original_word
    is_literal          = is_literal? token.original_word
    is_boolean_literal  = @language.boolean_literals.include? token.original_word
    is_logical_operator = @language.logical_operators.include? token.original_word
    is_loop_operator    = @language.loop_operators.include? token.original_word
    is_operator         = @language.operators.include? token.original_word
    is_pre_type         = @language.pre_type.include? token.end_char
    is_symbol           = @language.symbols.include? token.original_word
    is_type             = @language.types.include? token.original_word
    is_keyword          = @language.keywords.include? token.original_word
    is_pre_return_type  = @language.pre_return_type.include? token.original_word

    # using regex, we will check if the word has an open paren inside of it
    has_open_paren  = /\(/ =~ token.original_word
    has_close_paren = /\)/ =~ token.original_word

    if has_open_paren
      token.token_type = TokenType.new(name: :identifier)

      parts = token.original_word.split '('
      if parts.length > 1
        # means the word looks like `func_name(identifier_name` and both sides of the paren are identifiers
        # Splitting the word into tokens
        first_part  = parts[0]
        second_part = parts[1]

        # Token for the function name
        func_name_token               = Token.new
        func_name_token.token_type    = TokenType.new(name: :identifier)
        func_name_token.char_range    = index_start...(index_start + first_part.length)
        func_name_token.start_char    = first_part[0]
        func_name_token.end_char      = first_part[-1]
        func_name_token.original_word = first_part
        func_name_token.word          = first_part
        func_name_token.line_code     = code_on_this_line
        func_name_token.line_number   = line_number
        func_name_token.line_length   = code_on_this_line.length - 1
        func_name_token.word_number   = index
        func_name_token.word_length   = first_part.length - 1

        @tokens << func_name_token

        # Token for the identifier name
        literal_name_token               = Token.new
        literal_name_token.char_range    = (index_start + first_part.length + 1)...index_end
        literal_name_token.start_char    = second_part[0]
        literal_name_token.end_char      = second_part[-1]
        literal_name_token.original_word = second_part
        literal_name_token.word          = second_part[0...-1]
        literal_name_token.token_type    = TokenType.new(name: :identifier)
        literal_name_token.line_code     = code_on_this_line
        literal_name_token.line_number   = line_number
        literal_name_token.line_length   = code_on_this_line.length - 1
        literal_name_token.word_number   = index + 1
        literal_name_token.word_length   = second_part.length - 1
        # todo) split this into identifier and pre type, perhaps it's time for a method ;)

        @tokens << literal_name_token
        next

        # todo) should I add the paren tokens?
      end
    end

    if has_close_paren
      token.token_type = TokenType.new(name: :identifier)
      parts            = token.original_word.split ')'
      first_part       = parts[0]

      type_token            = Token.new
      type_token.token_type = TokenType.new(name: :type)
      # finish this code
      type_token.char_range    = index_start..index_end
      type_token.start_char    = word[0]
      type_token.end_char      = word[-1]
      type_token.original_word = word
      type_token.word          = word[0...-1]
      type_token.token_type    = TokenType.new(name: :type)
      type_token.line_code     = code_on_this_line
      type_token.line_number   = line_number
      type_token.line_length   = code_on_this_line.length - 1
      type_token.word_number   = index
      type_token.word_length   = word.length - 1
      @tokens << type_token
      next
    end

    token.token_type =
      if is_block_operator
        TokenType.new(name: :block_operator)
      elsif is_comment
        TokenType.new(name: :comment)
      elsif is_identifier
        TokenType.new(name: :identifier)
      elsif is_logical_operator
        TokenType.new(name: :logical_operator)
      elsif is_loop_operator
        TokenType.new(name: :loop_operator)
      elsif is_pre_type
        token.word = token.original_word[0..-2]
        TokenType.new(name: :identifier)
      elsif is_pre_return_type
        TokenType.new(name: :pre_return_type)
      elsif is_type
        TokenType.new(name: :type)
      elsif is_operator
        TokenType.new(name: :operator)
      elsif is_literal
        TokenType.new(name: :literal)
      elsif is_symbol
        TokenType.new(name: :key_symbol)
      elsif is_keyword
        TokenType.new(name: :key_word)
      elsif is_boolean_literal
        TokenType.new(name: :boolean_literal)
      else
        puts word.length
        TokenType.new(name: :unknown)
      end

    @tokens << token
  end
end

puts @tokens
