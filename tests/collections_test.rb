require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

class Collections_Test < Base_Test
	def test_array_initialize_with_varargs
		# These mimic Ruby's behavior
		out = Code.interp "Array(4, 8, 15, 16)"
		assert_equal [4, 8, 15, 16], out.values

		out = Code.interp "Array(23 42)"
		assert_equal [23, 42], out.values
	end

	def test_array_static_initializer_functions
		out = Code.interp "
		size := 5
		value := 42
		Array.of(value, size)"
		assert_equal [42, 42, 42, 42, 42], out.values

		# This also mimics Ruby's behavior:
		out = Code.interp "
		size := 4
		value := 8
		Array.new(size, value)"
		assert_equal [8, 8, 8, 8], out.values
	end

	def test_array_count_is_length
		assert_equal 3, Code.interp('[4, 8, 15].count()')
		assert_equal 0, Code.interp('[].count()')
		assert_equal 3, Code.interp('[4, 8, 15].length()')
	end

	def test_array_max_and_min
		assert_equal 3, Code.interp('[3, 1, 2].max()')
		assert_equal 1, Code.interp('[3, 1, 2].min()')
		assert_equal -109, Code.interp('[2, -109, -1].min()')
		assert_equal 2.5, Code.interp('[1, 2.5].max()')
		assert_nil Code.interp('[].max()')
		assert_nil Code.interp('[].min()')
	end

	def test_array_product_without_argument_multiplies
		assert_equal 24, Code.interp('[2, 3, 4].product()')
		assert_equal 3.0, Code.interp('[1.5, 2].product()')
		assert_equal 1, Code.interp('[].product()')
	end

	def test_array_product_with_array_is_cartesian
		out = Code.interp '[1, 2].product([3, 4])'
		assert_equal [[1, 3], [1, 4], [2, 3], [2, 4]], out.values

		out = Code.interp '[].product([1, 2])'
		assert_equal [], out.values
	end

	# Mirrors `distance` in sandbox/hexagons/hexagons.code: on a wrapping N-sized map, each axis can go two ways, and the shortest path is the min over all four combinations.
	def test_array_product_map_min_for_wrapped_hex_distance
		out = Code.interp "
		Position <q: Int, r: Int, z: Int>
		N := 108

		hex_length ( @splatr position: Position -> Integer;
			[q.abs(), r.abs(), (q+r).abs()].max()
		)

		distance ( a: Position, b: Position -> Int;
			dq := (b.q - a.q) % N
			dr := (b.r - a.r) % N
			flat := [dq, dq-N].product([dr, dr-N]).map(it;
				hex_length(Position(it.0, it.1, 0))
			).min()
			flat + (b.z - a.z).abs()
		)

		[
			distance(Position(0, 0, 0), Position(2, -1, 0)),
			distance(Position(0, 0, 0), Position(107, 0, 0)),
			distance(Position(0, 0, 0), Position(0, 0, 3)),
		]"
		assert_equal [2, 1, 3], out.values
	end
end
