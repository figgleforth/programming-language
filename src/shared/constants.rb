SORT_BY_LENGTH_DESC    = ->(str) { -str.size }
INTERPOLATE_CHAR       = '|' # "string with `interpolation`"
COMMENT_CHAR           = '`'
COMMENT_MULTILINE_CHAR = '```'
PREFIX                 = %w(! - + ~ $ # ? & ^ ./ ../ .../ not return).sort_by &SORT_BY_LENGTH_DESC
INFIX                  = %w(
		+ - ^ * ** / % ~ == === ? . .?
		= : ||= &&= **= <<= >>= += -= *= |= /= %= &= ^=
		&& || & | << >>
		.. >. .< ><
		!= <= >= < > <=> < >
		and or
	).sort_by &SORT_BY_LENGTH_DESC
POSTFIX                = %w() # Be sure not to make ; a postfix operator because it behaves as postfix with a declaration but as a delimiter inside func param declarations.
CIRCUMFIX              = %w( \( [ { | )
CIRCUMFIX_GROUPINGS    = { '(' => '()', '{' => '{}', '[' => '[]', '|' => '||' }.freeze

LOGICAL_OPERATORS          = %w(&& & || | and or).sort_by &SORT_BY_LENGTH_DESC
COMPOUND_OPERATORS         = %w(||= &&= **= <<= >>= += -= *= |= /= %= &= ^=).sort_by &SORT_BY_LENGTH_DESC
COMPARISON_OPERATORS       = %w(<=> == === != !== <= >= < > =~ !~).sort_by &SORT_BY_LENGTH_DESC
INFIX_ARITHMETIC_OPERATORS = %w(+ - * ** / % << >> ^ & |).sort_by &SORT_BY_LENGTH_DESC
RANGE_OPERATORS            = %w(.. .< >. ><).sort_by &SORT_BY_LENGTH_DESC
DOT_ACCESS_OPERATORS       = %w(. .?).sort_by &SORT_BY_LENGTH_DESC

RESERVED                   = %w(
		[ { ( , _ . ) } ]
		: ;
		+ - * ** / % ~
		= ||= &&= **= <<= >>= += -= *= |= /= %= &= ^=
		== === != !== <= >= < >
		! ? ?? !! && || & | << >>
		.. >. .< >< <=>
		@ ./ ../ .../
		``` `


		if ef el elif elsif else
		while ew elswhile elwhile elsewhile
		unless until true false nil
		skip stop and or return
	).sort_by &SORT_BY_LENGTH_DESC # todo, I want to add `remove` here as well but not is not the time.
TYPE_COMPOSITION_OPERATORS = %w(| & - ^)
ANY_IDENTIFIER             = %i(identifier Identifier IDENTIFIER)
GSCOPE                     = :global

OPERATOR_PRECEDENCE_ARRAY = [
	# Tightest binding
	%w(. .?),
	%w([ { \( ),
	%w(! not),
	%w(**),
	%w(* / %),
	%w(+ -),
	%w(<< >>),
	%w(< <= <=> > >=),
	%w(== != === !==),
	%w(| & - ^),
	%w(&& and),
	%w(|| or),
	%w(:),
	%w(,),
	%w(= += -= *= /= %= &= |= ^= <<= >>=),
	%w(.. .< >. ><),
	%w(return),
	%w(unless if while until),
	# Loosest binding
]
STARTING_PRECEDENCE       = OPERATOR_PRECEDENCE_ARRAY.count
