require 'minitest/autorun'
require './src/shared/helpers'

class Interpreter_Test < Minitest::Test

	def test_numeric_literals
		assert_equal 48, interp('48')
		assert_equal 15.16, interp('15.16')
		assert_equal 2342, interp('23_42')
	end

	def test_true_false_nil_literals
		assert_equal true, interp('true')
		assert_equal false, interp('false')
		assert_instance_of Nil, interp('nil')
	end

	def test_uninterpolated_strings
		assert_equal 'Walt!', interp('"Walt!"')
		assert_equal 'Vincent!', interp("'Vincent!'")
	end

	def test_raises_undeclared_identifier_when_reading
		assert_raises Undeclared_Identifier do
			interp 'hatch'
		end
	end

	def test_does_not_raise_undeclared_identifier_when_assigning
		refute_raises Undeclared_Identifier do
			interp 'found = true'
		end
	end

	def test_variable_assignment_and_lookup
		out = interp 'name = "Locke", name'
		assert_equal 'Locke', out
	end

	def test_constant_assignment_and_lookup
		out = interp 'ENVIRONMENT = :development, ENVIRONMENT'
		assert_equal :development, out
	end

	def test_type_assignment_and_lookup
		out = interp 'My_Type = :anything, My_Type'
		assert_equal :anything, out
	end

	def test_nil_assignment_operator
		out = interp 'nothing;'
		# assert_instance_of Nil, out
	end

	def test_empty_func_declaration
		out = interp 'open {;}'
		assert_instance_of Func, out
		assert_empty out.expressions
		assert_equal 'open', out.name
	end

	def test_basic_func_declaration
		out = interp 'enter { numbers = "4815162342"; }'
		assert_equal 1, out.expressions.count
		assert_instance_of Param_Expr, out.expressions.first
		assert_instance_of String_Expr, out.expressions.first.expression
	end

	def test_advanced_func_declaration
		out = interp 'add { a, b; a + b }'
		assert_equal 3, out.expressions.count
		assert_instance_of Infix_Expr, out.expressions.last
		refute out.expressions.first.expression
	end

	def test_complex_func_declaration
		out = interp 'run { a, labeled b, c = 4, labeled d = 8;
			c + d
		}'
		assert_equal 5, out.expressions.count

		a = out.expressions[0]
		assert_equal 'a', a.name
		refute a.label
		refute a.expression

		b = out.expressions[1]
		assert b.label
		assert_equal 'labeled', b.label
		refute b.expression

		c = out.expressions[2]
		assert c.expression
		refute c.label

		d = out.expressions[3]
		assert d.label
		assert d.expression

		assert_instance_of Infix_Expr, out.expressions.last
	end

	def test_empty_type_declaration
		out = interp 'Island {}'
		assert_instance_of Type, out
		assert_empty out.expressions
		assert_equal 'Island', out.name
	end

	def test_basic_type_declaration
		out = interp 'Hatch {
			computer = nil

			enter { numbers;
				`do something with the numbers
			}
		}'
		assert_instance_of Nil, out['computer']
		assert_instance_of Func, out['enter']
		assert_equal 2, out.expressions.count
	end

	def test_inline_type_composition_declaration
		out = interp 'Number {}
		Integer | Number {}'
		assert_instance_of Type, out
		assert_equal %w(Integer Number), out.types
	end

	def test_inbody_type_composition_declaration
		out = interp 'Numeric {
			numerator;
		}
		Number | Numeric {}
		Float {
			| Number
		}'
		assert_instance_of Type, out
		assert_equal %w(Float Number Numeric), out.types
	end

	def test_invalid_type_declaration
		assert_raises Undeclared_Identifier do
			interp 'Number | Numeric {}'
		end
	end

	def test_potential_colon_ambiguity
		out = interp 'assign_to_nil;'
		assert_instance_of Nil, out

		out = interp 'func { assign_to_nil; }'
		assert_instance_of Func, out
		assert_instance_of Param_Expr, out.expressions.first
		assert_equal 'assign_to_nil', out.expressions.first.name
	end

	def test_infix_arithmetic
		assert_equal 12, interp('4 + 8')
		assert_equal 4, interp('1 + 2 * 3 / 4 % 5 ^ 6')
		assert_equal 8, interp('(1 + (2 * 3 / 4) % 5) << 2')
	end

	def test_nested_type_declaration
		out = interp '
		Computer {
		}

		Island {
			Hatch {
				Commodore_64 | Computer {}
			}
		}

		Island.Hatch.Commodore_64'
		assert_instance_of Type, out
	end

	# I'm committing these to have as reference for rewriting the remainder of the Interpreter functionality.
	#
	# def test_constant_lookup
	# 	out = interp 'ENVIRONMENT := :development
	# 	ENVIRONMENT'
	# 	assert_equal out, :development
	# end
	#
	# def test_constants_cannot_be_reassigned
	# 	assert_raises Cannot_Reassign_Constant do
	# 		interp 'ENVIRONMENT := :development
	# 		ENVIRONMENT = :production'
	# 	end
	# end
	#
	# def test_variable_declarations
	# 	out = interp 'cool := "Cooper"'
	# 	assert_equal 'Cooper', out
	#
	# 	out = interp 'delta := 0.017'
	# 	assert_equal 0.017, out
	# end
	#
	# def test_declared_variable_lookup
	# 	out = interp 'number := 42
	# 	number'
	# 	assert_equal 42, out
	# end
	#
	# def test_undeclared_variable_lookup
	# 	assert_raises Undeclared_Identifier do
	# 		interp 'number'
	# 	end
	# end
	#
	# def test_assigning_undeclared_identifier
	# 	assert_raises Cannot_Assign_Undeclared_Identifier do
	# 		interp 'number = 42'
	# 	end
	#
	# 	assert_raises Cannot_Assign_Undeclared_Identifier do
	# 		interp 'square = { input; input * input }'
	# 	end
	# end
	#
	# def test_variable_can_be_reassigned
	# 	out = interp 'number := 42'
	# 	assert_equal 42, out
	#
	# 	out = interp 'number := 42
	# 	number = 8'
	# 	assert_equal 8, out
	# end
	#
	# def test_nil_shorthand_declaration
	# 	out = interp 'test =;'
	# 	assert_instance_of Nil, out
	# end
	#
	# def test_inclusive_range
	# 	out = interp '4..42'
	# 	assert_equal 4..42, out
	# 	assert out.include? 4
	# 	assert out.include? 23
	# 	assert out.include? 42
	# end
	#
	# def test_right_exclusive_range
	# 	out = interp '4.<42'
	# 	assert_equal 4...42, out
	# 	assert out.include? 4
	# 	assert out.include? 41
	# 	refute out.include? 42
	# end
	#
	# def test_left_exclusive_range
	# 	out = interp '4>.42'
	# 	assert_equal 4..42, out
	# 	refute out.include? 4
	# 	assert out.include? 5
	# 	assert out.include? 42
	# end
	#
	# def test_left_and_right_exclusive_range
	# 	out = interp '4><42'
	# 	assert_equal 4...42, out
	# 	refute out.include? 4
	# 	assert out.include? 5
	# 	assert out.include? 41
	# 	refute out.include? 42
	# end
	#
	# def test_empty_left_and_right_exclusive_range
	# 	out = interp '0><0'
	# 	assert_equal 0...0, out
	# 	refute out.include? -1
	# 	refute out.include? 0
	# 	refute out.include? 1
	# 	refute out.include? 0.5
	# end
	#
	# def test_simple_comparison_operators
	# 	out = interp '1 == 1'
	# 	assert out
	#
	# 	out = interp '1 != 1'
	# 	refute out
	#
	# 	out = interp '1 != 2'
	# 	assert out
	#
	# 	out = interp '1 < 2'
	# 	assert out
	#
	# 	out = interp '1 > 2'
	# 	refute out
	#
	# 	# It doesn't make sense to test all these since I'm just calling through to Ruby
	# end
	#
	# def test_boolean_logic
	# 	out = interp 'true && true'
	# 	assert out
	#
	# 	out = interp 'true && false'
	# 	refute out
	#
	# 	out = interp 'true and true'
	# 	assert out
	#
	# 	out = interp 'true and false'
	# 	refute out
	# end
	#
	# def test_arithmetic_operators
	# 	out = interp '1 + 2 / 3 - 4 * 5'
	# 	assert_equal -19, out
	#
	# 	# Right now this functions like the Ruby operator, but it could also be the power operator
	# 	out = interp '2 ^ 3'
	# 	assert_equal 1, out
	#
	# 	out = interp '1 << 2'
	# 	assert_equal 4, out
	#
	# 	out = interp '1 << 3'
	# 	assert_equal 8, out
	# end
	#
	# def test_double_operators
	# 	out = interp '1 - -9'
	# 	assert_equal 10, out
	#
	# 	out = interp '4 + -8'
	# 	assert_equal -4, out
	#
	# 	out = interp '8 - +15'
	# 	assert_equal -7, out
	# end
	#
	# def test_empty_array
	# 	out = interp '[]'
	# 	assert_equal [], out
	# end
	#
	# def test_non_empty_arrays
	# 	out = interp '[1]'
	# 	assert_equal [1], out
	#
	# 	out = interp '[1, "test", 5]'
	# 	assert_equal [1, 'test', 5], out
	# end
	#
	# def test_create_tuple
	# 	out = interp 'x := (1, 2)'
	# 	assert_kind_of Tuple, out
	# 	assert_equal [1, 2], out.values
	# end
	#
	# def test_empty_dictionary
	# 	out = interp '{}'
	# 	assert_kind_of Hash, out
	# 	assert_equal out, {}
	# end
	#
	# def test_create_dictionary_with_identifiers_as_keys_without_commas
	# 	out = interp '{a b c}'
	# 	assert_equal %i(a b c), out.keys
	# 	out.values.each do |value|
	# 		assert_instance_of Nil, value
	# 	end
	# end
	#
	# def test_create_dictionary_with_identifiers_as_keys_with_commas
	# 	out = interp '{a, b}'
	# 	out.values.each do |value|
	# 		assert_instance_of Nil, value
	# 	end
	# end
	#
	# def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation
	# 	out = interp '{ x:0 y=1 z}'
	# 	refute_instance_of Nil, out.values.first
	# 	refute_instance_of Nil, out.values[1]
	# 	assert_instance_of Nil, out.values.last
	# end
	#
	# def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation_and_commas
	# 	out = interp '{ x:4, y=8, z}'
	# 	assert_equal 4, out.values.first
	# 	assert_equal 8, out.values[1]
	# 	assert_instance_of Nil, out.values.last
	# end
	#
	# def test_create_dictionary_with_local_value
	# 	out = interp 'x:=4, y:=2, { x=x, y=y }'
	# 	assert_equal out, { x: 4, y: 2 }
	# end
	#
	# def test_symbol_as_dictionary_keys
	# 	out = interp '{ :x = 1 }'
	# 	assert_equal out, { x: 1 }
	# end
	#
	# def test_string_as_dictionary_keys
	# 	out = interp '{ "x" = 1 }'
	# 	assert_equal out, { x: 1 }
	# end
	#
	# def test_colon_as_dictionary_infix_operator
	# 	out = interp 'x := 123, { x: x }'
	# 	assert_equal out, { x: 123 }
	# end
	#
	# def test_equals_as_dictionary_infix_operator
	# 	out = interp 'x := 123, { x = x }'
	# 	assert_equal out, { x: 123 }
	# end
	#
	# def test_invalid_dictionary_infix
	# 	assert_raises Invalid_Dictionary_Infix_Operator do
	# 		interp '{ x > x }'
	# 	end
	# end
	#
	# def test_invalid_dictionary_keys
	# 	assert_raises Invalid_Dictionary_Key do
	# 		out = interp '{ () = 1 }'
	# 	end
	#
	# 	assert_raises Invalid_Dictionary_Key do
	# 		out = interp '{ 123 = 1 }'
	# 	end
	# end
	#
	# def test_anonymous_function_declaration
	# 	out = interp '{;}'
	# 	assert_kind_of Func, out
	# 	assert_nil out.name
	# 	assert_empty out.params
	# 	assert_empty out.expressions
	# end
	#
	# def test_named_function_declaration
	# 	out = interp 'funk {;}'
	# 	assert_equal 'funk', out.name
	# end
	#
	# def test_function_body
	# 	out = interp '{;
	# 		1, 2, 3
	# 	}'
	# 	refute_empty out.expressions
	# 	assert_equal 3, out.expressions.count
	# end
	#
	# def test_function_params
	# 	out = interp '{ a; }'
	# 	refute_empty out.params
	# 	assert_equal 1, out.params.count
	# end
	#
	# def test_function_param_labels
	# 	out = interp 'greet { person name = "Cooper";
	# 		"Hello |name|"
	# 	}'
	# 	assert_kind_of Func, out
	# 	assert_equal 1, out.params.count
	# 	assert_equal 1, out.expressions.count
	# end
	#
	# def test_assigning_function_to_variable
	# 	out = interp 'funk := { a, b, c; }'
	# 	assert_empty out.expressions
	# 	refute_empty out.params
	# 	assert_equal 3, out.params.count
	# end
	#
	# def test_empty_type_declaration
	# 	out = interp 'Island {}'
	# 	assert_kind_of Type, out
	# 	assert_equal 'Island', out.name
	# 	assert_empty out.expressions
	# 	assert_empty out.compositions
	# end
	#
	# def test_composed_type_declaration
	# 	out = interp 'Entity {
	# 		| Transform
	# 		- Rotation
	# 	}'
	# 	assert_kind_of Type, out
	# 	assert_kind_of Composition_Expr, out.compositions.first
	# 	assert_kind_of Composition_Expr, out.compositions.last
	# 	assert_equal 'Rotation', out.compositions.last.name
	# 	assert_equal '-', out.compositions.last.operator
	# end
	#
	# def test_composed_type_declaration_before_body
	# 	out = interp 'Entity | Transform & Physics {}'
	# 	assert_kind_of Type, out
	# 	assert_kind_of Composition_Expr, out.compositions.first
	# 	assert_kind_of Composition_Expr, out.compositions.last
	# 	assert_equal 'Physics', out.compositions.last.name
	# 	assert_equal '&', out.compositions.last.operator
	# end
	#
	# def test_complex_type_declaration
	# 	out = interp 'Transform {
	# 		position: Vector3
	# 		rotation: Float
	#
	# 		x: Int = 0
	# 		y := 0
	#
	# 		to_s {;
	# 			"Transform!"
	# 		}
	# 	}'
	# 	assert_kind_of Identifier_Expr, out.expressions[0]
	# 	assert_equal 'Vector3', out.expressions[0].type
	# 	assert_kind_of Infix_Expr, out.expressions[2]
	# 	assert_kind_of Infix_Expr, out.expressions[3]
	# 	assert_kind_of Func_Expr, out.expressions[4]
	# end
	#
	# def test_undeclared_type_init_with_new_keyword
	# 	assert_raises Undeclared_Identifier do
	# 		interp 'Type.new'
	# 	end
	# end
	#
	# def test_declaring_type
	# 	out = interp 'Type {}'
	# 	assert_kind_of Type, out
	# end
	#
	# def test_declared_type_init_with_new_keyword
	# 	out = interp 'Type {}
	# 	Type.new
	# 	'
	# 	assert_kind_of Type, out
	# 	assert_instance_of Instance, out
	# 	assert_equal 'Type', out.name
	# end
	#
	# def test_complex_type_init
	# 	out = interp 'Transform {
	# 		position: Vector3
	# 		rotation: Float
	#
	# 		x: Int = 4
	# 		y := 8
	#
	# 		to_s {;
	# 			"Transform!"
	# 		}
	#
	# 		new { position: Vector3; }
	# 	}, Transform.new'
	# 	assert_kind_of Type, out
	# 	assert_equal 'Transform', out.name
	# 	assert_kind_of Array, out.expressions
	# 	assert_equal 6, out.expressions.count
	# 	assert_kind_of Param_Decl, out.expressions.last.param_decls.first
	# 	assert_kind_of String_Expr, out.expressions[4].expressions.first
	# end
	#
	# def test_complex_type_with_value_lookup
	# 	out = interp 'Vector1 { x := 4 }
	# 	Vector1.new.x
	# 	'
	# 	assert_equal 4, out
	# end
	#
	# def test_instance_complex_value_lookup
	# 	out = interp 'Vector2 { x: Int = 1, y := 2 }
	# 	Transform {
	# 		position: Vector2 = Vector2.new
	# 	}
	# 	t: Transform = Transform.new
	# 	(t.position, t.position.y)
	# 	'
	# 	assert_kind_of Tuple, out
	# 	assert_kind_of Instance, out.values.first
	# 	assert_equal 2, out.values.last
	# end
	#
	# def test_type_declaration_with_parens
	# 	out = interp 'Vector2 { x: Int = 0, y: Int = 1 }
	# 	pos := Vector2()'
	# 	assert_kind_of Type, out
	# 	assert_instance_of Instance, out
	# end
	#
	# def test_type_declaration_with_args
	# 	out = interp '
	# 	Vector1 {
	# 		x: Int
	# 		new { x;
	# 			./x = x
	# 		}
	# 	}
	# 	'
	# 	assert_kind_of Type, out
	# end
	#
	# def test_global_declarations
	# 	out = interp 'String()'
	# 	assert_kind_of Type, out
	# 	assert_instance_of Instance, out
	# end
	#
	# def test_dot_slash
	# 	out = interp './x := 123'
	# 	assert_equal 123, out
	# end
	#
	# def test_look_up_dot_slash_without_dot_slash
	# 	out = interp './x := 123
	# 	x'
	# 	assert_equal 123, out
	# end
	#
	# def test_look_up_dot_slash_with_dot_slash
	# 	out = interp './y := 543
	# 	./y'
	# 	assert_equal 543, out
	# end
	#
	# def test_function_call_with_arguments
	# 	out = interp '
	# 	add { a, b; a+b }
	# 	add(4, 8)'
	# 	assert_equal 12, out
	# end
	#
	# def test_precedence_operation_regression
	# 	src = interp '1 + 2 / 3 - 4 * 5'
	# 	ref = interp '(1 + (2 / 3)) - (4 * 5)'
	# 	assert_equal ref, src
	# 	assert_equal -19, src
	# end
	#
	# def test_long_dot_chain
	# 	shared_code = '
	# 	A {
	# 		B {
	# 			C {
	# 				d := 4
	# 			}
	# 		}
	# 	}'
	#
	# 	out = interp "#{shared_code}
	# 	A.B"
	# 	assert_instance_of Type, out
	#
	# 	out = interp "#{shared_code}
	# 	A.B.C.new"
	# 	assert_instance_of Instance, out
	# end
	#
	# def test_long_dot_chain2
	# 	shared_code = '
	# 	A {
	# 		b := B {
	# 			c := C {
	# 				d := 4
	# 			}
	# 		}
	# 	}'
	#
	# 	out = interp "#{shared_code}
	# 	A.new.B"
	# 	assert_instance_of Type, out
	#
	# 	out = interp "#{shared_code}
	# 	A.new.B.new.C.new"
	# 	assert_instance_of Instance, out
	#
	# 	out = interp "#{shared_code}
	# 	A.new.B.new.C.new.d"
	# 	assert_equal 4, out
	# end
	#
	# def test_returns_with_end_of_line_conditional
	# 	out = interp 'return 3 if true'
	# 	assert_equal 3, out
	# end
	#
	# def test_standalone_array_index_expr
	# 	out = interp '4.8.15.16.23.42'
	# 	assert_equal [4, 8, 15, 16, 23, 42], out
	# end
	#
	# def test_array_index_expr
	# 	assert_raises Unhandled_Array_Index_Expr do
	# 		interp 'something := 1
	# 		something.4.8.15.16.23.42'
	# 	end
	# end
	#
	# def test_complex_return_with_simple_conditional
	# 	out = interp 'return (1+2*3/4) + (1+2*3/4) if 1 + 2 > 2'
	# 	assert_equal 4, out
	# end
	#
	# def test_greater_equals_regression
	# 	out = interp '2+1 >= 1'
	# 	assert out
	#
	# 	out = interp 'return 1+2*3/4%5-6 unless 1 + 2 >= 10'
	# 	assert_equal -4, out
	# end
	#
	# def test_number_dot_e_instance
	# 	out = interp '123.numerator'
	# 	assert_equal 123, out
	# end
	#
	# def test_number_instance_rationalize_function
	# 	out = interp '42.to_s()'
	# 	assert_equal "42", out
	# end
	#
	# def test_not_raising_preloaded_assert
	# 	refute_raises Assert_Triggered do
	# 		out = interp 'assert(true)'
	# 		assert_equal true, out
	# 	end
	# end
	#
	# def test_raising_preloaded_assert
	# 	assert_raises Assert_Triggered do
	# 		interp 'assert(false)'
	# 	end
	# end
	#
	# def test_complex_function_call_on_number_instance
	# 	out = interp '4815.negate()'
	# 	assert_equal -4815, out
	# end
	#
	# def test_mutating_state_across_calls
	# 	out = interp '
	# 	counter := 0
	# 	increment {; counter = counter + 1 }
	# 	increment()
	# 	increment()
	# 	'
	# 	assert_equal 2, out
	# end
	#
	# def test_closure_captures
	# 	skip "Closures!"
	# 	assert_raises Cannot_Assign_Undeclared_Identifier do
	# 		out = interp '
	# 	make_counter {;
	# 		count := 0
	# 		return {; count = count + 1 }
	# 	}
	# 	counter := make_counter()
	# 	counter()
	# 	counter()
	# 	'
	# 		assert_equal 3, out
	# 	end
	# end
	#
	# def test_truthy_falsy_logic
	# 	assert_equal 1, interp('if true 1 else 0 end')
	# 	assert_equal 0, interp('if 0 1 else 0 end')
	# 	assert_equal 0, interp('if nil 1 else 0 end')
	# end
	#
	# def test_sanity
	# 	out = interp 'add { amount = 1, to = 0;
	# 		to += amount
	# 	}
	# 	add(1, 41)'
	# 	assert_equal 42, out
	# end
	#
	# def test_calling_functions
	# 	refute_raises RuntimeError do
	# 		out = interp '
	# 		square { input;
	# 			input * input
	# 		}
	#
	# 		result := square(5)
	# 		assert(result == 5 ** 2)
	# 		result'
	# 		assert_equal 25, out
	# 	end
	# end
	#
	# def test_function_call_as_argument
	# 	out = interp '
	# 	add { amount = 1, to = 4;
	# 		to += amount
	# 	}
	# 	inc := add() `should return 5
	# 	assert(inc == 5)
	# 	add(inc, 1)'
	# 	assert_equal 6, out
	# end
	#
	# def test_preloads
	# 	refute_raises RuntimeError do
	# 		out = interp_file './src/emerald/preload.e'
	# 	end
	# end

end
