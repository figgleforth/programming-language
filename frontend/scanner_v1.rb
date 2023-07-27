require './frontend/tokens.rb'
require './frontend/token.rb'
filename = './hatch/example.hatch'

@tokens = []

def token_for_word(word, index, line_number, indent_in_spaces, code_on_this_line)
  # returns the index of the first char of the word within the line
  index_start = code_on_this_line.index word
  index_end   = index_start + word.length - 1

  # base token info that should be present for all tokens
  token                      = Token.new
  token.indent_in_spaces     = indent_in_spaces
  token.line_code            = code_on_this_line
  token.word                 = word
  token.word_index           = index
  token.contains_colon       = word.include? ":"
  token.contains_open_paren  = word.include? "("
  token.contains_close_paren = word.include? ")"

  token.char_range  = index_start..index_end
  token.start_char  = word[0]
  token.end_char    = word[-1]
  token.value       = word
  token.line_number = line_number
  token.line_length = code_on_this_line.length - 1
  token.word_length = word.length - 1
  return token

  # specific token info
  is_keyword          = KEYWORDS.include?(token.word)
  is_comment          = COMMENTS.include?(token.word)
  is_identifier       = is_identifier?(token.word)
  is_literal          = is_literal?(token.word)
  is_boolean_literal  = BOOLEAN_LITERALS.include?(token.word)
  is_logical_operator = LOGICAL_OPERATORS.include?(token.word)
  # is_method           = METHODS.include?(token.word)
  # is_object        = OBJECTS.include?(token.word)
  # is_operator      = OPERATORS.include?(token.word)
  # is_pre_block     = PRE_BLOCKS.include?(token.word)
  # is_pre_type      = PRE_TYPE.include?(token.end_char)
  # is_symbol        = SYMBOLS.include?(token.word)
  # is_type          = TYPES.include?(token.word)
  # is_reserved_word = RESERVED_WORDS.include?(token.word)
  # is_flow_control  = FLOW_CONTROL.include?(token.word)

  # is_block_operator   = @hatch.block_operators.include? token.word
  # is_comment          = @hatch.comments.include? token.word
  # is_identifier       = @hatch.identifiers.include? token.word
  # is_literal          = is_literal? token.word
  # is_boolean_literal  = @hatch.boolean_literals.include? token.word
  # is_logical_operator = @hatch.logical_operators.include? token.word
  # is_method           = @hatch.methods.include? token.word
  # is_object           = @hatch.objects.include? token.word
  # is_operator         = @hatch.operators.include? token.word
  # is_pre_block        = @hatch.pre_blocks.include? token.word
  # is_pre_type         = @hatch.pre_type.include? token.end_char
  # is_symbol           = @hatch.symbols.include? token.word
  # is_type             = @hatch.types.include? token.word
  # is_reserved_word    = @hatch.reserved_words.include? token.word
  # is_keyword          = @hatch.keywords.include? token.word
  # is_pre_return_type  = @hatch.pre_return_type.include? token.word

  # using regex, we will check if the word has an open paren inside of it
  has_open_paren  = /\(/ =~ token.word
  has_close_paren = /\)/ =~ token.word

  # handle special cases, like adding a pre_type token

  # if is_pre_type
  # t            = token.dup
  # t.token_type = TokenType.new(name: :pre_type, value: ':')
  # t.value      = ':'
  # @tokens << t

  # token.value      = token.word[0..-2]
  # token.token_type = TokenType.new(name: :identifier)
  # @tokens << token
  # next
  # end

  if has_open_paren
    token.token_type = TokenType.new(name: :identifier)

    parts = token.word.split '('
    if parts.length > 1
      # means the word looks like `func_name(identifier_name` and both sides of the paren are identifiers
      # Splitting the word into tokens
      first_part  = parts[0]
      second_part = parts[1]

      # Token for the function name
      func_name_token            = Token.new
      func_name_token.token_type = TokenType.new(name: :identifier)
      func_name_token.char_range = index_start...(index_start + first_part.length)
      func_name_token.start_char = first_part[0]
      func_name_token.end_char   = first_part[-1]
      func_name_token.word       = first_part
      # func_name_token.value       = first_part
      func_name_token.line_code   = code_on_this_line
      func_name_token.line_number = line_number
      func_name_token.line_length = code_on_this_line.length - 1
      func_name_token.word_index  = index
      func_name_token.word_length = first_part.length - 1
      token.indent_in_spaces      = indent_in_spaces

      @tokens << func_name_token

      # Token for the identifier name
      literal_name_token            = Token.new
      literal_name_token.char_range = (index_start + first_part.length + 1)...index_end
      literal_name_token.start_char = second_part[0]
      literal_name_token.end_char   = second_part[-1]
      literal_name_token.word       = second_part
      # literal_name_token.value            = second_part[0...-1]
      literal_name_token.token_type       = TokenType.new(name: :identifier)
      literal_name_token.line_code        = code_on_this_line
      literal_name_token.line_number      = line_number
      literal_name_token.line_length      = code_on_this_line.length - 1
      literal_name_token.word_index       = index + 1
      literal_name_token.word_length      = second_part.length - 1
      literal_name_token.indent_in_spaces = indent_in_spaces
      # todo) split this into identifier and pre type, perhaps it's time for a method ;)

      @tokens << literal_name_token
      return literal_name_token

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
    type_token.char_range = index_start..index_end
    type_token.start_char = word[0]
    type_token.end_char   = word[-1]
    type_token.word       = word
    # type_token.value            = word[0...-1]
    type_token.token_type       = TokenType.new(name: :type)
    type_token.line_code        = code_on_this_line
    type_token.line_number      = line_number
    type_token.line_length      = code_on_this_line.length - 1
    type_token.word_index       = index
    type_token.word_length      = word.length - 1
    type_token.indent_in_spaces = indent_in_spaces
    @tokens << type_token
    return type_token
  end

  # token.token_type =
  #   if is_object
  #     TokenType.new(name: :object)
  #   elsif is_comment
  #     TokenType.new(name: :comment)
  #   elsif is_logical_operator
  #     TokenType.new(name: :logical_operator)
  #   elsif is_pre_block
  #     TokenType.new(name: :pre_block)
  #   elsif is_type
  #     TokenType.new(name: :type)
  #   elsif is_operator
  #     TokenType.new(name: :operator)
  #   elsif is_literal
  #     TokenType.new(name: :literal)
  #   elsif is_symbol
  #     TokenType.new(name: :key_symbol)
  #   elsif is_boolean_literal
  #     TokenType.new(name: :boolean_literal)
  #   elsif is_reserved_word
  #     TokenType.new(name: :reserved_word)
  #   elsif is_identifier
  #     TokenType.new(name: :identifier)
  #   else
  #     TokenType.new(name: :unknown)
  #   end

  token
