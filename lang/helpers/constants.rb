SORT_BY_LENGTH_DESC = -> { -it.size }.freeze
INTERPOLATE_CHAR    = '`'.freeze # "string with `interpolation`"
COMMENT_MONOLINE    = '`'
COMMENT_MULTILINE   = '```'

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
