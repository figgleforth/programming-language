class Token
  attr_reader :type, :name, :line

  def initialize(type, name, line)
    @type = type
    @name = name
    @line = line
  end

  def inspect
    "Line #{@line}: #{@name} is #{@type}"
  end
end

module TokenType
  # keywords
  KEYWORD  = :keyword
  Keywords = %w[true false if else while for in return bail skip end it]

  # literals
  IDENTIFIER = :identifier # eg) variable_name
  STRING     = :string
  NUMBER     = :number

  # operators
  OPERATOR = :operator # eg) + - * / % = == != < > <= >=

  # punctuation
  PUNCTUATION = :punctuation # eg) { } ( ) [ ] , . ;

  # types
  TYPE  = :type # eg) int, float, string, bool, etc
  Types = %w[num int float string bool array]

  # comments
  COMMENT = :comment

  EOF = :eof
end

