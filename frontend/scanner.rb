require './frontend/character_info'
require './frontend/token_types'

class Scanner
  attr_accessor :source_code, :tokens, :curr_char, :curr_line
  attr_accessor :start_index, :curr_index, :line

  def initialize(source)
    @source_code = source
    @tokens      = []
    @curr_index  = 0
    @start_index = 0
    @curr_char   = nil
    @curr_line   = nil
  end

  def start
    until at_end?

      # @curr_char  = next_char!
      # start_index = curr_index

      # get the remainder source code substring starting at start_index and strip to ignore whitespaces so that the scan method doesn't have to worry about it
      curr_line = source_code[(start_index - 1)..-1].split("\n").first
      # puts "curr_line: #{curr_line.inspect}"
      remainder = source_code[start_index..-1].strip

      scan @curr_char, next_char, remainder

      @curr_char  = next_char!
      start_index = curr_index
    end

    add :eof
  end

  def scan(character, next_character, remainder)

    case character
    when ' '
    when '('
      add :left_paren
    when ')'
      add :right_paren
    when ':'
      add :type_colon
    when ','
      add :comma
    when '='
      add :assignment
    when '+'
      add :plus
    when '-'
      add :minus
    when '*'
      add :multiply
    when '/'
      add :divide
    when '%'
      add :modulo
    when '<'
      if next_character == '='
        add :less_than_or_equal
      else
        add :less_than
      end
    when '>'
      if next_character == '='
        add :greater_than_or_equal
      else
        add :greater_than
      end
    when '!'
      # todo) names can have ! in them, so check previous char(s) in case this is a not an operator
      add :not
    when '0'..'9'
      # start_index = current
      # look_ahead  = 1
      # # next_char   = next_char(look_ahead)
      # while next_character =~ /\d/
      #   look_ahead += 1
      #   # next_char  = next_char(look_ahead)
      # end
      #
      # if next_char == '.'
      #   # next_char!
      #   while next_char =~ /\d/
      #     # next_char!
      #   end
      # end
      # value       = source_code[start_index..current]
      # add :number_literal, value
    else
      # split remainder by delimeters, operators, and keywords, or whatever. basically I want to check if the code string following this char is a keyword, operator, or literal, or whatever else we did not catch above. the above is basically single character keywords, this here would be multiple character keywords.
      add(:identifier, character) if /^[a-zA-Z_][a-zA-Z0-9_]*$/ =~ character
    end
  end

  def next_char(ahead = 1)
    # returns next char without incrementing position
    source_code[@curr_index + ahead]
  end

  def next_char!
    # returns next char after incrementing position
    @curr_index += 1
    next_char 0
  end

  def add(token_type, value = nil)
    tokens << token(token_type, value)
  end

  def token(type, value = nil)
    { token_type: type, value: value || @curr_char } #, indent:  }
  end

  def at_end?
    @curr_index >= source_code.length
  end
end
