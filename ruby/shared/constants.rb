module Code
	DOM_CONSTRUCTOR_PROP_NAMES        = %w(onclick key)
	DOM_CONSTRUCTOR_PROP_PREFIXES     = %w(html_ css_)
	DOM_ATTRIBUTE_PREFIX              = 'data-runtime' # starts each attribute that the runtime writes and live_reload.js reads (<prefix>-onclick, <prefix>-on-server-read)
	DOM_TARGET_ID_HEADER              = 'X-Code-Target-Id' # a click reply's header that names the element live_reload.js replaces
	DOM_BROWSER_VIEW_SIZE             = 'browser_view_size'
	DOM_NAMESPACE                     = '_runtime' # the URL namespace of the runtime's own paths (DOM_EVENT_URL, DOM_HOT_RELOAD_URL)
	DOM_EVENT_PATH                    = 'event' # after DOM_NAMESPACE: a browser event (a click) for the closure that the token names
	DOM_EVENT_URL                     = "/#{DOM_NAMESPACE}/#{DOM_EVENT_PATH}" # live_reload.js posts to DOM_EVENT_URL/<token>
	DOM_HOT_RELOAD_PATH               = 'hot-reload' # after DOM_NAMESPACE: the stream that hot_reload.js listens to under Hot_Reloader
	DOM_HOT_RELOAD_URL                = "/#{DOM_NAMESPACE}/#{DOM_HOT_RELOAD_PATH}"
	LIVE_PAGE_INSTANCE_LIMIT          = 1024 # the most live page instances the server keeps; it drops the one it saw longest ago
	LIVE_PAGE_INSTANCE_ID_REGEX       = /\A[^-]+/ # the live page instance id at the start of a token: '9f3c…-page-0' gives '9f3c…'
	# The DOM_ values go into URLs, CSS selectors, HTTP headers, cookies and JavaScript strings without escaping, so each one must match its rule here. tests/validation_test.rb checks them.
	DOM_CONSTANT_RULES                = {
		DOM_ATTRIBUTE_PREFIX:  /\Adata(-[a-z0-9]+)+\z/,            # a data-* name: lowercase (HTML spec), no empty part between dashes
		DOM_TARGET_ID_HEADER:  /\A[A-Za-z0-9]+(-[A-Za-z0-9]+)*\z/, # no _: some proxies (nginx) drop a header with _ in its name
		DOM_BROWSER_VIEW_SIZE: /\A[A-Za-z0-9_-]+\z/,               # a cookie name
		DOM_NAMESPACE:         /\A[A-Za-z0-9_-]+\z/,               # one URL path part, so no / and no .
		DOM_EVENT_PATH:        /\A[A-Za-z0-9_-]+\z/,
		DOM_HOT_RELOAD_PATH:   /\A[A-Za-z0-9_-]+\z/,
	}
	HTML_ATTRS                        = %w(id class href)
	HTTP_VERBS                        = %w(get put patch post delete head options connect trace)
	VOID_HTML_TAGS                    = %w(area base br col command embed hr img input keygen link meta param source track wbr)
	RAW_TEXT_HTML_TAGS                = %w(script style) # their text is JavaScript or CSS, so it is never HTML-escaped
	HTTP_VERB_SEPARATOR               = '://'
	CONTEXT_OPERATOR                  = '@'
	CONTEXT_ARG_TERMINATORS           = %W( \n \r \) \} \] \, \; )
	NIL_INIT_POSTFIX                  = ','
	FUNCTION_RETURN_DELIMITER         = '->'
	FUNCTION_BODY_DELIMITER           = ';'
	PERCENT_LITERALS                  = %w(string symbol str Str STR sym Sym SYM)
	FOR_VERBS                         = %w(each map select reject count)
	INTERPOLATE_CHAR                  = '`' # easily distinguishable betwen ```
	COMMENT_PREFIX                    = '#'
	BLOCK_COMMENT_DELIMITER           = '###'
	FENCE_DELIMITER                   = '```'
	PREFIX                            = %w(! - + ~ not return -- ++)
	PREFIX_PRECEDENCES                = { '~' => 900 } # prefix `~` (bitwise NOT) binds like `!`; the shared `~` key in PRECEDENCES is left to infix type difference (`A ~ B`)
	INFIX                             = %w( + - ^ * ** / % ~ == === =!= =>= =<= =/= ? . .? = := : ||= &&= **= <<= >>= += -= *= |= /= %= &= ^= =~ !~ && || & | << >>
 .. >.. ..< >..< != <= >= < > <=> < > and or )
	POSTFIX                           = %w(++ --) # note: ; can never be a postfix, it's reserved
	CIRCUMFIX                         = %w( \( [ { | )
	CIRCUMFIX_GROUPINGS               = { '(' => '()', '{' => '{}', '[' => '[]', '|' => '||' }
	LOGICAL_OPERATORS                 = %w(&& & || | and or)
	COMPOUND_OPERATORS                = %w(||= &&= **= <<= >>= += -= *= |= /= %= &= ^=)
	COMPARISON_OPERATORS              = %w(<=> == === =!= =>= =<= =/= != <= >= < > =~ !~)
	ANY_WILDCARD_COMPARISON_OPERATORS = %w(== != =>= =<= =/=)
	INFIX_ARITHMETIC_OPERATORS        = %w(+ - * ** / % << >> ^ & |)
	RANGE_OPERATORS                   = %w(.. ..< >.. >..<)
	SELF_KEYWORDS                     = %w(self Self) # instance / type scope -- context-restricted
	SCOPE_KEYWORDS                    = %w(self Self Global) # every bare scope keyword you can dot into
	DOT_ACCESS_OPERATORS              = %w(. .?)
	TAG_OPERATOR                      = '\\'
	TYPE_COMPOSITION_OPERATORS        = %w(| & ~ ^) # In a type position, on values: either, both, not, exactly one
	MEMBER_COMPOSITION_OPERATORS      = %w(+ -) # In a declaration head and `Self +=`, on members: add, remove
	ANY_IDENTIFIER                    = %i(identifier Identifier IDENTIFIER)
	TYPE_IDENTIFIER                   = %i(Identifier IDENTIFIER)
	LITERAL_LEXEME_TYPES              = %i(string symbol number)
	GSCOPE                            = :global
	STARTING_PRECEDENCE               = 0
	DEFAULT_OPERATOR_PRECEDENCE       = 500 # given to all custom operators at runtime unless
	DELIMITERS                        = %W(, ; { } ( ) [ ] \n \r)
	ILLEGAL_OPERATOR_CHARS            = %w(` ' " { } ( ) [ ] , ; )
	NEWLINES                          = %W(\r\n \n \r)
	WHITESPACES                       = %W(\t \s)
	NUMERIC_REGEX                     = /\A\d+\z/
	ALPHA_REGEX                       = /\A\p{Alpha}+\z/
	ALPHANUMERIC_REGEX                = /\A\p{Alnum}+\z/
	SYMBOLIC_REGEX                    = /\A[^\p{Alnum}\s]+\z/
	INTEGER_TEXT_REGEX                = /\A-?\d+\z/ # text that is a whole number, such as a URL param for `id: Int`
	DECIMAL_TEXT_REGEX                = /\A-?\d+(\.\d+)?\z/ # text that is a decimal number, such as a URL param for `price: Dec`
	ANSI_COLOR_REGEX                  = /\e\[\d+(?:;\d+)*m/ # a terminal color code in an error message, removed before the message goes into a web page
	HTML_ROOT_ID_REGEX                = /\A\s*<[a-zA-Z][^>]*\sid="([^"]+)"/ # group 1: the id on the first tag of an HTML String, its root element (a click reply replaces that element)
	HEX_DIGITS                        = '0123456789abcdef'

	# It's been a while, but I believe this RESERVED list must be maintained. The other declarations above are helpers for comparisons while this contains every reserved symbols and identifiers.
	RESERVED = %w(
		[ { ( , _ . .? .. ) } ]
		: ; + - * ** / % ~
		++ --
		= := ||= &&= **= <<= >>= += -= *= |= /= %= &= ^=
		== != <= >= < > === =!= =/= =<= =>=
		! ? ?? !! && || & | << >>
		.. ... >.. ..< >..< <=>
		``` # \
		@

		if elif elsif else
		while elwhile elswhile
		unless until eluntil elsuntil
		and or return
		true false nil
		skip stop
		self Self Global
		for when
	)

	PRECEDENCES = {
		# Member access
		'.' => 1200, '.?' => 1200,

		# Subscript/call
		'[' => 1100, '{' => 1100, '(' => 1100,

		# Exponentiation
		'**' => 1000,

		# Unary
		'!' => 900, 'not' => 900, '\\' => 900, '++' => 900, '--' => 900,

		# Multiplicative
		'*' => 800, '/' => 800, '%' => 800,

		# Additive
		'+' => 700, '-' => 700,

		# Bitwise shifts
		'<<' => 600, '>>' => 600,

		# Bitwise AND, XOR, OR -- tighter than comparisons, so `a | b == 5` means `(a | b) == 5` (C binds them looser, a known trap)
		'&' => 590,
		'^' => 580,
		'|' => 570,

		# Relational
		'<' => 550, '<=' => 550, '<=>' => 550, '>' => 550, '>=' => 550,

		# Type set comparison
		'=>=' => 550, '=<=' => 550, '=!=' => 500, '=/=' => 500,

		# Type difference -- looser than `|`, so `A | B ~ C` is `(A | B) ~ C` in a type expression
		'~' => 500,

		# Equality
		'==' => 500, '!=' => 500, '===' => 500,

		# Logical AND
		'&&' => 300, 'and' => 300,

		# Logical OR
		'||' => 200, 'or' => 200,

		# Member/label
		':' => 140,

		# Comma
		',' => 100,

		# Postfix for-loop
		'for' => 95,

		# Assignment
		'='   => 90, ':=' => 90, '::' => 90, '+=' => 90, '-=' => 90, '*=' => 90, '/=' => 90,
		'%='  => 90, '&=' => 90, '&&=' => 90, '|=' => 90, '||=' => 90,
		'^='  => 90, '<<=' => 90, '>>=' => 90,
		'**=' => 90,

		# Ranges
		'..' => 80, '..<' => 80, '>..' => 80, '>..<' => 80,

		# Keywords
		'return' => 70,
		'unless' => 60, 'if' => 60, 'while' => 60, 'until' => 60,
	}
end
