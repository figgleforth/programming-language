require 'minitest/autorun'

class Base_Test < Minitest::Test
	def refute_raises * exceptions
		yield
	rescue *exceptions => e
		flunk "Expected no exception, but got #{e.class}: #{e.message}"
	end
end
