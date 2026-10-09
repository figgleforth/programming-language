require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

class Rational_Test < Base_Test
	def test_construction_from_two_integers
		assert_equal 1r/3, Code.interp("Rational(1, 3).value")
		assert_equal "1/3", Code.interp("Rational(1, 3).to_s()")
	end

	def test_construction_reduces_the_fraction
		assert_equal "1/2", Code.interp("Rational(2, 4).to_s()")
	end

	def test_construction_defaults
		assert_equal 0r, Code.interp("Rational().value")
		assert_equal 3r, Code.interp("Rational(3).value")
	end

	def test_construction_from_a_float_uses_the_simplest_fraction
		assert_equal "17/50", Code.interp("Rational(0.34).to_s()")
		assert_equal "1/2", Code.interp("Rational(0.5).to_s()")
	end

	def test_construction_from_a_string
		assert_equal "1/108", Code.interp("Rational('1/108').to_s()")
		assert_equal 0r, Code.interp("Rational('not a number').value")
	end

	def test_type_identity
		assert_equal true, Code.interp("Rational(1, 3) === Rational")
		assert_equal true, Code.interp("Rational(1, 3) =>= Number")
		assert_equal false, Code.interp("Rational(1, 3) === Float")
	end

	def test_annotation
		refute_raises do
			Code.interp "x: Rational = Rational(1, 4)"
		end
	end

	def test_addition_is_exact
		out = Code.interp <<~CODE
			sum := Rational(1, 3) + Rational(1, 6)
			sum == Rational(1, 2)
		CODE
		assert_equal true, out
	end

	def test_arithmetic_result_is_a_rational
		assert_equal true, Code.interp("(Rational(1, 3) + Rational(1, 6)) === Rational")
		assert_equal 1r/9, Code.interp("Rational(1, 3) * Rational(1, 3)")
		assert_equal 1r/6, Code.interp("Rational(1, 2) - Rational(1, 3)")
		assert_equal 3r/2, Code.interp("Rational(1, 2) / Rational(1, 3)")
	end

	def test_mixed_arithmetic_follows_ruby
		assert_equal true, Code.interp("(Rational(1, 2) + 1) === Rational")
		assert_equal true, Code.interp("(Rational(1, 2) + 0.5) === Float")
	end

	def test_many_small_steps_stay_exact
		# A Float drifts here: 17 steps of 1.0 / 108 give 0.15740740740740738, not 17.0 / 108.
		out = Code.interp <<~CODE
			step  := Rational(1, 108)
			added := Rational(0)
			added += step for 1..17
			added == Rational(17, 108)
		CODE
		assert_equal true, out
	end

	def test_equality
		assert_equal true, Code.interp("Rational(1, 2) == Rational(2, 4)")
		assert_equal false, Code.interp("Rational(1, 2) == Rational(1, 3)")
		assert_equal true, Code.interp("Rational(1, 2) != Rational(1, 3)")
		assert_equal true, Code.interp("Rational(3) == 3")
		assert_equal false, Code.interp("Rational(3) == nil")
		assert_equal false, Code.interp("Rational(3) == 'x'")
	end

	def test_comparison
		assert_equal true, Code.interp("Rational(1, 3) < Rational(1, 2)")
		assert_equal true, Code.interp("Rational(1, 2) >= Rational(2, 4)")
		assert_equal true, Code.interp("Rational(1, 3) < 0.5")
	end

	def test_numerator_and_denominator
		assert_equal 3, Code.interp("Rational(6, 8).numerator()")
		assert_equal 4, Code.interp("Rational(6, 8).denominator()")
	end

	def test_integer_division_is_unchanged
		assert_equal 3, Code.interp("7 / 2")
	end
end
