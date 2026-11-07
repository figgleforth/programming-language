# Implemented by Claude
#
module Code
	class Raylib < Instance
		BYTES_PER_PIXEL = 4 # the pixels that a program reads and writes are always RGBA

		def self.lib
			return @lib if defined? @lib

			begin
				require 'raylib'
			rescue LoadError
				raise "Raylib isn't available -- run `gem install raylib-bindings` to use it"
			end

			gem_lib_path = ::Gem::Specification.find_by_name('raylib-bindings').full_gem_path + '/lib/'
			arch         = RUBY_PLATFORM.split('-').first
			extension    = case RUBY_PLATFORM
			when /darwin/ then 'dylib'
			when /linux/ then 'so'
			when /mswin|msys|mingw|cygwin/ then 'dll'
			else raise "Raylib: unsupported platform #{RUBY_PLATFORM}"
			end

			::Raylib.load_lib(
				"#{gem_lib_path}libraylib.#{arch}.#{extension}",
				raygui_libpath: "#{gem_lib_path}raygui.#{arch}.#{extension}",
				physac_libpath: "#{gem_lib_path}physac.#{arch}.#{extension}"
			)
			@lib = ::Raylib
		end

		# raylib only logs a warning when a load fails, and gives back an empty struct. It fails when the file is missing, and a texture also fails before `init_window`.
		def self.valid_texture raylib_texture, source
			return raylib_texture if lib.IsTextureValid raylib_texture

			raise Code::Raylib_Load_Failed, "Cannot load a texture from #{source}. A texture needs `Raylib.init_window` first, and a file path starts from the working directory (#{::Dir.pwd})."
		end

		def self.valid_image raylib_image, source
			return raylib_image if lib.IsImageValid raylib_image

			raise Code::Raylib_Load_Failed, "Cannot load an image from #{source}. A file path starts from the working directory (#{::Dir.pwd})."
		end

		# --- Window / lifecycle ---

		# @param [::Symbol] name
		def proxy_config_flag name
			self.class.lib.const_get "FLAG_#{name.to_s.upcase}"
		end

		def proxy_set_config_flags flags
			self.class.lib.SetConfigFlags flags
		end

		def proxy_init_window width, height, title
			self.class.lib.InitWindow width, height, title
		end

		def proxy_close_window
			self.class.lib.CloseWindow
		end

		def proxy_window_should_close?
			self.class.lib.WindowShouldClose
		end

		def proxy_set_target_fps fps
			self.class.lib.SetTargetFPS fps
		end

		def proxy_get_frame_time
			self.class.lib.GetFrameTime
		end

		def proxy_get_time
			self.class.lib.GetTime
		end

		def proxy_get_screen_width
			self.class.lib.GetScreenWidth
		end

		def proxy_get_screen_height
			self.class.lib.GetScreenHeight
		end

		# --- Drawing ---

		def proxy_begin_drawing
			self.class.lib.BeginDrawing
		end

		def proxy_end_drawing
			self.class.lib.EndDrawing
		end

		def proxy_clear_background color
			self.class.lib.ClearBackground rgba(color)
		end

		# --- 2D Camera ---

		def proxy_begin_mode_2d camera
			self.class.lib.BeginMode2D camera2d(camera)
		end

		def proxy_end_mode_2d
			self.class.lib.EndMode2D
		end

		# --- Shapes ---

		def proxy_draw_circle x, y, radius, color
			self.class.lib.DrawCircle x, y, radius, rgba(color)
		end

		def proxy_draw_circle_lines x, y, radius, color
			self.class.lib.DrawCircleLines x, y, radius, rgba(color)
		end

		def proxy_draw_rectangle x, y, width, height, color
			self.class.lib.DrawRectangle x, y, width, height, rgba(color)
		end

		def proxy_draw_rectangle_lines x, y, width, height, color
			self.class.lib.DrawRectangleLines x, y, width, height, rgba(color)
		end

		def proxy_draw_rectangle_pro rect, origin, rotation, color
			self.class.lib.DrawRectanglePro rectangle(rect), vector2(origin), rotation, rgba(color)
		end

		def proxy_draw_line x1, y1, x2, y2, color
			self.class.lib.DrawLine x1, y1, x2, y2, rgba(color)
		end

		# --- Text ---

		def proxy_draw_text text, x, y, size, color
			self.class.lib.DrawText text, x, y, size, rgba(color)
		end

		def proxy_measure_text text, size
			self.class.lib.MeasureText text, size
		end

		def proxy_draw_fps x, y
			self.class.lib.DrawFPS x, y
		end


		def proxy_get_fps
			self.class.lib.GetFPS
		end

		def proxy_get_random_value min, max
			self.class.lib.GetRandomValue min, max
		end

		# --- Textures / Shaders / Render targets ---
		#
		# A Texture2D is a Code::Texture: these methods wrap the FFI struct on the way out, and unwrap it on the way back in. RenderTexture2D / Shader / Image values are opaque to Code -- the raw FFI struct flows through untouched, the same way a file handle or socket would.

		def proxy_load_texture path
			wrap_texture self.class.valid_texture(self.class.lib.LoadTexture(path), path)
		end

		def proxy_get_texture_width texture
			texture.proxy_width
		end

		def proxy_get_texture_height texture
			texture.proxy_height
		end

		# @param [::Symbol] filter
		def proxy_set_texture_filter texture, filter
			self.class.lib.SetTextureFilter texture.raylib_texture, texture_filter_code(filter)
		end

		# A placeholder texture built from a plain color -- no external image file needed. Combines
		# GenImageColor + LoadTextureFromImage; the CPU-side Image is only scratch space for building
		# the GPU texture, so it's unloaded again immediately after. Note: a flat, single-color texture
		# has no internal detail at all, so any UV-shift-based distortion shader (a wave/ripple effect,
		# say) has nothing to visibly displace -- every shifted sample looks identical to the original.
		# Use gen_checked_texture instead when the placeholder needs to actually show that kind of effect.
		def proxy_gen_color_texture width, height, color
			image   = self.class.lib.GenImageColor width, height, rgba(color)
			texture = self.class.lib.LoadTextureFromImage image
			self.class.lib.UnloadImage image
			wrap_texture texture
		end

		# Same idea, but a checkerboard instead of one flat color -- has actual internal detail, so a
		# UV-shift distortion shader visibly displaces it instead of sampling the same color either way.
		def proxy_gen_checked_texture width, height, checks_x, checks_y, color1, color2
			image   = self.class.lib.GenImageChecked width, height, checks_x, checks_y, rgba(color1), rgba(color2)
			texture = self.class.lib.LoadTextureFromImage image
			self.class.lib.UnloadImage image
			wrap_texture texture
		end

		def proxy_load_render_texture width, height
			self.class.lib.LoadRenderTexture width, height
		end

		# The drawable Texture2D backing a render target -- e.g. feeding one pass's output into the
		# next pass as an ordinary texture.
		def proxy_render_texture_texture render_texture
			wrap_texture render_texture.texture
		end

		def proxy_load_shader vertex_path, fragment_path
			self.class.lib.LoadShader vertex_path, fragment_path
		end

		def proxy_get_shader_location shader, name
			self.class.lib.GetShaderLocation shader, name&.to_s
		end

		# A GLSL shader's uniform (`uniform float u_time;`) can hold more than just
		# a float -- raylib tags every SetShaderValue call with which one it's writing. Code's own
		# Raylib.set_shader_value_float only ever writes the SHADER_UNIFORM_FLOAT case (all this demo
		# needs), but here's the full list raylib itself defines (raylib.h's ShaderUniformDataType),
		# for whenever a future shader needs one of the others:
		#
		#   SHADER_UNIFORM_FLOAT        a single float           (GLSL `float`)
		#   SHADER_UNIFORM_VEC2         2 floats                 (GLSL `vec2`)
		#   SHADER_UNIFORM_VEC3         3 floats                 (GLSL `vec3`)
		#   SHADER_UNIFORM_VEC4         4 floats                 (GLSL `vec4`)
		#   SHADER_UNIFORM_INT          a single int             (GLSL `int`)
		#   SHADER_UNIFORM_IVEC2        2 ints                   (GLSL `ivec2`)
		#   SHADER_UNIFORM_IVEC3        3 ints                   (GLSL `ivec3`)
		#   SHADER_UNIFORM_IVEC4        4 ints                   (GLSL `ivec4`)
		#   SHADER_UNIFORM_UINT         a single unsigned int    (GLSL `uint`)
		#   SHADER_UNIFORM_UIVEC2       2 unsigned ints          (GLSL `uivec2`)
		#   SHADER_UNIFORM_UIVEC3       3 unsigned ints          (GLSL `uivec3`)
		#   SHADER_UNIFORM_UIVEC4       4 unsigned ints          (GLSL `uivec4`)
		#   SHADER_UNIFORM_SAMPLER2D    a bound texture unit     (GLSL `sampler2D`)
		#
		def proxy_set_shader_value_float shader, location, value
			pointer = ::FFI::MemoryPointer.new(:float)
			pointer.write_float value
			self.class.lib.SetShaderValue shader, location, pointer, self.class.lib::SHADER_UNIFORM_FLOAT
		end

		# Binds a texture to a `uniform sampler2D` -- for reading a *different* texture than whatever
		# the current draw call's own `texture0` is (e.g. a shader that samples a separately-rendered
		# background to invert it). A real, separate raylib call from SetShaderValue -- it also binds
		# the texture unit, not just writes a value.
		def proxy_set_shader_value_texture shader, location, texture
			self.class.lib.SetShaderValueTexture shader, location, texture.raylib_texture
		end

		def proxy_begin_texture_mode render_texture
			self.class.lib.BeginTextureMode render_texture
		end

		def proxy_end_texture_mode
			self.class.lib.EndTextureMode
		end

		def proxy_begin_shader_mode shader
			self.class.lib.BeginShaderMode shader
		end

		def proxy_end_shader_mode
			self.class.lib.EndShaderMode
		end

		def proxy_draw_texture texture, x, y, color
			self.class.lib.DrawTexture texture.raylib_texture, x, y, rgba(color)
		end

		# `source`/`dest` are [x, y, width, height] Arrays, `origin` an [x, y] Array -- same "plain
		# Code Array in, real raylib struct out" boundary conversion as colors get.
		def proxy_draw_texture_pro texture, source, dest, origin, rotation, color
			self.class.lib.DrawTexturePro texture.raylib_texture, rectangle(source), rectangle(dest), vector2(origin), rotation, rgba(color)
		end

		# --- Texture pixels ---

		def proxy_update_texture texture, pixels
			write_texture_pixels texture, 0, 0, texture.proxy_width, texture.proxy_height, pixels
		end

		def proxy_update_texture_rec texture, rect, pixels
			x, y, width, height = rect.values
			write_texture_pixels texture, x, y, width, height, pixels
		end

		def proxy_set_texture_pixel texture, x, y, color
			write_texture_pixels texture, x, y, 1, 1, [color]
		end

		# @return [::Array] one [r, g, b, a] Code::Array for each pixel, row by row
		def proxy_get_texture_pixels texture
			lib = self.class.lib
			check_pixel_area texture, 0, 0, 0, 0
			image = lib.LoadImageFromTexture texture.raylib_texture
			list  = color_lists rgba_bytes(image)
			lib.UnloadImage image
			list
		end

		# @return [::Array] [r, g, b, a]
		def proxy_get_texture_pixel texture, x, y
			lib = self.class.lib
			check_pixel_area texture, x, y, 1, 1
			image = lib.LoadImageFromTexture texture.raylib_texture
			color = lib.GetImageColor image, x, y
			lib.UnloadImage image
			[color.r, color.g, color.b, color.a]
		end

		# --- Images: load, make, save ---

		def proxy_load_image path
			wrap_image self.class.valid_image(self.class.lib.LoadImage(path), path)
		end

		# @param [::Symbol] format
		def proxy_load_image_raw path, width, height, format, header_size
			wrap_image self.class.valid_image(self.class.lib.LoadImageRaw(path, width, height, pixel_format_code(format), header_size), path)
		end

		def proxy_load_image_from_texture texture
			wrap_image self.class.lib.LoadImageFromTexture(texture.raylib_texture)
		end

		def proxy_load_image_from_screen
			wrap_image self.class.lib.LoadImageFromScreen
		end

		def proxy_load_texture_from_image image
			wrap_texture self.class.lib.LoadTextureFromImage(image.raylib_image)
		end

		def proxy_is_image_valid? image
			self.class.lib.IsImageValid image.raylib_image
		end

		# The cleared fields make a second unload safe, and make a later read raise, not read freed memory.
		def proxy_unload_image image
			raw = image.raylib_image
			self.class.lib.UnloadImage raw
			raw.data   = ::FFI::Pointer::NULL
			raw.width  = 0
			raw.height = 0
		end

		def proxy_export_image image, path
			self.class.lib.ExportImage image.raylib_image, path
		end

		def proxy_export_image_as_code image, path
			self.class.lib.ExportImageAsCode image.raylib_image, path
		end

		# @param [::Symbol] name
		# @return [::Integer]
		def proxy_pixel_format name
			pixel_format_code name
		end

		def proxy_gen_image_color width, height, color
			wrap_image self.class.lib.GenImageColor(width, height, rgba(color))
		end

		def proxy_gen_image_gradient_linear width, height, direction, start_color, end_color
			wrap_image self.class.lib.GenImageGradientLinear(width, height, direction, rgba(start_color), rgba(end_color))
		end

		def proxy_gen_image_gradient_radial width, height, density, inner, outer
			wrap_image self.class.lib.GenImageGradientRadial(width, height, density, rgba(inner), rgba(outer))
		end

		def proxy_gen_image_gradient_square width, height, density, inner, outer
			wrap_image self.class.lib.GenImageGradientSquare(width, height, density, rgba(inner), rgba(outer))
		end

		def proxy_gen_image_checked width, height, checks_x, checks_y, color1, color2
			wrap_image self.class.lib.GenImageChecked(width, height, checks_x, checks_y, rgba(color1), rgba(color2))
		end

		def proxy_gen_image_white_noise width, height, factor
			wrap_image self.class.lib.GenImageWhiteNoise(width, height, factor)
		end

		def proxy_gen_image_perlin_noise width, height, offset_x, offset_y, scale
			wrap_image self.class.lib.GenImagePerlinNoise(width, height, offset_x, offset_y, scale)
		end

		def proxy_gen_image_cellular width, height, tile_size
			wrap_image self.class.lib.GenImageCellular(width, height, tile_size)
		end

		def proxy_gen_image_text width, height, text
			wrap_image self.class.lib.GenImageText(width, height, text)
		end

		def proxy_image_copy image
			wrap_image self.class.lib.ImageCopy(image.raylib_image)
		end

		def proxy_image_from_image image, rect
			wrap_image self.class.lib.ImageFromImage(image.raylib_image, rectangle(rect))
		end

		def proxy_image_from_channel image, channel
			wrap_image self.class.lib.ImageFromChannel(image.raylib_image, channel)
		end

		def proxy_image_text text, font_size, color
			wrap_image self.class.lib.ImageText(text, font_size, rgba(color))
		end

		# --- Images: read ---

		# @return [::Array] [r, g, b, a]
		def proxy_get_image_color image, x, y
			check_pixel_area image, x, y, 1, 1
			color = self.class.lib.GetImageColor image.raylib_image, x, y
			[color.r, color.g, color.b, color.a]
		end

		# @return [::Array] one [r, g, b, a] Code::Array for each pixel, row by row
		def proxy_load_image_colors image
			check_pixel_area image, 0, 0, 0, 0
			color_lists rgba_bytes(image.raylib_image)
		end

		# A copy of the pixels as RGBA bytes, in any format the image has. A later change to the image does not reach the Buffer.
		# @return [Code::Buffer]
		def proxy_get_image_buffer image
			check_pixel_area image, 0, 0, 0, 0
			Code::Buffer.new.proxy_from_string rgba_bytes(image.raylib_image)
		end

		# One call in place of many get_image_color calls. The whole square around (x, y), row by row, with the center at its middle; a pixel outside the image is nil, so each index keeps its meaning at the edge.
		# @return [::Array] (radius * 2 + 1) ** 2 values
		def proxy_get_image_neighbors image, x, y, radius = 1, channel = 0
			lib = self.class.lib
			check_pixel_area image, x, y, 1, 1
			raise Code::Invalid_Pixels, "`radius` must be 0 or more, but it is #{radius}." if radius < 0
			raise Code::Invalid_Pixels, "`channel` must be 0 (r), 1 (g), 2 (b) or 3 (a), but it is #{channel}." unless channel >= 0 && channel <= 3
		
			raw    = image.raylib_image
			width  = raw.width
			height = raw.height
			data   = raw.data
			rgba   = raw.format == lib::PIXELFORMAT_UNCOMPRESSED_R8G8B8A8
			list   = []
			(y - radius..y + radius).each do |row|
				inside_row = row >= 0 && row < height
				(x - radius..x + radius).each do |column|
					list << if !inside_row || column < 0 || column >= width
						nil
					elsif rgba
						data.get_uint8 (row * width + column) * BYTES_PER_PIXEL + channel
					else
						color = lib.GetImageColor raw, column, row
						[color.r, color.g, color.b, color.a][channel]
					end
				end
			end
			list
		end
		
		# @return [::Array] one [r, g, b, a] Code::Array for each color
		def proxy_load_image_palette image, max_size
			lib = self.class.lib
			check_pixel_area image, 0, 0, 0, 0
			count  = ::FFI::MemoryPointer.new :int
			colors = lib.LoadImagePalette image.raylib_image, max_size, count
			list   = color_lists colors.read_bytes(count.read_int * BYTES_PER_PIXEL)
			lib.UnloadImagePalette colors
			list
		end

		# @return [::Array] [x, y, width, height]
		def proxy_get_image_alpha_border image, threshold
			rect = self.class.lib.GetImageAlphaBorder image.raylib_image, threshold
			[rect.x, rect.y, rect.width, rect.height]
		end

		# --- Images: change in place ---

		# @param [::Symbol] format
		def proxy_image_format image, format
			self.class.lib.ImageFormat image_pointer(image), pixel_format_code(format)
		end

		def proxy_image_to_pot image, fill
			self.class.lib.ImageToPOT image_pointer(image), rgba(fill)
		end

		def proxy_image_crop image, rect
			self.class.lib.ImageCrop image_pointer(image), rectangle(rect)
		end

		def proxy_image_alpha_crop image, threshold
			self.class.lib.ImageAlphaCrop image_pointer(image), threshold
		end

		def proxy_image_alpha_clear image, color, threshold
			self.class.lib.ImageAlphaClear image_pointer(image), rgba(color), threshold
		end

		def proxy_image_alpha_mask image, alpha_mask
			self.class.lib.ImageAlphaMask image_pointer(image), alpha_mask.raylib_image
		end

		def proxy_image_alpha_premultiply image
			self.class.lib.ImageAlphaPremultiply image_pointer(image)
		end

		def proxy_image_blur_gaussian image, blur_size
			self.class.lib.ImageBlurGaussian image_pointer(image), blur_size
		end

		# @param kernel [Code::Array] a flat list of numbers; its length must be a square (9 for 3 by 3)
		def proxy_image_kernel_convolution image, kernel
			values = kernel.values
			side   = ::Integer.sqrt values.length
			raise Code::Invalid_Pixels, "A kernel must be square, so its length must be a square number. It has #{values.length} values." unless side * side == values.length && side > 0

			pointer = ::FFI::MemoryPointer.new :float, values.length
			pointer.write_array_of_float values
			self.class.lib.ImageKernelConvolution image_pointer(image), pointer, values.length
		end

		def proxy_image_resize image, width, height
			self.class.lib.ImageResize image_pointer(image), width, height
		end

		def proxy_image_resize_nn image, width, height
			self.class.lib.ImageResizeNN image_pointer(image), width, height
		end

		def proxy_image_resize_canvas image, width, height, offset_x, offset_y, fill
			self.class.lib.ImageResizeCanvas image_pointer(image), width, height, offset_x, offset_y, rgba(fill)
		end

		def proxy_image_mipmaps image
			self.class.lib.ImageMipmaps image_pointer(image)
		end

		def proxy_image_dither image, r_bpp, g_bpp, b_bpp, a_bpp
			self.class.lib.ImageDither image_pointer(image), r_bpp, g_bpp, b_bpp, a_bpp
		end

		def proxy_image_flip_vertical image
			self.class.lib.ImageFlipVertical image_pointer(image)
		end

		def proxy_image_flip_horizontal image
			self.class.lib.ImageFlipHorizontal image_pointer(image)
		end

		def proxy_image_rotate image, degrees
			self.class.lib.ImageRotate image_pointer(image), degrees
		end

		def proxy_image_rotate_cw image
			self.class.lib.ImageRotateCW image_pointer(image)
		end

		def proxy_image_rotate_ccw image
			self.class.lib.ImageRotateCCW image_pointer(image)
		end

		def proxy_image_color_tint image, color
			self.class.lib.ImageColorTint image_pointer(image), rgba(color)
		end

		def proxy_image_color_invert image
			self.class.lib.ImageColorInvert image_pointer(image)
		end

		def proxy_image_color_grayscale image
			self.class.lib.ImageColorGrayscale image_pointer(image)
		end

		def proxy_image_color_contrast image, contrast
			self.class.lib.ImageColorContrast image_pointer(image), contrast
		end

		def proxy_image_color_brightness image, brightness
			self.class.lib.ImageColorBrightness image_pointer(image), brightness
		end

		def proxy_image_color_replace image, color, replace
			self.class.lib.ImageColorReplace image_pointer(image), rgba(color), rgba(replace)
		end

		# --- Images: draw ---

		def proxy_image_clear_background image, color
			self.class.lib.ImageClearBackground image_pointer(image), rgba(color)
		end

		def proxy_image_draw_pixel image, x, y, color
			self.class.lib.ImageDrawPixel image_pointer(image), x, y, rgba(color)
		end

		def proxy_image_draw_line image, x1, y1, x2, y2, color
			self.class.lib.ImageDrawLine image_pointer(image), x1, y1, x2, y2, rgba(color)
		end

		def proxy_image_draw_line_ex image, start_point, end_point, thick, color
			self.class.lib.ImageDrawLineEx image_pointer(image), vector2(start_point), vector2(end_point), thick, rgba(color)
		end

		def proxy_image_draw_line_strip image, points, color
			self.class.lib.ImageDrawLineStrip image_pointer(image), vector2_list(points), points.values.length, rgba(color)
		end

		def proxy_image_draw_triangle image, v1, v2, v3, color
			self.class.lib.ImageDrawTriangle image_pointer(image), vector2(v1), vector2(v2), vector2(v3), rgba(color)
		end

		def proxy_image_draw_triangle_gradient image, v1, v2, v3, c1, c2, c3
			self.class.lib.ImageDrawTriangleGradient image_pointer(image), vector2(v1), vector2(v2), vector2(v3), rgba(c1), rgba(c2), rgba(c3)
		end

		def proxy_image_draw_triangle_lines image, v1, v2, v3, color
			self.class.lib.ImageDrawTriangleLines image_pointer(image), vector2(v1), vector2(v2), vector2(v3), rgba(color)
		end

		def proxy_image_draw_triangle_fan image, points, color
			self.class.lib.ImageDrawTriangleFan image_pointer(image), vector2_list(points), points.values.length, rgba(color)
		end

		def proxy_image_draw_triangle_strip image, points, color
			self.class.lib.ImageDrawTriangleStrip image_pointer(image), vector2_list(points), points.values.length, rgba(color)
		end

		def proxy_image_draw_rectangle image, x, y, width, height, color
			self.class.lib.ImageDrawRectangle image_pointer(image), x, y, width, height, rgba(color)
		end

		def proxy_image_draw_rectangle_lines image, x, y, width, height, color
			self.class.lib.ImageDrawRectangleLines image_pointer(image), x, y, width, height, rgba(color)
		end

		def proxy_image_draw_rectangle_lines_ex image, rect, thick, color
			self.class.lib.ImageDrawRectangleLinesEx image_pointer(image), rectangle(rect), thick, rgba(color)
		end

		def proxy_image_draw_circle image, x, y, radius, color
			self.class.lib.ImageDrawCircle image_pointer(image), x, y, radius, rgba(color)
		end

		def proxy_image_draw_circle_lines image, x, y, radius, color
			self.class.lib.ImageDrawCircleLines image_pointer(image), x, y, radius, rgba(color)
		end

		def proxy_image_draw_image image, source, x, y, tint
			self.class.lib.ImageDrawImage image_pointer(image), source.raylib_image, x, y, rgba(tint)
		end

		def proxy_image_draw_image_rec image, source, source_rect, position, tint
			self.class.lib.ImageDrawImageRec image_pointer(image), source.raylib_image, rectangle(source_rect), vector2(position), rgba(tint)
		end

		def proxy_image_draw_image_pro image, source, source_rect, dest_rect, origin, rotation, tint
			self.class.lib.ImageDrawImagePro image_pointer(image), source.raylib_image, rectangle(source_rect), rectangle(dest_rect), vector2(origin), rotation, rgba(tint)
		end

		def proxy_image_draw_text image, text, x, y, font_size, color
			self.class.lib.ImageDrawText image_pointer(image), text, x, y, font_size, rgba(color)
		end

		def proxy_unload_texture texture
			self.class.lib.UnloadTexture texture.raylib_texture
		end

		def proxy_unload_render_texture render_texture
			self.class.lib.UnloadRenderTexture render_texture
		end

		def proxy_unload_shader shader
			self.class.lib.UnloadShader shader
		end

		# --- Input: Keyboard ---

		# @param [::Symbol] key
		def proxy_is_key_down? key
			self.class.lib.IsKeyDown key_code(key)
		end

		# @param [::Symbol] key
		def proxy_is_key_pressed? key
			self.class.lib.IsKeyPressed key_code(key)
		end

		# @param [::Symbol] name
		# @return [::Integer]
		def proxy_key name
			key_code name
		end

		# --- Input: Mouse ---

		def proxy_get_mouse_position
			pixel_from_vector2 self.class.lib.GetMousePosition
		end

		def proxy_get_mouse_x
			self.class.lib.GetMouseX
		end

		def proxy_get_mouse_y
			self.class.lib.GetMouseY
		end

		def proxy_get_mouse_delta
			pixel_from_vector2 self.class.lib.GetMouseDelta
		end

		def proxy_get_mouse_wheel_move
			self.class.lib.GetMouseWheelMove
		end

		# @param [::Symbol] button
		def proxy_is_mouse_button_down? button
			self.class.lib.IsMouseButtonDown mouse_button_code(button)
		end

		# @param [::Symbol] button
		def proxy_is_mouse_button_pressed? button
			self.class.lib.IsMouseButtonPressed mouse_button_code(button)
		end

		# @param [::Symbol] button
		def proxy_is_mouse_button_released? button
			self.class.lib.IsMouseButtonReleased mouse_button_code(button)
		end

		# --- Input: Gamepad ---

		def proxy_is_gamepad_available? gamepad
			self.class.lib.IsGamepadAvailable gamepad
		end

		# GetGamepadName returns a raw C string pointer -- raylib owns that memory and reuses it, so
		# read it out to a real Ruby String immediately rather than holding onto the pointer.
		def proxy_get_gamepad_name gamepad
			pointer = self.class.lib.GetGamepadName gamepad
			pointer.null? ? nil : pointer.read_string
		end

		# @param [::Symbol] button
		def proxy_is_gamepad_button_down? gamepad, button
			self.class.lib.IsGamepadButtonDown gamepad, gamepad_button_code(button)
		end

		# @param [::Symbol] button
		def proxy_is_gamepad_button_pressed? gamepad, button
			self.class.lib.IsGamepadButtonPressed gamepad, gamepad_button_code(button)
		end

		# @param [::Symbol] button
		def proxy_is_gamepad_button_released? gamepad, button
			self.class.lib.IsGamepadButtonReleased gamepad, gamepad_button_code(button)
		end

		def proxy_get_gamepad_axis_count gamepad
			self.class.lib.GetGamepadAxisCount gamepad
		end

		# @param [::Symbol] axis
		def proxy_get_gamepad_axis_movement gamepad, axis
			self.class.lib.GetGamepadAxisMovement gamepad, gamepad_axis_code(axis)
		end

		def proxy_set_gamepad_vibration gamepad, left_motor, right_motor, duration
			self.class.lib.SetGamepadVibration gamepad, left_motor, right_motor, duration
		end

		# --- Audio ---
		#
		# Sound/Music values are opaque to Backend, the same "hand it back, pass it straight into the
		# next call" treatment as a Texture2D/Shader gets -- nothing here wraps them in a Code:: type.

		def proxy_init_audio_device
			self.class.lib.InitAudioDevice
		end

		def proxy_close_audio_device
			self.class.lib.CloseAudioDevice
		end

		def proxy_is_audio_device_ready?
			self.class.lib.IsAudioDeviceReady
		end

		def proxy_load_sound path
			self.class.lib.LoadSound path
		end

		def proxy_play_sound sound
			self.class.lib.PlaySound sound
		end

		def proxy_stop_sound sound
			self.class.lib.StopSound sound
		end

		def proxy_is_sound_playing? sound
			self.class.lib.IsSoundPlaying sound
		end

		def proxy_set_sound_volume sound, volume
			self.class.lib.SetSoundVolume sound, volume
		end

		def proxy_set_sound_pitch sound, pitch
			self.class.lib.SetSoundPitch sound, pitch
		end

		def proxy_unload_sound sound
			self.class.lib.UnloadSound sound
		end

		def proxy_load_music_stream path
			self.class.lib.LoadMusicStream path
		end

		def proxy_play_music_stream music
			self.class.lib.PlayMusicStream music
		end

		# Raylib streams music in buffered chunks off the main thread's own timing -- this has to run
		# once per frame while a stream is meant to be audible, or it silently starves and stops.
		def proxy_update_music_stream music
			self.class.lib.UpdateMusicStream music
		end

		def proxy_stop_music_stream music
			self.class.lib.StopMusicStream music
		end

		def proxy_pause_music_stream music
			self.class.lib.PauseMusicStream music
		end

		def proxy_resume_music_stream music
			self.class.lib.ResumeMusicStream music
		end

		def proxy_set_music_volume music, volume
			self.class.lib.SetMusicVolume music, volume
		end

		def proxy_is_music_stream_playing? music
			self.class.lib.IsMusicStreamPlaying music
		end

		def proxy_unload_music_stream music
			self.class.lib.UnloadMusicStream music
		end

		# --- Low-level (rlgl) ---

		def proxy_rl_set_texture texture
			self.class.lib.rlSetTexture texture.proxy_id
		end

		def proxy_rl_begin_quads
			self.class.lib.rlBegin self.class.lib::RL_QUADS
		end

		def proxy_rl_end
			self.class.lib.rlEnd
		end

		def proxy_rl_color color
			r, g, b, a = color.values
			self.class.lib.rlColor4ub r, g, b, a || 255
		end

		def proxy_rl_normal x, y, z
			self.class.lib.rlNormal3f x, y, z
		end

		def proxy_rl_tex_coord u, v
			self.class.lib.rlTexCoord2f u, v
		end

		def proxy_rl_vertex x, y
			self.class.lib.rlVertex2f x, y
		end

		private

		# @param [::Raylib::Texture] raylib_texture
		# @return [Code::Texture]
		def wrap_texture raylib_texture
			texture                = Code::Texture.new
			texture.raylib_texture = self.class.valid_texture raylib_texture, 'this call'
			texture
		end

		# @param [::Raylib::Image] raylib_image
		# @return [Code::Image]
		def wrap_image raylib_image
			image              = Code::Image.new
			image.raylib_image = raylib_image
			image
		end

		def image_pointer image
			image.raylib_image.to_ptr
		end

		# @param [::Symbol] name
		# @return [::Integer]
		def pixel_format_code name
			self.class.lib.const_get "PIXELFORMAT_#{name.to_s.upcase}"
		end

		# The pixels of a raylib image as RGBA bytes, whatever format the image has.
		# @param [::Raylib::Image] raylib_image
		# @return [::String]
		def rgba_bytes raylib_image
			lib    = self.class.lib
			colors = lib.LoadImageColors raylib_image
			bytes  = colors.read_bytes raylib_image.width * raylib_image.height * BYTES_PER_PIXEL
			lib.UnloadImageColors colors
			bytes
		end

		# @param [::String] bytes RGBA bytes
		# @return [::Array] one [r, g, b, a] Code::Array for each pixel
		def color_lists bytes
			interpreter = Code::Interpreter.current
			bytes.unpack('C*').each_slice(BYTES_PER_PIXEL).map { interpreter.wrap_prog_array it }
		end

		# A Code list of points -> a C array of raylib Vector2 values, which are two floats each.
		def vector2_list points
			coordinates = points.values.flat_map { it.values.first 2 }
			pointer     = ::FFI::MemoryPointer.new :float, coordinates.length
			pointer.write_array_of_float coordinates
			pointer
		end

		# raylib reads width * height pixels from the pointer with no check, and a wrong area writes nothing or reads black, so both are checked first.
		# @param target [Code::Texture | Code::Image]
		def check_pixel_area target, x, y, width, height
			format = target.proxy_format
			raise Code::Invalid_Pixels, "A compressed #{target.name} (format #{format}) has no pixels to read or write." if format >= self.class.lib::PIXELFORMAT_COMPRESSED_DXT1_RGB

			inside = x.is_a?(::Integer) && y.is_a?(::Integer) && width.is_a?(::Integer) && height.is_a?(::Integer) &&
			         x >= 0 && y >= 0 && width >= 0 && height >= 0 && x + width <= target.proxy_width && y + height <= target.proxy_height
			raise Code::Invalid_Pixels, "The area (x: #{x}, y: #{y}, width: #{width}, height: #{height}) is not inside the #{target.proxy_width} by #{target.proxy_height} #{target.name}." unless inside
		end

		# @param source [Code::Image] must be the size of the area
		def write_texture_image texture, rect, width, height, source
			lib = self.class.lib
			check_pixel_area source, 0, 0, width, height
			raise Code::Invalid_Pixels, "The area is #{width} by #{height}, but the Image is #{source.proxy_width} by #{source.proxy_height}." unless source.proxy_width == width && source.proxy_height == height

			raw_texture = texture.raylib_texture
			raw_image   = source.raylib_image
			return lib.UpdateTextureRec raw_texture, rect, raw_image.data if raw_image.format == raw_texture.format

			copy = lib.ImageCopy raw_image
			lib.ImageFormat copy.to_ptr, raw_texture.format
			lib.UpdateTextureRec raw_texture, rect, copy.data
			lib.UnloadImage copy
		end

		# @param pixels [Code::Array | ::Array | Code::Buffer | Code::Image] one color for each pixel, RGBA bytes, or an image
		def write_texture_pixels texture, x, y, width, height, pixels
			check_pixel_area texture, x, y, width, height
			return write_texture_image texture, self.class.lib::Rectangle.create(x, y, width, height), width, height, pixels if pixels.is_a? Code::Image

			bytes = if pixels.is_a? Code::Buffer
				pixels.io_buffer.get_string
			else
				list = pixels.is_a?(::Array) ? pixels : pixels.values
				list.flat_map do
					r, g, b, a = it.values
					[r, g, b, a || 255]
				end.pack 'C*'
			end
			expected = width * height * BYTES_PER_PIXEL
			raise Code::Invalid_Pixels, "The area needs #{expected} bytes (#{width * height} pixels), but it got #{bytes.bytesize} bytes." unless bytes.bytesize == expected

			lib  = self.class.lib
			rect = lib::Rectangle.create x, y, width, height
			raw  = texture.raylib_texture
			if raw.format == lib::PIXELFORMAT_UNCOMPRESSED_R8G8B8A8
				pointer = ::FFI::MemoryPointer.new :uint8, expected
				pointer.put_bytes 0, bytes
				lib.UpdateTextureRec raw, rect, pointer
			else
				# raylib wants the bytes in the texture's own format (a PNG with no alpha loads as R8G8B8), so an Image converts them. ImageFormat frees and replaces the Image's data, so the data must come from raylib.
				image = lib.GenImageColor width, height, lib::Color.from_u8(0, 0, 0, 0)
				image.data.put_bytes 0, bytes
				lib.ImageFormat image.to_ptr, raw.format
				lib.UpdateTextureRec raw, rect, image.data
				lib.UnloadImage image
			end
		end

		# @param [::Symbol] name
		def texture_filter_code name
			self.class.lib.const_get "TEXTURE_FILTER_#{name.to_s.upcase}"
		end

		# @param [::Symbol] name
		# @return [::Integer]
		def key_code name
			self.class.lib.const_get "KEY_#{name.to_s.upcase}"
		end

		# @param [::Symbol] name
		# @return [::Integer]
		def mouse_button_code name
			self.class.lib.const_get "MOUSE_BUTTON_#{name.to_s.upcase}"
		end

		# @param [::Symbol] name
		# @return [::Integer]
		def gamepad_button_code name
			self.class.lib.const_get "GAMEPAD_BUTTON_#{name.to_s.upcase}"
		end

		# @param [::Symbol] name
		# @return [::Integer]
		def gamepad_axis_code name
			self.class.lib.const_get "GAMEPAD_AXIS_#{name.to_s.upcase}"
		end

		def pixel_from_vector2 vector
			interpreter = Code::Interpreter.current
			template    = interpreter.global['Pixel'] # Pixel | Vector2 <>      (see lang/raylib.code.)
			pixel       = interpreter.build_struct template.names, template.type_names, template.type_objects, [vector.x, vector.y]
			interpreter.adopt_type pixel, 'Pixel'
			pixel.name = template.name
			pixel
		end

		# @param [Code::Array | Code::Struct] collection that responds to &:values
		# @return [::Integer]
		def rgba collection
			r, g, b, a = collection.values
			self.class.lib::Color.from_u8(r, g, b, a || 255)
		end

		# A Code [x, y, width, height] Array -> a real raylib Rectangle.
		def rectangle collection
			x, y, width, height = collection.values
			self.class.lib::Rectangle.create(x, y, width, height)
		end

		# A Code [x, y] Array (or anything else that responds to &:values with two elements, a
		# `Vector2`/`Pixel` struct included) -> a real raylib Vector2.
		def vector2 collection
			x, y = collection.values
			self.class.lib::Vector2.create(x, y)
		end

		# A Code `Camera_2d` struct -> a real raylib Camera2D. `with_target`/`with_offset` take raw
		# x/y floats, not a Vector2, so this reads straight off `target`/`offset`'s own `.values`
		# rather than going through #vector2's raylib-Vector2 return.
		def camera2d struct
			target_x, target_y = struct['target'].values
			offset_x, offset_y = struct['offset'].values
			self.class.lib::Camera2D.new
				.with_target(target_x, target_y)
				.with_offset(offset_x, offset_y)
				.with_rotation(struct['rotation'])
				.with_zoom(struct['zoom'])
		end
	end
end
