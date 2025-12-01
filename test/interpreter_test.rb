require 'minitest/autorun'
require_relative '../lib/ore'
require_relative 'base_test'

class Interpreter_Test < Base_Test
	def test_preload_dot_air
		refute_raises RuntimeError do
			Ore.interp_file './ore/preload.ore'
		end
	end

	def test_numeric_literals
		assert_equal 48, Ore.interp('48')
		assert_equal 15.16, Ore.interp('15.16')
		assert_equal 2342, Ore.interp('23_42')
	end

	def test_true_false_nil_literals
		assert_equal true, Ore.interp('true')
		assert_equal false, Ore.interp('false')
		assert_instance_of NilClass, Ore.interp('nil')
	end

	def test_uninterpolated_strings
		assert_equal 'Walt!', Ore.interp('"Walt!"')
		assert_equal 'Vincent!', Ore.interp("'Vincent!'")
	end

	def test_raises_undeclared_identifier_when_reading
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp 'hatch'
		end
	end

	def test_does_not_raise_undeclared_identifier_when_assigning
		refute_raises Ore::Undeclared_Identifier do
			Ore.interp 'found = true'
		end
	end

	def test_variable_assignment_and_lookup
		out = Ore.interp 'name = "Locke", name'
		assert_equal 'Locke', out
	end

	def test_constant_assignment_and_lookup
		out = Ore.interp 'ENVIRONMENT = :development, ENVIRONMENT'
		assert_equal :development, out
	end

	def test_cannot_assign_incompatible_type
		assert_raises Ore::Cannot_Assign_Incompatible_Type do
			Ore.interp 'My_Type = :anything'
		end

		refute_raises Ore::Cannot_Assign_Incompatible_Type do
			Ore.interp 'My_Type = Other {}'
		end
	end

	def test_nil_assignment_operator
		out = Ore.interp 'nothing;'
		assert_instance_of NilClass, out
	end

	def test_anonymous_func_expr
		out = Ore.interp '{;}'
		assert_instance_of Ore::Func, out
		assert_empty out.expressions
		assert_equal 'Ore::Func', out.name
	end

	def test_empty_func_declaration
		out = Ore.interp 'open {;}'
		assert_instance_of Ore::Func, out
		assert_empty out.expressions
		assert_equal 'open', out.name
	end

	def test_basic_func_declaration
		out = Ore.interp 'enter { numbers = "4815162342"; }'
		assert_equal 1, out.expressions.count
		assert_instance_of Ore::Param_Expr, out.expressions.first
		assert_instance_of Ore::String_Expr, out.expressions.first.default
	end

	def test_advanced_func_declaration
		out = Ore.interp 'add { a, b; a + b }'
		assert_equal 3, out.expressions.count
		assert_instance_of Ore::Infix_Expr, out.expressions.last
		refute out.expressions.first.default
	end

	def test_complex_func_declaration
		out = Ore.interp 'run { a, labeled b, c = 4, labeled d = 8;
			c + d
		}'
		assert_equal 5, out.expressions.count

		a = out.expressions[0]
		assert_equal 'a', a.name
		refute a.label
		refute a.default

		b = out.expressions[1]
		assert b.label
		assert_equal 'labeled', b.label
		refute b.default

		c = out.expressions[2]
		assert c.default
		refute c.label

		d = out.expressions[3]
		assert d.label
		assert d.default

		assert_instance_of Ore::Infix_Expr, out.expressions.last
	end

	def test_empty_type_declaration
		out = Ore.interp 'Island {}'
		assert_instance_of Ore::Type, out
		assert_empty out.expressions
		assert_equal 'Island', out.name
	end

	def test_basic_type_declaration
		out = Ore.interp 'Hatch {
			computer = nil

			enter { numbers;
				`do something with the numbers
			}
		}'
		assert_instance_of Ore::Type, out
		assert_instance_of NilClass, out[:computer]
		assert_instance_of Ore::Func, out[:enter]
	end

	def test_inline_type_composition_declaration
		out = Ore.interp 'Number {}
		Integer | Number {}'
		assert_instance_of Ore::Type, out
		assert_equal %w(Integer Number), out.types
	end

	def test_inbody_type_composition_declaration
		out = Ore.interp 'Numeric {
			numerator;
		}
		Number | Numeric {}
		Float {
			| Number
		}'
		assert_instance_of Ore::Type, out
		assert_equal %w(Float Number Numeric), out.types
	end

	def test_invalid_type_declaration
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp 'Number | Numeric {}'
		end
	end

	def test_potential_colon_ambiguity
		out = Ore.interp 'assign_to_nil;'
		assert_instance_of NilClass, out

		out = Ore.interp 'func { assign_to_nil; }'
		assert_instance_of Ore::Func, out
		assert_instance_of Ore::Param_Expr, out.expressions.first
		assert_equal 'assign_to_nil', out.expressions.first.name
	end

	def test_infix_arithmetic
		assert_equal 12, Ore.interp('4 + 8')
		assert_equal 4, Ore.interp('1 + 2 * 3 / 4 % 5 ^ 6')
		assert_equal 8, Ore.interp('(1 + (2 * 3 / 4) % 5) << 2')
	end

	def test_nested_type_declaration
		out = Ore.interp '
		Computer {
		}

		Island {
			Hatch {
				Commodore_64 | Computer {}
			}
		}

		Island.Hatch.Commodore_64'
		assert_instance_of Ore::Type, out
	end

	def test_constants_cannot_be_reassigned
		assert_raises Ore::Cannot_Reassign_Constant do
			Ore.interp 'ENVIRONMENT = :development
			ENVIRONMENT = :production'
		end
	end

	def test_variable_declarations
		out = Ore.interp 'cool = "Cooper"'
		assert_equal 'Cooper', out

		out = Ore.interp 'delta = 0.017'
		assert_equal 0.017, out
	end

	def test_declared_variable_lookup
		out = Ore.interp 'number = 42
		number'
		assert_equal 42, out
	end

	def test_variable_can_be_reassigned
		out = Ore.interp 'number = 42'
		assert_equal 42, out

		out = Ore.interp 'number = 42
		number = 8'
		assert_equal 8, out
	end

	def test_inclusive_range
		out = Ore.interp '4..42'
		assert_instance_of Ore::Range, out
		assert_equal 4..42, out
		assert out.include? 4
		assert out.include? 23
		assert out.include? 42
	end

	def test_right_exclusive_range
		out = Ore.interp '4.<42'
		assert_instance_of Ore::Range, out
		assert_equal 4...42, out
		assert out.include? 4
		assert out.include? 41
		refute out.include? 42
	end

	def test_left_exclusive_range
		out = Ore.interp '4>.42'
		assert_instance_of Ore::Range, out
		assert_equal 5..42, out
		refute out.include? 4
		assert out.include? 5
		assert out.include? 42
	end

	def test_left_and_right_exclusive_range
		out = Ore.interp '4><42'
		assert_instance_of Ore::Range, out
		assert_equal 5...42, out
		refute out.include? 4
		assert out.include? 5
		assert out.include? 41
		refute out.include? 42
	end

	def test_empty_left_and_right_exclusive_range
		out = Ore.interp '0><0'
		assert_equal 1...0, out
		refute out.include? -1
		refute out.include? 0
		refute out.include? 1
		refute out.include? 0.5
	end

	def test_simple_comparison_operators
		assert Ore.interp '1 == 1'
		refute Ore.interp '1 != 1'
		assert Ore.interp '1 != 2'
		assert Ore.interp '1 < 2'
		refute Ore.interp '1 > 2'

		# It doesn't make sense to test all these since I'm just calling through to Ruby
	end

	def test_boolean_logic
		assert Ore.interp 'true && true'
		refute Ore.interp 'true && false'
		assert Ore.interp 'true and true'
		refute Ore.interp 'true and false'
	end

	def test_arithmetic_operators
		out = Ore.interp '1 + 2 / 3 - 4 * 5'
		assert_equal -19, out

		# Right now this functions like the Ruby operator, but it could also be the power operator
		out = Ore.interp '2 ^ 3'
		assert_equal 1, out

		out = Ore.interp '1 << 2'
		assert_equal 4, out

		out = Ore.interp '1 << 3'
		assert_equal 8, out
	end

	def test_double_operators
		out = Ore.interp '1 - -9'
		assert_equal 10, out

		out = Ore.interp '4 + -8'
		assert_equal -4, out

		out = Ore.interp '8 - +15'
		assert_equal -7, out
	end

	def test_empty_array
		out = Ore.interp '[]'
		assert_equal [], out.values
		assert_instance_of Ore::List, out
	end

	def test_non_empty_arrays
		out = Ore.interp '[1]'
		assert_instance_of Ore::List, out
		assert_equal [1], out.values

		out = Ore.interp '[1, "test", 5]'
		assert_instance_of Ore::List, out
		assert_equal Ore::List.new([1, 'test', 5]).values, out.values
	end

	def test_tuples
		out = Ore.interp '(1, 2)'
		assert_kind_of Ore::Tuple, out
		assert_equal [1, 2], out.values

		out = Ore.interp 't = ("Hello", "from" ,"Tuple")
		t_first = t.0
		t2 = (t.0, t.1, t.2)
		(t_first, t == t2, t_first == t2, t2)'
		assert_equal "Hello", out.values.first
		assert out.values[1]
		refute out.values[2]
		assert_equal ["Hello", "from", "Tuple"], out.values.last.values
	end

	def test_empty_dictionary
		out = Ore.interp '{}'
		assert_kind_of Hash, out
		assert_equal out, {}
	end

	def test_create_dictionary_with_identifiers_as_keys_without_commas
		out = Ore.interp '{a b c}'
		assert_equal %i(a b c), out.keys
		out.values.each do |value|
			assert_instance_of NilClass, value
		end
	end

	def test_create_dictionary_with_identifiers_as_keys_with_commas
		out = Ore.interp '{a, b}'
		out.values.each do |value|
			assert_instance_of NilClass, value
		end
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation
		out = Ore.interp '{ x:0 y=1 z}'
		refute_instance_of NilClass, out.values.first
		refute_instance_of NilClass, out.values[1]
		assert_instance_of NilClass, out.values.last
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation_and_commas
		out = Ore.interp '{ x:4, y=8, z}'
		assert_equal 4, out.values.first
		assert_equal 8, out.values[1]
		assert_instance_of NilClass, out.values.last
	end

	def test_create_dictionary_with_local_value
		out = Ore.interp 'x=4, y=2, { x=x, y=y }'
		assert_equal out, { x: 4, y: 2 }
	end

	def test_symbol_as_dictionary_keys
		out = Ore.interp '{ :x = 1 }'
		assert_equal out, { x: 1 }
	end

	def test_string_as_dictionary_keys
		out = Ore.interp '{ "x" = 1 }'
		assert_equal out, { x: 1 }
	end

	def test_colon_as_dictionary_infix_operator
		out = Ore.interp 'x = 123, { x: x }'
		assert_equal out, { x: 123 }
	end

	def test_equals_as_dictionary_infix_operator
		out = Ore.interp 'x = 123, { x = x }'
		assert_equal out, { x: 123 }
	end

	def test_invalid_dictionary_infix
		assert_raises Ore::Invalid_Dictionary_Infix_Operator do
			Ore.interp '{ x > x }'
		end
	end

	def test_assigning_function_to_variable
		out = Ore.interp 'funk = { a, b, c; }'
		assert_equal 3, out.expressions.count
	end

	def test_composed_type_declaration
		out = Ore.interp '
		Transform {}
		Rotation {}
		Entity {
			| Transform
			~ Rotation
		}'
		assert_kind_of Ore::Type, out
		assert_kind_of Ore::Composition_Expr, out.expressions.first
		assert_kind_of Ore::Composition_Expr, out.expressions.last
		assert_equal 'Rotation', out.expressions.last.identifier.value
		assert_equal '~', out.expressions.last.operator
	end

	def test_composed_type_declaration_before_body
		out = Ore.interp '
		Transform {}, Physics {}
		Entity | Transform ~ Physics {}'
		assert_kind_of Ore::Type, out
		assert_kind_of Ore::Composition_Expr, out.expressions.first
		assert_kind_of Ore::Composition_Expr, out.expressions.last
		assert_equal 'Physics', out.expressions.last.identifier.value
		assert_equal '~', out.expressions.last.operator
	end

	def test_complex_type_declaration
		out = Ore.interp 'Transform {
			position;
			rotation;

			x = 0
			y = 0

			to_s {;
				"Transform!"
			}
		}'
		assert_kind_of Ore::Postfix_Expr, out.expressions[0]
		assert_kind_of Ore::Infix_Expr, out.expressions[2]
		assert_kind_of Ore::Infix_Expr, out.expressions[3]
		assert_kind_of Ore::Func_Expr, out.expressions[4]
	end

	def test_undeclared_type_init_with_new_keyword
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp 'Type.new'
		end
	end

	def test_raises_non_type_initialization_error
		assert_raises Ore::Cannot_Initialize_Non_Type_Identifier do
			Ore.interp 'x = 1, x.new'
		end
	end

	def test_declared_type_init_with_new_keyword
		out = Ore.interp 'Type {}, Type.new'
		assert_instance_of Ore::Instance, out
		assert_equal 'Type', out.name
	end

	def test_complex_type_init
		out = Ore.interp 'Transform {
			position;
			rotation;

			x = 4
			y = 8

			to_s {;
				"Transform!"
			}

			new { position; }
		}, Transform.new'
		assert_kind_of Ore::Instance, out
		assert_equal 'Transform', out.name
		assert_kind_of ::Array, out.expressions
		assert_equal 6, out.expressions.count
		assert_kind_of Ore::Func_Expr, out.expressions.last
	end

	def test_complex_type_with_value_lookup
		out = Ore.interp 'Vector1 { x = 4 }
		Vector1.new.x
		'
		assert_equal 4, out
	end

	def test_instance_complex_value_lookup
		out = Ore.interp 'Vector2 { x = 1, y = 2 }
		Transform {
			position = Vector2.new
		}
		t = Transform.new
		(t.position, t.position.y)
		'
		assert_kind_of Ore::Tuple, out
		assert_kind_of Ore::Instance, out.values.first
		assert_equal 2, out.values.last
	end

	def test_type_declaration_with_parens
		out = Ore.interp 'Vector2 { x = 0, y = 1 }
		pos = Vector2()'
		assert_instance_of Ore::Instance, out
		data = { 'x' => 0, 'y' => 1 }
		assert_equal data, out.declarations
	end

	def test_dot_slash
		out = Ore.interp './x = 123'
		assert_equal 123, out
	end

	def test_look_up_dot_slash_without_dot_slash
		out = Ore.interp './x = 123
		x'
		assert_equal 123, out
	end

	def test_look_up_dot_slash_with_dot_slash
		out = Ore.interp './y = 543
		./y'
		assert_equal 543, out
	end

	def test_function_call_with_arguments
		out = Ore.interp '
		add { a, b; a+b }
		add(4, 8)'
		assert_equal 12, out
	end

	def test_compound_operator
		out = Ore.interp 'add { amount = 1, to = 0;
			to += amount
		}
		add(5, 37)'
		assert_equal 42, out
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

		out = Ore.interp "#{shared_code}
		A.B"
		assert_instance_of Ore::Type, out

		out = Ore.interp "#{shared_code}
		A.B.C.new"
		assert_instance_of Ore::Instance, out

		out = Ore.interp "#{shared_code}
		A.B.C.new.d"
		assert_equal 4, out
	end

	def test_closures_do_not_exist
		out = Ore.interp '
		counter = -1
		increment { count;
			counter += count
		}
		increment(counter)
		counter
		'
		assert_equal -2, out
	end

	def test_calling_functions
		refute_raises RuntimeError do
			out = Ore.interp '
			square { input;
				input * input
			}

			result = square(5)
			result'
			assert_equal 25, out
		end
	end

	def test_function_call_as_argument
		out = Ore.interp '
		add { amount = 1, to = 4;
			to + amount
		}
		inc = add() `should return 5
		add(inc, 1)'
		assert_equal 6, out
	end

	def test_complex_return_with_simple_conditional
		out = Ore.interp 'return (1+2*3/4) + (1+2*3/4) if 1 + 2 > 2'
		assert_equal 4, out.value
	end

	def test_truthy_falsy_logic
		assert_equal 1, Ore.interp('if true 1 else 0 end')
		assert_equal 0, Ore.interp('if 0 1 else 0 end')
		assert_equal 0, Ore.interp('if nil 1 else 0 end')
	end

	def test_returns_with_end_of_line_conditional
		out = Ore.interp 'return 3 if true'
		assert_equal 3, out.value
	end

	def test_standalone_array_index_expr
		out = Ore.interp '4.8.15.16.23.42'
		assert_equal [4, 8, 15, 16, 23, 42], out
	end

	def test_array_access_by_dot_index
		out = Ore.interp 'things = [4, 8, 15]
		things.0'
		assert_equal 4, out
	end

	def test_nested_array_access_by_dot_index
		out = Ore.interp 'things = [4, [8, 15, 16], 23, [42, 108, 418, 3]]
		(things.1.0, things.3.1)'
		assert_instance_of Ore::Tuple, out
		assert_equal 8, out.values.first
		assert_equal 108, out.values.last
	end

	def test_function_scope
		out = Ore.interp 'x = 123
		double {; x * 2 }
		double()'
		assert_equal 246, out
	end

	def test_function_scope_some_more
		out = Ore.interp 'x = 108

		Doubler {
			double {; x * 2 }
		}

		Doubler().double()'
		assert_equal 216, out
	end

	def test_returns
		out = Ore.interp 'return 1'
		assert_instance_of Ore::Return, out
		assert_equal 1, out.value

		out = Ore.interp '
		eject {;
			if true
				return "true!"
			end

			return "should not get here"
		}
		eject()'
		assert_instance_of Ore::Return, out
		assert_equal "true!", out.value
	end

	def test_type_does_have_new_function
		out = Ore.interp '
		Atom {
			new {;}
		}'
		assert out.has? :new
	end

	def test_instance_does_not_have_new_function
		out = Ore.interp '
		Atom {
			new {;}
		}
		a = Atom()
		b = Atom.new()
		(a, b)'
		refute out.values.first.has? :new
		refute out.values.last.has? :new
	end

	def test_while_loops
		out = Ore.interp '
		x = 0
		while x < 4
			x += 1
		end
		x'
		assert_equal 4, out
	end

	def test_fancy_while_loops
		out = Ore.interp '
		x = 0
		y = 0
		z = 0
		while x < 4
			x += 1
		elwhile y > -8
			y -= 1
		else
			z = 1_516
		end
		(x, y, z)'
		assert_equal [4, -8, 1516], out.values
	end

	def test_until_loops
		out = Ore.interp '
		x = 1
		until x >= 23
			x += 2
		end
		'
		assert_equal 23, out
	end

	def test_fancy_until_loops
		out = Ore.interp '
		x = 1
		y = 0
		until x >= 23
			x += 2
		else
			y = x
		end
		(x, y)
		'
		assert_equal [23, 23], out.values
	end

	def test_control_flows_as_expressions
		out = Ore.interp '
		condition = false
		x = unless condition `Equivalent to "if !condition"
			4
		else
			-4
		end
		'
		assert_equal 4, out
	end

	def test_if_and_unless_control_flows
		out = Ore.interp '
		a = if true
			4
		end

		b = if false
			8
		end

		c = unless true
			15
		end

		d = if not true
			23
		else
			16
		end

		(a, b, c, d)
		'
		assert_equal [4, nil, nil, 16], out.values
	end

	def test_nil_instances_are_shared
		out = Ore.interp '
		x;
		y;

		equal = x == y
		(x, y, equal)'
		assert_equal out.values[0].object_id, out.values[1].object_id
		assert_equal true, out.values[2]
	end

	def test_accessing_declarations_through_type_composition
		out = Ore.interp "
		Vec2 {
			x = 0, y = 0

			new { x, y;
				./x = x
				./y = y
			}

			multiply! { times;
				./x *= times
				./y *= times
			}

		}

		Transform | Vec2 {
			new { position = Vec2();
				./x = position.x
				y = position.y
			}

			to_s {;
				'Transform(|x|,|y|)'
			}

			scale! { value;
				multiply!(value)
			}
		}

		pos = Vec2(4, 8)
		t = Transform(pos)
		a = t.to_s()
		t.scale!(3)
		b = t.to_s()

		`Let's remove Vec2 from a type that composes with Transform
		Xform | Transform ~ Vec2 {}

		(a, b, t)"

		# Testing in order of the values in the tuple
		assert_equal "Transform(4,8)", out.values[0]
		assert_equal "Transform(12,24)", out.values[1]

		assert_instance_of Ore::Instance, out.values[2]
		assert_equal 12, out.values[2][:x]
		assert_equal 24, out.values[2][:y]
	end

	def test_random_composition_example
		refute_raises Ore::Undeclared_Identifier do
			out = Ore.interp "
			Vec2 {
				x = 0, y = 0

				new { x, y;
					./x = x
					./y = y
				}
			}

			Transform | Vec2 {
				new { position = Vec2();
					./x = position.x
					y = position.y
				}
			}

			Xform | Transform ~ Vec2 {}

			Xform(Vec2(23, 42))
			"
			assert_instance_of Ore::Instance, out
			assert_equal ['Xform', 'Transform'], out.types
		end
	end

	def test_union_composition
		refute_raises Ore::Undeclared_Identifier do
			out = Ore.interp '
			Aa {
				a = 1
			}
			Bb {
				a = 4; b = 2; unique = 10
			}

			Union | Aa | Bb {}

			u = Union()
			(u.a, u.b, u.unique)
			'
			assert_equal [1, 2, 10], out.values
		end
	end

	def test_difference_composition
		shared_code = "
			Aa {
				a = 8
				common = 15
			}

			Bb {
				b = 42
				common = 16
			}

			AaBb | Aa | Bb {}

			Diff | AaBb ~ Bb {
				common = 23
			}

			d = Diff()".freeze

		refute_raises Ore::Undeclared_Identifier do
			out = Ore.interp "#{shared_code}
			a = Aa()
			b = Bb()
			(d.a, a.common, b.common, d.common)"
			assert_equal [8, 15, 16, 23], out.values
		end

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			d.b"
		end
	end

	def test_intersection_composition
		shared_code = "
			Aa { a = 4;  common = 8 }
			Bb { b = 15; common = 16 }

			Intersected | Aa & Bb {}

			i = Intersected()"

		refute_raises Ore::Undeclared_Identifier do
			out = Ore.interp "#{shared_code}
			i.common"
			assert_equal 8, out
		end

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			i.a"
		end

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			i.b"
		end
	end

	def test_symmetric_difference_composition
		shared_code = "
			Aa { a = 4; common = 10 }
			Bb { b = 8; common = 10 }

			Sym_Diff | Aa ^ Bb {}
			s = Sym_Diff()\n"

		out = Ore.interp "#{shared_code} (s.a, s.b)"
		assert_equal [4, 8], out.values

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code} s.common"
		end
	end

	def test_union_composition_is_left_biased
		out = Ore.interp "
		Aa { a = 4 }
		Bb { a = 8 }
		Union | Aa | Bb {}
		Union().a"
		assert_equal 4, out
	end

	def test_composition_with_inbody_declarations
		out = Ore.interp "
		Aa { a = 15 }
		Bb { a = 16; b; }
		Union {
			`With or without space is valid
			| Aa
			|Bb
		}
		u = Union()
		(u.a, u.b)"
		assert_equal [15, nil], out.values
	end

	def test_routes
		out = Ore.interp 'get://some/thing/:id { id;
			do_something()
		}'

		assert_instance_of Ore::Route, out
		assert_equal 'Ore::Route', out.name
		assert_equal 'get', out.http_method.value
		assert_equal 'some/thing/:id', out.path
		assert_equal 2, out.handler.expressions.count
	end

	def test_html_element
		out = Ore.interp "<My_Div> {
			element = 'div'

			id = 'my_div'
			class = 'my_class'
			data_something = 'some data attribute'

			render {;
				'Text content of this div'
			}
		}

		it = My_Div()
		(My_Div, it, it.render())"
		assert_instance_of Ore::Html_Element, out.values[0]
		assert_instance_of Ore::Instance, out.values[1]
		assert_instance_of String, out.values[2]
		assert_equal 'Text content of this div', out.values[2]
	end

	def test_loading_external_source_files
		out = Ore.interp "#load 'ore/preload.ore'; (Bool, Bool())"

		assert_instance_of Ore::Type, out.values[0]
		assert_instance_of Ore::Instance, out.values[1]
	end

	def test_standalone_load_into_current_scope
		out = Ore.interp "#load 'test/samples/test_module.ore'
		(MODULE_NAME, MODULE_VALUE, module_func(10))"

		assert_instance_of Ore::Tuple, out
		assert_equal "Test_Module", out.values[0]
		assert_equal 42, out.values[1]
		assert_equal 20, out.values[2]
	end

	def test_load_assignment_into_variable_identifier
		out = Ore.interp "mod = #load 'test/samples/test_module.ore'
		(mod, mod.MODULE_NAME, mod.MODULE_VALUE, mod.module_func(10))"

		assert_instance_of Ore::Tuple, out
		assert_instance_of Ore::Scope, out.values[0]
		assert_equal "Test_Module", out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 20, out.values[3]

		# Verify declarations are NOT in current scope
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "mod = #load 'test/samples/test_module.ore'
			MODULE_NAME"
		end
	end

	def test_load_assignment_into_class_identifier
		out = Ore.interp "Module = #load 'test/samples/test_module.ore'
		(Module, Module.MODULE_NAME, Module.MODULE_VALUE, Module.module_func(10))"

		assert_instance_of Ore::Tuple, out
		assert_instance_of Ore::Scope, out.values[0]
		assert_equal "Test_Module", out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 20, out.values[3]

		# Verify declarations are NOT in current scope
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "Module = #load 'test/samples/test_module.ore'
			MODULE_NAME"
		end
	end

	def test_load_assignment_into_constant_identifier
		out = Ore.interp "MODULE = #load 'test/samples/test_module.ore'
		(MODULE, MODULE.MODULE_NAME, MODULE.MODULE_VALUE, MODULE.module_func(10))"

		assert_instance_of Ore::Tuple, out
		assert_instance_of Ore::Scope, out.values[0]
		assert_equal "Test_Module", out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 20, out.values[3]

		# Verify declarations are NOT in current scope
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "MODULE = #load 'test/samples/test_module.ore'
			MODULE_NAME"
		end
	end

	def test_load_same_file_into_multiple_scopes
		out = Ore.interp "
		lib1 = #load 'test/samples/test_module.ore'
		lib2 = #load 'test/samples/test_module.ore'

		(lib1, lib2, lib1.MODULE_VALUE, lib2.MODULE_VALUE, lib1 != lib2)"

		assert_instance_of Ore::Tuple, out
		assert_instance_of Ore::Scope, out.values[0]
		assert_instance_of Ore::Scope, out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 42, out.values[3]
		assert out.values[4]

		# Scopes are different objects even though loaded from same file
		refute_equal out.values[0].object_id, out.values[1].object_id
	end

	def test_double_loading_file
		assert_raises Ore::Cannot_Reassign_Constant do
			out = Ore.interp "
			#load 'test/samples/constants.ore'
			#load 'test/samples/constants.ore'"
		end
	end

	def test_for_loop
		out = Ore.interp "
		NUMBERS = [4, 8, 15, 16, 23, 42]
		numbers = []

		for NUMBERS
			numbers << it
		end

		(numbers == NUMBERS, numbers, NUMBERS)"
		assert out.values[0]
	end

	def test_for_loop_by_strides
		out = Ore.interp "
		NUMBERS = [4, 8, 15, 16, 23, 42]
		numbers = []

		for NUMBERS by 2
			numbers << it
		end

		numbers"
		assert_equal [[4, 8], [15, 16], [23, 42]], out.values
	end

	def test_for_loop_at_and_it_intrinsics
		out = Ore.interp "
		indices = []

		for [4, 8, 15, 16, 23, 42]
			indices << '|at|: |it|'
		end

		indices"
		assert_equal ['0: 4', '1: 8', '2: 15', '3: 16', '4: 23', '5: 42'], out.values
	end

	def test_for_loop_with_ranges
		out = Ore.interp "
		zero = []
		one = []
		two = []
		three = []

		for 1..5
			zero << it
		end

		for 1><5
			one << it
		end

		for 1>.5
			two << it
		end

		for 1.<5
			three << it
		end


		(zero, one, two, three)"
		assert_equal [1, 2, 3, 4, 5], out.values[0].values
		assert_equal [2, 3, 4], out.values[1].values
		assert_equal [2, 3, 4, 5], out.values[2].values
		assert_equal [1, 2, 3, 4], out.values[3].values
	end

	def test_for_loop_skip
		out = Ore.interp "
		result = []
		for [1, 2, 3, 4, 5]
			if it == 3
				skip
			end
			result << it
		end
		result"
		assert_equal [1, 2, 4, 5], out.values
	end

	def test_for_loop_stop
		out = Ore.interp "
		result = []
		for [1, 2, 3, 4, 5]
			if it == 3
				stop
			end
			result << it
		end
		result"
		assert_equal [1, 2], out.values
	end

	def test_for_loop_skip_with_index
		out = Ore.interp "
		result = []
		for ['a', 'b', 'c', 'd']
			if at == 1 or at == 2
				skip
			end
			result << it
		end
		result"
		assert_equal ['a', 'd'], out.values
	end

	def test_for_loop_stop_with_index
		out = Ore.interp "
		result = []
		for ['a', 'b', 'c', 'd']
			if at == 2
				stop
			end
			result << it
		end
		result"
		assert_equal ['a', 'b'], out.values
	end

	def test_nested_for_loop_stop
		out = Ore.interp "
		result = []

		for 0..10
			skip if it == 4

			if it % 2 == 0
				result << 'START |it|'
				for 0..10
					result << it
					stop if it == 2
				end
				result << 'STOP |it|'
			end

			if it == 6
				stop
			end
		end

		result
		"
		assert_equal ["START 0", 0, 1, 2, "STOP 0", "START 2", 0, 1, 2, "STOP 2", "START 6", 0, 1, 2, "STOP 6"], out.values
	end

	def test_while_loop_skip
		out = Ore.interp "
		result = []
		x = 0
		while x < 5
			x += 1
			if x == 3
				skip
			end
			result << x
		end
		result"
		assert_equal [1, 2, 4, 5], out.values
	end

	def test_while_loop_stop
		out = Ore.interp "
		result = []
		x = 0
		while x < 10
			x += 1
			if x == 4
				stop
			end
			result << x
		end
		result"
		assert_equal [1, 2, 3], out.values
	end

	def test_until_loop_skip
		out = Ore.interp "
		result = []
		x = 0
		until x >= 5
			x += 1
			if x == 2 or x == 4
				skip
			end
			result << x
		end
		result"
		assert_equal [1, 3, 5], out.values
	end

	def test_until_loop_stop
		out = Ore.interp "
		result = []
		x = 0
		until x >= 10
			x += 1
			if x == 3
				stop
			end
			result << x
		end
		result"
		assert_equal [1, 2], out.values
	end
end
