require 'minitest/autorun'
require './src/shared/helpers'

class Interpreter_Test < Minitest::Test
	FIZZ_BUZZ_CODE = %q(
			fizz_buzz { n;
				if n % 3 == 0 and n % 5 == 0
					'FizzBuzz'
				elif n % 3 == 0
					'Fizz'
				elif n % 5 == 0
					'Buzz'
				else
					'|n|'
				end
			}
		).freeze

	def test_numeric_literals
		assert_equal 48, _interp('48')
		assert_equal 15.16, _interp('15.16')
		assert_equal 2342, _interp('23_42')
	end

	def test_true_false_nil_literals
		assert_equal true, _interp('true')
		assert_equal false, _interp('false')
		assert_instance_of Nil, _interp('nil')
	end

	def test_uninterpolated_strings
		assert_equal 'Walt!', _interp('"Walt!"')
		assert_equal 'Vincent!', _interp("'Vincent!'")
	end

	def test_raises_undeclared_identifier_when_reading
		assert_raises Undeclared_Identifier do
			_interp 'hatch'
		end
	end

	def test_does_not_raise_undeclared_identifier_when_assigning
		refute_raises Undeclared_Identifier do
			_interp 'found = true'
		end
	end

	def test_variable_assignment_and_lookup
		out = _interp 'name = "Locke", name'
		assert_equal 'Locke', out
	end

	def test_constant_assignment_and_lookup
		out = _interp 'ENVIRONMENT = :development, ENVIRONMENT'
		assert_equal :development, out
	end

	def test_cannot_assign_incompatible_type
		assert_raises Cannot_Assign_Incompatible_Type do
			_interp 'My_Type = :anything'
		end

		refute_raises Cannot_Assign_Incompatible_Type do
			_interp 'My_Type = Other {}'
		end
	end

	def test_nil_assignment_operator
		out = _interp 'nothing;'
		assert_instance_of Nil, out
	end

	def test_anonymous_func_expr
		out = _interp '{;}'
		assert_instance_of Func, out
		assert_empty out.expressions
		assert_nil out.name
	end

	def test_empty_func_declaration
		out = _interp 'open {;}'
		assert_instance_of Func, out
		assert_empty out.expressions
		assert_equal 'open', out.name
	end

	def test_basic_func_declaration
		out = _interp 'enter { numbers = "4815162342"; }'
		assert_equal 1, out.expressions.count
		assert_instance_of Param_Expr, out.expressions.first
		assert_instance_of String_Expr, out.expressions.first.expression
	end

	def test_advanced_func_declaration
		out = _interp 'add { a, b; a + b }'
		assert_equal 3, out.expressions.count
		assert_instance_of Infix_Expr, out.expressions.last
		refute out.expressions.first.expression
	end

	def test_complex_func_declaration
		out = _interp 'run { a, labeled b, c = 4, labeled d = 8;
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
		out = _interp 'Island {}'
		assert_instance_of Type, out
		assert_empty out.expressions
		assert_equal 'Island', out.name
	end

	def test_basic_type_declaration
		out = _interp 'Hatch {
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
		out = _interp 'Number {}
		Integer | Number {}'
		assert_instance_of Type, out
		assert_equal %w(Integer Number), out.types
	end

	def test_inbody_type_composition_declaration
		out = _interp 'Numeric {
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
			_interp 'Number | Numeric {}'
		end
	end

	def test_potential_colon_ambiguity
		out = _interp 'assign_to_nil;'
		assert_instance_of Nil, out

		out = _interp 'func { assign_to_nil; }'
		assert_instance_of Func, out
		assert_instance_of Param_Expr, out.expressions.first
		assert_equal 'assign_to_nil', out.expressions.first.name
	end

	def test_infix_arithmetic
		assert_equal 12, _interp('4 + 8')
		assert_equal 4, _interp('1 + 2 * 3 / 4 % 5 ^ 6')
		assert_equal 8, _interp('(1 + (2 * 3 / 4) % 5) << 2')
	end

	def test_nested_type_declaration
		out = _interp '
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
			_interp 'ENVIRONMENT = :development
			ENVIRONMENT = :production'
		end
	end

	def test_variable_declarations
		out = _interp 'cool = "Cooper"'
		assert_equal 'Cooper', out

		out = _interp 'delta = 0.017'
		assert_equal 0.017, out
	end

	def test_declared_variable_lookup
		out = _interp 'number = 42
		number'
		assert_equal 42, out
	end

	def test_variable_can_be_reassigned
		out = _interp 'number = 42'
		assert_equal 42, out

		out = _interp 'number = 42
		number = 8'
		assert_equal 8, out
	end

	def test_inclusive_range
		out = _interp '4..42'
		assert_equal 4..42, out
		assert out.include? 4
		assert out.include? 23
		assert out.include? 42
	end

	def test_right_exclusive_range
		out = _interp '4.<42'
		assert_equal 4...42, out
		assert out.include? 4
		assert out.include? 41
		refute out.include? 42
	end

	def test_left_exclusive_range
		out = _interp '4>.42'
		assert_equal 4..42, out
		refute out.include? 4
		assert out.include? 5
		assert out.include? 42
	end

	def test_left_and_right_exclusive_range
		out = _interp '4><42'
		assert_equal 4...42, out
		refute out.include? 4
		assert out.include? 5
		assert out.include? 41
		refute out.include? 42
	end

	def test_empty_left_and_right_exclusive_range
		out = _interp '0><0'
		assert_equal 0...0, out
		refute out.include? -1
		refute out.include? 0
		refute out.include? 1
		refute out.include? 0.5
	end

	def test_simple_comparison_operators
		assert _interp '1 == 1'
		refute _interp '1 != 1'
		assert _interp '1 != 2'
		assert _interp '1 < 2'
		refute _interp '1 > 2'

		# It doesn't make sense to test all these since I'm just calling through to Ruby
	end

	def test_boolean_logic
		assert _interp 'true && true'
		refute _interp 'true && false'
		assert _interp 'true and true'
		refute _interp 'true and false'
	end

	def test_arithmetic_operators
		out = _interp '1 + 2 / 3 - 4 * 5'
		assert_equal -19, out

		# Right now this functions like the Ruby operator, but it could also be the power operator
		out = _interp '2 ^ 3'
		assert_equal 1, out

		out = _interp '1 << 2'
		assert_equal 4, out

		out = _interp '1 << 3'
		assert_equal 8, out
	end

	def test_double_operators
		out = _interp '1 - -9'
		assert_equal 10, out

		out = _interp '4 + -8'
		assert_equal -4, out

		out = _interp '8 - +15'
		assert_equal -7, out
	end

	def test_empty_array
		out = _interp '[]'
		assert_equal [], out.values
		assert_instance_of Emerald::Array, out
	end

	def test_non_empty_arrays
		out = _interp '[1]'
		assert_instance_of Emerald::Array, out
		assert_equal [1], out.values

		out = _interp '[1, "test", 5]'
		assert_instance_of Emerald::Array, out
		assert_equal Emerald::Array.new([1, 'test', 5]).values, out.values
	end

	def test_create_tuple
		out = _interp 'x = (1, 2)'
		assert_kind_of Tuple, out
		assert_equal [1, 2], out.values
	end

	def test_empty_dictionary
		out = _interp '{}'
		assert_kind_of Hash, out
		assert_equal out, {}
	end

	def test_create_dictionary_with_identifiers_as_keys_without_commas
		out = _interp '{a b c}'
		assert_equal %i(a b c), out.keys
		out.values.each do |value|
			assert_instance_of Nil, value
		end
	end

	def test_create_dictionary_with_identifiers_as_keys_with_commas
		out = _interp '{a, b}'
		out.values.each do |value|
			assert_instance_of Nil, value
		end
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation
		out = _interp '{ x:0 y=1 z}'
		refute_instance_of Nil, out.values.first
		refute_instance_of Nil, out.values[1]
		assert_instance_of Nil, out.values.last
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation_and_commas
		out = _interp '{ x:4, y=8, z}'
		assert_equal 4, out.values.first
		assert_equal 8, out.values[1]
		assert_instance_of Nil, out.values.last
	end

	def test_create_dictionary_with_local_value
		out = _interp 'x=4, y=2, { x=x, y=y }'
		assert_equal out, { x: 4, y: 2 }
	end

	def test_symbol_as_dictionary_keys
		out = _interp '{ :x = 1 }'
		assert_equal out, { x: 1 }
	end

	def test_string_as_dictionary_keys
		out = _interp '{ "x" = 1 }'
		assert_equal out, { x: 1 }
	end

	def test_colon_as_dictionary_infix_operator
		out = _interp 'x = 123, { x: x }'
		assert_equal out, { x: 123 }
	end

	def test_equals_as_dictionary_infix_operator
		out = _interp 'x = 123, { x = x }'
		assert_equal out, { x: 123 }
	end

	def test_invalid_dictionary_infix
		assert_raises Invalid_Dictionary_Infix_Operator do
			_interp '{ x > x }'
		end
	end

	def test_objects_as_dictionary_keys
		skip "Once Instance can be hashed, then this test will work properly."
		_interp '{ () = 1 }'
		_interp '{ 123 = 1 }'
	end

	def test_assigning_function_to_variable
		out = _interp 'funk = { a, b, c; }'
		assert_equal 3, out.expressions.count
	end

	def test_composed_type_declaration
		out = _interp '
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
		out = _interp '
		Transform {}, Physics {}
		Entity | Transform - Physics {}'
		assert_kind_of Type, out
		assert_kind_of Composition_Expr, out.expressions.first
		assert_kind_of Composition_Expr, out.expressions.last
		assert_equal 'Physics', out.expressions.last.name.value
		assert_equal '-', out.expressions.last.operator
	end

	def test_complex_type_declaration
		out = _interp 'Transform {
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
			_interp 'Type.new'
		end
	end

	def test_raises_non_type_initialization_error
		assert_raises Cannot_Initialize_Non_Type_Identifier do
			_interp 'x = 1, x.new'
		end
	end

	def test_declared_type_init_with_new_keyword
		out = _interp 'Type {}, Type.new'
		assert_instance_of Instance, out
		assert_equal 'Type', out.name
	end

	def test_complex_type_init
		out = _interp 'Transform {
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
		out = _interp 'Vector1 { x = 4 }
		Vector1.new.x
		'
		assert_equal 4, out
	end

	def test_instance_complex_value_lookup
		out = _interp 'Vector2 { x = 1, y = 2 }
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
		out = _interp 'Vector2 { x = 0, y = 1 }
		pos = Vector2()'
		assert_instance_of Instance, out
		data = { 'x' => 0, 'y' => 1 }
		assert_equal data, out.data
	end

	def test_dot_slash
		out = _interp './x = 123'
		assert_equal 123, out
	end

	def test_look_up_dot_slash_without_dot_slash
		out = _interp './x = 123
		x'
		assert_equal 123, out
	end

	def test_look_up_dot_slash_with_dot_slash
		out = _interp './y = 543
		./y'
		assert_equal 543, out
	end

	def test_function_call_with_arguments
		out = _interp '
		add { a, b; a+b }
		add(4, 8)'
		assert_equal 12, out
	end

	def test_compound_operator
		out = _interp 'add { amount = 1, to = 0;
			to += amount
		}
		add(5, 37)'
		assert_equal 42, out
	end

	def test_precedence_operation_regression
		src = _interp '1 + 2 / 3 - 4 * 5'
		ref = _interp '(1 + (2 / 3)) - (4 * 5)'
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

		out = _interp "#{shared_code}
		A.B"
		assert_instance_of Type, out

		out = _interp "#{shared_code}
		A.B.C.new"
		assert_instance_of Instance, out

		out = _interp "#{shared_code}
		A.B.C.new.d"
		assert_equal 4, out
	end

	def test_mutating_state_across_calls
		out = _interp '
		counter = 0
		increment {; counter = counter + 1 }
		increment()
		increment()'
		assert_equal 2, out
	end

	def test_calling_functions
		refute_raises RuntimeError do
			out = _interp '
			square { input;
				input * input
			}

			result = square(5)
			result'
			assert_equal 25, out
		end
	end

	def test_function_call_as_argument
		out = _interp '
		add { amount = 1, to = 4;
			to + amount
		}
		inc = add() `should return 5
		add(inc, 1)'
		assert_equal 6, out
	end

	def test_complex_return_with_simple_conditional
		out = _interp 'return (1+2*3/4) + (1+2*3/4) if 1 + 2 > 2'
		assert_equal 4, out.value
	end

	def test_greater_equals_regression
		out = _interp '2+1 >= 1'
		assert out

		out = _interp 'return 1+2*3/4%5-6 unless 1 + 2 >= 10'
		assert_equal -4, out.value
	end

	def test_truthy_falsy_logic
		assert_equal 1, _interp('if true 1 else 0 end')
		assert_equal 0, _interp('if 0 1 else 0 end')
		assert_equal 0, _interp('if nil 1 else 0 end')
	end

	def test_returns_with_end_of_line_conditional
		out = _interp 'return 3 if true'
		assert_equal 3, out.value
	end

	def test_standalone_array_index_expr
		out = _interp '4.8.15.16.23.42'
		assert_equal [4, 8, 15, 16, 23, 42], out
	end

	def test_array_access_by_dot_index
		out = _interp 'things = [4, 8, 15]
		things.0'
		assert_equal 4, out
	end

	def test_nested_array_access_by_dot_index
		out = _interp 'things = [4, [8, 15, 16], 23, [42, 108, 418, 3]]
		(things.1.0, things.3.1)'
		assert_instance_of Tuple, out
		assert_equal 8, out.values.first
		assert_equal 108, out.values.last
	end

	def test_calling_member_functions
		out = _interp 'Number {
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
		out = _interp 'Number {
			numerator = 8

			new { num;
				numerator = num
			}
		}
		x = Number.new(15)
		x.numerator'
		assert_equal 15, out
	end

	def test_function_scope
		out = _interp 'x = 123
		double {; x * 2 }
		double()'
		assert_equal 246, out
	end

	def test_function_scope_some_more
		out = _interp 'x = 108

		Doubler {
			double {; x * 2 }
		}

		Doubler().double()'
		assert_equal 216, out
	end

	def test_returns
		out = _interp 'return 1'
		assert_instance_of Return, out
		assert_equal 1, out.value

		out = _interp '
		eject {;
			if true
				return "true!"
			end

			return "should not get here"
		}
		eject()'
		assert_instance_of Return, out
		assert_equal "true!", out.value
	end

	def test_preload_dot_e
		out = _interp_file './src/emerald/preload.e'
	end
	
	def test_fizz_buzz_structure
		out = _interp FIZZ_BUZZ_CODE
		assert_instance_of Func, out
		assert_instance_of Conditional_Expr, out.expressions.last
		assert_equal 2, out.expressions.count
	end

	def test_fizz_buzz_output
		out = _interp "#{FIZZ_BUZZ_CODE}
		three = []
		1..3.each {;
			three << fizz_buzz(it)
		}

		five = []
		1..5.each {;
			five << fizz_buzz(it)
		}

		fifteen = []
		1..15.each {;
			fifteen << fizz_buzz(it)
		}

		(three, five, fifteen)"
		assert_instance_of Tuple, out
		out.values.each do |it|
			assert_instance_of Emerald::Array, it
		end

		assert_equal ['1', '2', 'Fizz'], out.values[0].values
		assert_equal ['1', '2', 'Fizz', '4', 'Buzz'], out.values[1].values
		assert_equal ['1', '2', 'Fizz', '4', 'Buzz', 'Fizz', '7', '8', 'Fizz', 'Buzz', '11', 'Fizz', '13', '14', 'FizzBuzz'], out.values[2].values
	end
end
