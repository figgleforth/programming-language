class TokenType
  attr_accessor :name

  # lets you instantiate a new TokenType with a hash of options, eg) TokenType.new(string: 'int', is_key_word: true)
  def initialize(**options)
    options.each do |key, value|
      instance_variable_set("@#{key}", value) if respond_to?(key)
    end
  end
end

class Token
  # hint) these are definitely set in the parser
  attr_accessor :first_char
  attr_accessor :second_char
  attr_accessor :second_last_char
  attr_accessor :last_char

  attr_accessor :raw_line
  attr_accessor :raw_word
  attr_accessor :formatted_word


  # use the index to determine the distance to the token. 0 is the current token, 1 is the next token, -1 is the previous token, so really just the index in the positive (forward) or negative (backward) direction
  attr_accessor :tokens_ahead
  attr_accessor :tokens_behind

  # hint) it's best to assume any of the following properties could be nil

  attr_accessor :token_type # TokenType

  attr_accessor :next_word
  attr_accessor :previous_word

  attr_accessor :is_key_word
  attr_accessor :is_key_symbol
  attr_accessor :is_identifier
  attr_accessor :is_pre_type
  attr_accessor :is_type
  attr_accessor :is_user_type
  attr_accessor :is_operator
  attr_accessor :is_logical_operator
  attr_accessor :is_pre_block
  attr_accessor :is_block_operator
  attr_accessor :is_comment

  def initialize
    @tokens_ahead = []
    @tokens_behind = []
  end
end
