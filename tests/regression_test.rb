require 'minitest/autorun'
require './code/ruby/shared/helpers'

class Regression_Test < Minitest::Test
	def test_greater_equals_regression
		out = _interp '2+1 >= 1'
		assert out
	end

	def test_precedence_operation_regression
		src = _interp '1 + 2 / 3 - 4 * 5'
		ref = _interp '(1 + (2 / 3)) - (4 * 5)'
		assert_equal ref, src
		assert_equal -19, src
	end

	def test_infixes_regression
		COMPOUND_OPERATORS.each do |operator|
			code = "left #{operator} right"
			out  = _parse(code)
			assert_kind_of Infix_Expr, out.first
		end
	end

	def test_dot_slashes_regression
		invalid_samples = [
			'./', '../', '.../',
		]

		invalid_samples.each do |sample|
			assert_raises Malformed_Scoped_Identifier do
				_parse sample
			end
		end

		ds   = _parse './abc'
		dds  = _parse '../def'
		ddds = _parse '.../ghi'
		assert_kind_of Identifier_Expr, ds.first
		assert_kind_of Identifier_Expr, dds.first
		assert_kind_of Identifier_Expr, ddds.first

		ds = _parse './abc'
		assert_kind_of Identifier_Expr, ds.last
		assert_equal './', ds.last.scope_operator
		assert_equal 'abc', ds.last.value
	end

	def test_dot_slash_regression
		out = _interp './x = 123'
		assert_equal 123, out
	end

	def test_look_up_dot_slash_without_dot_slash_regression
		out = _interp './x = 456
		x'
		assert_equal 456, out
	end

	def test_look_up_dot_slash_with_dot_slash_regression
		out = _interp './y = 789
		./y'
		assert_equal 789, out
	end

	def test_dot_slash_within_infix_regression
		out = _parse './x? = 123'
		assert_kind_of Infix_Expr, out.first
		assert_equal '=', out.first.operator
		assert_equal 'x?', out.first.left.value
		assert_kind_of Identifier_Expr, out.first.left
		assert_equal './', out.first.left.scope_operator
	end

	def test_scope_operators_regression
		out = _parse './this_instance'
		assert_kind_of Identifier_Expr, out.first
		assert_equal 1, out.count

		out = _parse '../one_up_the_stack'
		assert_kind_of Identifier_Expr, out.first
		assert_equal 1, out.count

		out = _parse '.../global_scope'
		assert_kind_of Identifier_Expr, out.first
		assert_equal 1, out.count
	end

	def test_assigning_false_value_regression
		out = _interp 'how = false
		how'
		assert_equal false, out
	end

	def test_identifier_lookup_regression
		out = _interp 'Air {}, Air'
		assert_instance_of Type, out
	end

	def test_instance_does_not_have_new_function_regression
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

	def test_dot_new_initializer_regression
		out = _interp 'Number {
			numerator = 8

			new { num;
				./numerator = num
			}
		}
		x = Number.new(15)
		x.numerator'
		assert_equal 15, out
	end

	def test_calling_member_functions
		out = _interp '
		Number {
			numerator = -100

			new { num;
				./numerator = num
			}
		}
		x = Number(4)
		x.numerator'
		assert_equal 4, out
	end

	def test_dot_slash_regression
		out = _interp '
		Box {
			kind = "NONE"

			new { new_kind;
				./kind = new_kind
			}

			to_s {;
				"|kind|-box"
			}
		}

		b1 = Box("Big")
		s1 = b1.to_s()
		b2 = Box("Small")
		s2 = b2.to_s()
		(b1, s1, b2, s2)
		'
		assert_instance_of Instance, out.values[0]
		assert_equal "Big-box", out.values[1]
		assert_equal "Small-box", out.values[3]
	end

	def test_identifier_lookup_regression
		out = _interp "./x = 123, ./x"
		assert_equal 123, out

		out = _interp "x = 123
		funk {;
			./x + 2
		}
		funk()"
		assert_equal 125, out

		out = _interp "y = 0
		add { amount_to_add = 1;
			./y + amount_to_add
		}
		(a = add(4))

		(a, add(a * 2))"
		assert_equal [4, 8], out.values

		out = _interp "y = 0
		add { amount_to_add = 1;
			y += amount_to_add
		}
		a = add(4)

		(y, a)"
		assert_equal [4, 4], out.values

		refute_raises Undeclared_Identifier do
			out = _interp "
			Thing {
				id;
				name = 'Thingy'

				new { new_name = '', id = 123;
					./name = new_name
					./id = id
				}
			}

			t1 = Thing()
			t2 = Thing('Thingus', 456)

			(t1.id, t1.name, t2.id, t2.name)"
			assert_equal [123, "", 456, "Thingus"], out.values
		end

		assert_raises Missing_Argument do
			out = _interp "
			Thing {
				id;
				name = 'Thingy';

				new { new_name, id;
					./name = new_name
					./id = id
				}
			}

			t = Thing() `This will raise
			(t.id, t.name)"
			assert_equal [456, "Thingus"], out.values
		end

		assert_raises Missing_Argument do
			_interp "
	        funk { it;
				it == true
			}
			funk() `This will raise
			"
		end

		refute_raises Undeclared_Identifier do
			_interp "
			funk { it;
				it == true
			}
			funk(true), funk(false)
			"
		end

		refute_raises Undeclared_Identifier do
			_interp "
			funk { it = \"true\";
				it == true
			}
			funk(true), funk()
			"
		end

		refute_raises Undeclared_Identifier do
			_interp "
			funk { it = \"false\";
				it == true
			}
			funk(true), funk()
			"
		end

		refute_raises Undeclared_Identifier do
			_interp "
			funk { it = true;
				it == true
			}
			funk(true), funk()
			"
		end

		refute_raises Undeclared_Identifier do
			_interp "
			funk { funkit = false;
				funkit == true
			}
			funk(true), funk()
			"
		end

		refute_raises Undeclared_Identifier do
			_interp "
		funk { it = nil;
			it == true
		}
		funk(true), funk()
		"
		end
	end
end
