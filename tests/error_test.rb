require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

class Error_Test < Base_Test
	def test_undeclared_identifier
		error = assert_raises Code::Undeclared_Identifier do
			Code.interp 'does_not_exist'
		end
	end

	def test_undeclared_identifier_in_file
		error = assert_raises Code::Undeclared_Identifier do
			Code.interp_file 'tests/fixtures/undeclared_identifier.code'
		end
	end

	def test_receiver_is_nil_on_member_read
		error = assert_raises Code::Receiver_Is_Nil do
			Code.interp "task,\ntask.type"
		end
		# Ascii.bold wraps parts of the message in escape codes when stdout is a TTY -- strip them so the
		# assertion holds whether or not the test run is attached to a terminal.
		plain = error.message.gsub(/\e\[[\d;]*m/, '')
		assert_includes plain, 'task is nil -- no member .type to reach'
	end

	def test_receiver_is_nil_on_member_call
		assert_raises Code::Receiver_Is_Nil do
			Code.interp "x,\nx.foo()"
		end
	end

	def test_receiver_is_nil_on_member_write_and_declare
		assert_raises Code::Receiver_Is_Nil do
			Code.interp "x,\nx.foo = 1"
		end

		assert_raises Code::Receiver_Is_Nil do
			Code.interp "x,\nx.foo := 1"
		end
	end

	def test_nil_still_reaches_its_own_declared_members
		assert_equal 'nil', Code.interp('nil.to_s()')
	end

	def test_safe_navigation_on_nil_returns_nil
		assert_nil Code.interp("x,\nx.?foo")
	end

	def test_cannot_reassign_constant
		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp 'CONST := 5, CONST = 10'
		end

		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp 'CONST = 123'
		end
	end

	def test_increment_and_decrement_cannot_change_a_constant
		%w(Foo FOO).each do |name|
			["#{name}++", "++#{name}", "#{name}--", "--#{name}"].each do |change|
				assert_raises Code::Cannot_Reassign_Constant, change do
					Code.interp <<~CODE
						#{name} := 1
						#{change}
					CODE
				end
			end
		end

		assert_equal 2, Code.interp(<<~CODE)
			count := 1
			count++
			count
		CODE
	end

	def test_a_method_cannot_change_a_capital_member
		%w(Foo FOO).each do |name|
			["self.#{name} = 2", "self.#{name} += 1", "self.#{name} := 2", "Self.Static = 2", "Self.Static += 1", "Self.Static := 2"].each do |change|
				assert_raises Code::Cannot_Reassign_Constant, change do
					Code.interp <<~CODE
						Thing {
							#{name} := 1
							Self.Static := 1

							change (;
								#{change}
							)
						}

						Thing().change()
					CODE
				end
			end
		end
	end

	def test_a_function_called_from_self_cannot_change_a_capital_member
		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp <<~CODE
				Thing {
					FOO := 1

					Self (;
						change()
					)

					change (;
						self.FOO = 2
					)
				}

				Thing()
			CODE
		end

		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp <<~CODE
				Thing {
					FOO := 1

					Self (;
						change (;
							self.FOO = 2
						)
						change()
					)
				}

				Thing()
			CODE
		end
	end

	def test_a_closure_made_in_self_cannot_change_a_capital_member_later
		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp <<~CODE
				Thing {
					FOO := 1
					change := nil

					Self (;
						self.change = (;
							self.FOO = 2
						)
					)
				}

				Thing().change()
			CODE
		end
	end

	def test_self_can_set_a_capital_member
		%w(Foo FOO).each do |name|
			assert_equal 3, Code.interp(<<~CODE)
				Thing {
					#{name},

					Self (;
						self.#{name} = 1
						self.#{name} += 1

						if true
							self.#{name} = 3
						end
					)
				}

				Thing().#{name}
			CODE
		end

		assert_equal 2, Code.interp(<<~CODE)
			Thing {
				Self.COUNT := 0

				Self (;
					Self.COUNT += 1
				)
			}

			Thing()
			Thing()
			Thing.COUNT
		CODE
	end

	def test_a_method_can_read_and_call_a_capital_member
		assert_equal [1, 7], Code.interp(<<~CODE).values
			Thing {
				FOO := 1
				Run := (; 7 )

				read (;
					[self.FOO, self.Run()]
				)
			}

			Thing().read()
		CODE
	end

	def test_global_dot_cannot_change_a_constant
		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp <<~CODE
				FOO := 1
				Global.FOO = 2
			CODE
		end

		assert_equal 2, Code.interp(<<~CODE)
			FOO := 1
			Global.FOO := 2
			FOO
		CODE
	end

	# A type name is a constant too: `=` never changes it, and neither does a compound operator
	def test_cannot_reassign_a_type
		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp 'Person { name, }, Person = 5'
		end

		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp <<~CODE
				Person {}
				Robot {}

				Person = Robot
			CODE
		end

		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp 'Person {}, Person += 1'
		end

		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp 'COUNT := 1, COUNT += 1'
		end

		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp <<~CODE
				Outer {
					Inner {}
				}

				Outer.Inner = 5
			CODE
		end
	end

	# `:=` declares it again on purpose
	def test_colon_equals_redeclares_a_type
		out = Code.interp <<~CODE
			Person {}
			Robot {}

			Person := Robot
			Person.@name
		CODE
		assert_equal 'Robot', out
	end

	def test_cannot_call_value
		assert_raises Code::Receiver_Is_Not_Callable do
			Code.interp 'x := 5, x()'
		end
	end

	def test_cannot_call_value_when_a_dictionary_field_shadows_a_builtin_method_name
		assert_raises Code::Receiver_Is_Not_Callable do
			Code.interp 'dict := {:keys = 4}, dict.keys()'
		end
	end

	def test_colon_dictionary_entry
		assert_raises Code::Colon_Dictionary_Entry do
			Code.interp '{5: "value"}'
		end
	end

	def test_missing_argument
		# todo: Doesn't display code and location
		assert_raises Code::Missing_Argument do
			Code.interp 'add := ( a, b; a + b ), add(5)'
		end
	end

	def test_non_iterable_collection_in_for_loop
		# Regression: `collection` (the actual runtime value, not a second Expression) used to pass
		# straight through as `highlighted_expression` -- Error_Formatter crashed trying to read a
		# location off it (`NoMethodError`, not this error at all) the moment this ever got raised.
		# Never had a test at all, is how that shipped unnoticed. `true` (not `5` -- see
		# test_for_loop_over_a_bare_integer below) since a bare Integer is legitimately iterable now.
		error = assert_raises Code::Non_Iterable_Collection_In_For_Loop do
			Code.interp "for true\n@puts it\nend"
		end
		assert_match 'TrueClass', error.message
	end

	def test_out_of_tokens_carries_last_parsed_expression
		# `Parser#begin_expression` used to raise `Out_Of_Tokens.new` with no argument at all, so
		# the error had no location and rendered as "unknown location" with no source snippet.
		# `Parser#output`'s top-level loop now tracks `@last_expression` (the previously completed
		# top-level statement) and passes it in, giving Error_Formatter something real to anchor
		# a snippet on. `a := 5` and `b := a +` sit on the same line with nothing but a space
		# between them -- no comma/newline separator lexeme in between to eat first -- so by the
		# time parsing runs out of tokens hunting for `+`'s right operand, `@last_expression` is
		# still the completed `a := 5` statement, not nil.
		error = assert_raises Code::Out_Of_Tokens do
			Code.interp 'a := 5 b := a +'
		end
		assert_instance_of Code::Infix_Expr, error.expression
		assert_equal ':=', error.expression.operator.value
		assert_equal 1, error.expression.line_start

		plain = error.message.gsub(/\e\[[\d;]*m/, '')
		assert_includes plain, 'a := 5 b := a +' # the real source line, not a blank/missing snippet
		refute_includes plain, 'unknown location'
	end

	def test_out_of_tokens_with_nothing_parsed_yet_still_falls_back_gracefully
		# No prior statement exists at all here (this fails on the very first token), so
		# `@last_expression` is legitimately nil -- same as before this change -- and the
		# formatter should still degrade to its plain "unknown location" message instead of
		# crashing on a nil expression.
		error = assert_raises Code::Out_Of_Tokens do
			Code.interp 'a +'
		end
		assert_nil error.expression
		assert_includes error.message, 'unknown location'
	end

	def test_invalid_start_directive_argument
		# todo: Doesn't display code and location
		assert_raises Code::Invalid_Server_Argument do
			Code.interp '@start_server 5'
		end
	end

	def test_onclick_and_on_server_read_need_a_function
		assert_raises Code::Invalid_Callback_Argument do
			Code.interp '@onclick(5)'
		end
		assert_raises Code::Invalid_Callback_Argument do
			Code.interp '@on_server_read()'
		end
	end

	def test_unknown_context_word_raises
		# `@unknown` isn't a Context member anywhere -- there's no "directive" concept to reject it as.
		assert_raises Code::Undeclared_Identifier do
			Code.interp '@unknown 123'
		end
	end

	def test_unterminated_string_literal
		# todo: Doesn't display code and location
		assert_raises Code::Unterminated_String_Literal do
			Code.interp '"unterminated'
		end
	end

	def test_too_many_subscript_expressions
		assert_raises Code::Too_Many_Subscript_Expressions do
			Code.interp 'arr := [1, 2, 3], arr[0, 1]'
		end
	end

	def test_arguments_given_but_not_expected
		assert_raises Code::Arguments_Given_But_Not_Expected do
			Code.interp 'funk (; 42 ), funk(5)'
		end
	end

	def test_invalid_composition_with_a_non_scope_type
		assert_raises Code::Invalid_Composition_With_A_Non_Scope_type do
			Code.interp 'Foo := :bar, Person + Foo { name, }'
		end
	end

	# A symbol that no `@operator` declares split the line into three statements, so `v </> 2` gave `v` with no error.
	def test_an_undeclared_symbol_between_two_values_raises
		error = assert_raises(Code::Undeclared_Operator) { Code.interp "v := 5\nv </> 2" }
		assert_equal "</>", error.expression.value
		assert_kind_of Code::Undeclared_Infix_Operator, error
		assert_equal [2, 3], [error.expression.line_start, error.expression.column_start], "the error points at the operator, not at v"
	end

	# A symbol on its own gave nil.
	def test_an_undeclared_symbol_on_its_own_raises
		assert_raises(Code::Undeclared_Operator) { Code.interp "</>" }
	end

	# A built-in symbol that an operand cannot take keeps the plain error.
	def test_a_built_in_symbol_on_the_wrong_operand_keeps_the_plain_error
		error = assert_raises(Code::Undeclared_Infix_Operator) { Code.interp "nil + 1" }
		refute_kind_of Code::Undeclared_Operator, error
	end

	# The parser's pre-scan registers a custom operator file-wide, but the overload itself is a regular declaration — using the operator outside the scope that declares it finds no overload. Used to silently evaluate to nil.
	def test_undeclared_infix_operator
		assert_raises Code::Undeclared_Infix_Operator do
			Code.interp 'scoped (;
				@operator ~> @infix 300 ( l, r; l )
			)
			1 ~> 2'
		end
	end

	def test_route_param_expected_but_not_found
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := 3099;
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get://users/:id ( id;
		    		"User `id`"
		    	)
		    }

		    app := Web_App()
		CODE

		interpreter = Code::Interpreter.new
		interpreter.run code
		route = interpreter.route_functions_by_route_name.values.first

		req = interpreter.build_prog_request '/users', 'get', {}, {}, {}, {}
		res = interpreter.build_prog_response nil

		# Bypasses the normal HTTP dispatch path (which always extracts matching url_params from the URL), so it's the only way to hit this branch: an :id param declared on the route but missing from url_params.
		assert_raises Code::Route_Param_Expected_But_Not_Found do
			interpreter.interp_route_body route, req, res, {}
		end
	end

	def test_error_location_tracking_inline
		assert_raises Code::Undeclared_Identifier do
			Code.interp 'x := 5, y := undefined_var, z := 10'
		end
	end

	def test_error_location_tracking_file
		assert_raises Code::Undeclared_Identifier do
			Code.interp_file 'tests/fixtures/undeclared_identifier.code'
		end
	end

	def test_error_with_infix_expression_has_location
		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp 'CONST := 5, CONST = 10'
		end
	end

	def test_error_formatting_includes_source_snippet
		assert_raises Code::Undeclared_Identifier do
			Code.interp 'x := 5, y := undefined_var'
		end
	end

	# An error raised in a call inside a loop body used to be replaced by `Expected condition to be truthy`: the call's frames were still on the stack, so the loop's own pop found the wrong scope. See Interpreter#pop_scope_to.
	def assert_error_inside_loop_survives source
		interpreter = Code::Interpreter.new
		error       = assert_raises Code::Undeclared_Identifier do
			interpreter.run "boom (; nope )\n#{source}"
		end
		assert_includes error.message.gsub(/\e\[[\d;]*m/, ''), 'nope has not been declared'
		assert_equal [interpreter.global], interpreter.stack, 'the loop should cut the stack back to Global, call frames included'
	end

	def test_an_error_inside_a_for_loop_keeps_its_own_class
		assert_error_inside_loop_survives "for [1, 2]\n\tboom()\nend"
	end

	def test_an_error_inside_a_strided_for_loop_keeps_its_own_class
		assert_error_inside_loop_survives "for [1, 2, 3, 4] by 2\n\tboom()\nend"
	end

	def test_an_error_inside_a_c_style_for_loop_keeps_its_own_class
		assert_error_inside_loop_survives "for i := 0, i < 2, i += 1\n\tboom()\nend"
	end

	def test_an_error_inside_a_custom_iterable_for_loop_keeps_its_own_class
		assert_error_inside_loop_survives <<~CODE
			Twos {
				next (index: Int -> Any;
					if index >= 2
						Stop_Iterating()
					else
						index
					end
				)
			}
			for Twos()
				boom()
			end
		CODE
	end

	def test_an_error_inside_a_when_case_keeps_its_own_class
		assert_error_inside_loop_survives "if 1\nwhen 1\n\tboom()\nend"
	end
end
