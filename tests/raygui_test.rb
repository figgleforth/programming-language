require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

# A fake raylib stands in for the real library, because raygui needs a window. Each fake control writes through its C pointer the way raygui does, so these tests check that a new value reaches the program.
class Raygui_Test < Base_Test
	module Fake_Raylib
		STATE_DISABLED    = 3
		BUTTON            = 2
		BASE_COLOR_NORMAL = 1
		BORDER_WIDTH      = 12
		ICON_PLAYER_PLAY  = 131

		module Color
			def self.from_u8(*values) = values
		end

		module Rectangle
			def self.create(*values) = values
		end

		class << self
			attr_accessor :calls, :style

			def GuiSetState(state) = calls << [:GuiSetState, state]
			def GuiGetState = 3
			def GuiSetStyle(control, property, value) = self.style = [control, property, value]
			def GuiGetStyle(_control, _property) = style.last
			def GuiIconText(icon, text) = ::FFI::MemoryPointer.from_string("##{icon}##{text}")
			def GuiWindowBox(_rect, _title) = 1
			def GuiPanel(_rect, _text) = 0

			def GuiButton(_rect, text) = text == 'clicked' ? 1 : 0
			def GuiLabelButton(_rect, _text) = 0
			def GuiCheckBox(_rect, _text, pointer) = pointer.put(:bool, 0, !pointer.get(:bool, 0)) && 0
			def GuiToggle(_rect, _text, pointer) = pointer.put(:bool, 0, !pointer.get(:bool, 0)) && 0
			def GuiToggleGroup(_rect, _text, pointer) = pointer.write_int(pointer.read_int + 1) && 0
			def GuiToggleSlider(_rect, _text, pointer) = pointer.write_int(pointer.read_int + 1) && 0
			def GuiComboBox(_rect, _text, pointer) = pointer.write_int(pointer.read_int + 1) && 0

			def GuiSlider(_rect, _left, _right, pointer, _min, max) = pointer.write_float(max.to_f) && 0
			def GuiSliderBar(_rect, _left, _right, pointer, _min, max) = pointer.write_float(max.to_f) && 0
			def GuiProgressBar(_rect, _left, _right, pointer, _min, _max) = pointer.read_float && 0

			def GuiDropdownBox(_rect, _text, pointer, edit_mode)
				calls << [:edit_mode, edit_mode]
				pointer.write_int pointer.read_int + 1
				1
			end

			def GuiSpinner(_rect, _text, pointer, _min, max, _edit_mode)
				pointer.write_int max
				0
			end

			def GuiValueBox(_rect, _text, pointer, min, _max, _edit_mode)
				pointer.write_int min
				1
			end

			def GuiValueBoxFloat(_rect, _text, text_pointer, value_pointer, _edit_mode)
				text_pointer.put_string 0, '2.5'
				value_pointer.write_float 2.5
				1
			end

			def GuiTextBox(_rect, pointer, size, _edit_mode)
				calls << [:size, size]
				pointer.put_string 0, "#{pointer.read_string}!"
				1
			end

			def GuiListView(_rect, _text, scroll, active)
				scroll.write_int 5
				active.write_int 6
				0
			end

			def GuiListViewEx(_rect, list, count, scroll, active, focus)
				calls << [:items, list.read_array_of_pointer(count).map(&:read_string)]
				scroll.write_int 1
				active.write_int 2
				focus.write_int 3
				0
			end

			def GuiTabBar(_rect, _text, scroll, active)
				scroll.write_int 1
				active.write_int 2
				-1
			end

			def GuiTabBarEx(_rect, list, count, scroll, active, focus)
				calls << [:items, list.read_array_of_pointer(count).map(&:read_string)]
				scroll.write_int 1
				active.write_int 2
				focus.write_int 3
				0
			end

			def GuiMessageBox(_rect, _title, _message, _buttons, active)
				active.write_int 1
				2
			end

			def GuiTextInputBox(_rect, _title, _message, text, _size, _buttons, active, secret)
				calls << [:secret, secret]
				text.put_string 0, 'typed'
				active.write_int 1
				secret&.put :bool, 0, true
				1
			end

			def GuiScrollPanel(_rect, _text, _content, scroll, view)
				scroll.write_array_of_float [1.0, 2.0]
				view.write_array_of_float [3.0, 4.0, 5.0, 6.0]
				0
			end

			def GuiGrid(_rect, _text, _spacing, _subdivisions, cell)
				cell.write_array_of_float [7.0, 8.0]
				0
			end

			def GuiColorPicker(_rect, _text, pointer)
				pointer.write_array_of_uint8 [1, 2, 3, 4]
				0
			end

			def GuiColorPanel(_rect, _text, pointer)
				pointer.write_array_of_uint8 [5, 6, 7, 8]
				0
			end

			def GuiColorBarAlpha(_rect, _text, pointer) = pointer.write_float(0.5) && 0
			def GuiColorBarHue(_rect, _text, pointer) = pointer.write_float(90.0) && 0

			def GuiColorPickerHSV(_rect, _text, pointer)
				pointer.write_array_of_float [10.0, 0.5, 0.25]
				0
			end

			def GuiColorPanelHSV(_rect, _text, pointer)
				pointer.write_array_of_float [20.0, 0.5, 0.25]
				0
			end
		end
	end

	RECT = '[0, 0, 10, 10]'

	def setup
		super
		begin
			require 'ffi' # the raylib gem loads it for a real program
		rescue LoadError
			skip 'needs the ffi gem'
		end
		@real_lib         = Code::Raylib.instance_variable_get :@lib
		Fake_Raylib.calls = []
		Fake_Raylib.style = nil
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

	def gui source
		Code.interp "@load 'lang/raygui'\n\n#{source}"
	end

	def test_a_click_gives_a_bool_so_that_an_unclicked_button_is_falsy
		assert_equal true, gui("Raygui.button(#{RECT}, 'clicked')")
		assert_equal false, gui("Raygui.button(#{RECT}, 'other')")
		assert_equal 'no', gui("if Raygui.button(#{RECT}, 'other')\n\t'yes'\nelse\n\t'no'\nend")
		assert_equal true, gui("Raygui.window_box(#{RECT}, 'title')")
	end

	def test_a_control_with_one_value_gives_back_the_new_value
		assert_equal false, gui("Raygui.check_box(#{RECT}, 'a', true)")
		assert_equal true, gui("Raygui.toggle(#{RECT}, 'a', false)")
		assert_equal 3, gui("Raygui.toggle_group(#{RECT}, 'a;b', 2)")
		assert_equal 3, gui("Raygui.toggle_slider(#{RECT}, 'a;b', 2)")
		assert_equal 3, gui("Raygui.combo_box(#{RECT}, 'a;b', 2)")
		assert_equal 9.0, gui("Raygui.slider(#{RECT}, 'l', 'r', 1, 0, 9)")
		assert_equal 9.0, gui("Raygui.slider_bar(#{RECT}, 'l', 'r', 1.5, 0, 9)")
		assert_equal 1.5, gui("Raygui.progress_bar(#{RECT}, 'l', 'r', 1.5, 0, 9)")
		assert_equal 0.5, gui("Raygui.color_bar_alpha(#{RECT}, 'a', 1)")
		assert_equal 90.0, gui("Raygui.color_bar_hue(#{RECT}, 'a', 0)")
	end

	def test_a_new_value_can_be_stored_back_in_its_variable
		out = gui <<~CODE
			speed := 0.5
			speed = Raygui.slider(#{RECT}, '', '', speed, 0, 1)
			on := false
			on = Raygui.check_box(#{RECT}, 'on', on)
			[speed, on]
		CODE
		assert_equal [1.0, true], out.values
	end

	def test_a_control_with_two_results_gives_a_struct_that_destructures
		out = gui <<~CODE
			box := Raygui.dropdown_box(#{RECT}, 'a;b', 1, false)
			(active, pressed) := Raygui.dropdown_box(#{RECT}, 'a;b', 1, true)
			[box.active, box.pressed, active, pressed]
		CODE
		assert_equal [2, true, 2, true], out.values
		assert_equal [[:edit_mode, false], [:edit_mode, true]], Fake_Raylib.calls
	end

	def test_number_boxes_give_a_value_and_pressed
		assert_equal [10, false], gui("r := Raygui.spinner(#{RECT}, 'a', 1, 0, 10, false)\n[r.value, r.pressed]").values
		assert_equal [0, true], gui("r := Raygui.value_box(#{RECT}, 'a', 1, 0, 10, false)\n[r.value, r.pressed]").values
		assert_equal ['2.5', 2.5, true], gui("r := Raygui.value_box_float(#{RECT}, 'a', '1', 1.0, true)\n[r.text_value, r.value, r.pressed]").values
	end

	def test_a_text_box_keeps_the_typed_text_and_a_nil_edit_mode_is_false
		assert_equal ['Ada!', true], gui("r := Raygui.text_box(#{RECT}, 'Ada', 32, nil)\n[r.text, r.pressed]").values
		assert_includes Fake_Raylib.calls, [:size, 32]
	end

	def test_a_text_that_does_not_fit_raises
		assert_raises(Code::Raygui_Text_Too_Long) { gui "Raygui.text_box(#{RECT}, 'abcd', 4, false)" }
		assert_equal 'abc!', gui("Raygui.text_box(#{RECT}, 'abc', 5, false).text")
	end

	def test_lists_and_tabs_give_each_value
		assert_equal [5, 6], gui("r := Raygui.list_view(#{RECT}, 'a;b', 0, -1)\n[r.scroll_index, r.active]").values
		assert_equal [1, 2, 3], gui("r := Raygui.list_view_ex(#{RECT}, ['x', 'y'], 0, -1, -1)\n[r.scroll_index, r.active, r.focus]").values
		assert_includes Fake_Raylib.calls, [:items, %w(x y)]
		assert_equal [1, 2, -1], gui("r := Raygui.tab_bar(#{RECT}, 'a;b', 0, 0)\n[r.scroll, r.active, r.result]").values
		assert_equal [1, 2, 3, 0], gui("r := Raygui.tab_bar_ex(#{RECT}, ['x'], 0, 0, 0)\n[r.scroll, r.active, r.focus, r.result]").values
	end

	def test_dialogs_give_each_value
		assert_equal [1, 2], gui("r := Raygui.message_box(#{RECT}, 't', 'm', 'yes;no', 0)\n[r.active, r.result]").values
		assert_equal ['typed', 1, true, 1], gui("r := Raygui.text_input_box(#{RECT}, 't', 'm', '', 16, 'ok', 0, false)\n[r.text, r.active, r.secret, r.result]").values
		assert_equal ['typed', 1, nil, 1], gui("r := Raygui.text_input_box(#{RECT}, 't', 'm', '', 16, 'ok', 0, nil)\n[r.text, r.active, r.secret, r.result]").values
		assert_nil Fake_Raylib.calls.last.last
	end

	def test_scroll_panel_and_grid_give_lists
		out = gui("r := Raygui.scroll_panel(#{RECT}, 't', #{RECT}, [0, 0])\n[r.scroll, r.view]")
		assert_equal [[1.0, 2.0], [3.0, 4.0, 5.0, 6.0]], out.values.map(&:values)
		assert_equal [7, 8], gui("Raygui.grid(#{RECT}, 't', 10, 2)").values
	end

	def test_color_controls_give_lists
		assert_equal [1, 2, 3, 4], gui("Raygui.color_picker(#{RECT}, 'a', [0, 0, 0])").values
		assert_equal [5, 6, 7, 8], gui("Raygui.color_panel(#{RECT}, 'a', [0, 0, 0, 0])").values
		assert_equal [10.0, 0.5, 0.25], gui("Raygui.color_picker_hsv(#{RECT}, 'a', [0, 0, 0])").values
		assert_equal [20.0, 0.5, 0.25], gui("Raygui.color_panel_hsv(#{RECT}, 'a', [0, 0, 0])").values
	end

	def test_set_style_takes_a_number_or_a_color_and_reads_back_both_ways
		gui "Raygui.set_style(:button, :border_width, 4)"
		assert_equal [2, 12, 4], Fake_Raylib.style

		# 0xFF is the sign bit of the 32-bit number that raygui stores.
		out = gui <<~CODE
			Raygui.set_style(:button, :base_color_normal, [255, 16, 32])
			[Raygui.get_style(:button, :base_color_normal), Raygui.get_style_color(:button, :base_color_normal)]
		CODE
		assert_equal [255, 16, 32, 255].pack('C4').unpack1('l>'), out.values.first
		assert_equal [255, 16, 32, 255], out.values.last.values
	end

	def test_state_and_icons_go_by_name
		assert_equal :disabled, gui('Raygui.get_state()')
		gui 'Raygui.set_state(:disabled)'
		assert_includes Fake_Raylib.calls, [:GuiSetState, 3]
		assert_equal '#131#go', gui("Raygui.icon_text(:player_play, 'go')")
		assert_equal 131, gui('Raygui.constant(:icon_player_play)')
	end

	def test_a_control_with_only_a_look_gives_nil
		assert_nil gui("Raygui.panel(#{RECT}, 'a')")
	end

	def test_a_control_checks_its_arguments
		assert_raises(Code::Type_Contract_Violation) { gui "Raygui.slider(#{RECT}, 'l', 'r', 'high', 0, 1)" }
	end

	def test_rect_point_and_color_work_where_a_list_works
		out = gui <<~CODE
			@load 'lang/shapes'

			box := Rect(1, 2, 30, 40)
			Raygui.panel(box, 'a')
			scrolled := Raygui.scroll_panel(box, 't', box, Point(0, 0))
			[Raygui.button(box, 'clicked'), Raygui.color_picker(box, 'a', Color(9, 9, 9)), scrolled.view]
		CODE
		assert_equal true, out.values[0]
		assert_equal [1, 2, 3, 4], out.values[1].values
		assert_equal [3.0, 4.0, 5.0, 6.0], out.values[2].values
	end

	def test_raygui_works_through_a_named_load
		assert_equal 9.0, Code.interp("Lib := @load 'lang/raygui'\n\nLib.Raygui.slider(#{RECT}, 'l', 'r', 1, 0, 9)")
	end

	# Each declaration in lang/raygui.code needs its Ruby method, and each Gui call in the Ruby file must name a real raygui function.
	def test_each_declaration_has_a_proxy_and_each_call_a_real_function
		names = File.read(File.join(Code::ROOT_PATH, 'lang/raygui.code')).scan(/^\s*Self\.(\S+) \(.*@ruby/).flatten
		assert_operator names.length, :>, 50
		names.each { assert Code::Raygui.method_defined?("proxy_#{it}"), "no proxy_#{it}" }

		Code::Raylib.remove_instance_variable :@lib
		begin
			real = Code::Raylib.lib
		rescue LoadError, StandardError => error
			skip "needs raylib-bindings: #{error.message}"
		end
		calls = File.read(File.join(Code::ROOT_PATH, 'ruby/proxies/raygui.rb')).scan(/\blib\.(Gui[A-Za-z0-9]*)/).flatten.uniq
		assert_operator calls.length, :>, 50
		calls.each { assert_respond_to real, it }
		@real_lib ||= real
	end
end
