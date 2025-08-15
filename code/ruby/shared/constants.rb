SORT_BY_LENGTH_DESC        = ->(str) { -str.size }
REFERENCE_PREFIX           = '@' # I'm not sold on this yet, tbd.
INTERPOLATE_CHAR           = '|'
COMMENT_CHAR               = '`'
COMMENT_MULTILINE_CHAR     = '```'
PREFIX                     = %w(! - + ~ $ @ # ? & ^ not return).sort_by &SORT_BY_LENGTH_DESC
INFIX                      = %w(
		+ - ^ * ** / % ~ == === ? . .?
		= : ||= &&= **= <<= >>= += -= *= |= /= %= &= ^=
		&& || & | << >>
		.. >. .< ><
		!= <= >= < > <=> < >
		and or
	).sort_by &SORT_BY_LENGTH_DESC
POSTFIX                    = %w() # Be sure not to make ; a postfix operator because it behaves as postfix with a declaration but as a delimiter inside func param declarations.
CIRCUMFIX                  = %w( \( [ { | )
CIRCUMFIX_GROUPINGS        = { '(' => '()', '{' => '{}', '[' => '[]', '|' => '||' }.freeze
LOGICAL_OPERATORS          = %w(&& & || | and or).sort_by &SORT_BY_LENGTH_DESC
COMPOUND_OPERATORS         = %w(||= &&= **= <<= >>= += -= *= |= /= %= &= ^=).sort_by &SORT_BY_LENGTH_DESC
COMPARISON_OPERATORS       = %w(<=> == === != !== <= >= < > =~ !~).sort_by &SORT_BY_LENGTH_DESC
INFIX_ARITHMETIC_OPERATORS = %w(+ - * ** / % << >> ^ & |).sort_by &SORT_BY_LENGTH_DESC
RANGE_OPERATORS            = %w(.. .< >. ><).sort_by &SORT_BY_LENGTH_DESC
DOT_ACCESS_OPERATORS       = %w(. .?).sort_by &SORT_BY_LENGTH_DESC
TYPE_COMPOSITION_OPERATORS = %w(| & ~ ^) # Union, Intersection, Removal, Symmetric Difference
ANY_IDENTIFIER             = %i(identifier Identifier IDENTIFIER)
GSCOPE                     = :global
SCOPE_OPERATORS            = %w(./ ../ .../).sort_by &SORT_BY_LENGTH_DESC
STARTING_PRECEDENCE        = 0
DELIMITERS                 = %W(, ; { } ( ) [ ] \n \r).freeze
NEWLINES                   = %W(\r\n \n).freeze
WHITESPACES                = %W(\t \s).freeze
NUMERIC_REGEX              = /\A\d+\z/
ALPHA_REGEX                = /\A\p{Alpha}+\z/
ALPHANUMERIC_REGEX         = /\A\p{Alnum}+\z/
SYMBOLIC_REGEX             = /\A[^\p{Alnum}\s]+\z/

# It's been a while, but I believe this RESERVED list must be maintained. The other declarations above are helpers for comparisons while this contains every reserved symbols and identifiers.
RESERVED = %w(
		[ { ( , _ . ) } ]
		: ;
		+ - * ** / % ~
		= ||= &&= **= <<= >>= += -= *= |= /= %= &= ^=
		== === != !== <= >= < >
		! ? ?? !! && || & | << >>
		.. >. .< >< <=>
		@ ./ ../ .../ ~/
		``` `

		for
		if elif else
		while elwhile
		unless until
		true false nil
		and or return
	).sort_by &SORT_BY_LENGTH_DESC # todo, I want to add `remove` here as well but not is not the time.
