require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

# lang/iterable.code: `Iterable` isn't auto-loaded (needs its own `@load`, see
# lang/readme.md) and isn't documented there either -- it's a small, work-in-progress
# base type (see its own `# todo` comment) that gives a composing type a `next(index -> Any)`
# method over a `collection: Array` member. `for` doesn't actually require `Iterable` itself --
# `#interp_for_loop` (ruby/interpreter.rb) falls back to calling *any* instance's own `next`
# method whenever the collection isn't a plain Array/Range/Set/etc, `Iterable` is just the
# ready-made way to get one. These tests cover both: composing `Iterable`, and hand-rolling the
# same `next`/`Done` protocol directly.
class Iterable_Test < Base_Test
	ITERABLE = "@load 'lang/iterable.code'"

	def test_composed_iterable_drives_a_for_loop
		out = Code.interp <<~CODE
		    #{ITERABLE}
		    Countdown | Iterable {
		        Self ( collection; self.collection = collection )
		    }
		    result := []
		    for Countdown([10, 20, 30])
		        result << it
		    end
		    result
		CODE
		assert_equal [10, 20, 30], out.values
	end

	def test_composed_iterable_exposes_it_and_at
		out = Code.interp <<~CODE
		    #{ITERABLE}
		    Countdown | Iterable {
		        Self ( collection; self.collection = collection )
		    }
		    pairs := []
		    for Countdown(['a', 'b', 'c'])
		        pairs << (at, it)
		    end
		    pairs
		CODE
		assert_equal [[0, 'a'], [1, 'b'], [2, 'c']], out.values.map(&:values)
	end

	def test_composed_iterable_supports_skip_and_stop
		out = Code.interp <<~CODE
		    #{ITERABLE}
		    Countdown | Iterable {
		        Self ( collection; self.collection = collection )
		    }
		    result := []
		    for Countdown([1, 2, 3, 4, 5])
		        if it == 3
		            skip
		        end
		        if it == 5
		            stop
		        end
		        result << it
		    end
		    result
		CODE
		assert_equal [1, 2, 4], out.values
	end

	def test_composing_iterable_gives_real_type_identity
		out = Code.interp <<~CODE
		    #{ITERABLE}
		    Countdown | Iterable {
		        Self ( collection; self.collection = collection )
		    }
		    Countdown([1]) =>= Iterable
		CODE
		assert_equal true, out
	end

	# `Iterable` itself is just one way to satisfy the protocol -- `#interp_for_loop` only checks
	# that the collection `has?('next')`, so a type that hand-rolls its own `next`/`Done` works
	# the same way without composing `Iterable` at all.
	def test_hand_rolled_next_protocol_works_without_composing_iterable
		out = Code.interp <<~CODE
			@load 'lang/iterable'

		    Tens {
		        values := [1, 2, 3]
		        next (index: Int -> Any;
		            if index >= values.length()
		                Stop_Iterating()
		            else
		                values[index] * 10
		            end
		        )
		        Done {}
		    }
		    result := []
		    for Tens()
		        result << it
		    end
		    result
		CODE
		assert_equal [10, 20, 30], out.values
	end

	# A type with no `next` method still raises the ordinary error -- composing `Iterable` (or
	# hand-rolling `next`) is what opts a type into `for`, not being a plain Instance.
	def test_instance_without_next_still_raises_non_iterable_error
		assert_raises Code::Non_Iterable_Collection_In_For_Loop do
			Code.interp "Plain { x := 1 }\nfor Plain()\n@puts it\nend"
		end
	end
end
