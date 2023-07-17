require './frontend/opal.rb'
require './frontend/token.rb'

filename = './opal/example.opal'

@tokens = []
@opal   = Opal.new

def is_literal?(word)
  /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/ =~ word
end

def add_token(token)
  # puts "ADD: #{token}"
  @tokens << token
end

File.open(filename).read&.each_line&.with_index do |code_on_this_line, line_number|
  indent_in_spaces = code_on_this_line[/\A\s*/]&.size
  words            = code_on_this_line.split ' '

  words.each_with_index do |word, index|
    # returns the index of the first char of the word within the line
    index_start = code_on_this_line.index word
    index_end   = index_start + word.length - 1

    token                  = Token.new
    token.indent_in_spaces = indent_in_spaces
    token.char_range       = index_start..index_end
    token.start_char       = word[0]
    token.end_char         = word[-1]
    token.word             = word
    token.value            = word
    token.line_code        = code_on_this_line
    token.line_number      = line_number
    token.line_length      = code_on_this_line.length - 1
    token.word_number      = index
    token.word_length      = word.length - 1

    is_comment          = Opal::COMMENTS.include?(token.word)
    is_identifier       = Opal::IDENTIFIERS.include?(token.word)
    is_literal          = is_literal?(token.word)
    is_boolean_literal  = Opal::BOOLEAN_LITERALS.include?(token.word)
    is_logical_operator = Opal::LOGICAL_OPERATORS.include?(token.word)
    # is_method           = Opal::METHODS.include?(token.word)
    is_object = Opal::OBJECTS.include?(token.word)
    is_operator      = Opal::OPERATORS.include?(token.word)
    is_pre_block     = Opal::PRE_BLOCKS.include?(token.word)
    is_pre_type      = Opal::PRE_TYPE.include?(token.end_char)
    is_symbol        = Opal::SYMBOLS.include?(token.word)
    is_type          = Opal::TYPES.include?(token.word)
    is_reserved_word = Opal::RESERVED_WORDS.include?(token.word)
    is_flow_control  = Opal::FLOW_CONTROL.include?(token.word)

    # is_block_operator   = @opal.block_operators.include? token.word
    # is_comment          = @opal.comments.include? token.word
    # is_identifier       = @opal.identifiers.include? token.word
    # is_literal          = is_literal? token.word
    # is_boolean_literal  = @opal.boolean_literals.include? token.word
    # is_logical_operator = @opal.logical_operators.include? token.word
    # is_method           = @opal.methods.include? token.word
    # is_object           = @opal.objects.include? token.word
    # is_operator         = @opal.operators.include? token.word
    # is_pre_block        = @opal.pre_blocks.include? token.word
    # is_pre_type         = @opal.pre_type.include? token.end_char
    # is_symbol           = @opal.symbols.include? token.word
    # is_type             = @opal.types.include? token.word
    # is_reserved_word    = @opal.reserved_words.include? token.word
    # is_keyword          = @opal.keywords.include? token.word
    # is_pre_return_type  = @opal.pre_return_type.include? token.word

    # using regex, we will check if the word has an open paren inside of it
    has_open_paren  = /\(/ =~ token.word
    has_close_paren = /\)/ =~ token.word

    # handle special cases, like adding a pre_type token

    if is_pre_type
      # t            = token.dup
      # t.token_type = TokenType.new(name: :pre_type, value: ':')
      # t.value      = ':'
      # @tokens << t

      # token.value      = token.word[0..-2]
      # token.token_type = TokenType.new(name: :identifier)
      # add_token(token)
      # next
    end

    if has_open_paren
      token.token_type = TokenType.new(name: :identifier)

      parts = token.word.split '('
      if parts.length > 1
        # means the word looks like `func_name(identifier_name` and both sides of the paren are identifiers
        # Splitting the word into tokens
        first_part  = parts[0]
        second_part = parts[1]

        # Token for the function name
        func_name_token             = Token.new
        func_name_token.token_type  = TokenType.new(name: :identifier)
        func_name_token.char_range  = index_start...(index_start + first_part.length)
        func_name_token.start_char  = first_part[0]
        func_name_token.end_char    = first_part[-1]
        func_name_token.word        = first_part
        func_name_token.value       = first_part
        func_name_token.line_code   = code_on_this_line
        func_name_token.line_number = line_number
        func_name_token.line_length = code_on_this_line.length - 1
        func_name_token.word_number = index
        func_name_token.word_length = first_part.length - 1
        token.indent_in_spaces = indent_in_spaces

        @tokens << func_name_token

        # Token for the identifier name
        literal_name_token             = Token.new
        literal_name_token.char_range  = (index_start + first_part.length + 1)...index_end
        literal_name_token.start_char  = second_part[0]
        literal_name_token.end_char    = second_part[-1]
        literal_name_token.word        = second_part
        literal_name_token.value       = second_part[0...-1]
        literal_name_token.token_type  = TokenType.new(name: :identifier)
        literal_name_token.line_code   = code_on_this_line
        literal_name_token.line_number = line_number
        literal_name_token.line_length = code_on_this_line.length - 1
        literal_name_token.word_number = index + 1
        literal_name_token.word_length = second_part.length - 1
        literal_name_token.indent_in_spaces = indent_in_spaces
        # todo) split this into identifier and pre type, perhaps it's time for a method ;)

        @tokens << literal_name_token
        next

        # todo) should I add the paren tokens?
      end
    end

    if has_close_paren
      token.token_type = TokenType.new(name: :identifier)
      parts            = token.word.split ')'
      first_part       = parts[0]

      type_token            = Token.new
      type_token.token_type = TokenType.new(name: :type)
      # finish this code
      type_token.char_range  = index_start..index_end
      type_token.start_char  = word[0]
      type_token.end_char    = word[-1]
      type_token.word        = word
      type_token.value       = word[0...-1]
      type_token.token_type  = TokenType.new(name: :type)
      type_token.line_code   = code_on_this_line
      type_token.line_number = line_number
      type_token.line_length = code_on_this_line.length - 1
      type_token.word_number = index
      type_token.word_length = word.length - 1
      type_token.indent_in_spaces = indent_in_spaces
      @tokens << type_token
      next
    end

    token.token_type =
      if is_object
        TokenType.new(name: :object)
      elsif is_comment
        TokenType.new(name: :comment)
      elsif is_logical_operator
        TokenType.new(name: :logical_operator)
      elsif is_pre_block
        TokenType.new(name: :pre_block)
      elsif is_type
        TokenType.new(name: :type)
      elsif is_operator
        TokenType.new(name: :operator)
      elsif is_literal
        TokenType.new(name: :literal)
      elsif is_symbol
        TokenType.new(name: :key_symbol)
      elsif is_boolean_literal
        TokenType.new(name: :boolean_literal)
      elsif is_reserved_word
        TokenType.new(name: :reserved_word)
      elsif is_identifier
        TokenType.new(name: :identifier)
      else
        TokenType.new(name: :unknown)
      end

    add_token(token)
  end
end

puts @tokens
