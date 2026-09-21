require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

# Every Code::Expression subclass should carry an accurate span: the very first lexeme's own
# start, and the very last lexeme's own end -- set in the parser via #set_expr_location /
# #copy_location. One test per expression kind below. Most source snippets are written so their
# own length lines up with the expected end column, so a wrong assertion is easy to catch by eye
# -- a span that doesn't reach the last character of its snippet is almost always a bug.
class Code_Location_Test < Base_Test
	# @return [Code::Expression] the LAST top-level expression parsed from `code`
	def parse code
		Code.parse(code).last
	end

	def assert_span expected, expr
		assert_equal expected, expr.line_col
	end

	# --- Number_Expr / Array_Index_Expr -----------------------------------------

	def test_number_expr
		assert_span '1:1..1:3', parse('123')
	end

	def test_number_expr_float
		assert_span '1:1..1:3', parse('2.5')
	end

	def test_array_index_expr_bare
		# A single number lexeme with more than one dot ("1.2.3") parses straight into an
		# Array_Index_Expr inside #parse_number_expr -- no separate dot-infix involved.
		out = parse('1.2.3')
		assert_kind_of Code::Array_Index_Expr, out
		assert_span '1:1..1:5', out
	end

	def test_array_index_expr_dot_chain
		# `arr.1.2` -- an ordinary `.` infix whose float RHS (`1.2`) gets repackaged into an
		# Array_Index_Expr by #complete_expression. Regression: the repackaging used to build
		# the replacement from the whole Number_Expr instead of its lexeme, which silently left
		# both `.value`/`.lexeme` AND the location unset on the replacement.
		out = parse('arr.1.2')
		assert_span '1:1..1:7', out
		assert_kind_of Code::Array_Index_Expr, out.right
		assert_span '1:5..1:7', out.right
	end

	# --- Symbol_Expr / String_Expr ------------------------------------------------

	def test_symbol_expr
		assert_span '1:1..1:6', parse(':hello')
	end

	def test_string_expr
		assert_span '1:1..1:7', parse("'hello'")
	end

	# --- Prefix_Expr / Postfix_Expr ------------------------------------------------

	def test_prefix_expr
		assert_span '1:1..1:5', parse('!true')
	end

	def test_prefix_expr_keyword_operator
		# `not`/`return` lex as plain identifiers, not :operator -- #complete_expression still
		# recognizes them as prefixes by value alone.
		assert_span '1:1..1:8', parse('not true')
	end

	def test_prefix_expr_with_nothing_following
		# A bare `return` with no expression after it -- #parse_expression can come back nil, so
		# the span has to fall back to the operator's own end instead of crashing.
		func = Code.parse("foo (;\n\treturn\n)\nfoo()").first
		out  = func.expressions.first
		assert_kind_of Code::Prefix_Expr, out
		assert_span '2:2..2:7', out
	end

	def test_postfix_expr
		# No built-in postfix operator exists (POSTFIX is empty) -- has to be declared first.
		code = "@operator pm @postfix 600 ( left; left )\n11 pm\n"
		out  = Code.parse(code).last
		assert_kind_of Code::Postfix_Expr, out
		assert_span '2:1..2:5', out
	end

	# --- Infix_Expr --------------------------------------------------------------

	def test_infix_expr
		assert_span '1:1..1:5', parse('1 + 2')
	end

	def test_infix_expr_compound_operator
		assert_span '1:1..1:6', parse('x += 1')
	end

	def test_infix_expr_dot_chain
		assert_span '1:1..1:5', parse('x.y.z')
	end

	def test_infix_expr_declaration
		assert_span '1:1..1:6', parse('x := 5')
	end

	def test_beginless_range_expr
		assert_span '1:1..1:3', parse('..5')
	end

	def test_endless_range_expr
		assert_span '1:1..1:3', parse('x..')
	end

	# --- Circumfix_Expr / Percent_Literal_Expr / Operator_Expr ---------------------

	def test_circumfix_expr_tuple
		assert_span '1:1..1:9', parse('(1, 2, 3)')
	end

	def test_circumfix_expr_array
		assert_span '1:1..1:9', parse('[1, 2, 3]')
	end

	def test_percent_literal_expr
		# Regression: used to `copy_location` from the leading `%` alone, ignoring the kind,
		# every item, and the closing `)` -- the whole rest of the literal.
		assert_span '1:1..1:14', parse('%string(a b c)')
	end

	def test_operator_expr
		# A bare operator item inside a percent literal builds an Operator_Expr directly.
		out = parse('%string(+)').expressions.first
		assert_kind_of Code::Operator_Expr, out
		assert_span '1:9..1:9', out
	end

	def test_operator_overload_expr
		code = '@operator -> @infix 300 (left, right; right(left))'
		out  = parse(code)
		assert_kind_of Code::Operator_Overload_Expr, out
		assert_span "1:1..1:#{code.length}", out
	end

	# --- Nil_Init_Expr -------------------------------------------------------------

	def test_nil_init_expr
		# The trailing `,` is punctuation, not part of the value -- the span stops at the
		# identifier itself, never at the comma.
		assert_span '1:1..1:3', parse('abc,')
	end

	# --- Identifier_Expr -----------------------------------------------------------

	def test_identifier_expr
		assert_span '1:1..1:3', parse('foo')
	end

	def test_identifier_expr_with_type_annotation
		# Regression: used to `copy_location` from the identifier's own single lexeme, dropping
		# a trailing `: Type` annotation from the span entirely.
		out = parse('<a: Number>').types.first
		assert_span '1:2..1:10', out
	end

	def test_identifier_expr_with_tag
		# Same regression, through a tag instead of a plain type (`x: Abc\Def`) -- and the tag
		# itself (`Abc\Def`, parsed via a nested #parse_identifier_expr call) has to extend its
		# own span through `\Def` too, not just stop at `Abc`.
		out = parse('<x: Abc\Def>').types.first
		assert_span '1:2..1:11', out
	end

	# --- Composition_Expr / bare composition chain ---------------------------------

	def test_composition_expr
		out = parse('Combined | Abc | Def {}').expressions.first
		assert_span '1:10..1:14', out
	end

	def test_composition_expr_dot_chain
		# Regression: the dot-chained tail (`.Def`) used to be dropped -- `copy_location` only
		# ever copied the receiver's (`Abc`'s) own span.
		out = parse('Combined | Abc.Def {}').expressions.first
		assert_span '1:10..1:18', out
	end

	def test_bare_composition_chain
		# `x := |Abc ^ Def` -- a composition chain used as a plain value. Regression: used to
		# collapse to just the leading `|`, one character.
		out = parse('x := |Abc ^ Def').right
		assert_span '1:6..1:15', out
	end

	# --- Type_Expr -----------------------------------------------------------------

	def test_type_expr_with_body
		assert_span '1:1..3:1', parse("Thing {\n x\n}")
	end

	def test_type_expr_reference_no_body
		out = parse('Abc\<Number>')
		assert_span '1:1..1:12', out
		assert_span '1:5..1:12', out.tag
	end

	def test_type_expr_anonymous_composition
		# `Abc | Def`, no body -- regression: used to collapse to just `Abc`.
		out = parse('Abc | Def')
		assert out.anonymous_composition
		assert_span '1:1..1:9', out
	end

	def test_type_expr_with_trailing_struct_body
		assert_span '1:1..1:25', parse('Abc | Def <extra: String>')
	end

	# --- Conditional_Expr ------------------------------------------------------------

	def test_conditional_expr
		assert_span '1:1..3:3', parse("if true\n1\nend")
	end

	def test_conditional_expr_postfix
		assert_span '1:1..1:9', parse('1 if true')
	end

	# --- Call_Expr / Subscript_Expr ---------------------------------------------------

	def test_call_expr
		assert_span '1:1..1:10', parse('f(1, 2, 3)')
	end

	def test_call_expr_spread_lambda
		# `xs.map(x; x*2)` -- the dropped-parens anonymous-func sugar.
		assert_span '1:1..1:14', parse('xs.map(x; x*2)')
	end

	def test_subscript_expr
		assert_span '1:1..1:6', parse('arr[0]')
	end

	# --- For_Loop_Expr ---------------------------------------------------------------

	def test_for_loop_expr
		assert_span '1:1..3:3', parse("for [1,2,3]\n it\nend")
	end

	# --- Fence_Expr / Html_Fence_Expr / Statement_Expr / Comment_Expr ------------------

	def test_fence_expr
		# Regression: had no location call at all.
		assert_span '1:1..3:3', parse("```md\nhi\n```")
	end

	def test_html_fence_expr
		# Regression: had no location call at all.
		assert_span '1:1..3:3', parse("```html\n<p>hi</p>\n```")
	end

	def test_statement_expr
		# Regression: had no location call at all.
		assert_span '1:1..1:5', parse('`1+2`')
	end

	def test_comment_expr
		# Regression: had no location call at all.
		assert_span '1:1..1:7', parse('# hello')
	end

	def test_comment_expr_block
		assert_span '1:1..3:3', parse("###\nhi\n###")
	end

	# --- Func_Expr / Param_Expr / Func_Signature_Expr -----------------------------------

	def test_func_expr
		assert_span '1:1..1:15', parse('f (a, b; a + b)')
	end

	def test_param_expr
		# Regression: a param's own span was never tracked at all -- now it runs through its
		# default value (or type, or name), whichever was actually parsed last.
		func = parse('f (a: Number := 5, b; a + b)')
		assert_span '1:4..1:17', func.parameters[0]
		assert_span '1:20..1:20', func.parameters[1]
	end

	def test_func_signature_expr
		assert_span '1:1..1:27', parse('double: (Number -> Number;)')
	end

	def test_self_prefixed_func_name
		# `self.bar (;)` -- the constructor-name form of #parse_self_prefixed_identifier.
		# Regression: used to start at "bar" (the plain identifier's own span), dropping
		# "self." off the front.
		out = parse('self.bar (; 1 )')
		assert_span '1:1..1:15', out
		assert_span '1:1..1:8', out.name
	end

	# --- Struct_Expr -----------------------------------------------------------------

	def test_struct_expr_bare
		assert_span '1:1..1:16', parse('<String, Number>')
	end

	def test_struct_expr_named
		assert_span '1:1..1:16', parse('Name <a: Number>')
	end

	# --- Enum_Expr -----------------------------------------------------------------

	def test_enum_expr
		assert_span '1:1..1:19', parse('Status [ OK, FAIL ]')
	end

	# --- Route_Expr ------------------------------------------------------------------

	def test_route_expr
		# Regression: used to stop right at the route token itself, dropping the whole handler
		# function from the span.
		assert_span '1:1..1:17', parse('get://path (; 1 )')
	end

	# --- self.-prefixed nil-init -------------------------------------------------------

	def test_self_prefixed_nil_init
		# `self.foo,` -- the nil-init form of #parse_self_prefixed_identifier. Regression: used
		# to start at "foo", dropping "self." off the front; the comma stays excluded either way.
		out = parse('self.foo,')
		assert_span '1:1..1:8', out
		assert_span '1:1..1:8', out.left
	end

	# --- Context (`@`) calls -----------------------------------------------------------

	def test_context_call_with_parens
		assert_span '1:1..1:17', parse('@push_scope(Vec2)')
	end

	def test_context_call_bare_reference
		# `@puts` with nothing to call it on desugars into a plain `.` member-access read
		# (`member` in #parse_context_call). Needs something meaningful after it, or
		# #complete_expression's own "out of lexemes" guard returns the bare `@puts`
		# Identifier_Expr untouched, before this desugaring ever runs.
		out = Code.parse("p := @puts\nx := 1").first.right
		assert_kind_of Code::Infix_Expr, out
		assert_span '1:6..1:10', out
	end

	def test_number_expr_negative_prefix
		# `Lexer#lex_number` used to eat the leading `-`/`+` sign *before* calling
		# `#make_lexeme`, so `#mark_start` captured the position one column too late and the
		# sign fell outside the lexeme's own span. Fixed by moving the sign-eating inside
		# `#make_lexeme`'s own block.
		assert_span '1:1..1:3', parse('-42')
	end

	# --- A realistic, multi-declaration class body ---------------------------------
	#
	# Everything above tests one expression kind in isolation. A real program nests several
	# different kinds inside each other -- an untyped field, a typed field with a default,
	# and two multi-line methods, all inside one Type_Expr -- so this checks the whole tree
	# stays correct at every level: the class's own span, each top-level declaration's span,
	# and a couple of spans one level deeper still, inside a method body.
	def test_type_expr_with_multiple_nested_declarations
		code = <<~CODE
			Point {
				x := 0
				y: Number = 0

				Self ( x, y;
					self.z = x
					self.y = y
				)

				length (;
					x + y
				)
			}
		CODE

		klass = Code.parse(code).first
		assert_kind_of Code::Type_Expr, klass
		assert_span '1:1..13:1', klass # spans from `Point` through the closing `}`
		assert_equal 4, klass.expressions.count

		x_decl, y_decl, self_func, length_func = klass.expressions

		assert_span '2:2..2:7', x_decl # `x := 0`

		# `y: Number = 0` -- both sides need checking: the left side is a typed Identifier_Expr
		# whose span has to reach through its own `: Number` annotation, not just stop at `y`.
		assert_span '3:2..3:14', y_decl
		assert_span '3:2..3:10', y_decl.left
		assert_span '3:14..3:14', y_decl.right

		# Each method's own span runs from its name through its closing `)`, multi-line body
		# and all.
		assert_span '5:2..8:2', self_func
		assert_span '10:2..12:2', length_func

		# One level deeper still: statements inside a method body.
		assert_span '6:3..6:12', self_func.expressions[0] # `self.x = x`
		assert_span '7:3..7:12', self_func.expressions[1] # `self.y = y`
		assert_span '11:3..11:7', length_func.expressions[0] # `x + y`
	end
end
