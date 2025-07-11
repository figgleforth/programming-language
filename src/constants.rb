SORT_BY_LENGTH_DESC    = ->(str) { -str.size }
INTERPOLATE_CHAR       = '|' # "string with `interpolation`"
COMMENT_CHAR           = '`'
COMMENT_MULTILINE_CHAR = '```'
PREFIX                 = %w(! - + ~ $ # ? & ^ ./ ../ .../ not return).sort_by &SORT_BY_LENGTH_DESC

# todo, I'm considering switching up the := inferred initialization shortcut to ;= because it's easier for me to type and it's the opposite of =; which initializes to nil.
INFIX               = %w(
		+ - ^ * ** / % ~ == === ? .
		= : := ||= &&= **= <<= >>= += -= *= |= /= %= &= ^=
		&& || & | << >>
		.. >. .< ><
		!= <= >= < > <=> < >
		and or
	).sort_by &SORT_BY_LENGTH_DESC
POSTFIX             = %w(=;)
CIRCUMFIX           = %w( \( [ { | )
CIRCUMFIX_GROUPINGS = { '(' => '()', '{' => '{}', '[' => '[]', '|' => '||' }.freeze

LOGICAL_OPERATORS          = %w(&& & || | and or).sort_by &SORT_BY_LENGTH_DESC
COMPOUND_OPERATORS         = %w(||= &&= **= <<= >>= += -= *= |= /= %= &= ^=).sort_by &SORT_BY_LENGTH_DESC
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
	).sort_by &SORT_BY_LENGTH_DESC # todo, I want to add `remove` here as well but not is not the time.
TYPE_COMPOSITION_OPERATORS = %w(| & - ^)
ANY_IDENTIFIER             = %i(identifier Identifier IDENTIFIER)
STARTING_PRECEDENCE        = 0
PRECEDENCE_OFFSET          = 100
GSCOPE                     = :global
