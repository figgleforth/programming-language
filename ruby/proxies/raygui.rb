# Implemented by Claude
#
module Code
	# Thin bindings over the raygui functions of the `raylib-bindings` gem. raygui writes a control's new value through a C pointer, and a program has no pointers, so each proxy takes the current value and gives back the new one.
	class Raygui < Instance
		STATES          = %i(normal focused pressed disabled)
		VALUE_TEXT_SIZE = 64 # raygui's value boxes write up to RAYGUI_VALUEBOX_MAX_CHARS (32) characters

		def lib
			Code::Raylib.lib
		end

		# --- Global state ---

		def proxy_enable
			lib.GuiEnable
		end

		def proxy_disable
			lib.GuiDisable
		end

		def proxy_lock
			lib.GuiLock
		end

		def proxy_unlock
			lib.GuiUnlock
		end

		def proxy_is_locked?
			lib.GuiIsLocked
		end

		def proxy_set_alpha alpha
			lib.GuiSetAlpha alpha
		end

		# @param [::Symbol] state
		def proxy_set_state state
			lib.GuiSetState lib.const_get("STATE_#{state.to_s.upcase}")
		end

		# @return [::Symbol]
		def proxy_get_state
			STATES[lib.GuiGetState]
		end

		# --- Style ---

		# @param [::Symbol] name any raygui constant
		# @return [::Integer]
		def proxy_constant name
			lib.const_get name.to_s.upcase
		end

		# @param [::Symbol] control
		# @param [::Symbol] property
		# @param value [::Integer | Code::Array | Code::Struct] a number, or a color
		def proxy_set_style control, property, value
			number = value.respond_to?(:values) ? rgba_integer(value) : value
			lib.GuiSetStyle proxy_constant(control), proxy_constant(property), number
		end

		# @return [::Integer]
		def proxy_get_style control, property
			lib.GuiGetStyle proxy_constant(control), proxy_constant(property)
		end

		# @return [::Array] [r, g, b, a]
		def proxy_get_style_color control, property
			[proxy_get_style(control, property)].pack('N').unpack 'C4'
		end

		def proxy_load_style path
			lib.GuiLoadStyle path
		end

		def proxy_load_style_default
			lib.GuiLoadStyleDefault
		end

		def proxy_enable_tooltip
			lib.GuiEnableTooltip
		end

		def proxy_disable_tooltip
			lib.GuiDisableTooltip
		end

		def proxy_set_tooltip text
			lib.GuiSetTooltip text
		end

		# --- Icons and text ---

		# raygui writes the result into its own memory and reuses it, so it is read out at once.
		# @param [::Symbol] icon
		# @return [::String]
		def proxy_icon_text icon, text
			text_from lib.GuiIconText(icon_code(icon), text)
		end

		def proxy_set_icon_scale scale
			lib.GuiSetIconScale scale
		end

		# @param [::Symbol] icon
		def proxy_draw_icon icon, x, y, pixel_size, color
			lib.GuiDrawIcon icon_code(icon), x, y, pixel_size, rgba(color)
		end

		def proxy_load_icons path
			lib.GuiLoadIcons path, false
			nil
		end

		def proxy_get_text_width text
			lib.GuiGetTextWidth text
		end

		# --- Containers ---

		# @return [true | false] true when the close button is clicked
		def proxy_window_box rect, title
			lib.GuiWindowBox(rectangle(rect), title) == 1
		end

		def proxy_group_box rect, text
			lib.GuiGroupBox rectangle(rect), text
			nil
		end

		def proxy_line rect, text
			lib.GuiLine rectangle(rect), text
			nil
		end

		def proxy_panel rect, text
			lib.GuiPanel rectangle(rect), text
			nil
		end

		# @return [Code::Struct] <scroll: [x, y], view: [x, y, width, height]>
		def proxy_scroll_panel rect, text, content, scroll
			scroll_pointer = float_pointer scroll.values
			view_pointer   = float_pointer [0, 0, 0, 0]
			lib.GuiScrollPanel rectangle(rect), text, rectangle(content), scroll_pointer, view_pointer
			result scroll: scroll_pointer.read_array_of_float(2), view: view_pointer.read_array_of_float(4)
		end

		def proxy_status_bar rect, text
			lib.GuiStatusBar rectangle(rect), text
			nil
		end

		def proxy_dummy_rec rect, text
			lib.GuiDummyRec rectangle(rect), text
			nil
		end

		# @return [::Array] [column, row] under the mouse, or [-1, -1]
		def proxy_grid rect, text, spacing, subdivisions
			cell = float_pointer [-1, -1]
			lib.GuiGrid rectangle(rect), text, spacing, subdivisions, cell
			cell.read_array_of_float(2).map(&:to_i)
		end

		# --- Basic controls ---

		def proxy_label rect, text
			lib.GuiLabel rectangle(rect), text
			nil
		end

		# @return [true | false] true when it is clicked
		def proxy_button rect, text
			lib.GuiButton(rectangle(rect), text) == 1
		end

		# @return [true | false] true when it is clicked
		def proxy_label_button rect, text
			lib.GuiLabelButton(rectangle(rect), text) == 1
		end

		# @return [true | false] the new value
		def proxy_toggle rect, text, active
			pointer = bool_pointer active
			lib.GuiToggle rectangle(rect), text, pointer
			pointer.get :bool, 0
		end

		# @return [::Integer] the new value
		def proxy_toggle_group rect, text, active
			pointer = int_pointer active
			lib.GuiToggleGroup rectangle(rect), text, pointer
			pointer.read_int
		end

		# @return [::Integer] the new value
		def proxy_toggle_slider rect, text, active
			pointer = int_pointer active
			lib.GuiToggleSlider rectangle(rect), text, pointer
			pointer.read_int
		end

		# @return [true | false] the new value
		def proxy_check_box rect, text, checked
			pointer = bool_pointer checked
			lib.GuiCheckBox rectangle(rect), text, pointer
			pointer.get :bool, 0
		end

		# @return [::Integer] the new value
		def proxy_combo_box rect, text, active
			pointer = int_pointer active
			lib.GuiComboBox rectangle(rect), text, pointer
			pointer.read_int
		end

		# @return [Code::Struct] <active, pressed>
		def proxy_dropdown_box rect, text, active, edit_mode
			pointer = int_pointer active
			pressed = lib.GuiDropdownBox rectangle(rect), text, pointer, truthy(edit_mode)
			result active: pointer.read_int, pressed: pressed == 1
		end

		# @return [Code::Struct] <value, pressed>
		def proxy_spinner rect, text, value, min, max, edit_mode
			pointer = int_pointer value
			pressed = lib.GuiSpinner rectangle(rect), text, pointer, min, max, truthy(edit_mode)
			result value: pointer.read_int, pressed: pressed == 1
		end

		# @return [Code::Struct] <value, pressed>
		def proxy_value_box rect, text, value, min, max, edit_mode
			pointer = int_pointer value
			pressed = lib.GuiValueBox rectangle(rect), text, pointer, min, max, truthy(edit_mode)
			result value: pointer.read_int, pressed: pressed == 1
		end

		# raygui keeps the digits typed so far in text_value, so a program passes back what it got.
		# @return [Code::Struct] <text_value, value, pressed>
		def proxy_value_box_float rect, text, text_value, value, edit_mode
			text_pointer  = text_buffer text_value, VALUE_TEXT_SIZE
			value_pointer = float_pointer [value]
			pressed       = lib.GuiValueBoxFloat rectangle(rect), text, text_pointer, value_pointer, truthy(edit_mode)
			result text_value: text_from(text_pointer), value: value_pointer.read_float, pressed: pressed == 1
		end

		# @param size [::Integer] the largest text in bytes, with one more for the C string's end
		# @return [Code::Struct] <text, pressed>
		def proxy_text_box rect, text, size, edit_mode
			pointer = text_buffer text, size
			pressed = lib.GuiTextBox rectangle(rect), pointer, size, truthy(edit_mode)
			result text: text_from(pointer), pressed: pressed == 1
		end

		# @return [::Float] the new value
		def proxy_slider rect, left_text, right_text, value, min, max
			pointer = float_pointer [value]
			lib.GuiSlider rectangle(rect), left_text, right_text, pointer, min, max
			pointer.read_float
		end

		# @return [::Float] the new value
		def proxy_slider_bar rect, left_text, right_text, value, min, max
			pointer = float_pointer [value]
			lib.GuiSliderBar rectangle(rect), left_text, right_text, pointer, min, max
			pointer.read_float
		end

		# @return [::Float] the new value
		def proxy_progress_bar rect, left_text, right_text, value, min, max
			pointer = float_pointer [value]
			lib.GuiProgressBar rectangle(rect), left_text, right_text, pointer, min, max
			pointer.read_float
		end

		# --- Lists and tabs ---

		# @return [Code::Struct] <scroll_index, active>
		def proxy_list_view rect, text, scroll_index, active
			scroll_pointer = int_pointer scroll_index
			active_pointer = int_pointer active
			lib.GuiListView rectangle(rect), text, scroll_pointer, active_pointer
			result scroll_index: scroll_pointer.read_int, active: active_pointer.read_int
		end

		# @param items [Code::Array] of Strings
		# @return [Code::Struct] <scroll_index, active, focus>
		def proxy_list_view_ex rect, items, scroll_index, active, focus
			scroll_pointer = int_pointer scroll_index
			active_pointer = int_pointer active
			focus_pointer  = int_pointer focus
			strings, list  = string_list items
			lib.GuiListViewEx rectangle(rect), list, strings.length, scroll_pointer, active_pointer, focus_pointer
			result scroll_index: scroll_pointer.read_int, active: active_pointer.read_int, focus: focus_pointer.read_int
		end

		# @return [Code::Struct] <scroll, active, result>
		def proxy_tab_bar rect, text, scroll, active
			scroll_pointer = int_pointer scroll
			active_pointer = int_pointer active
			outcome        = lib.GuiTabBar rectangle(rect), text, scroll_pointer, active_pointer
			result scroll: scroll_pointer.read_int, active: active_pointer.read_int, result: outcome
		end

		# @param items [Code::Array] of Strings
		# @return [Code::Struct] <scroll, active, focus, result>
		def proxy_tab_bar_ex rect, items, scroll, active, focus
			scroll_pointer = int_pointer scroll
			active_pointer = int_pointer active
			focus_pointer  = int_pointer focus
			strings, list  = string_list items
			outcome        = lib.GuiTabBarEx rectangle(rect), list, strings.length, scroll_pointer, active_pointer, focus_pointer
			result scroll: scroll_pointer.read_int, active: active_pointer.read_int, focus: focus_pointer.read_int, result: outcome
		end

		# --- Dialogs ---

		# @return [Code::Struct] <active, result>
		def proxy_message_box rect, title, message, buttons, active
			pointer = int_pointer active
			outcome = lib.GuiMessageBox rectangle(rect), title, message, buttons, pointer
			result active: pointer.read_int, result: outcome
		end

		# A nil `secret` leaves out the button that shows the hidden text.
		# @return [Code::Struct] <text, active, secret, result>
		def proxy_text_input_box rect, title, message, text, size, buttons, active, secret
			text_pointer   = text_buffer text, size
			active_pointer = int_pointer active
			secret_pointer = bool_pointer secret unless secret.nil?
			outcome        = lib.GuiTextInputBox rectangle(rect), title, message, text_pointer, size, buttons, active_pointer, secret_pointer
			result text: text_from(text_pointer), active: active_pointer.read_int, secret: secret_pointer&.get(:bool, 0), result: outcome
		end

		# --- Color controls ---

		# @return [::Array] [r, g, b, a]
		def proxy_color_picker rect, text, color
			pointer = color_pointer color
			lib.GuiColorPicker rectangle(rect), text, pointer
			pointer.read_array_of_uint8 4
		end

		# @return [::Array] [r, g, b, a]
		def proxy_color_panel rect, text, color
			pointer = color_pointer color
			lib.GuiColorPanel rectangle(rect), text, pointer
			pointer.read_array_of_uint8 4
		end

		# @return [::Float] the new value
		def proxy_color_bar_alpha rect, text, alpha
			pointer = float_pointer [alpha]
			lib.GuiColorBarAlpha rectangle(rect), text, pointer
			pointer.read_float
		end

		# @return [::Float] the new value
		def proxy_color_bar_hue rect, text, value
			pointer = float_pointer [value]
			lib.GuiColorBarHue rectangle(rect), text, pointer
			pointer.read_float
		end

		# @return [::Array] [hue, saturation, value]
		def proxy_color_picker_hsv rect, text, color
			pointer = float_pointer color.values
			lib.GuiColorPickerHSV rectangle(rect), text, pointer
			pointer.read_array_of_float 3
		end

		# @return [::Array] [hue, saturation, value]
		def proxy_color_panel_hsv rect, text, color
			pointer = float_pointer color.values
			lib.GuiColorPanelHSV rectangle(rect), text, pointer
			pointer.read_array_of_float 3
		end

		private

		# @param values [::Hash] member name => value
		# @return [Code::Struct] with one named member for each
		def result ** values
			names = values.keys.map(&:to_s)
			Code::Interpreter.current.build_struct names, names.map { nil }, names.map { nil }, values.values.map { it.is_a?(::Array) ? Code::Interpreter.current.wrap_prog_array(it) : it }
		end

		# A value from `.code` can be nil as well as a Bool, and FFI takes only true or false.
		def truthy value
			Code::Interpreter.current.truthy? value
		end

		def icon_code name
			lib.const_get "ICON_#{name.to_s.upcase}"
		end

		def int_pointer value
			pointer = ::FFI::MemoryPointer.new :int
			pointer.write_int value
			pointer
		end

		def bool_pointer value
			pointer = ::FFI::MemoryPointer.new :bool
			pointer.put :bool, 0, truthy(value)
			pointer
		end

		def float_pointer values
			pointer = ::FFI::MemoryPointer.new :float, values.length
			pointer.write_array_of_float values
			pointer
		end

		def color_pointer color
			r, g, b, a = color.values
			pointer    = ::FFI::MemoryPointer.new :uint8, 4
			pointer.write_array_of_uint8 [r, g, b, a || 255]
			pointer
		end

		# A buffer that raygui can write into. A text that does not fit would be cut with no sign, so it raises.
		def text_buffer text, size
			bytes = text.to_s.b
			raise Code::Raygui_Text_Too_Long, "The text has #{bytes.bytesize} bytes, but size #{size} holds #{size - 1} bytes and the end of the C string." unless bytes.bytesize < size

			pointer = ::FFI::MemoryPointer.new :char, size
			pointer.put_bytes 0, bytes
			pointer
		end

		def text_from pointer
			pointer.read_string.force_encoding('UTF-8').scrub
		end

		# The strings must stay alive for the call, so they are given back beside the C array that points at them.
		def string_list items
			strings = items.values.map { ::FFI::MemoryPointer.from_string it.to_s }
			list    = ::FFI::MemoryPointer.new :pointer, strings.length
			list.write_array_of_pointer strings
			[strings, list]
		end

		# raygui stores a color as one signed 32-bit number, 0xRRGGBBAA.
		def rgba_integer color
			r, g, b, a = color.values
			[r, g, b, a || 255].pack('C4').unpack1 'l>'
		end

		# @pasted from Code::Raylib#rgba
		def rgba collection
			r, g, b, a = collection.values
			lib::Color.from_u8 r, g, b, a || 255
		end

		# @pasted from Code::Raylib#rectangle
		def rectangle collection
			x, y, width, height = collection.values
			lib::Rectangle.create x, y, width, height
		end
	end
end
