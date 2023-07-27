COMMENTS         = %w(# ~ // ### ~~~ ///)
LOGGING          = %w(::)
NUMBER_LITERALS  = %w(0 1 2 3 4 5 6 7 8 9)
BOOLEAN_LITERALS = %w(true false)
DELIMITERS       = %w(( ) : [ ] { } , . ;)

BINARY_OPERATORS   = %w(+ - * / %)
EQUALITY_OPERATORS = %w(= == != < > <= >=)
LOGICAL_OPERATORS  = %w(&& || ! and or not)

SYMBOLS       = %w(@)
TYPES         = %w(int float str bool dict array object obj)
CLASSIC_TYPES = %w(class struct)
WORDS         = %w(enum new it at iam obj api is)
PRE_BLOCKS    = %w(while for loop def)
FLOW_CONTROL  = %w(stop next end if else while for return)
OBJECT        = %w(obj object)

KEYWORDS = [
  SYMBOLS,
  TYPES,
  WORDS,
  PRE_BLOCKS,
  FLOW_CONTROL
].flatten

OPERATORS = [
  BINARY_OPERATORS,
  EQUALITY_OPERATORS,
  LOGICAL_OPERATORS
].flatten

OTHERS = [
  COMMENTS,
  LOGGING,
  NUMBER_LITERALS,
  BOOLEAN_LITERALS,
  DELIMITERS
].flatten

def is_literal?(word)
  /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$/ =~ word
end

def is_identifier?(word)
  /^[a-zA-Z_][a-zA-Z0-9_]*$/ =~ word
end
