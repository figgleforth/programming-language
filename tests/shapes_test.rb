require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

class Shapes_Test < Base_Test
	def shapes source
		Code.interp "@load 'lang/shapes'\n\n#{source}"
	end

	def test_rect_holds_its_members_in_order
		out = shapes "rect := Rect(1, 2, 3, 4)\n[rect.x, rect.y, rect.width, rect.height, rect === Rectangle]"
		assert_equal [1, 2, 3, 4, true], out.values
	end

	def test_color_alpha_is_opaque_by_default
		assert_equal [1, 2, 3, 255], shapes('Color(1, 2, 3).@values').values
		assert_equal [1, 2, 3, 4], shapes('Color(1, 2, 3, 4).@values').values
	end

	def test_point_is_a_vector2
		assert_equal [1, 2, true], shapes("point := Point(1, 2)\n[point.x, point.y, point =>= Vector2]").values
	end

	def test_contains_counts_the_left_and_top_edges_only
		out = shapes <<~CODE
			rect := Rect(10, 10, 5, 5)
			[rect.contains?(Point(10, 10)), rect.contains?(Point(14, 14)), rect.contains?(Point(15, 12)), rect.contains?(Point(12, 15)), rect.contains?(Point(9, 12))]
		CODE
		assert_equal [true, true, false, false, false], out.values
	end

	def test_center_and_inset
		out = shapes <<~CODE
			rect := Rect(10, 20, 30, 40)
			center := rect.center()
			smaller := rect.inset(5)
			[center.x, center.y, smaller.x, smaller.y, smaller.width, smaller.height]
		CODE
		assert_equal [25.0, 40.0, 15, 25, 20, 30], out.values
	end

	def test_each_split_gives_the_part_and_the_rest
		rects = {
			'split_left(10)'   => [[0, 0, 10, 50], [10, 0, 90, 50]],
			'split_right(10)'  => [[90, 0, 10, 50], [0, 0, 90, 50]],
			'split_top(10)'    => [[0, 0, 100, 10], [0, 10, 100, 40]],
			'split_bottom(10)' => [[0, 40, 100, 10], [0, 0, 100, 40]],
		}
		rects.each do |call, (taken, rest)|
			out = shapes <<~CODE
				parts := Rect(0, 0, 100, 50).#{call}
				[parts.taken.x, parts.taken.y, parts.taken.width, parts.taken.height, parts.rest.x, parts.rest.y, parts.rest.width, parts.rest.height]
			CODE
			assert_equal taken + rest, out.values, call
		end
	end

	def test_a_split_destructures
		out = shapes <<~CODE
			(left, rest) := Rect(0, 0, 100, 50).split_left(30)
			[left.width, rest.width]
		CODE
		assert_equal [30, 70], out.values
	end

	def test_shapes_load_with_raylib_in_either_order
		assert_equal 2, Code.interp("@load 'lang/shapes'\n@load 'lang/raylib'\n\nPoint(1, 2).y")
		assert_equal 2, Code.interp("@load 'lang/raylib'\n@load 'lang/shapes'\n\nPoint(1, 2).y")
	end
end
