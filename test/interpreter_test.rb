require 'minitest/autorun'
require 'recursive-open-struct'
require './test/helper'

class Interpreter_Test < Minitest::Test
	def test_integer_literals
		out = interp '48'
		assert_equal 48, out

	end

	def test_underscored_numbers
		out = interp '4_8'
		assert_equal 48, out
	end

	def test_decimal_literals
		out = interp '15.16'
		assert_equal 15.16, out
	end

	def test_booleans
		out = interp 'true'
		assert_equal true, out

		out = interp 'false'
		assert_equal false, out
	end

	def test_single_quote_strings
		out = interp "'We have to go back'"
		assert_equal out, "We have to go back"
	end

	def test_double_quote_strings
		out = interp '"Walt!"'
		assert_equal out, "Walt!"
	end

	def test_constant_declarations
		out = interp 'ENVIRONMENT := :development'
		assert_equal out, :development
	end

	def test_constant_lookup
		out = interp 'ENVIRONMENT := :development
		ENVIRONMENT'
		assert_equal out, :development
	end

	def test_constants_cannot_be_reassigned
		assert_raises Cannot_Reassign_Constant do
			interp 'ENVIRONMENT := :development
			ENVIRONMENT = :production'
		end
	end

	def test_variable_declarations
		out = interp 'cool := "Cooper"'
		assert_equal 'Cooper', out

		out = interp 'delta := 0.017'
		assert_equal 0.017, out
	end

	def test_declared_variable_lookup
		out = interp 'number := 42
		number'
		assert_equal 42, out
	end

	def test_undeclared_variable_lookup
		out = interp 'number'
		assert_nil out
	end

	def test_assigning_undeclared_identifier
		assert_raises Cannot_Assign_Undeclared_Identifier do
			interp 'number = 42'
		end

		assert_raises Cannot_Assign_Undeclared_Identifier do
			interp 'square = { input; input * input }'
		end
	end

	def test_variable_can_be_reassigned
		out = interp 'number := 42'
		assert_equal 42, out

		out = interp 'number := 42
		number = 8'
		assert_equal 8, out
	end

	def test_nil_shorthand_declaration
		out = interp 'test =;'
		assert_nil out
	end

	def test_inclusive_range
		out = interp '4..42'
		assert_equal 4..42, out
		assert out.include? 4
		assert out.include? 23
		assert out.include? 42
	end

	def test_right_exclusive_range
		out = interp '4.<42'
		assert_equal 4...42, out
		assert out.include? 4
		assert out.include? 41
		refute out.include? 42
	end

	def test_left_exclusive_range
		out = interp '4>.42'
		assert_equal 4..42, out
		refute out.include? 4
		assert out.include? 5
		assert out.include? 42
	end

	def test_left_and_right_exclusive_range
		out = interp '4><42'
		assert_equal 4...42, out
		refute out.include? 4
		assert out.include? 5
		assert out.include? 41
		refute out.include? 42
	end

	def test_empty_left_and_right_exclusive_range
		out = interp '0><0'
		assert_equal 0...0, out
		refute out.include? -1
		refute out.include? 0
		refute out.include? 1
		refute out.include? 0.5
	end

	def test_simple_comparison_operators
		out = interp '1 == 1'
		assert out

		out = interp '1 != 1'
		refute out

		out = interp '1 != 2'
		assert out

		out = interp '1 < 2'
		assert out

		out = interp '1 > 2'
		refute out

		# It doesn't make sense to test all these since I'm just calling through to Ruby
	end

	def test_boolean_logic
		out = interp 'true && true'
		assert out

		out = interp 'true && false'
		refute out

		out = interp 'true and true'
		assert out

		out = interp 'true and false'
		refute out
	end

	def test_arithmetic_operators
		out = interp '1 + 2 / 3 - 4 * 5'
		assert_equal -19, out

		# Right now this functions like the Ruby operator, but it could also be the power operator
		out = interp '2 ^ 3'
		assert_equal 1, out

		out = interp '1 << 2'
		assert_equal 4, out

		out = interp '1 << 3'
		assert_equal 8, out
	end

	def test_double_operators
		out = interp '1 - -9'
		assert_equal 10, out

		out = interp '4 + -8'
		assert_equal -4, out

		out = interp '8 - +15'
		assert_equal -7, out
	end

	def test_empty_array
		out = interp '[]'
		assert_equal [], out
	end

	def test_non_empty_arrays
		out = interp '[1]'
		assert_equal [1], out

		out = interp '[1, "test", 5]'
		assert_equal [1, 'test', 5], out
	end

	def test_create_tuple
		out = interp 'x := (1, 2)'
		assert_kind_of Tuple, out
		assert_equal [1, 2], out.values
	end

	def test_empty_dictionary
		out = interp '{}'
		assert_kind_of Hash, out
		assert_equal out, {}
	end

	def test_create_dictionary_with_identifiers_as_keys
		out = interp '{a b c}'
		assert_equal out, { a: nil, b: nil, c: nil }

	end

	def test_create_dictionary_with_keys_and_values
		out = interp '{ x:0 y=1 z}'
		assert_equal out, { x: 0, y: 1, z: nil }

		out = interp '{ x:4, y=8, z}'
		assert_equal out, { x: 4, y: 8, z: nil }
	end

	def test_create_dictionary_with_local_value
		out = interp 'x:=4, y:=2, { x=x, y=y}'
		assert_equal out, { x: 4, y: 2 }
	end

	def test_symbol_as_dictionary_keys
		out = interp '{ :x = 1 }'
		assert_equal out, { x: 1 }
	end

	def test_colon_as_dictionary_infix_operator
		out = interp 'x := 123, { x: x }'
		assert_equal out, { x: 123 }
	end

	def test_invalid_dictionary_infix
		assert_raises Invalid_Dictionary_Infix_Operator do
			interp '{ x > x }'
		end
	end

	def test_invalid_dictionary_keys
		assert_raises Invalid_Dictionary_Key do
			out = interp '{ () = 1 }'
		end

		assert_raises Invalid_Dictionary_Key do
			out = interp '{ 123 = 1 }'
		end
	end

	def test_anonymous_function_declaration
		out = interp '{;}'
		assert_kind_of Func, out
		assert_nil out.name
		assert_empty out.params
		assert_empty out.expressions
	end

	def test_named_function_declaration
		out = interp 'funk {;}'
		assert_equal 'funk', out.name
	end

	def test_function_body
		out = interp '{;
			1, 2, 3
		}'
		refute_empty out.expressions
		assert_equal 3, out.expressions.count
	end

	def test_function_params
		out = interp '{ a; }'
		refute_empty out.params
		assert_equal 1, out.params.count
	end

	def test_function_param_labels
		out = interp 'greet { person name = "Cooper";
			"Hello `name`"
		}'
		assert_kind_of Func, out
		assert_equal 1, out.params.count
		assert_equal 1, out.expressions.count
		# #todo :homoiconic_expressions
	end

	def test_assigning_function_to_variable
		out = interp 'funk := { a, b, c; }'
		assert_empty out.expressions
		refute_empty out.params
		assert_equal 3, out.params.count
	end

	def test_empty_type_declaration
		out = interp 'Island {}'
		assert_kind_of Type, out
		assert_equal 'Island', out.name
		assert_empty out.expressions
		assert_empty out.compositions
	end

	def test_composed_type_declaration
		out = interp 'Entity {
			| Transform
			- Rotation
		}'
		assert_kind_of Type, out
		assert_kind_of Composition_Expr, out.compositions.first
		assert_kind_of Composition_Expr, out.compositions.last
		assert_equal 'Rotation', out.compositions.last.name
		assert_equal '-', out.compositions.last.operator
		# :homoiconic_expressions assert out.exprs.include? Some hash representing expressions somehow.
	end

	def test_composed_type_declaration_before_body
		out = interp 'Entity | Transform & Physics {}'
		assert_kind_of Type, out
		assert_kind_of Composition_Expr, out.compositions.first
		assert_kind_of Composition_Expr, out.compositions.last
		assert_equal 'Physics', out.compositions.last.name
		assert_equal '&', out.compositions.last.operator
	end

	def test_complex_type_declaration
		out = interp 'Transform {
			position: Vector3
			rotation: Float

			x: Int = 0
			y := 0

			to_s {;
				"Transform!"
			}
		}'
		assert_kind_of Identifier_Expr, out.expressions[0]
		assert_equal 'Vector3', out.expressions[0].type
		assert_kind_of Infix_Expr, out.expressions[2]
		assert_kind_of Infix_Expr, out.expressions[3]
		assert_kind_of Func_Expr, out.expressions[4]
	end

	def test_undeclared_type_init_with_new_keyword
		assert_raises Cannot_Initialize_Undeclared_Identifier do
			interp 'Type.new'
		end
	end

	def test_declaring_type
		out = interp 'Type {}'
		assert_kind_of Type, out
	end

	def test_declared_type_init_with_new_keyword
		out = interp 'Type {}
		Type.new
		'
		assert_kind_of Type, out
		assert_instance_of Instance, out
		assert_equal 'Type', out.name
	end

	def test_complex_type_init
		out = interp 'Transform {
			position: Vector3
			rotation: Float

			x: Int = 4
			y := 8

			to_s {;
				"Transform!"
			}

			new { position: Vector3; }
		}, Transform.new'
		assert_kind_of Type, out
		assert_equal 'Transform', out.name
		assert_kind_of Array, out.expressions
		assert_equal 6, out.expressions.count
		assert_kind_of Param_Decl, out.expressions.last.param_decls.first
		assert_kind_of String_Expr, out.expressions[4].expressions.first
	end

	def test_complex_type_with_value_lookup
		out = interp 'Vector1 { x := 4 }
		Vector1.new.x
		'
		assert_equal 4, out
	end

	def test_instance_complex_value_lookup
		out = interp 'Vector2 { x: Int = 1, y := 2 }
		Transform {
			position: Vector2 = Vector2.new
		}
		t: Transform = Transform.new
		(t.position, t.position.y)
		'
		assert_kind_of Tuple, out
		assert_kind_of Instance, out.values.first
		assert_equal 2, out.values.last
	end

	def test_type_declaration_with_parens
		out = interp 'Vector2 { x: Int, y: Int }
		pos := Vector2()'
		assert_kind_of Type, out
		assert_instance_of Instance, out
	end

	def test_type_declaration_with_args
		out = interp '
		Vector1 {
			x: Int
			new { x;
				./x = x
			}
		}
		'
		assert_kind_of Type, out
	end

	def test_global_declarations
		out = interp 'String()'
		assert_kind_of Type, out
		assert_instance_of Instance, out
	end

	def test_dot_slash
		out = interp './x := 123'
		assert_equal 123, out
	end

	def test_look_up_dot_slash_without_dot_slash
		out = interp './x := 123
		x'
		assert_equal 123, out
	end

	def test_look_up_dot_slash_with_dot_slash
		out = interp './y := 543
		./y'
		assert_equal 543, out
	end

	def test_function_call_with_arguments
		out = interp '
		add { a, b; a+b }
		add(4, 8)'
		assert_equal 12, out
	end

	def test_precedence_operation_regression
		src = interp '1 + 2 / 3 - 4 * 5'
		ref = interp '(1 + (2 / 3)) - (4 * 5)'
		assert_equal ref, src
		assert_equal -19, src
	end

	def test_long_dot_chain
		shared_code = '
		A {
			B {
				C {
					d := 4
				}
			}
		}'

		out = interp "#{shared_code}
		A.B"
		assert_instance_of Type, out

		out = interp "#{shared_code}
		A.B.C.new"
		assert_instance_of Instance, out
	end

	def test_long_dot_chain2
		shared_code = '
		A {
			b := B {
				c := C {
					d := 4
				}
			}
		}'

		out = interp "#{shared_code}
		A.new.B"
		assert_instance_of Type, out

		out = interp "#{shared_code}
		A.new.B.new.C.new"
		assert_instance_of Instance, out

		out = interp "#{shared_code}
		A.new.B.new.C.new.d"
		assert_equal 4, out
	end

	def test_returns_with_end_of_line_conditional
		out = interp 'return 3 if true'
		assert_equal 3, out
	end

	def test_standalone_array_index_expr
		out = interp '4.8.15.16.23.42'
		assert_equal [4, 8, 15, 16, 23, 42], out
	end

	def test_array_index_expr
		assert_raises Unhandled_Array_Index_Expr do
			interp 'something := 1
			something.4.8.15.16.23.42'
		end
	end

	def test_complex_return_with_simple_conditional
		out = interp 'return (1+2*3/4) + (1+2*3/4) if 1 + 2 > 2'
		assert_equal 4, out
	end

	def test_greater_equals_regression
		out = interp '2+1 >= 1'
		assert out

		out = interp 'return 1+2*3/4%5-6 unless 1 + 2 >= 10'
		assert_equal -4, out
	end
end
