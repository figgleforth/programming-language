class Opal
  COMMENTS = %w(# ~ //)
  BOOLEAN_LITERALS = %w(true false)
  DELIMITERS = %w(( ) : [ ] { } , .)
  IDENTIFIERS = %w(self)
  LOGICAL_OPERATORS = %w(&& || ! and or not)
  LOGGING = %w(! !! !!!)
  MULTILINE_COMMENT = %w(## ~~ //)
  OPERATORS = %w(+ - * / % = == != < > <= >=)
  PRE_TYPE = %w(:)
  SYMBOLS = %w(@)
  TYPES = %w(int float str bool dict array list)
  OBJECTS = %w(struct: class:)
  RESERVED_WORDS = %w(iam obj enum new it at iam obj)
  PRE_BLOCKS = %w(while for loop def)
  FLOW_CONTROL = %w(stop next end if else while for return)

  KEYWORDS = [
    BOOLEAN_LITERALS,
    COMMENTS,
    DELIMITERS,
    IDENTIFIERS,
    LOGICAL_OPERATORS,
    LOGGING,
    MULTILINE_COMMENT,
    OPERATORS,
    PRE_TYPE,
    SYMBOLS,
    TYPES,
    OBJECTS,
    RESERVED_WORDS,
    PRE_BLOCKS,
    FLOW_CONTROL
  ].flatten

  def initialize
    # no need for attr_accessor
  end
end



# class Opal
#   # todo) make all of these constants, this is way too much boilerplate.
#
#   comments = %w(# ~ //)
#   # and so on
#
#   attr_accessor :boolean_literals
#   attr_accessor :comments
#   attr_accessor :identifiers
#   attr_accessor :keywords
#   attr_accessor :logical_operators
#   attr_accessor :logging
#   attr_accessor :multiline_comment
#   attr_accessor :objects
#   attr_accessor :operators
#   attr_accessor :pre_blocks
#   attr_accessor :pre_return_type
#   attr_accessor :pre_type
#   attr_accessor :symbols
#   attr_accessor :types
#   attr_accessor :words
#   attr_accessor :flow_control
#   attr_accessor :reserved_words
#
#   def initialize
#     @boolean_literals  = %w(true false)
#     @comments          = %w(# ~ //)
#     @delimiters        = %w(( ) : [ ] { } , .)
#     @identifiers       = %w(self)
#     @logical_operators = %w(&& || ! and or not)
#     @logging           = %w(! !! !!!)
#     @multiline_comment = %w(## ~~ //)
#     @operators         = %w(+ - * / % = == != < > <= >=)
#     @pre_type          = %w(:)
#     @symbols           = %w(@)
#     @types             = %w(int float str bool dict array list)
#     @objects           = %w(struct class)
#     # be more specific with these
#     @reserved_words    = %w(iam obj enum new it at iam obj)
#     @pre_blocks        = %w(while for loop def)
#     @flow_control      = %w(stop next end if else while for return)
#
#     # @keywords is a flattened array of all the arrays above
#     @keywords = [
#       @boolean_literals,
#       @comments,
#       @delimiters,
#       @identifiers,
#       @keywords,
#       @logical_operators,
#       @logging,
#       @multiline_comment,
#       @objects,
#       @operators,
#       @pre_blocks,
#       @pre_type,
#       @symbols,
#       @types,
#       @flow_control,
#       @reserved_words
#     ].flatten
#   end
# end
