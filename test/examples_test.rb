require 'minitest/autorun'
require_relative '../lib/air'

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
		assert_instance_of Air::Tuple, out
		out.values.each do |it|
			assert_instance_of Air::Array, it
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

	def test_more_realistic_example
		out = _interp "
		Server {
			port;
			running = false

			new { port = 4815;
				./port = port
			}

			start! {;
				./running = true
			}

			stop! {;
				running = false
			}

			running? {;
				running
			}

		}

		s = Server()
		_running? = s.running?()
		s.start!()
		a = s.running?()
		s.stop!()
		b = s.running?()
		(_running?, a, b, s.port, s, s.start!, s.running?)
		"
		assert_equal [false, true, false, 4815], out.values[0..3]
		assert_instance_of Air::Instance, out.values[4]
		assert_instance_of Air::Func, out.values[5]
		assert_instance_of Air::Func, out.values[6]
	end

	def test_nested_scopes
		out = _interp "
		outer = 1

		global_add { left, right; left + right }

		increment { value = 1;
			inner = 3

			add { value;
				increment {;
					.../global_add(outer, value) `.../ is the decorator/prefix that says to look in the global scope directly for 'global_add'
				}

				increment()
			}

			add(inner)
		}

		increment()"
		assert_equal 4, out
	end
end
