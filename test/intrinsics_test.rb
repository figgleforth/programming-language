require 'minitest/autorun'
require_relative '../lib/ore'
require_relative 'base_test'

class Intrinsics_Test < Base_Test
	def test_invalid_intrinsic_directive_usage
		assert_raises Ore::Invalid_Intrinsic_Directive_Usage do
			Ore.interp '#intrinsic'
		end
	end

	def test_string_upcase_intrinsic
		out = Ore.interp "'hello'.upcase()"
		assert_equal "HELLO", out
	end
end
