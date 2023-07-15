class TokenType
  attr_reader :name

  # eg) TokenType.new(string: 'int', is_key_word: true)
  def initialize(**options)
    options.each do |key, value|
      instance_variable_set("@#{key}", value) if respond_to?(key)
    end
  end

  def to_s
    "#{name}"
  end
end

class Token
  attr_accessor :token_type # TokenType
  attr_accessor :token_sub_type

  attr_accessor :char_range # eg) 0..3

  attr_accessor :line_code
  attr_accessor :line_number
  attr_accessor :line_length
  attr_accessor :word_number
  attr_accessor :word_length
  attr_accessor :original_word
  attr_accessor :word # hint) this starts the same value as @original_word, but may differ by some chars based on the type of this token. eg) `variable:` would become `variable` when formatted because the

  attr_accessor :start_char
  attr_accessor :end_char
  attr_accessor :second_char
  attr_accessor :second_last_char

  # use the index to determine the distance to the token. 0 is the current token, 1 is the next token, -1 is the previous token, so really just the index in the positive (forward) or negative (backward) direction
  attr_accessor :tokens_ahead
  attr_accessor :tokens_behind

  # hint) it's best to assume any of the following properties could be nil, because they may not be set yet


  attr_accessor :next_word
  attr_accessor :previous_word


  def initialize
    @tokens_ahead  = []
    @tokens_behind = []
  end

  def to_s
    " #{token_type}\n\t#{word}\n\n"
  end

  def inspect
    "\n#{super}\n"
  end
end
