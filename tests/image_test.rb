require 'minitest/autorun'
require 'tmpdir'
require_relative '../ruby/main'
require_relative 'base_test'

# These use the real raylib library, because its Image functions run on the CPU and need no window. They skip when the gem or its native library is not there.
class Image_Test < Base_Test
	RAYLIB = "@load 'lang/raylib'"

	def setup
		super
		Code::Raylib.lib
	rescue LoadError, StandardError => error
		skip "needs raylib-bindings: #{error.message}"
	end

	def run_with_raylib source
		Code.interp "#{RAYLIB}\n\n#{source}"
	end

	def test_gen_image_color_gives_an_image_with_its_fields
		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(4, 3, [1, 2, 3, 4])
			[image === Image, image.width, image.height, image.mipmaps, image.format == Raylib.pixel_format(:uncompressed_r8g8b8a8), "`image`"]
		CODE
		assert_equal [true, 4, 3, 1, true, 'Image(width: 4, height: 3, mipmaps: 1, format: 7)'], out.values
	end

	def test_a_drawn_pixel_reads_back_and_its_neighbor_stays
		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(4, 4, [0, 0, 0, 255])
			Raylib.image_draw_pixel(image, 2, 1, [255, 128, 7, 200])
			[Raylib.get_image_color(image, 2, 1), Raylib.get_image_color(image, 1, 1)]
		CODE
		assert_equal [[255, 128, 7, 200], [0, 0, 0, 255]], out.values.map(&:values)
	end

	def test_a_read_outside_raises_and_a_draw_outside_is_clipped
		assert_raises Code::Invalid_Pixels do
			run_with_raylib <<~CODE
				image := Raylib.gen_image_color(4, 4, [0, 0, 0])
				Raylib.get_image_color(image, 4, 0)
			CODE
		end

		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(4, 4, [0, 0, 0])
			Raylib.image_draw_pixel(image, 4, 0, [1, 1, 1])
			Raylib.image_draw_rectangle(image, -2, -2, 3, 3, [9, 9, 9])
			Raylib.get_image_color(image, 0, 0)
		CODE
		assert_equal [9, 9, 9, 255], out.values
	end

	def test_an_image_constructor_and_load_image_read_a_file_and_keep_exact_values
		Dir.mktmpdir do |dir|
			path = File.join dir, 'world.png'
			out  = run_with_raylib <<~CODE
				world := Raylib.gen_image_color(2, 2, [12, 34, 56, 0])
				Raylib.image_draw_pixel(world, 1, 1, [200, 100, 50, 7])
				saved := Raylib.export_image(world, '#{path}')

				first := Image('#{path}')
				second := Raylib.load_image('#{path}')
				[saved, first === Image, Raylib.get_image_color(first, 0, 0), Raylib.get_image_color(second, 1, 1)]
			CODE
			assert_equal true, out.values[0]
			assert_equal true, out.values[1]
			assert_equal [12, 34, 56, 0], out.values[2].values
			assert_equal [200, 100, 50, 7], out.values[3].values
		end
	end

	def test_a_missing_file_raises
		["Image('missing.png')", "Raylib.load_image('missing.png')"].each do |call|
			assert_raises(Code::Raylib_Load_Failed, call) { run_with_raylib call }
		end
	end

	def test_an_image_needs_a_path
		assert_raises(Code::Missing_Argument) { run_with_raylib 'Image()' }
	end

	def test_a_texture_needs_a_path
		assert_raises(Code::Missing_Argument) { run_with_raylib 'Texture()' }
	end

	def test_a_texture_with_no_window_raises
		["Texture('examples/raylib/assets/booth.png')", "Raylib.load_texture('examples/raylib/assets/booth.png')"].each do |call|
			assert_raises(Code::Raylib_Load_Failed, call) { run_with_raylib call }
		end
	end

	def test_functions_that_change_the_size_change_the_fields
		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(4, 2, [1, 2, 3])
			Raylib.image_rotate_cw(image)
			rotated := [image.width, image.height]
			Raylib.image_resize_nn(image, 8, 16)
			resized := [image.width, image.height]
			Raylib.image_crop(image, [0, 0, 3, 5])
			cropped := [image.width, image.height]
			Raylib.image_resize_canvas(image, 6, 6, 0, 0, [0, 0, 0])
			canvas := [image.width, image.height]
			Raylib.image_to_pot(image, [0, 0, 0])
			[rotated, resized, cropped, canvas, [image.width, image.height]]
		CODE
		assert_equal [[2, 4], [8, 16], [3, 5], [6, 6], [8, 8]], out.values.map(&:values)
	end

	def test_image_format_changes_the_format_and_reads_stay_rgba
		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(2, 2, [10, 20, 30, 255])
			Raylib.image_format(image, :uncompressed_r8g8b8)
			[image.format, Raylib.get_image_color(image, 0, 0), Raylib.get_image_buffer(image).length()]
		CODE
		assert_equal 4, out.values[0]
		assert_equal [10, 20, 30, 255], out.values[1].values
		assert_equal 16, out.values[2]
	end

	def test_image_copy_and_image_from_image_are_separate_images
		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(4, 4, [1, 1, 1])
			copy := Raylib.image_copy(image)
			part := Raylib.image_from_image(image, [0, 0, 2, 3])
			Raylib.image_draw_pixel(image, 0, 0, [9, 9, 9])
			[Raylib.get_image_color(copy, 0, 0).0, Raylib.get_image_color(part, 0, 0).0, part.width, part.height]
		CODE
		assert_equal [1, 1, 2, 3], out.values
	end

	def test_load_image_colors_and_get_image_buffer_read_row_by_row
		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(2, 2, [0, 0, 0, 255])
			Raylib.image_draw_pixel(image, 1, 1, [7, 8, 9, 10])
			colors := Raylib.load_image_colors(image)
			buffer := Raylib.get_image_buffer(image)
			[colors.length(), colors[3], buffer.length(), buffer.get(:u8, 1 * 2 * 4 + 1 * 4), Raylib.load_image_palette(image, 8).length()]
		CODE
		assert_equal 4, out.values[0]
		assert_equal [7, 8, 9, 10], out.values[1].values
		assert_equal [16, 7, 2], out.values[2..]
	end

	def test_draw_functions_put_pixels_on_the_image
		calls = [
			'Raylib.image_clear_background(image, COLOR)',
			'Raylib.image_draw_line(image, 0, 0, 7, 7, COLOR)',
			'Raylib.image_draw_line_ex(image, [0, 0], [7, 7], 3, COLOR)',
			'Raylib.image_draw_line_strip(image, [[0, 0], [7, 7], [0, 7]], COLOR)',
			'Raylib.image_draw_triangle(image, [0, 0], [0, 7], [7, 0], COLOR)',
			'Raylib.image_draw_triangle_gradient(image, [0, 0], [0, 7], [7, 0], COLOR, COLOR, COLOR)',
			'Raylib.image_draw_triangle_lines(image, [0, 0], [0, 7], [7, 0], COLOR)',
			'Raylib.image_draw_triangle_fan(image, [[0, 0], [0, 7], [7, 7], [7, 0]], COLOR)',
			'Raylib.image_draw_triangle_strip(image, [[0, 0], [0, 7], [7, 0], [7, 7]], COLOR)',
			'Raylib.image_draw_rectangle(image, 0, 0, 8, 8, COLOR)',
			'Raylib.image_draw_rectangle_lines(image, 0, 0, 8, 8, COLOR)',
			'Raylib.image_draw_rectangle_lines_ex(image, [0, 0, 8, 8], 2, COLOR)',
			'Raylib.image_draw_circle(image, 4, 4, 3, COLOR)',
			'Raylib.image_draw_circle_lines(image, 4, 4, 3, COLOR)',
			'Raylib.image_draw_image(image, STAMP, 0, 0, WHITE)',
			'Raylib.image_draw_image_rec(image, STAMP, [0, 0, 8, 8], [0, 0], WHITE)',
			'Raylib.image_draw_image_pro(image, STAMP, [0, 0, 8, 8], [0, 0, 8, 8], [0, 0], 0, WHITE)',
		]
		calls.each do |call|
			out = run_with_raylib <<~CODE
				COLOR := [200, 10, 20, 255]
				WHITE := [255, 255, 255, 255]
				STAMP := Raylib.gen_image_color(8, 8, COLOR)

				image := Raylib.gen_image_color(8, 8, [0, 0, 0, 255])
				#{call}
				Raylib.load_image_colors(image).filter(it; it == COLOR).length()
			CODE
			assert_operator out, :>, 0, call
		end
	end

	def test_functions_that_change_colors_run_and_change_the_image
		{
			'Raylib.image_color_invert(image)'                    => [155, 155, 155, 255],
			'Raylib.image_color_replace(image, GRAY, [1, 2, 3])'  => [1, 2, 3, 255],
			'Raylib.image_color_tint(image, [0, 255, 0])'         => [0, 100, 0, 255],
			'Raylib.image_flip_vertical(image)'                   => [100, 100, 100, 255],
			'Raylib.image_flip_horizontal(image)'                 => [100, 100, 100, 255],
			'Raylib.image_rotate_ccw(image)'                      => [100, 100, 100, 255],
			'Raylib.image_color_grayscale(image)'                 => nil,
			'Raylib.image_color_contrast(image, 50)'              => nil,
			'Raylib.image_color_brightness(image, 10)'            => [110, 110, 110, 255],
			'Raylib.image_blur_gaussian(image, 1)'                => nil,
			'Raylib.image_alpha_premultiply(image)'               => nil,
			'Raylib.image_alpha_clear(image, GRAY, 0.5)'          => nil,
			'Raylib.image_alpha_crop(image, 0.5)'                 => nil,
			'Raylib.image_alpha_mask(image, MASK)'                => nil,
			'Raylib.image_mipmaps(image)'                         => nil,
			'Raylib.image_dither(image, 5, 6, 5, 0)'              => nil,
			'Raylib.image_rotate(image, 45)'                      => nil,
			'Raylib.image_resize(image, 4, 4)'                    => nil,
		}.each do |call, expected|
			out = run_with_raylib <<~CODE
				GRAY := [100, 100, 100, 255]
				MASK := Raylib.gen_image_color(4, 4, [255, 255, 255, 255])

				image := Raylib.gen_image_color(4, 4, GRAY)
				#{call}
				Raylib.get_image_color(image, 0, 0)
			CODE
			assert_equal 4, out.values.length, call
			assert_equal expected, out.values, call if expected
		end
	end

	def test_kernel_convolution_applies_a_kernel
		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(3, 3, [0, 0, 0, 255])
			Raylib.image_draw_pixel(image, 1, 1, [90, 90, 90, 255])
			Raylib.image_kernel_convolution(image, [0, 0, 0, 0, 1, 0, 0, 0, 0])
			Raylib.get_image_color(image, 1, 1).0
		CODE
		assert_equal 90, out

		assert_raises Code::Invalid_Pixels do
			run_with_raylib <<~CODE
				image := Raylib.gen_image_color(3, 3, [0, 0, 0])
				Raylib.image_kernel_convolution(image, [1, 2])
			CODE
		end
	end

	def test_generators_give_an_image_of_the_size_asked_for
		[
			'Raylib.gen_image_gradient_linear(4, 3, 0, [0, 0, 0], [9, 9, 9])',
			'Raylib.gen_image_gradient_radial(4, 3, 0.5, [0, 0, 0], [9, 9, 9])',
			'Raylib.gen_image_gradient_square(4, 3, 0.5, [0, 0, 0], [9, 9, 9])',
			'Raylib.gen_image_checked(4, 3, 2, 2, [0, 0, 0], [9, 9, 9])',
			'Raylib.gen_image_white_noise(4, 3, 0.5)',
			'Raylib.gen_image_perlin_noise(4, 3, 0, 0, 1.0)',
			'Raylib.gen_image_cellular(4, 3, 2)',
			"Raylib.gen_image_text(4, 3, 'abcdefghijkl')",
		].each do |call|
			out = run_with_raylib "image := #{call}\n[image.width, image.height, Raylib.is_image_valid?(image)]"
			assert_equal [4, 3, true], out.values, call
		end
	end

	def test_image_from_channel_gives_that_channel_as_grayscale
		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(2, 2, [10, 20, 30, 255])
			green := Raylib.image_from_channel(image, 1)
			Raylib.get_image_color(green, 0, 0).0
		CODE
		assert_equal 20, out
	end

	def test_get_image_alpha_border_gives_the_rect_of_visible_pixels
		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(4, 4, [0, 0, 0, 0])
			Raylib.image_draw_pixel(image, 1, 2, [9, 9, 9, 255])
			Raylib.get_image_alpha_border(image, 0.5)
		CODE
		assert_equal [1, 2, 1, 1], out.values
	end

	def test_load_image_raw_reads_plain_bytes
		Dir.mktmpdir do |dir|
			path = File.join dir, 'world.raw'
			File.binwrite path, [1, 2, 3, 4, 5, 6, 7, 8].pack('C*')
			out = run_with_raylib <<~CODE
				image := Raylib.load_image_raw('#{path}', 2, 1, :uncompressed_r8g8b8a8, 0)
				Raylib.get_image_color(image, 1, 0)
			CODE
			assert_equal [5, 6, 7, 8], out.values
		end
	end

	def test_export_image_as_code_writes_a_file
		Dir.mktmpdir do |dir|
			path = File.join dir, 'world.h'
			assert_equal true, run_with_raylib(<<~CODE)
				Raylib.export_image_as_code(Raylib.gen_image_color(1, 1, [1, 2, 3]), '#{path}')
			CODE
			assert File.exist? path
		end
	end

	def test_get_image_neighbors_gives_the_square_of_one_channel_with_nil_outside
		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(3, 3, [1, 2, 3, 4])
			Raylib.image_draw_pixel(image, 1, 1, [50, 60, 70, 80])
			[Raylib.get_image_neighbors(image, 1, 1), Raylib.get_image_neighbors(image, 0, 0, 1, 1), Raylib.get_image_neighbors(image, 1, 1, 0, 3)]
		CODE
		assert_equal [1, 1, 1, 1, 50, 1, 1, 1, 1], out.values[0].values
		assert_equal [nil, nil, nil, nil, 2, 2, nil, 2, 60], out.values[1].values
		assert_equal [80], out.values[2].values
	end

	def test_get_image_neighbors_reads_another_format_the_same_way
		out = run_with_raylib <<~CODE
			image := Raylib.gen_image_color(2, 2, [10, 20, 30, 255])
			Raylib.image_format(image, :uncompressed_r8g8b8)
			Raylib.get_image_neighbors(image, 0, 0, 1, 1)
		CODE
		assert_equal [nil, nil, nil, nil, 20, 20, nil, 20, 20], out.values
	end

	def test_get_image_neighbors_checks_its_arguments
		["5, 0", "0, 0, -1", "0, 0, 1, 4"].each do |arguments|
			assert_raises(Code::Invalid_Pixels, arguments) do
				run_with_raylib "Raylib.get_image_neighbors(Raylib.gen_image_color(3, 3, [0, 0, 0]), #{arguments})"
			end
		end
	end

	def test_rect_point_and_color_work_where_a_list_works
		out = run_with_raylib <<~CODE
			@load 'lang/shapes'

			WHITE := Color(255, 255, 255)
			stamp := Raylib.gen_image_color(4, 4, Color(1, 2, 3))
			image := Raylib.gen_image_color(8, 8, Color(0, 0, 0))

			Raylib.image_draw_image_rec(image, stamp, Rect(0, 0, 4, 4), Point(2, 2), WHITE)
			first := Raylib.get_image_color(image, 2, 2)

			Raylib.image_draw_image_pro(image, stamp, Rect(0, 0, 4, 4), Rect(4, 4, 4, 4), Point(0, 0), 0, WHITE)
			second := Raylib.get_image_color(image, 5, 5)

			Raylib.image_draw_line_ex(image, Point(0, 0), Point(0, 7), 1, Color(9, 9, 9, 200))
			third := Raylib.get_image_color(image, 0, 3)

			Raylib.image_draw_rectangle_lines_ex(image, Rect(0, 0, 8, 8), 1, Color(7, 7, 7))
			part := Raylib.image_from_image(image, Rect(0, 0, 2, 3))
			Raylib.image_crop(part, Rect(0, 0, 1, 1))
			[first, second, third, part.width, part.height]
		CODE
		assert_equal [1, 2, 3, 255], out.values[0].values
		assert_equal [1, 2, 3, 255], out.values[1].values
		assert_equal 9, out.values[2].values.first
		assert_equal [1, 1], out.values.last(2)
	end

	def test_a_second_unload_is_safe_and_a_read_after_unload_raises
		assert_raises Code::Invalid_Pixels do
			run_with_raylib <<~CODE
				image := Raylib.gen_image_color(2, 2, [1, 2, 3])
				Raylib.unload_image(image)
				Raylib.unload_image(image)
				Raylib.get_image_color(image, 0, 0)
			CODE
		end
	end

	def test_a_function_that_takes_an_image_checks_the_type
		assert_raises(Code::Type_Contract_Violation) { run_with_raylib 'Raylib.image_draw_pixel(5, 0, 0, [1, 2, 3])' }
	end

	def test_an_image_works_through_a_named_load
		out = Code.interp <<~CODE
			Lib := @load 'lang/raylib'

			image := Lib.Raylib.gen_image_color(2, 2, [10, 20, 30])
			[image.width, Lib.Raylib.get_image_color(image, 0, 0).0, "`image`"]
		CODE
		assert_equal [2, 10, 'Image(width: 2, height: 2, mipmaps: 1, format: 7)'], out.values
	end

	# Each declaration in lang/raylib.code needs its Ruby method, and each raylib call in the Ruby file must name a real function.
	def test_each_declaration_has_a_proxy_and_each_call_a_real_function
		names = File.read(File.join(Code::ROOT_PATH, 'lang/raylib.code')).scan(/^\s*Self\.(\S+) \(.*@ruby/).flatten
		assert_operator names.length, :>, 100
		names.each { assert Code::Raylib.method_defined?("proxy_#{it}"), "no proxy_#{it}" }

		calls = File.read(File.join(Code::ROOT_PATH, 'ruby/proxies/raylib.rb')).scan(/\blib\.((?:[A-Z]|rl[A-Z])[A-Za-z0-9]*)/).flatten.uniq
		calls.each { assert_respond_to Code::Raylib.lib, it }
	end
end
