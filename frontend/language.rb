class Language
  require 'ostruct'

  attr_accessor :keywords
  attr_accessor :symbols
  attr_accessor :identifiers
  attr_accessor :pre_blocks
  attr_accessor :block_operators
  attr_accessor :pre_type
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
    @symbols         = %w(@)
    @identifiers     = %w(self bwah)
    @pre_blocks      = %w(if else while for)
    @block_operators = %w(stop next it index)
    @pre_type        = %w(:)
    @types           = %w(int float str bool list dict)
    @comments        = %w(#)
    @operators       = %w(+ - * / % = == != < > <= >=)
    @logical_operators = %w(&& || ! and or not)
    @loop_operators    = %w(stop next it index)

    @keywords = [
      @identifiers,
      @pre_blocks,
      @block_operators,
      @types,
      @loop_operators,
    ].flatten
  end
end