end

# Pass 1
# split into words by whitespace, map words to tokens, best guess token type

File.open(filename).read&.each_line&.with_index do |code_on_this_line, line_number|
  indent_in_spaces = code_on_this_line[/\A\s*/]&.size
  words            = code_on_this_line.split ' '

  @tokens << words.map.with_index do |word, index|
    token_for_word word, index, line_number, indent_in_spaces, code_on_this_line
  end
end

@tokens.flatten!

# Pass 2
# double check tokens, split or join or fix as needed
#
# [value:] [float] [=] [1]
# should really be
# [value] [:] [float] [=] [1]

@tokens2 = @tokens.dup
@tokens.each do |token|
  if token.contains_colon
    # split this token into [identifier] [:]
    # update this token, insert [:] after it
    token.word        = token.word[0...-1]
    token.end_char    = token.word[-1]
    token.word_length -= 1
    token.char_range  = token.char_range.begin...(token.char_range.end - 1)
    # insert : as next token
    new_token             = token.dup
    new_token.word        = ':'
    new_token.start_char  = ':'
    new_token.end_char    = ':'
    new_token.word_length = 0
    new_token.char_range  = token.char_range.end...token.char_range.end
    new_token.word_index  = token.word_index + 1
    new_token.token_type  = TokenType.new(name: :pre_type)

    # insert it now
    index_of_token = @tokens2.index token
    @tokens2.insert index_of_token + 1, new_token
  end

  if token.contains_open_paren
    parts = token.word.split '('
    # update this token, insert `(` after it, then insert whatever token is after `(` as a new token
    # create a token for each part
    # [identifier] or [type] in case of methods

    # [open paren]

    # [identifier]

  end

  # todo) gather as much info in pass 1, then modify here. so move these to vars on Token, and set in pass 1
  # specific token info
  # has_open_paren      = token.word.include?('(')
  # has_close_paren     = token.word.include?(')')
  is_keyword          = KEYWORDS.include?(token.word)
  is_comment          = COMMENTS.include?(token.word)
  is_identifier       = is_identifier?(token.word)
  is_literal          = is_literal?(token.word)
  is_boolean_literal  = BOOLEAN_LITERALS.include?(token.word)
  is_logical_operator = LOGICAL_OPERATORS.include?(token.word)
  # is_method           = METHODS.include?(token.word)
  # is_object        = OBJECTS.include?(token.word)
  # is_operator      = OPERATORS.include?(token.word)
  # is_pre_block     = PRE_BLOCKS.include?(token.word)
  # is_pre_type      = PRE_TYPE.include?(token.end_char)
  # is_symbol        = SYMBOLS.include?(token.word)
  is_type = TYPES.include?(token.word)
  # is_reserved_word = RESERVED_WORDS.include?(token.word)
  # is_flow_control  = FLOW_CONTROL.include?(token.word)

  # is_block_operator   = @hatch.block_operators.include? token.word
  # is_comment          = @hatch.comments.include? token.word
  # is_identifier       = @hatch.identifiers.include? token.word
  # is_literal          = is_literal? token.word
  # is_boolean_literal  = @hatch.boolean_literals.include? token.word
  # is_logical_operator = @hatch.logical_operators.include? token.word
  # is_method           = @hatch.methods.include? token.word
  # is_object           = @hatch.objects.include? token.word
  # is_operator         = @hatch.operators.include? token.word
  # is_pre_block        = @hatch.pre_blocks.include? token.word
  # is_pre_type         = @hatch.pre_type.include? token.end_char
  # is_symbol           = @hatch.symbols.include? token.word
  # is_type             = @hatch.types.include? token.word
  # is_reserved_word    = @hatch.reserved_words.include? token.word
  # is_keyword          = @hatch.keywords.include? token.word
  # is_pre_return_type  = @hatch.pre_return_type.include? token.word

  # using regex, we will check if the word has parens or : inside of it
  has_open_paren   = /\(/ =~ token.word
  has_close_paren  = /\)/ =~ token.word
  has_colon        = /:/ =~ token.word




  # set all token types!
  token.token_type = TokenType.new(name: :keyword) if is_keyword
  token.token_type = TokenType.new(name: :comment) if is_comment
  token.token_type = TokenType.new(name: :literal) if is_literal
  token.token_type = TokenType.new(name: :boolean_literal) if is_boolean_literal
  token.token_type = TokenType.new(name: :logical_operator) if is_logical_operator
  token.token_type = TokenType.new(name: :identifier) if is_identifier
  token.token_type = TokenType.new(name: :type) if is_type
end

# puts "PASS 1:\n\n", @tokens.map(&:to_s)

puts "\nPASS 2:\n\n", @tokens2.map(&:to_s)

