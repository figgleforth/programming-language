class TokenType
  attr_reader :name

  # any keys and values, comma separated
  def initialize(**options)
    options.each do |key, value|
      instance_variable_set("@#{key}", value) if respond_to?(key)
    end
  end

  def to_s
    "(#{name || 'unknown'})"
  end
end



class Token
  attr_accessor :token_type # TokenType
  attr_accessor :word
  attr_accessor :word_index

  attr_accessor :indent_in_spaces
  attr_accessor :line_code
  attr_accessor :line_number
  attr_accessor :line_length
  attr_accessor :word_length
  attr_accessor :value # hint) this starts the same value as @word, but may differ by some chars based on the type of this token. eg) `variable:` would become `variable` when formatted

  attr_accessor :start_char
  attr_accessor :end_char
  attr_accessor :char_range # eg) 0..3

  attr_accessor :contains_colon
  attr_accessor :contains_open_paren
  attr_accessor :contains_close_paren

  # any keys and values, comma separated
  def initialize(**options)
    options.each do |key, val|
      instance_variable_set("@#{key}", val) if respond_to?(key)
    end
  end

  def to_s
    indent = "".tap do |str|
      (@indent_in_spaces || 0).times do
        str << " "
      end
    end

    "#{indent}#{token_type} #{word}\n"
  end

  def inspect
    "\n#{super}\n"
  end

  def start_char_index
    line_code.index value
  end
end
