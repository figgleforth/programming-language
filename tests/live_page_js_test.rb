require 'minitest/autorun'
require 'json'
require 'open3'
require 'tmpdir'
require_relative '../ruby/main'
require_relative 'base_test'

# Runs ruby/shared/live_page.js in Node, in the small fake browser of tests/js/live_page_harness.js. The placeholders are filled the same way #handle_request fills them. Skips when Node is not installed.
class Live_Page_Js_Test < Base_Test
	PLACEHOLDER_REGEX = /#\{(\w+)\}/ # group 1: the NAME in a #{NAME} placeholder
	HARNESS           = ::File.join __dir__, 'js/live_page_harness.js'

	def test_live_page_js_in_a_fake_browser
		node = ENV.fetch('PATH', '').split(':').map { ::File.join it, 'node' }.find { ::File.executable? it }
		skip 'Node is not installed' unless node

		source = ::File.read ::File.join(Code::ROOT_PATH, 'ruby/shared/live_page.js')
		filled = source.gsub(PLACEHOLDER_REGEX) { Code.const_get($1) }
		names  = %w(DOM_ATTRIBUTE_PREFIX DOM_BROWSER_VIEW_SIZE DOM_EVENT_URL DOM_TARGET_ID_HEADER LIVE_PAGE_EVENTS)

		::Dir.mktmpdir do |dir|
			script = ::File.join dir, 'live_page.js'
			::File.write script, filled
			output, status = Open3.capture2e node, HARNESS, script, JSON.generate(names.to_h { [it, Code.const_get(it)] })
			assert status.success?, "live_page.js failed in the fake browser:\n#{output}"
		end
	end
end
