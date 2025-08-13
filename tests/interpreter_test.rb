require 'minitest/autorun'
require './code/ruby/shared/helpers'

class Interpreter_Test < Minitest::Test
	def test_preload_dot_air
		refute_raises RuntimeError do
			_interp_file './code/air/preload.air'
		end
	end

	def test_numeric_literals
		assert_equal 48, _interp('48')
		assert_equal 15.16, _interp('15.16')
		assert_equal 2342, _interp('23_42')
	end

	def test_true_false_nil_literals
		assert_equal true, _interp('true')
		assert_equal false, _interp('false')
		assert_instance_of NilClass, _interp('nil')
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
		assert_instance_of NilClass, out
	end

	def test_anonymous_func_expr
		out = _interp '{;}'
		assert_instance_of Air::Func, out
		assert_empty out.expressions
		assert_nil out.name
	end

	def test_empty_func_declaration
		out = _interp 'open {;}'
		assert_instance_of Air::Func, out
		assert_empty out.expressions
		assert_equal 'open', out.name
	end

	def test_basic_func_declaration
		out = _interp 'enter { numbers = "4815162342"; }'
		assert_equal 1, out.expressions.count
		assert_instance_of Param_Expr, out.expressions.first
		assert_instance_of String_Expr, out.expressions.first.default
	end

	def test_advanced_func_declaration
		out = _interp 'add { a, b; a + b }'
		assert_equal 3, out.expressions.count
		assert_instance_of Infix_Expr, out.expressions.last
		refute out.expressions.first.default
	end

	def test_complex_func_declaration
		out = _interp 'run { a, labeled b, c = 4, labeled d = 8;
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

		assert_instance_of Infix_Expr, out.expressions.last
	end

	def test_empty_type_declaration
		out = _interp 'Island {}'
		assert_instance_of Air::Type, out
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
		assert_instance_of Air::Type, out
		assert_instance_of NilClass, out[:computer]
		assert_instance_of Air::Func, out[:enter]
	end

	def test_inline_type_composition_declaration
		out = _interp 'Number {}
		Integer | Number {}'
		assert_instance_of Air::Type, out
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
		assert_instance_of Air::Type, out
		assert_equal %w(Float Number Numeric), out.types
	end

	def test_invalid_type_declaration
		assert_raises Undeclared_Identifier do
			_interp 'Number | Numeric {}'
		end
	end

	def test_potential_colon_ambiguity
		out = _interp 'assign_to_nil;'
		assert_instance_of NilClass, out

		out = _interp 'func { assign_to_nil; }'
		assert_instance_of Air::Func, out
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
		assert_instance_of Air::Type, out
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
		assert_instance_of Air::Array, out
	end

	def test_non_empty_arrays
		out = _interp '[1]'
		assert_instance_of Air::Array, out
		assert_equal [1], out.values

		out = _interp '[1, "test", 5]'
		assert_instance_of Air::Array, out
		assert_equal Air::Array.new([1, 'test', 5]).values, out.values
	end

	def test_create_tuple
		out = _interp 'x = (1, 2)'
		assert_kind_of Air::Tuple, out
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
			assert_instance_of NilClass, value
		end
	end

	def test_create_dictionary_with_identifiers_as_keys_with_commas
		out = _interp '{a, b}'
		out.values.each do |value|
			assert_instance_of NilClass, value
		end
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation
		out = _interp '{ x:0 y=1 z}'
		refute_instance_of NilClass, out.values.first
		refute_instance_of NilClass, out.values[1]
		assert_instance_of NilClass, out.values.last
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation_and_commas
		out = _interp '{ x:4, y=8, z}'
		assert_equal 4, out.values.first
		assert_equal 8, out.values[1]
		assert_instance_of NilClass, out.values.last
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
			~ Rotation
		}'
		assert_kind_of Air::Type, out
		assert_kind_of Composition_Expr, out.expressions.first
		assert_kind_of Composition_Expr, out.expressions.last
		assert_equal 'Rotation', out.expressions.last.identifier.value
		assert_equal '~', out.expressions.last.operator
	end

	def test_composed_type_declaration_before_body
		out = _interp '
		Transform {}, Physics {}
		Entity | Transform ~ Physics {}'
		assert_kind_of Air::Type, out
		assert_kind_of Composition_Expr, out.expressions.first
		assert_kind_of Composition_Expr, out.expressions.last
		assert_equal 'Physics', out.expressions.last.identifier.value
		assert_equal '~', out.expressions.last.operator
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
		assert_instance_of Air::Instance, out
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
		assert_kind_of Air::Instance, out
		assert_equal 'Transform', out.name
		assert_kind_of Array, out.expressions
		assert_equal 6, out.expressions.count
		assert_kind_of Func_Expr, out.expressions.last
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
		assert_kind_of Air::Tuple, out
		assert_kind_of Air::Instance, out.values.first
		assert_equal 2, out.values.last
	end

	def test_type_declaration_with_parens
		out = _interp 'Vector2 { x = 0, y = 1 }
		pos = Vector2()'
		assert_instance_of Air::Instance, out
		data = { 'x' => 0, 'y' => 1 }
		assert_equal data, out.declarations
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
		assert_instance_of Air::Type, out

		out = _interp "#{shared_code}
		A.B.C.new"
		assert_instance_of Air::Instance, out

		out = _interp "#{shared_code}
		A.B.C.new.d"
		assert_equal 4, out
	end

	def test_closures_do_not_exist
		out = _interp '
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
		assert_instance_of Air::Tuple, out
		assert_equal 8, out.values.first
		assert_equal 108, out.values.last
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
		assert_instance_of Air::Return, out
		assert_equal 1, out.value

		out = _interp '
		eject {;
			if true
				return "true!"
			end

			return "should not get here"
		}
		eject()'
		assert_instance_of Air::Return, out
		assert_equal "true!", out.value
	end

	def test_type_does_have_new_function
		out = _interp '
		Atom {
			new {;}
		}'
		assert out.has? :new
	end

	def test_instance_does_not_have_new_function
		out = _interp '
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
		out = _interp '
		x = 0
		while x < 4
			x += 1
		end
		x'
		assert_equal 4, out
	end

	def test_fancy_while_loops
		out = _interp '
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
		out = _interp '
		x = 1
		until x >= 23
			x += 2
		end
		'
		assert_equal 23, out
	end

	def test_fancy_until_loops
		out = _interp '
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
		out = _interp '
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
		out = _interp '
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
		out = _interp '
		x;
		y;

		equal = x == y
		(x, y, equal)'
		assert_equal out.values[0].object_id, out.values[1].object_id
		assert_equal true, out.values[2]
	end

	def test_accessing_declarations_through_type_composition
		out = _interp "
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

		assert_instance_of Air::Instance, out.values[2]
		assert_equal 12, out.values[2][:x]
		assert_equal 24, out.values[2][:y]
	end

	def test_random_composition_example
		refute_raises Undeclared_Identifier do
			out = _interp "
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
			assert_instance_of Air::Instance, out
			assert_equal ['Xform', 'Transform'], out.types
		end
	end

	def test_union_composition
		refute_raises Undeclared_Identifier do
			out = _interp '
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

		refute_raises Undeclared_Identifier do
			out = _interp "#{shared_code}
			a = Aa()
			b = Bb()
			(d.a, a.common, b.common, d.common)"
			assert_equal [8, 15, 16, 23], out.values
		end

		assert_raises Undeclared_Identifier do
			_interp "#{shared_code}
			d.b"
		end
	end

	def test_intersection_composition
		shared_code = "
			Aa { a = 4;  common = 8 }
			Bb { b = 15; common = 16 }

			Intersected | Aa & Bb {}

			i = Intersected()"

		refute_raises Undeclared_Identifier do
			out = _interp "#{shared_code}
			i.common"
			assert_equal 8, out
		end

		assert_raises Undeclared_Identifier do
			_interp "#{shared_code}
			i.a"
		end

		assert_raises Undeclared_Identifier do
			_interp "#{shared_code}
			i.b"
		end
	end

	def test_symmetric_difference_composition
		shared_code = "
			Aa { a = 4; common = 10 }
			Bb { b = 8; common = 10 }

			Sym_Diff | Aa ^ Bb {}
			s = Sym_Diff()\n"

		out = _interp "#{shared_code} (s.a, s.b)"
		assert_equal [4, 8], out.values

		assert_raises Undeclared_Identifier do
			_interp "#{shared_code} s.common"
		end
	end

	def test_union_composition_is_left_biased
		out = _interp "
		Aa { a = 4 }
		Bb { a = 8 }
		Union | Aa | Bb {}
		Union().a"
		assert_equal 4, out
	end

	def test_composition_with_inbody_declarations
		out = _interp "
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

	def test_server_type
		# Since this is the first test to use Server, I want to call out that I'm passing `true` as the second arg to #_interp so that it'll call #preload_intrinsics on the Interpreter, so that Server is available
		out = _interp "
		App | Server {}

		app = App(4815)
		(app, app.port, app.routes)
		", true
		assert_instance_of Air::Instance, out.values[0]
		assert_equal %w(App Server), out.values[0].types

		assert out.values[0].has? :routes
		assert_nil out.values[0][:routes]
		assert out.values[0].has? :port
		assert_equal 4815, out.values[0][:port]

		assert_equal 4815, out.values[1]
		assert_nil out.values[2]

		assert_raises Undeclared_Identifier do
			# Passing false as the second argument (default behavior) does not preload intrinsics (which is where Server is declared)
			_interp "App | Server {}", false
		end
	end
end
