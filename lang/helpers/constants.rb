SORT_BY_LENGTH_DESC    = -> { -it.size }.freeze
INTERPOLATE_CHAR       = '`'.freeze # "string with `interpolation`"
COMMENT_CHAR           = '`'
COMMENT_MULTILINE_CHAR = '```'

PREFIX  = %w(! - + ~ # ? & ^ ./ ../ .../).sort_by &SORT_BY_LENGTH_DESC
INFIX   = %w(
		+ - * ** / % ~ == === ? .
		=
		&& || & | << >> <=>
		.. >. .< ><
		and or
	).sort_by &SORT_BY_LENGTH_DESC
POSTFIX = %w(=;)

RESERVED = %w(
		[ { ( , _ . ) } ] : ;
		+ - * ** / % ~
		= == === ||= &&= **= <<= >>= += -= *= |= /= %= &= ^= != <= >= <=>
		! ? ?? !! && || & | << >>
		.. >. .< ><
		@ ./ ../ .../
		``` `
		=;

		if el elsif elif else
		while ew elswhile elwhile
		unless until true false nil
		skip stop and or return
	).sort_by &SORT_BY_LENGTH_DESC

COLORS = {
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
