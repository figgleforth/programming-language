require 'minitest/autorun'
require 'tmpdir'
require_relative '../ruby/main'
require_relative 'base_test'

# A fake raylib stands in for the real library, so these tests need no window and no GPU. It records each call, so a test can check that raylib gets the raw struct and not the Code::Texture.
class Texture_Test < Base_Test
	RAW_TEXTURE = ::Struct.new :id, :width, :height, :mipmaps, :format
	RAW_RENDER  = ::Struct.new :texture

	module Fake_Raylib
		TEXTURE_FILTER_POINT              = 0
		PIXELFORMAT_UNCOMPRESSED_R8G8B8   = 4
		PIXELFORMAT_UNCOMPRESSED_R8G8B8A8 = 7
		PIXELFORMAT_COMPRESSED_DXT1_RGB   = 14

		# lang/raylib.code reads every window flag when it loads, for Config_Flags.
		{ FULLSCREEN_MODE: 2, WINDOW_RESIZABLE: 4, WINDOW_UNDECORATED: 8, WINDOW_TRANSPARENT: 16, MSAA_4X_HINT: 32, VSYNC_HINT: 64, WINDOW_HIDDEN: 128, WINDOW_ALWAYS_RUN: 256, WINDOW_MINIMIZED: 512, WINDOW_MAXIMIZED: 1024, WINDOW_UNFOCUSED: 2048, WINDOW_TOPMOST: 4096, WINDOW_HIGHDPI: 8192, WINDOW_MOUSE_PASSTHROUGH: 16384, BORDERLESS_WINDOWED_MODE: 32768, INTERLACED_HINT: 65536 }.each { |name, value| const_set "FLAG_#{name}", value }

		RAW_IMAGE  = ::Struct.new :data, :to_ptr, :width, :height
		RAW_COLOR  = ::Struct.new :r, :g, :b, :a
		RAW_COLORS = ::Struct.new :read_bytes_result do
			def read_bytes(_count) = read_bytes_result
		end

		module Color
			def self.from_u8(*) = :color
		end

		module Rectangle
			def self.create(*) = :rectangle
		end

		module Vector2
			def self.create(*) = :vector2
		end

		class << self
			attr_accessor :calls, :raw_format

			def raw = RAW_TEXTURE.new(7, 2, 2, 1, raw_format)
			def LoadTexture(_path) = raw
			def IsTextureValid(_texture) = true
			def UpdateTextureRec(_texture, rect, pointer) = calls << [:UpdateTextureRec, rect, pointer.get_bytes(0, pointer.size)]
			def ImageFormat(_image, format) = calls << [:ImageFormat, format]
			def LoadImageFromTexture(_texture) = RAW_IMAGE.new(nil, nil, 2, 2)
			def LoadImageColors(_image) = RAW_COLORS.new((1..16).to_a.pack('C*'))
			def UnloadImageColors(_colors) = calls << [:UnloadImageColors]
			def GetImageColor(_image, x, y) = RAW_COLOR.new(x, y, 3, 4)
			def LoadTextureFromImage(_image) = raw
			def LoadRenderTexture(_width, _height) = RAW_RENDER.new(raw)
			def GenImageColor(width = 1, height = 1, *) = RAW_IMAGE.new(::FFI::MemoryPointer.new(:uint8, width * height * 4), :image_pointer)
			def GenImageChecked(*) = :image
			def UnloadImage(_image) = nil
			def SetTextureFilter(*args) = calls << [:SetTextureFilter, args.first]
			def SetShaderValueTexture(*args) = calls << [:SetShaderValueTexture, args.last]
			def DrawTexture(*args) = calls << [:DrawTexture, args.first]
			def DrawTexturePro(*args) = calls << [:DrawTexturePro, args.first]
			def UnloadTexture(*args) = calls << [:UnloadTexture, args.first]
			def rlSetTexture(*args) = calls << [:rlSetTexture, args.first]
		end
	end

	RAYLIB = "@load 'lang/raylib'"

	def setup
		super
		begin
			require 'ffi' # the raylib gem loads it for a real program
		rescue LoadError
			skip 'needs the ffi gem'
		end
		@real_lib              = Code::Raylib.instance_variable_get :@lib
		Fake_Raylib.calls      = []
		Fake_Raylib.raw_format = Fake_Raylib::PIXELFORMAT_UNCOMPRESSED_R8G8B8A8
		Code::Raylib.instance_variable_set :@lib, Fake_Raylib
	end

	def teardown
		if @real_lib
			Code::Raylib.instance_variable_set :@lib, @real_lib
		elsif Code::Raylib.instance_variable_defined? :@lib
			Code::Raylib.remove_instance_variable :@lib
		end
		super
	end

	def writes
		Fake_Raylib.calls.select { it.first == :UpdateTextureRec }
	end

	def test_load_texture_gives_a_texture_with_its_fields
		out = Code.interp <<~CODE
			#{RAYLIB}

			texture := Raylib.load_texture('any.png')
			[texture === Texture, texture.id, texture.width, texture.height, texture.mipmaps, texture.format]
		CODE
		assert_equal [true, 7, 2, 2, 1, 7], out.values
	end

	def test_update_texture_sends_a_list_of_colors_as_rgba_bytes
		Code.interp <<~CODE
			#{RAYLIB}

			Color <r: Int, g: Int, b: Int>

			texture := Raylib.load_texture('any.png')
			Raylib.update_texture(texture, [[1, 2, 3, 4], [5, 6, 7], Color(8, 9, 10), [11, 12, 13, 14]])
		CODE
		assert_equal [1, 2, 3, 4, 5, 6, 7, 255, 8, 9, 10, 255, 11, 12, 13, 14], writes.first.last.unpack('C*')
	end

	def test_update_texture_takes_a_buffer_of_bytes
		Code.interp <<~CODE
			#{RAYLIB}

			pixels := Buffer(16)
			pixels.set(:u8, 0, 200)
			Raylib.update_texture(Raylib.load_texture('any.png'), pixels)
		CODE
		assert_equal [200] + [0] * 15, writes.first.last.unpack('C*')
	end

	def test_update_texture_rec_and_set_texture_pixel_write_only_their_area
		Code.interp <<~CODE
			#{RAYLIB}

			texture := Raylib.load_texture('any.png')
			Raylib.update_texture_rec(texture, [1, 0, 1, 2], [[1, 1, 1], [2, 2, 2]])
			Raylib.set_texture_pixel(texture, 1, 1, [3, 3, 3])
		CODE
		assert_equal [1, 1, 1, 255, 2, 2, 2, 255], writes.first.last.unpack('C*')
		assert_equal [3, 3, 3, 255], writes.last.last.unpack('C*')
	end

	def test_a_texture_with_another_format_gets_its_bytes_converted
		Fake_Raylib.raw_format = Fake_Raylib::PIXELFORMAT_UNCOMPRESSED_R8G8B8
		Code.interp <<~CODE
			#{RAYLIB}

			Raylib.set_texture_pixel(Raylib.load_texture('any.png'), 0, 0, [1, 2, 3])
		CODE
		assert_includes Fake_Raylib.calls, [:ImageFormat, Fake_Raylib::PIXELFORMAT_UNCOMPRESSED_R8G8B8]
	end

	def test_get_texture_pixels_gives_a_list_of_rgba_arrays
		out = Code.interp <<~CODE
			#{RAYLIB}

			pixels := Raylib.get_texture_pixels(Raylib.load_texture('any.png'))
			[pixels.length(), pixels[1] == [5, 6, 7, 8], pixels[3][3]]
		CODE
		assert_equal [4, true, 16], out.values
		assert_includes Fake_Raylib.calls, [:UnloadImageColors]
	end

	def test_get_texture_pixel_gives_one_rgba_array
		out = Code.interp <<~CODE
			#{RAYLIB}

			Raylib.get_texture_pixel(Raylib.load_texture('any.png'), 1, 0)
		CODE
		assert_equal [1, 0, 3, 4], out.values
	end

	def test_pixels_that_do_not_fit_raise_and_never_reach_raylib
		[
			'Raylib.update_texture(texture, [[1, 2, 3]])',
			'Raylib.update_texture(texture, Buffer(15))',
			'Raylib.update_texture_rec(texture, [1, 1, 2, 2], [[1, 2, 3], [1, 2, 3], [1, 2, 3], [1, 2, 3]])',
			'Raylib.update_texture_rec(texture, [0.5, 0, 1, 1], [[1, 2, 3]])',
			'Raylib.set_texture_pixel(texture, 2, 0, [1, 2, 3])',
			'Raylib.set_texture_pixel(texture, -1, 0, [1, 2, 3])',
			'Raylib.get_texture_pixel(texture, 0, 2)',
		].each do |call|
			assert_raises Code::Invalid_Pixels, call do
				Code.interp <<~CODE
					#{RAYLIB}

					texture := Raylib.load_texture('any.png')
					#{call}
				CODE
			end
		end
		assert_empty writes
	end

	def test_a_compressed_texture_raises
		Fake_Raylib.raw_format = Fake_Raylib::PIXELFORMAT_COMPRESSED_DXT1_RGB
		['Raylib.set_texture_pixel(texture, 0, 0, [1, 2, 3])', 'Raylib.get_texture_pixels(texture)'].each do |call|
			assert_raises Code::Invalid_Pixels, call do
				Code.interp <<~CODE
					#{RAYLIB}

					texture := Raylib.load_texture('any.png')
					#{call}
				CODE
			end
		end
	end

	def test_each_function_that_makes_a_texture_gives_a_texture
		out = Code.interp <<~CODE
			#{RAYLIB}

			target := Raylib.load_render_texture(10, 10)

			[
				Raylib.gen_color_texture(10, 10, [1, 2, 3]) === Texture
				Raylib.gen_checked_texture(10, 10, 2, 2, [1, 2, 3], [4, 5, 6]) === Texture
				Raylib.render_texture_texture(target) === Texture
			]
		CODE
		assert_equal [true, true, true], out.values
	end

	def test_a_texture_shows_its_fields
		out = Code.interp <<~CODE
			#{RAYLIB}

			"`Raylib.load_texture('any.png')`"
		CODE
		assert_equal 'Texture(id: 7, width: 2, height: 2, mipmaps: 1, format: 7)', out
	end

	def test_get_texture_width_and_height_read_a_texture
		out = Code.interp <<~CODE
			#{RAYLIB}

			texture := Raylib.load_texture('any.png')
			[Raylib.get_texture_width(texture), Raylib.get_texture_height(texture)]
		CODE
		assert_equal [2, 2], out.values
	end

	def test_raylib_gets_the_raw_struct_back
		Code.interp <<~CODE
			#{RAYLIB}

			texture := Raylib.load_texture('any.png')
			Raylib.set_texture_filter(texture, :point)
			Raylib.set_shader_value_texture(nil, 0, texture)
			Raylib.draw_texture(texture, 0, 0, [1, 2, 3])
			Raylib.draw_texture_pro(texture, [0, 0, 1, 1], [0, 0, 1, 1], [0, 0], 0, [1, 2, 3])
			Raylib.unload_texture(texture)
		CODE
		assert_equal %i(SetTextureFilter SetShaderValueTexture DrawTexture DrawTexturePro UnloadTexture), Fake_Raylib.calls.map(&:first)
		assert Fake_Raylib.calls.all? { it.last.is_a? RAW_TEXTURE }
	end

	def test_rl_set_texture_gets_the_id
		Code.interp <<~CODE
			#{RAYLIB}

			Raylib.rl_set_texture(Raylib.load_texture('any.png'))
		CODE
		assert_equal [[:rlSetTexture, 7]], Fake_Raylib.calls
	end

	def test_a_function_that_takes_a_texture_checks_the_type
		assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
				#{RAYLIB}

				Raylib.draw_texture(5, 0, 0, [1, 2, 3])
			CODE
		end
	end

	def test_a_texture_works_through_a_named_load
		out = Code.interp <<~CODE
			Lib := @load 'lang/raylib'

			texture := Lib.Raylib.load_texture('any.png')
			Lib.Raylib.draw_texture(texture, 0, 0, [1, 2, 3])
			[texture.width, "`texture`"]
		CODE
		assert_equal [2, 'Texture(id: 7, width: 2, height: 2, mipmaps: 1, format: 7)'], out.values
	end
end
