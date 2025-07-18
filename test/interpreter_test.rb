require 'minitest/autorun'
require './src/shared/helpers'

class Interpreter_Test < Minitest::Test

	def test_numeric_literals
		assert_equal 48, interp_helper('48')
		assert_equal 15.16, interp_helper('15.16')
		assert_equal 2342, interp_helper('23_42')
	end

	def test_true_false_nil_literals
		assert_equal true, interp_helper('true')
		assert_equal false, interp_helper('false')
		assert_instance_of Nil, interp_helper('nil')
	end

	def test_uninterpolated_strings
		assert_equal 'Walt!', interp_helper('"Walt!"')
		assert_equal 'Vincent!', interp_helper("'Vincent!'")
	end

	def test_raises_undeclared_identifier_when_reading
		assert_raises Undeclared_Identifier do
			interp_helper 'hatch'
		end
	end

	def test_does_not_raise_undeclared_identifier_when_assigning
		refute_raises Undeclared_Identifier do
			interp_helper 'found = true'
		end
	end

	def test_variable_assignment_and_lookup
		out = interp_helper 'name = "Locke", name'
		assert_equal 'Locke', out
	end

	def test_constant_assignment_and_lookup
		out = interp_helper 'ENVIRONMENT = :development, ENVIRONMENT'
		assert_equal :development, out
	end

	def test_cannot_assign_incompatible_type
		assert_raises Cannot_Assign_Incompatible_Type do
			interp_helper 'My_Type = :anything'
		end

		refute_raises Cannot_Assign_Incompatible_Type do
			interp_helper 'My_Type = Other {}'
		end
	end

	def test_nil_assignment_operator
		out = interp_helper 'nothing;'
		assert_instance_of Nil, out
	end

	def test_anonymous_func_expr
		out = interp_helper '{;}'
		assert_instance_of Func, out
		assert_empty out.expressions
		assert_nil out.name
	end

	def test_empty_func_declaration
		out = interp_helper 'open {;}'
		assert_instance_of Func, out
		assert_empty out.expressions
		assert_equal 'open', out.name
	end

	def test_basic_func_declaration
		out = interp_helper 'enter { numbers = "4815162342"; }'
		assert_equal 1, out.expressions.count
		assert_instance_of Param_Expr, out.expressions.first
		assert_instance_of String_Expr, out.expressions.first.expression
	end

	def test_advanced_func_declaration
		out = interp_helper 'add { a, b; a + b }'
		assert_equal 3, out.expressions.count
		assert_instance_of Infix_Expr, out.expressions.last
		refute out.expressions.first.expression
	end

	def test_complex_func_declaration
		out = interp_helper 'run { a, labeled b, c = 4, labeled d = 8;
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
		out = interp_helper 'Island {}'
		assert_instance_of Type, out
		assert_empty out.expressions
		assert_equal 'Island', out.name
	end

	def test_basic_type_declaration
		out = interp_helper 'Hatch {
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
		out = interp_helper 'Number {}
		Integer | Number {}'
		assert_instance_of Type, out
		assert_equal %w(Integer Number), out.types
	end

	def test_inbody_type_composition_declaration
		out = interp_helper 'Numeric {
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
			interp_helper 'Number | Numeric {}'
		end
	end

	def test_potential_colon_ambiguity
		out = interp_helper 'assign_to_nil;'
		assert_instance_of Nil, out

		out = interp_helper 'func { assign_to_nil; }'
		assert_instance_of Func, out
		assert_instance_of Param_Expr, out.expressions.first
		assert_equal 'assign_to_nil', out.expressions.first.name
	end

	def test_infix_arithmetic
		assert_equal 12, interp_helper('4 + 8')
		assert_equal 4, interp_helper('1 + 2 * 3 / 4 % 5 ^ 6')
		assert_equal 8, interp_helper('(1 + (2 * 3 / 4) % 5) << 2')
	end

	def test_nested_type_declaration
		out = interp_helper '
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

	def test_constants_cannot_be_reassigned
		assert_raises Cannot_Reassign_Constant do
			interp_helper 'ENVIRONMENT = :development
			ENVIRONMENT = :production'
		end
	end

	def test_variable_declarations
		out = interp_helper 'cool = "Cooper"'
		assert_equal 'Cooper', out

		out = interp_helper 'delta = 0.017'
		assert_equal 0.017, out
	end

	def test_declared_variable_lookup
		out = interp_helper 'number = 42
		number'
		assert_equal 42, out
	end

	def test_variable_can_be_reassigned
		out = interp_helper 'number = 42'
		assert_equal 42, out

		out = interp_helper 'number = 42
		number = 8'
		assert_equal 8, out
	end

	def test_inclusive_range
		out = interp_helper '4..42'
		assert_equal 4..42, out
		assert out.include? 4
		assert out.include? 23
		assert out.include? 42
	end

	def test_right_exclusive_range
		out = interp_helper '4.<42'
		assert_equal 4...42, out
		assert out.include? 4
		assert out.include? 41
		refute out.include? 42
	end

	def test_left_exclusive_range
		out = interp_helper '4>.42'
		assert_equal 4..42, out
		refute out.include? 4
		assert out.include? 5
		assert out.include? 42
	end

	def test_left_and_right_exclusive_range
		out = interp_helper '4><42'
		assert_equal 4...42, out
		refute out.include? 4
		assert out.include? 5
		assert out.include? 41
		refute out.include? 42
	end

	def test_empty_left_and_right_exclusive_range
		out = interp_helper '0><0'
		assert_equal 0...0, out
		refute out.include? -1
		refute out.include? 0
		refute out.include? 1
		refute out.include? 0.5
	end

	def test_simple_comparison_operators
		assert interp_helper '1 == 1'
		refute interp_helper '1 != 1'
		assert interp_helper '1 != 2'
		assert interp_helper '1 < 2'
		refute interp_helper '1 > 2'

		# It doesn't make sense to test all these since I'm just calling through to Ruby
	end

	def test_boolean_logic
		assert interp_helper 'true && true'
		refute interp_helper 'true && false'
		assert interp_helper 'true and true'
		refute interp_helper 'true and false'
	end

	def test_arithmetic_operators
		out = interp_helper '1 + 2 / 3 - 4 * 5'
		assert_equal -19, out

		# Right now this functions like the Ruby operator, but it could also be the power operator
		out = interp_helper '2 ^ 3'
		assert_equal 1, out

		out = interp_helper '1 << 2'
		assert_equal 4, out

		out = interp_helper '1 << 3'
		assert_equal 8, out
	end

	def test_double_operators
		out = interp_helper '1 - -9'
		assert_equal 10, out

		out = interp_helper '4 + -8'
		assert_equal -4, out

		out = interp_helper '8 - +15'
		assert_equal -7, out
	end

	def test_empty_array
		out = interp_helper '[]'
		assert_equal [], out.values
		assert_instance_of Emerald::Array, out
	end

	def test_non_empty_arrays
		out = interp_helper '[1]'
		assert_instance_of Emerald::Array, out
		assert_equal [1], out.values

		out = interp_helper '[1, "test", 5]'
		assert_instance_of Emerald::Array, out
		assert_equal Emerald::Array.new([1, 'test', 5]).values, out.values
	end

	def test_create_tuple
		out = interp_helper 'x = (1, 2)'
		assert_kind_of Tuple, out
		assert_equal [1, 2], out.values
	end

	def test_empty_dictionary
		out = interp_helper '{}'
		assert_kind_of Hash, out
		assert_equal out, {}
	end

	def test_create_dictionary_with_identifiers_as_keys_without_commas
		out = interp_helper '{a b c}'
		assert_equal %i(a b c), out.keys
		out.values.each do |value|
			assert_instance_of Nil, value
		end
	end

	def test_create_dictionary_with_identifiers_as_keys_with_commas
		out = interp_helper '{a, b}'
		out.values.each do |value|
			assert_instance_of Nil, value
		end
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation
		out = interp_helper '{ x:0 y=1 z}'
		refute_instance_of Nil, out.values.first
		refute_instance_of Nil, out.values[1]
		assert_instance_of Nil, out.values.last
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation_and_commas
		out = interp_helper '{ x:4, y=8, z}'
		assert_equal 4, out.values.first
		assert_equal 8, out.values[1]
		assert_instance_of Nil, out.values.last
	end

	def test_create_dictionary_with_local_value
		out = interp_helper 'x=4, y=2, { x=x, y=y }'
		assert_equal out, { x: 4, y: 2 }
	end

	def test_symbol_as_dictionary_keys
		out = interp_helper '{ :x = 1 }'
		assert_equal out, { x: 1 }
	end

	def test_string_as_dictionary_keys
		out = interp_helper '{ "x" = 1 }'
		assert_equal out, { x: 1 }
	end

	def test_colon_as_dictionary_infix_operator
		out = interp_helper 'x = 123, { x: x }'
		assert_equal out, { x: 123 }
	end

	def test_equals_as_dictionary_infix_operator
		out = interp_helper 'x = 123, { x = x }'
		assert_equal out, { x: 123 }
	end

	def test_invalid_dictionary_infix
		assert_raises Invalid_Dictionary_Infix_Operator do
			interp_helper '{ x > x }'
		end
	end

	def test_objects_as_dictionary_keys
		skip "Once Instance can be hashed, then this test will work properly."
		interp_helper '{ () = 1 }'
		interp_helper '{ 123 = 1 }'
	end

	def test_assigning_function_to_variable
		out = interp_helper 'funk = { a, b, c; }'
		assert_equal 3, out.expressions.count
	end

	def test_composed_type_declaration
		out = interp_helper '
		Transform {}
		Rotation {}
		Entity {
			| Transform
			- Rotation
		}'
		assert_kind_of Type, out
		assert_kind_of Composition_Expr, out.expressions.first
		assert_kind_of Composition_Expr, out.expressions.last
		assert_equal 'Rotation', out.expressions.last.name.value
		assert_equal '-', out.expressions.last.operator
	end

	def test_composed_type_declaration_before_body
		out = interp_helper '
		Transform {}, Physics {}
		Entity | Transform - Physics {}'
		assert_kind_of Type, out
		assert_kind_of Composition_Expr, out.expressions.first
		assert_kind_of Composition_Expr, out.expressions.last
		assert_equal 'Physics', out.expressions.last.name.value
		assert_equal '-', out.expressions.last.operator
	end

	def test_complex_type_declaration
		out = interp_helper 'Transform {
			position;
			rotation;

			x = 0
			y = 0

			to_s {;
				"Transform!"
			}
		}'
		assert_kind_of Postfix_Expr, out.expressions[0]
		assert_kind_of Infix_Expr, out.expressions[2]
		assert_kind_of Infix_Expr, out.expressions[3]
		assert_kind_of Func_Expr, out.expressions[4]
	end

	def test_undeclared_type_init_with_new_keyword
		assert_raises Undeclared_Identifier do
			interp_helper 'Type.new'
		end
	end

	def test_raises_non_type_initialization_error
		assert_raises Cannot_Initialize_Non_Type_Identifier do
			interp_helper 'x = 1, x.new'
		end
	end

	def test_declared_type_init_with_new_keyword
		out = interp_helper 'Type {}, Type.new'
		assert_instance_of Instance, out
		assert_equal 'Type', out.name
	end

	def test_complex_type_init
		out = interp_helper 'Transform {
			position;
			rotation;

			x = 4
			y = 8

			to_s {;
				"Transform!"
			}

			new { position; }
		}, Transform.new'
		assert_kind_of Instance, out
		assert_equal 'Transform', out.name
		assert_kind_of Array, out.expressions
		assert_equal 6, out.expressions.count
		assert_kind_of Func_Expr, out.expressions.last
		# It would be nice if an Instance's @data also contained :expressions, but those interpreted into Func. So Instance.expressions is [Func_Expr], instance.data is [Func].
	end

	def test_complex_type_with_value_lookup
		out = interp_helper 'Vector1 { x = 4 }
		Vector1.new.x
		'
		assert_equal 4, out
	end

	def test_instance_complex_value_lookup
		out = interp_helper 'Vector2 { x = 1, y = 2 }
		Transform {
			position = Vector2.new
		}
		t = Transform.new
		(t.position, t.position.y)
		'
		assert_kind_of Tuple, out
		assert_kind_of Instance, out.values.first
		assert_equal 2, out.values.last
	end

	def test_type_declaration_with_parens
		out = interp_helper 'Vector2 { x = 0, y = 1 }
		pos = Vector2()'
		assert_instance_of Instance, out
		data = { 'x' => 0, 'y' => 1 }
		assert_equal data, out.data
	end

	def test_dot_slash
		out = interp_helper './x = 123'
		assert_equal 123, out
	end

	def test_look_up_dot_slash_without_dot_slash
		out = interp_helper './x = 123
		x'
		assert_equal 123, out
	end

	def test_look_up_dot_slash_with_dot_slash
		out = interp_helper './y = 543
		./y'
		assert_equal 543, out
	end

	def test_function_call_with_arguments
		out = interp_helper '
		add { a, b; a+b }
		add(4, 8)'
		assert_equal 12, out
	end

	def test_compound_operator
		out = interp_helper 'add { amount = 1, to = 0;
			to += amount
		}
		add(5, 37)'
		assert_equal 42, out
	end

	def test_precedence_operation_regression
		src = interp_helper '1 + 2 / 3 - 4 * 5'
		ref = interp_helper '(1 + (2 / 3)) - (4 * 5)'
		assert_equal ref, src
		assert_equal -19, src
	end

	def test_long_dot_chain
		shared_code = '
		A {
			B {
				C {
					d = 4
				}
			}
		}'

		out = interp_helper "#{shared_code}
		A.B"
		assert_instance_of Type, out

		out = interp_helper "#{shared_code}
		A.B.C.new"
		assert_instance_of Instance, out

		out = interp_helper "#{shared_code}
		A.B.C.new.d"
		assert_equal 4, out
	end

	def test_mutating_state_across_calls
		out = interp_helper '
		counter = 0
		increment {; counter = counter + 1 }
		increment()
		increment()'
		assert_equal 2, out
	end

	def test_calling_functions
		refute_raises RuntimeError do
			out = interp_helper '
			square { input;
				input * input
			}

			result = square(5)
			result'
			assert_equal 25, out
		end
	end

	def test_function_call_as_argument
		out = interp_helper '
		add { amount = 1, to = 4;
			to + amount
		}
		inc = add() `should return 5
		add(inc, 1)'
		assert_equal 6, out
	end

	def test_complex_return_with_simple_conditional
		out = interp_helper 'return (1+2*3/4) + (1+2*3/4) if 1 + 2 > 2'
		assert_equal 4, out
	end

	def test_greater_equals_regression
		out = interp_helper '2+1 >= 1'
		assert out

		out = interp_helper 'return 1+2*3/4%5-6 unless 1 + 2 >= 10'
		assert_equal -4, out
	end

	def test_truthy_falsy_logic
		assert_equal 1, interp_helper('if true 1 else 0 end')
		assert_equal 0, interp_helper('if 0 1 else 0 end')
		assert_equal 0, interp_helper('if nil 1 else 0 end')
	end

	def test_returns_with_end_of_line_conditional
		out = interp_helper 'return 3 if true'
		assert_equal 3, out
	end

	def test_standalone_array_index_expr
		out = interp_helper '4.8.15.16.23.42'
		assert_equal [4, 8, 15, 16, 23, 42], out
	end

	def test_array_access_by_dot_index
		out = interp_helper 'things = [4, 8, 15]
		things.0'
		assert_equal 4, out
	end

	def test_nested_array_access_by_dot_index
		out = interp_helper 'things = [4, [8, 15, 16], 23, [42, 108, 418, 3]]
		(things.1.0, things.3.1)'
		assert_instance_of Tuple, out
		assert_equal 8, out.values.first
		assert_equal 108, out.values.last
	end

	def test_calling_member_functions
		out = interp_helper 'Number {
			numerator = -1

			new { num; `num = nil is implied
				./numerator = num
			}
		}
		x = Number(4)
		x.numerator'
		assert_equal 4, out
	end

	def test_dot_new_initializer_regression
		out = interp_helper 'Number {
			numerator = 8

			new { num;
				numerator = num
			}
		}
		x = Number.new(15)
		x.numerator'
		assert_equal 15, out
	end
end
