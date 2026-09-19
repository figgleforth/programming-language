require 'minitest/autorun'
require_relative '../source/main'
require_relative 'base_test'

# source/code/html2.code: the Element/Attribute structs, Html_Formatter_Visitor (render + minify, void
# tags, embedded css), Html_Stats_Visitor, Html_Sanitizer_Visitor, Html_Lint_Visitor, and the
# lowercase element constructors.
class Html2_Test < Base_Test
	HTML = "@load 'code/html2.code'"

	# --- Html_Formatter_Visitor: render -----------------------------------------

	def test_render_simple_element_compact
		out = Code.interp "#{HTML}\nHtml_Render.render(div('hi'))"
		assert_equal '<div>hi</div>', out
	end

	def test_render_simple_element_pretty
		out = Code.interp "#{HTML}\nHtml_Format.render(div('hi'))"
		assert_equal '<div>hi</div>', out
	end

	def test_render_void_tag_never_gets_a_closing_tag_pretty
		out = Code.interp "#{HTML}\nHtml_Format.render(br())"
		assert_equal '<br>', out
	end

	def test_render_void_tag_never_gets_a_closing_tag_compact
		out = Code.interp "#{HTML}\nHtml_Render.render(br())"
		assert_equal '<br>', out
	end

	def test_render_void_tag_with_attributes
		out = Code.interp "#{HTML}\nHtml_Format.render(input([Attribute('type', 'text')]))"
		assert_equal '<input type="text">', out
	end

	def test_render_multiple_children_expands_to_block_style_pretty
		out = Code.interp "#{HTML}\nHtml_Format.render(div([h1('A'), p('B')]))"
		assert_equal "<div>\n  <h1>A</h1>\n  <p>B</p>\n</div>", out
	end

	def test_render_single_bare_text_child_stays_inline_pretty
		out = Code.interp "#{HTML}\nHtml_Format.render(div([p('one')]))"
		assert_equal "<div>\n  <p>one</p>\n</div>", out
	end

	def test_render_attributes_preserve_call_order
		out = Code.interp "#{HTML}\nHtml_Render.render(div('x', [Attribute('id', 'a'), Attribute('class', 'b')]))"
		assert_equal '<div id="a" class="b">x</div>', out
	end

	def test_render_nested_elements_indent_by_depth_pretty
		out = Code.interp "#{HTML}\nHtml_Format.render(div(ul([li('one'), li('two')])))"
		assert_equal "<div>\n  <ul>\n    <li>one</li>\n    <li>two</li>\n  </ul>\n</div>", out
	end

	# --- Html_Formatter_Visitor: attached css -----------------------------------

	def test_render_css_embeds_a_style_child_compact
		out = Code.interp <<~CODE
		    #{HTML}
		    node := div('x', [], Style_Rule(['.x'], [Property('color', 'red')]))
		    Html_Render.render(node)
		CODE
		assert_equal '<div>x<style>.x{color:red;}</style></div>', out
	end

	def test_render_css_is_formatted_pretty_inside_a_pretty_page
		out = Code.interp <<~CODE
		    #{HTML}
		    node := div('x', [], Style_Rule(['.x'], [Property('color', 'red')]))
		    Html_Format.render(node)
		CODE
		# A multi-line text child (the formatted CSS) expands to block layout, indented one level
		# past its <style> tag -- so the embedded stylesheet lines up with the rest of the page.
		assert_equal "<div>\nx\n  <style>\n    .x {\n      color: red;\n    }\n  </style>\n</div>", out
	end

	def test_render_scope_rule_css_nests_correctly
		out = Code.interp <<~CODE
		    #{HTML}
		    node := div('x', [], Scope_Rule('.widget', '', [Style_Rule(['p'], [Property('margin', '0')])]))
		    Html_Render.render(node)
		CODE
		assert_equal '<div>x<style>@scope(.widget){p{margin:0;}}</style></div>', out
	end

	def test_element_with_no_css_renders_no_style_tag
		out = Code.interp "#{HTML}\nHtml_Render.render(div('x'))"
		refute_includes out, '<style>'
	end

	# Regression coverage for the `Array#concat`-is-destructive bug (bugs.md): rendering the same
	# tree twice used to permanently append a second <style> child to the tree's own `children` on
	# the second render, since the first render's `.concat` call mutated it in place.
	def test_rendering_the_same_tree_twice_does_not_duplicate_the_style_child
		out = Code.interp <<~CODE
		    #{HTML}
		    node := div('x', [], Style_Rule(['.x'], [Property('color', 'red')]))
		    first := Html_Format.render(node)
		    Html_Render.render(node)
		CODE
		assert_equal 1, out.scan('<style>').length
		assert_equal '<div>x<style>.x{color:red;}</style></div>', out
	end

	def test_custom_indent_size_is_honored
		out = Code.interp "#{HTML}\nHtml_Formatter_Visitor(4).render(div([p('one')]))"
		assert_equal "<div>\n    <p>one</p>\n</div>", out
	end

	# `render`'s plain-text fallback (`node.to_s()`) and `indent_block`'s `text.split("\n")` both used
	# to raise instead of falling back to a plain display when handed a bare, uninstantiated Type
	# value (a struct member typed `String`/`Any` that never got a real value) -- same root gotcha as
	# Array#to_s (a bare String Type or the literal Any wildcard both satisfy `=== String`/`=== Element`
	# without having the instance methods those branches assumed).
	def test_render_does_not_crash_on_a_bare_type_text_child_regression
		refute_raises(Code::Undeclared_Identifier) { Code.interp "#{HTML}\nHtml_Render.render(div([String]))" }
		refute_raises(Code::Cannot_Call_Instance_Member_On_Type) { Code.interp "#{HTML}\nHtml_Format.render(div([String]))" }
	end

	def test_embedded_style_child_does_not_crash_on_a_bare_string_type_regression
		refute_raises(Code::Cannot_Call_Instance_Member_On_Type) { Code.interp "#{HTML}\nHtml_Format.render(style([String]))" }
		refute_raises(Code::Cannot_Call_Instance_Member_On_Type) { Code.interp "#{HTML}\nHtml_Render.render(style([String]))" }
	end

	# --- Html_Stats_Visitor -----------------------------------------------------

	def test_stats_node_count_and_max_depth
		out = Code.interp <<~CODE
		    #{HTML}
		    tree := div([h1('A'), p('B'), img([Attribute('src', 'a.png')])])
		    stats := Html_Stats_Visitor().analyze(tree)
		    (stats.node_count, stats.max_depth)
		CODE
		assert_equal [4, 1], out.values
	end

	def test_stats_unique_tags
		out = Code.interp <<~CODE
		    #{HTML}
		    tree := div([h1('A'), p('B'), img([Attribute('src', 'a.png')])])
		    Html_Stats_Visitor().analyze(tree).unique_tags()
		CODE
		assert_equal %i[div h1 p img], out.values
	end

	def test_stats_sizes_reflect_minified_vs_pretty_render
		out = Code.interp <<~CODE
		    #{HTML}
		    tree := div([h1('A'), p('B')])
		    stats := Html_Stats_Visitor()
		    (stats.minified_size(tree), stats.pretty_size(tree))
		CODE
		minified, pretty = out.values
		assert_equal Code.interp("#{HTML}\nHtml_Render.render(div([h1('A'), p('B')])).length"), minified
		assert_equal Code.interp("#{HTML}\nHtml_Format.render(div([h1('A'), p('B')])).length"), pretty
		assert_operator pretty, :>, minified
	end

	def test_stats_analyze_resets_between_calls
		out = Code.interp <<~CODE
		    #{HTML}
		    stats := Html_Stats_Visitor()
		    stats.analyze(div([h1('A'), p('B')]))
		    stats.analyze(div([]))
		    stats.node_count
		CODE
		assert_equal 1, out
	end

	# --- Html_Sanitizer_Visitor --------------------------------------------------

	def test_sanitize_strips_a_dangerous_tag_and_its_children_entirely
		out = Code.interp <<~CODE
		    #{HTML}
		    tree := div([p('safe'), script('alert(1)')])
		    Html_Render.render(Html_Sanitizer_Visitor().sanitize(tree))
		CODE
		assert_equal '<div><p>safe</p></div>', out
	end

	def test_sanitize_strips_on_star_attributes
		out = Code.interp <<~CODE
		    #{HTML}
		    tree := button('Click', [Attribute('onclick', 'evil()'), Attribute('class', 'btn')])
		    Html_Render.render(Html_Sanitizer_Visitor().sanitize(tree))
		CODE
		assert_equal '<button class="btn">Click</button>', out
	end

	def test_sanitize_strips_javascript_href
		out = Code.interp <<~CODE
		    #{HTML}
		    tree := href('javascript:alert(1)', 'bad')
		    Html_Render.render(Html_Sanitizer_Visitor().sanitize(tree))
		CODE
		assert_equal '<a>bad</a>', out
	end

	# `attr.value === String` is also true for the literal `Any` type -- which has no callable
	# `trim()` -- so this used to raise Undeclared_Identifier instead of just treating it as "not a
	# javascript: URL" (same gotcha as Array#to_s).
	def test_dangerous_attribute_does_not_crash_on_a_bare_type_value_regression
		out = Code.interp <<~CODE
		    #{HTML}
		    Html_Sanitizer_Visitor().dangerous_attribute?(Attribute('href', Any))
		CODE
		assert_equal false, out
	end

	def test_sanitize_keeps_safe_href
		out = Code.interp <<~CODE
		    #{HTML}
		    tree := href('http://example.com', 'good')
		    Html_Render.render(Html_Sanitizer_Visitor().sanitize(tree))
		CODE
		assert_equal '<a href="http://example.com">good</a>', out
	end

	def test_sanitize_preserves_attached_css
		out = Code.interp <<~CODE
		    #{HTML}
		    tree := div('x', [], Style_Rule(['.x'], [Property('color', 'red')]))
		    Html_Render.render(Html_Sanitizer_Visitor().sanitize(tree))
		CODE
		assert_equal '<div>x<style>.x{color:red;}</style></div>', out
	end

	# --- Html_Lint_Visitor -------------------------------------------------------

	def test_lint_flags_void_element_given_children
		out = Code.interp <<~CODE
		    #{HTML}
		    node := Element('br', [], nil, ['oops'])
		    Html_Lint_Visitor().lint(node)
		CODE
		assert_equal ['<br> is a void element but was given children'], out.values
	end

	def test_lint_flags_img_missing_alt
		out = Code.interp "#{HTML}\nHtml_Lint_Visitor().lint(img([Attribute('src', 'a.png')]))"
		assert_equal ['<img> is missing an alt attribute'], out.values
	end

	def test_lint_does_not_flag_img_with_alt
		out = Code.interp "#{HTML}\nHtml_Lint_Visitor().lint(img([Attribute('src', 'a.png'), Attribute('alt', 'a')]))"
		assert_equal [], out.values
	end

	def test_lint_flags_empty_container
		out = Code.interp "#{HTML}\nHtml_Lint_Visitor().lint(div([]))"
		assert_equal ['<div> is empty'], out.values
	end

	def test_lint_flags_duplicate_attribute_name
		out = Code.interp "#{HTML}\nHtml_Lint_Visitor().lint(div('x', [Attribute('id', 'a'), Attribute('id', 'b')]))"
		assert_equal ["<div> has a duplicate 'id' attribute"], out.values
	end

	def test_lint_recurses_into_children
		out = Code.interp <<~CODE
		    #{HTML}
		    tree := div([img([Attribute('src', 'a.png')]), div([])])
		    Html_Lint_Visitor().lint(tree)
		CODE
		assert_equal ['<img> is missing an alt attribute', '<div> is empty'], out.values
	end

	def test_lint_clean_tree_has_no_warnings
		out = Code.interp "#{HTML}\nHtml_Lint_Visitor().lint(div(img([Attribute('src', 'a.png'), Attribute('alt', 'a')])))"
		assert_equal [], out.values
	end

	# Unlike Css_Lint_Visitor, Html_Lint_Visitor's own `lint` does reset `warnings` at the start --
	# reusing one instance across calls does not accumulate.
	def test_lint_resets_between_calls_on_the_same_instance
		out = Code.interp <<~CODE
		    #{HTML}
		    linter := Html_Lint_Visitor()
		    linter.lint(div([]))
		    linter.lint(div('x'))
		CODE
		assert_equal [], out.values
	end

	# --- Constructors / as_children / merge_attribute ----------------------------

	def test_as_children_wraps_a_single_bare_child
		out = Code.interp "#{HTML}\ndiv('hi').children.length()"
		assert_equal 1, out
	end

	def test_as_children_leaves_an_array_of_children_alone
		out = Code.interp "#{HTML}\ndiv(['a', 'b']).children.length()"
		assert_equal 2, out
	end

	def test_href_appends_its_own_attribute_after_the_callers
		out = Code.interp "#{HTML}\nHtml_Render.render(href('http://x.com', 'link', [Attribute('class', 'ext')]))"
		assert_equal '<a class="ext" href="http://x.com">link</a>', out
	end

	def test_href_overrides_an_existing_href_attribute_in_place
		out = Code.interp "#{HTML}\nHtml_Render.render(href('http://new.com', 'link', [Attribute('href', 'http://old.com')]))"
		assert_equal '<a href="http://new.com">link</a>', out
	end

	def test_utf8_meta_merges_in_the_charset_attribute
		out = Code.interp "#{HTML}\nHtml_Render.render(utf8_meta())"
		assert_equal '<meta charset="utf-8">', out
	end

	def test_element_defaults_to_empty_attributes_no_css_and_no_children
		out = Code.interp <<~CODE
		    #{HTML}
		    node := Element('div')
		    (node.attributes.length(), node.css, node.children.length())
		CODE
		assert_equal [0, nil, 0], out.values
	end

	def test_a_representative_sample_of_constructors_build_the_expected_tags
		out = Code.interp <<~CODE
		    #{HTML}
		    [html(), head(), title('t'), h1('h'), p('p'), ul(), form(), input(), button('b'), img(), meta(), link()].map(el; el.tag)
		CODE
		assert_equal %w[html head title h1 p ul form input button img meta link], out.values
	end
end
