require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

class Grid_Test < Base_Test
	GRID = "@load 'lang/grid'"

	def grid source
		Code.interp "#{GRID}\n\n#{source}"
	end

	def test_a_new_grid_has_its_size_and_value
		out = grid <<~CODE
			scent := Grid(4, 3, 0.5)
			[scent === Grid, scent.width, scent.height, scent.get(3, 2), "`scent`"]
		CODE
		assert_equal [true, 4, 3, 0.5, 'Grid(width: 4, height: 3)'], out.values
		assert_equal 0.0, grid('Grid(2, 2).get(0, 0)')
	end

	def test_set_and_add_change_one_cell_and_small_values_stay
		out = grid <<~CODE
			scent := Grid(3, 3)
			scent.set(1, 2, 0.001)
			added := scent.add(1, 2, 0.002)
			[added, scent.get(1, 2), scent.get(2, 1)]
		CODE
		assert_in_delta 0.003, out.values[0], 1e-12
		assert_in_delta 0.003, out.values[1], 1e-12
		assert_equal 0.0, out.values[2]
	end

	def test_a_cell_outside_raises
		['get(3, 0)', 'get(0, 3)', 'get(-1, 0)', 'set(3, 0, 1)', 'add(0, -1, 1)', 'neighbors(3, 0)'].each do |call|
			assert_raises(Code::Invalid_Grid, call) { grid "Grid(3, 3).#{call}" }
		end
		assert_raises(Code::Invalid_Grid) { grid 'Grid(0, 3)' }
		assert_raises(Code::Invalid_Grid) { grid 'Grid(3, 3).neighbors(0, 0, -1)' }
		assert_raises(Code::Invalid_Grid) { grid 'Grid(3, 3).spread(1.5)' }
	end

	def test_neighbors_gives_the_square_with_nil_outside
		out = grid <<~CODE
			scent := Grid(3, 3)
			scent.set(0, 0, 1)
			scent.set(1, 0, 2)
			scent.set(1, 1, 5)
			[scent.neighbors(1, 1), scent.neighbors(0, 0), scent.neighbors(1, 1, 0)]
		CODE
		assert_equal [1.0, 2.0, 0.0, 0.0, 5.0, 0.0, 0.0, 0.0, 0.0], out.values[0].values
		assert_equal [nil, nil, nil, nil, 1.0, 2.0, nil, 0.0, 5.0], out.values[1].values
		assert_equal [5.0], out.values[2].values
	end

	def test_decay_fades_with_no_rounding
		value = grid <<~CODE
			scent := Grid(2, 2, 200)
			for 0..<150
				scent.decay(0.99)
			end
			scent.get(0, 0)
		CODE
		assert_in_delta 200 * (0.99 ** 150), value, 1e-6
	end

	def test_spread_moves_a_cell_toward_the_mean_of_its_neighbors
		out = grid <<~CODE
			scent := Grid(3, 3)
			scent.set(1, 1, 1)
			scent.spread(0.5)
			[scent.get(1, 1), scent.get(0, 1), scent.get(0, 0)]
		CODE
		assert_equal [0.5, 0.5 * (1.0 / 3), 0.0], out.values

		assert_equal 7.0, grid("one := Grid(1, 1, 7)\none.spread(1)\none.get(0, 0)")
		assert_equal 7.0, grid("same := Grid(3, 3, 7)\nsame.spread(1)\nsame.get(1, 1)")
	end

	def test_fill_min_max_and_sum
		out = grid <<~CODE
			scent := Grid(2, 2)
			scent.fill(1)
			scent.set(0, 0, 4)
			scent.set(1, 1, -2)
			[scent.min(), scent.max(), scent.sum()]
		CODE
		assert_equal [-2.0, 4.0, 4.0], out.values
	end

	def test_functions_that_change_every_cell_chain
		assert_equal 1.0, grid('Grid(2, 2, 2).decay(0.5).spread(0.5).get(0, 0)')
	end

	# A program can have its own Grid, as sandbox/hexagons does, so only an explicit load brings this one in.
	def test_raylib_leaves_the_name_grid_to_the_program
		assert_equal 3, Code.interp("@load 'lang/raylib'\n\nGrid <size: Int>\nGrid(3).size")
	end

	def real_raylib
		Code::Raylib.lib
	rescue LoadError, StandardError => error
		skip "needs raylib-bindings: #{error.message}"
	end

	def test_from_image_reads_one_channel_and_scales_it
		real_raylib
		out = Code.interp <<~CODE
			@load 'lang/raylib'
@load 'lang/grid'

			image := Raylib.gen_image_color(2, 1, [51, 102, 255, 0])
			first := Grid.from_image(image)
			green := Grid.from_image(image, 1, 0, 10)
			[first === Grid, first.width, first.height, first.get(0, 0), green.get(1, 0)]
		CODE
		assert_equal [true, 2, 1, 0.2, 4.0], out.values
	end

	def test_write_to_image_scales_each_value_and_leaves_alpha
		real_raylib
		out = Code.interp <<~CODE
			@load 'lang/raylib'
@load 'lang/grid'

			scent := Grid(3, 1)
			scent.set(0, 0, 0.5)
			scent.set(1, 0, 2)
			scent.set(2, 0, -1)
			image := Raylib.gen_image_color(3, 1, [9, 9, 9, 77])
			scent.write_to_image(image)
			gray := [Raylib.get_image_color(image, 0, 0), Raylib.get_image_color(image, 1, 0), Raylib.get_image_color(image, 2, 0)]

			scent.write_to_image(image, 1, 0, 2)
			[gray, Raylib.get_image_color(image, 1, 0)]
		CODE
		gray, green = out.values
		assert_equal [[128, 128, 128, 77], [255, 255, 255, 77], [0, 0, 0, 77]], gray.values.map(&:values)
		assert_equal [255, 255, 255, 77], green.values
	end

	def test_write_to_image_checks_the_size_and_format
		real_raylib
		assert_raises Code::Invalid_Pixels do
			Code.interp "@load 'lang/raylib'\n@load 'lang/grid'\n\nGrid(2, 2).write_to_image(Raylib.gen_image_color(3, 3, [0, 0, 0]))"
		end
		assert_raises Code::Invalid_Pixels do
			Code.interp <<~CODE
				@load 'lang/raylib'
@load 'lang/grid'

				image := Raylib.gen_image_color(2, 2, [0, 0, 0])
				Raylib.image_format(image, :uncompressed_r8g8b8)
				Grid(2, 2).write_to_image(image)
			CODE
		end
	end
end
