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
