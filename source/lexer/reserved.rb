COMMENTS         = %w(# ~ // ### ~~~ ///)
LOGGING          = %w(@log @warn @error)
NUMBER_LITERALS  = %w(0 1 2 3 4 5 6 7 8 9)
BOOLEAN_LITERALS = %w(true false)

BUILTIN_TYPES = %w(int float str bool dict array nil)
CLASSIC_TYPES = %w(class struct)

WORDS = %w(self enum new it at obj api is when while for loop def stop next end if else while for return obj iam)

OTHERS = [
  COMMENTS,
  LOGGING,
  NUMBER_LITERALS,
  BOOLEAN_LITERALS,
# DELIMITERS
].flatten

TYPES = %w(
 int float array dictionary bool string
 yes no true false
 nil
)

# NEW

KEYWORDS = %w(
 api obj def new end
 enum const private public static
 do if else for next stop at it is self when while
)

# in this specific order so multi character operators are matched first

TRIPLE_SYMBOLS = %w(=== ||=)
DOUBLE_SYMBOLS = %w(== != <= >= += -= *= /= |= && || @@ ++ -- ->)
SINGLE_SYMBOLS = %w(! ? ~ = + - * / % < > ( ) : [ ] { } , . ; @ & |)

SYMBOLS = [
  TRIPLE_SYMBOLS,
  DOUBLE_SYMBOLS,
  SINGLE_SYMBOLS
].flatten
