require 'minitest/autorun'
require_relative '../lib/ore'
require_relative 'base_test'

class Intrinsics_Test < Base_Test
	def test_invalid_intrinsic_directive_usage
		assert_raises Ore::Invalid_Intrinsic_Directive_Usage do
			Ore.interp '#intrinsic'
		end
	end

	def test_string_intrinsics
		assert_equal "HELLO", Ore.interp("'hello'.upcase()")
		assert_equal "world", Ore.interp("'WORLD'.downcase()")

		assert_equal ['he', '', 'o'], Ore.interp("'hello'.split('l')")
		assert_equal "ORL", Ore.interp("'WORLD'.slice('ORL')")

		assert_equal "Locke!", Ore.interp("'   Locke!    '.trim()")
		assert_equal "Locke!    ", Ore.interp("'   Locke!    '.trim_left()")
		assert_equal "   Locke!", Ore.interp("'   Locke!    '.trim_right()")

		assert_equal %w(w a l t), Ore.interp("'walt'.chars()")
		assert_equal 6, Ore.interp("'Enter the numbers'.index('the')")

		assert_equal 123, Ore.interp("'123'.to_i()")
		assert_equal 456.0, Ore.interp("'456'.to_f()")

		assert Ore.interp("''.empty?()")
		refute Ore.interp("'cool'.empty?()")

		assert Ore.interp("'island'.include?('and')")
		refute Ore.interp("'island'.include?('or')")

		assert_equal 'edcba', Ore.interp("'abcde'.reverse()")
		assert_equal 'replaced', Ore.interp("'replace_me'.replace('replaced')")
	end
end
