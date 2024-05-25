COMMENTS         = %w(# ~ // ### ~~~ ///)
LOGGING          = %w(@log @warn @error)
NUMBER_LITERALS  = %w(0 1 2 3 4 5 6 7 8 9)
BOOLEAN_LITERALS = %w(true false)
DELIMITERS       = %w(( ) : [ ] { } , . ;)

BINARY_OPERATORS   = %w(+ - * / %)
EQUALITY_OPERATORS = %w(= == != < > <= >= &&)
LOGICAL_OPERATORS  = %w(&& || ! and or not)

BUILTIN_TYPES = %w(int float str bool dict array nil)
CLASSIC_TYPES = %w(class struct)

SYMBOLS = %w(@ @@)
WORDS   = %w(self enum new it at obj api is when while for loop def stop next end if else while for return obj iam)

# KEYWORDS = [
#   SYMBOLS,
#   BUILTIN_TYPES,
#   WORDS,
#   LOGGING
# ].flatten

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

KEYWORDS = %w(
 api obj def new end
 int float array dictionary bool string
 enum const private public static
 do if else for next stop at it is self when while nil
 yes no true false
)
