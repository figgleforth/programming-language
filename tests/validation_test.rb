require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

# The DOM_ constants in constants.rb go into URLs, CSS selectors, HTTP headers, cookies and JavaScript strings without escaping, so each one must match its rule in DOM_CONSTANT_RULES.
class Validation_Test < Base_Test
	PLACEHOLDER_REGEX = /#\{(\w+)\}/ # group 1: the NAME in a #{NAME} placeholder that the server fills in

	def test_each_dom_constant_matches_its_rule
		Code::DOM_CONSTANT_RULES.each do |name, rule|
			assert_match rule, Code.const_get(name), "#{name} breaks its rule in DOM_CONSTANT_RULES"
		end
	end

	# Both are mounted under DOM_NAMESPACE, so the same part would give two endpoints one URL.
	def test_event_path_and_hot_reload_path_differ
		refute_equal Code::DOM_EVENT_PATH, Code::DOM_HOT_RELOAD_PATH
	end

	# The server writes an attribute for each event in LIVE_PAGE_EVENTS, so live_page.js must listen for each one.
	def test_live_page_js_listens_for_each_live_page_event
		source = ::File.read ::File.join(Code::ROOT_PATH, 'ruby/shared/live_page.js')
		Code::LIVE_PAGE_EVENTS.each do |event|
			assert_match(/'#{event}'/, source, "live_page.js does not listen for #{event}")
		end
	end

	# An event is complete only in all four places: the Dom member, the Dom constructor's named arguments, the html2 Element member, and both html2 constructor kinds.
	def test_each_live_page_event_is_in_every_place
		names = Code::LIVE_PAGE_EVENTS.map { "on#{it}" }
		assert_empty names - Code::DOM_CONSTRUCTOR_PROP_NAMES

		dom = Code.interp "@load 'lang/web/html'\nDom()"
		names.each { assert dom.has?(it), "Dom has no #{it} member" }

		element = Code.interp("@load 'lang/web/html2'\nElement('div')").names.compact
		assert_empty names - element, 'html2 Element is missing members'

		names.each do |name|
			interp = Code::Interpreter.new
			start_live_page_instance interp
			out = interp.run "@load 'lang/web/html2'\n[Html_Renderer.render(div('x', #{name} := (; 1 ))), Html_Renderer.render(input(#{name} := (; 1 )))]"
			out.values.each { assert_includes it, "#{Code::DOM_ATTRIBUTE_PREFIX}-#{name}=", "an html2 constructor does not take #{name}" }

			interp = Code::Interpreter.new
			start_live_page_instance interp
			html = interp.render_dom_to_html interp.run("@load 'lang/web/html'\nDiv(html_id := 'p', #{name} := (; 1 ))")
			assert_includes html, "#{Code::DOM_ATTRIBUTE_PREFIX}-#{name}=", "a Dom constructor does not take #{name}"
		end
	end

	# A placeholder with a typo (`#{DOM_ATRIBUTE_PREFIX}`) would reach the browser unfilled.
	def test_each_placeholder_in_the_browser_scripts_names_a_real_constant
		%w(ruby/shared/live_page.js ruby/shared/hot_reload.js).each do |path|
			source = ::File.read ::File.join(Code::ROOT_PATH, path)

			source.scan(PLACEHOLDER_REGEX).flatten.uniq.each do |name|
				assert Code.const_defined?(name), "#{path} has the placeholder \#{#{name}}, but no constant has that name"
			end
		end
	end
end
