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
			id;
			size;

			new { id, size;
				./id = id
				./size = size
			}

			to_s {;
				"Box #|./id||./size|"
			}

			with_args { id, size;
				"Box #|./id||./size|"
			}

			with_args_calls_without { id, size;
				./id = id
				./size = size
				to_s()
			}

			without_dot_slash { id, size;
				id = id
				size = size
				to_s()
			}
		}


		b1 = Box("A", 4)
		l1 = b1.to_s()

		b2 = Box("B", 8)
		l2 = b2.with_args("B", 8)

		b3 = Box("C", 23)
		l3 = b3.with_args_calls_without("C", 23)

		b4 = Box("D", 42)
		l4 = b4.without_dot_slash("D", 42)

		(l1, l2, l3, l4)'
		l1  = out.values[0]
		l2  = out.values[1]
		l3  = out.values[2]
		l4  = out.values[3]
		assert_equal 'Box #A4', l1
		assert_equal 'Box #B8', l2
		assert_equal 'Box #C23', l3
		assert_equal 'Box #D42', l4
	end

	def test_assigning_false_value_regression
		skip
		out = _interp 'wip? = true, wip?'
		assert_equal true, out

		out = _interp 'wip? = false, wip?'
		assert_equal false, out # The value here is nil instead of false
	end
end
