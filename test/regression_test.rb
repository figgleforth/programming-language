require 'minitest/autorun'
require './src/shared/helpers'

class Regression_Test < Minitest::Test
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

	def test_greater_equals_regression
		out = _interp '2+1 >= 1'
		assert out

		out = _interp 'return 1+2*3/4%5-6 unless 1 + 2 >= 10'
		assert_equal -4, out.value
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
end
