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
		assert_equal 12, Ore.interp("'hello, world'.length")
		assert_equal 104, Ore.interp("'hello, world'.ord")

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

		assert Ore.interp("'hello world'.start_with?('hello')")
		refute Ore.interp("'hello world'.start_with?('world')")

		assert Ore.interp("'hello world'.end_with?('world')")
		refute Ore.interp("'hello world'.end_with?('hello')")

		assert_equal 'hellu wurld', Ore.interp("'hello world'.gsub('o', 'u')")
		assert_equal 'heyo world', Ore.interp("'hello world'.gsub('hell', 'hey')")
	end

	def test_array_builtin_each
		out = Ore.interp <<~ORE
		    x = [1, 2, 3]
		    y = []
		    x.each({ item;
		        y << item * 2
		    })
		    y
		ORE
		assert_equal [2, 4, 6], out.values
	end

	def test_array_intrinsics
		assert_equal [1, 2, 3, 4, 5], Ore.interp("[1, 2, 3].concat([4, 5])")
		assert_equal [1, 2, 3, 4], Ore.interp("[[1, 2], [3, 4]].flatten()").values
		assert_equal [1, 2, 3], Ore.interp("[3, 1, 2].sort()")
		assert_equal [1, 2, 3], Ore.interp("[1, 2, 2, 3, 1].uniq()")

		assert Ore.interp("[1, 2, 3].include?(2)")
		refute Ore.interp("[1, 2, 3].include?(5)")

		assert Ore.interp("[].empty?()")
		refute Ore.interp("[1].empty?()")

		assert_equal 2, Ore.interp("[1, 2, 3].find({ x; x > 1 })")
		assert_equal nil, Ore.interp("[1, 2, 3].find({ x; x > 5 })")

		assert Ore.interp("[1, 2, 3].any?({ x; x > 2 })")
		refute Ore.interp("[1, 2, 3].any?({ x; x > 5 })")

		assert Ore.interp("[1, 2, 3].all?({ x; x > 0 })")
		refute Ore.interp("[1, 2, 3].all?({ x; x > 2 })")
	end

	def test_dictionary_intrinsics
		assert Ore.interp("{}.empty?()")
		refute Ore.interp("{x: 1}.empty?()")

		out = Ore.interp("d = {x: 1, y: 2}; d.clear(); d")
		assert_equal({}, out.dict)

		assert_equal 1, Ore.interp("{x: 1}.fetch(:x, 0)")
		assert_equal 0, Ore.interp("{x: 1}.fetch(:y, 0)")
	end

	def test_number_intrinsics
		assert Ore.interp("4.even?()")
		refute Ore.interp("5.even?()")

		assert Ore.interp("5.odd?()")
		refute Ore.interp("4.odd?()")

		assert_equal 42, Ore.interp("42.5.to_i()")
		assert_equal 42.0, Ore.interp("42.to_f()")

		assert_equal 5, Ore.interp("3.clamp(5, 10)")
		assert_equal 7, Ore.interp("7.clamp(5, 10)")
		assert_equal 10, Ore.interp("15.clamp(5, 10)")
	end
end
