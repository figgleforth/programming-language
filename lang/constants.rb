# #todo Clean up
# todo should return be a prefix?
SORT_BY_LENGTH_DESC        = ->(str) { -str.size }
INTERPOLATE_CHAR           = '`' # "string with `interpolation`"
COMMENT_CHAR               = '`'
COMMENT_MULTILINE_CHAR     = '```'
PREFIX                     = %w(! - + ~ $ # ? & ^ ./ ../ .../ not).sort_by &SORT_BY_LENGTH_DESC
INFIX                      = %w(
		+ - ^ * ** / % ~ == === ? .
		= : := ||= &&= **= <<= >>= += -= *= |= /= %= &= ^=
		&& || & | << >>
		.. >. .< ><
		!= <= >= < > <=> < >
		and or
	).sort_by &SORT_BY_LENGTH_DESC
POSTFIX                    = %w(=;)
COMPOUND_OPERATORS         = %w(||= &&= **= <<= >>= += -= *= |= /= %= &= ^= != <= >=).sort_by &SORT_BY_LENGTH_DESC
COMPARISON_OPERATORS       = %w(<=> == === != !== <= >= < > =~ !~).sort_by &SORT_BY_LENGTH_DESC
ARITHMETIC_OPERATORS       = %w(+ - * ** / % ~ << >> ^ & |).sort_by &SORT_BY_LENGTH_DESC
RANGE_OPERATORS            = %w(.. .< >. ><).sort_by &SORT_BY_LENGTH_DESC
RESERVED                   = %w(
		[ { ( , _ . ) } ] : ;
		+ - * ** / % ~
		= ||= &&= **= <<= >>= += -= *= |= /= %= &= ^=
		== === != !== <= >= < >
		! ? ?? !! && || & | << >>
		.. >. .< >< <=>
		@ ./ ../ .../
		``` `
		=;

		if ef el elif elsif else
		while ew elswhile elwhile elsewhile
		unless until true false nil
		skip stop and or return
	).sort_by &SORT_BY_LENGTH_DESC
TYPE_COMPOSITION_OPERATORS = %w(| & - ^)
ANY_IDENTIFIER             = %i(identifier Identifier IDENTIFIER)
GROUPINGS                  = { '(' => '()', '{' => '{}', '[' => '[]', '|' => '||' }.freeze
STARTING_PRECEDENCE        = 0
PRECEDENCE_OFFSET          = 100
GSCOPE                     = :global
COLORS                     = {
	                             black:         0,
	                             red:           1,
	                             green:         2,
	                             yellow:        3,
	                             blue:          4,
	                             magenta:       5,
	                             cyan:          6,
	                             white:         7,
	                             gray:          236,
	                             light_gray:    240,
	                             lighter_gray:  244,
	                             light_red:     9,
	                             light_green:   10,
	                             light_yellow:  11,
	                             light_blue:    12,
	                             light_magenta: 13,
	                             light_cyan:    14,
	                             light_white:   15
                             }.freeze
