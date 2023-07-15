class Language
  require 'ostruct'

  attr_accessor :boolean_literals
  attr_accessor :keywords
  attr_accessor :symbols
  attr_accessor :identifiers
  attr_accessor :pre_blocks
  attr_accessor :block_operators
  attr_accessor :pre_type
  attr_accessor :pre_return_type
  attr_accessor :types
  attr_accessor :comments
  attr_accessor :operators
  attr_accessor :loop_operators
  attr_accessor :logical_operators

  # pre_functions: %w(func),
  # functions: %w(),
  # pre_variables: %w(),
  # variables: %w(),
  # pre_operators: %w(),
  # pre_punctuation: %w(),
  # punctuation: %w(),
  # pre_comments: %w(),
  # pre_eof: %w(),
  # eof: %w(),

  def initialize
    @boolean_literals  = %w(true false)
    @delimiters        = %w(( ))
    @block_operators   = %w(stop next it index end)
    @comments          = %w(#)
    @identifiers       = %w(self)
    @keywords          = %w(end if else while for return)
    @logical_operators = %w(&& || ! and or not)
    @loop_operators    = %w(stop next it index)
    @operators         = %w(+ - * / % = == != < > <= >=)
    @pre_blocks        = %w(if else while for)
    @pre_type          = %w(:)
    @pre_return_type   = %w(->)
    @symbols           = %w(@)
    @types             = %w(int float str bool list dict)

    @keywords = [
      @keywords,
      @identifiers,
      @pre_blocks,
      @block_operators,
      @types,
      @loop_operators,
    ].flatten
  end
end
