require 'minitest/autorun'
require './code/ruby/shared/helpers'

class Examples_Test < Minitest::Test
	def test_fizz_buzz
		out = _interp "
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

	def test_factorial
		out = _interp '
		factorial { n;
			if n == 0 or n == 1
				1
			else
				n * factorial(n - 1)
			end
		}
		factorial(8)
		'
		assert_equal 40320, out
	end

	def test_fibonacci
		out = _interp '
		fib { n;
			if n <= 1
				n
			else
				fib(n - 1) + fib(n - 2)
			end
		}
		[fib(0), fib(1), fib(2), fib(3), fib(4), fib(5)]'
		assert_equal [0, 1, 1, 2, 3, 5], out.values
	end

	def test_finding_max_value_in_array
		skip "This requires closures to exist and work properly."
		out = _interp '
		max? { list;
			max = -100
		    list.each {;
				if it > max
					max = it
				end
			}
		    max
		}
		max?([1,2,3,4,5])'
		assert_equal 5, out
	end
end
