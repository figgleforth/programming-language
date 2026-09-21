# Implemented by Claude
#
module Code
	class Raylib < Instance
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
		# Texture2D / RenderTexture2D / Shader / Image values are opaque to Code -- these methods
		# hand back the raw FFI struct raylib itself returns and take it straight back in on the next
		# call, the same way a file handle or socket would flow through untouched. Nothing here wraps
		# them in a Code:: type; nothing needs to.

		def proxy_load_texture path
			self.class.lib.LoadTexture path
		end

		def proxy_get_texture_width texture
			texture.width
		end

		def proxy_get_texture_height texture
			texture.height
		end

		# @param [::Symbol] filter
		def proxy_set_texture_filter texture, filter
			self.class.lib.SetTextureFilter texture, texture_filter_code(filter)
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
			texture
		end

		# Same idea, but a checkerboard instead of one flat color -- has actual internal detail, so a
		# UV-shift distortion shader visibly displaces it instead of sampling the same color either way.
		def proxy_gen_checked_texture width, height, checks_x, checks_y, color1, color2
			image   = self.class.lib.GenImageChecked width, height, checks_x, checks_y, rgba(color1), rgba(color2)
			texture = self.class.lib.LoadTextureFromImage image
			self.class.lib.UnloadImage image
			texture
		end

		def proxy_load_render_texture width, height
			self.class.lib.LoadRenderTexture width, height
		end

		# The drawable Texture2D backing a render target -- e.g. feeding one pass's output into the
		# next pass as an ordinary texture.
		def proxy_render_texture_texture render_texture
			render_texture.texture
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
			self.class.lib.SetShaderValueTexture shader, location, texture
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
			self.class.lib.DrawTexture texture, x, y, rgba(color)
		end

		# `source`/`dest` are [x, y, width, height] Arrays, `origin` an [x, y] Array -- same "plain
		# Code Array in, real raylib struct out" boundary conversion as colors get.
		def proxy_draw_texture_pro texture, source, dest, origin, rotation, color
			self.class.lib.DrawTexturePro texture, rectangle(source), rectangle(dest), vector2(origin), rotation, rgba(color)
		end

		def proxy_unload_texture texture
			self.class.lib.UnloadTexture texture
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
			self.class.lib.rlSetTexture texture.id
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
