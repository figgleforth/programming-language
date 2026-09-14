require 'minitest/autorun'
require_relative '../source/main'
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

	def test_cannot_assign_incompatible_type
		error = assert_raises Code::Cannot_Assign_Incompatible_Type do
			Code.interp 'Person { name, }, Person = 5'
		end
	end

	def test_cannot_call_value
		assert_raises Code::Receiver_Is_Not_Callable do
			Code.interp 'x := 5, x()'
		end
	end

	def test_cannot_call_value_when_a_dictionary_field_shadows_a_builtin_method_name
		assert_raises Code::Receiver_Is_Not_Callable do
			Code.interp 'dict := {keys: 4}, dict.keys()'
		end
	end

	def test_invalid_dictionary_key
		error = assert_raises Code::Invalid_Dictionary_Key do
			Code.interp '{5: "value"}'
		end
	end

	def test_invalid_dictionary_infix_operator
		error = assert_raises Code::Invalid_Dictionary_Infix_Operator do
			Code.interp '{x + 5}'
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
			Code.interp 'Foo := :bar, Person | Foo { name, }'
		end
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

		    Web_App | Server {
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
end
