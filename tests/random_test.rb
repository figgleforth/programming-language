require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

class Random_Test < Base_Test
	def run_random source
		Code.interp "@load 'lang/random'\n\n#{source}"
	end

	def test_random_needs_a_load
		assert_raises(Code::Undeclared_Identifier) { Code.interp 'Random(1)' }
	end

	def test_the_same_seed_gives_the_same_numbers
		out = run_random <<~CODE
			numbers ( seed;
				random := Random(seed)
				[random.int(0, 1000), random.float(), random.chance?(0.5), random.pick([1, 2, 3, 4, 5, 6, 7, 8]), random.weighted_pick([1, 2, 3, 4]), random.shuffle([1, 2, 3, 4, 5, 6, 7, 8])]
			)

			first := numbers(42)
			second := numbers(42)
			other := numbers(43)
			[first == second, first == other]
		CODE
		assert_equal [true, false], out.values
	end

	def test_with_no_seed_it_picks_one_and_can_repeat_it
		out = run_random <<~CODE
			first := Random()
			second := Random(first.seed)
			[first.seed > 0, first.int(0, 100000) == second.int(0, 100000), first === Random, "`Random(7)`"]
		CODE
		assert_equal [true, true, true, 'Random(seed: 7)'], out.values
	end

	def test_start_begins_again_from_a_seed
		assert_equal true, run_random(<<~CODE)
			random := Random(1)
			first := random.int(0, 100000)
			random.start(1)
			first == random.int(0, 100000)
		CODE
	end

	def test_int_includes_both_ends_and_float_stays_below_max
		out = run_random <<~CODE
			random := Random(1)
			ints := for 0..<200 map
				random.int(1, 3)
			end
			floats := for 0..<200 map
				random.float(2)
			end
			[ints.uniq().sort(), floats.min() >= 0, floats.max() < 2]
		CODE
		assert_equal [1, 2, 3], out.values.first.values
		assert_equal [true, true], out.values.drop(1)
	end

	def test_chance_at_the_two_ends
		assert_equal [false, true], run_random("random := Random(1)\n[random.chance?(0), random.chance?(1)]").values
	end

	def test_pick_gives_an_item_and_nil_for_an_empty_list
		assert_equal [5, nil], run_random("random := Random(1)\n[random.pick([5]), random.pick([])]").values
	end

	def test_shuffle_keeps_the_items_and_leaves_the_list
		out = run_random <<~CODE
			random := Random(1)
			list := [1, 2, 3, 4, 5]
			shuffled := random.shuffle(list)
			[shuffled.sort(), list]
		CODE
		assert_equal [[1, 2, 3, 4, 5], [1, 2, 3, 4, 5]], out.values.map(&:values)
	end

	def test_weighted_pick_follows_the_weights
		out = run_random <<~CODE
			random := Random(1)
			picks := for 0..<1000 map
				random.weighted_pick([1, 0, 3])
			end
			[picks.filter(it; it == 0).length(), picks.filter(it; it == 1).length(), picks.filter(it; it == 2).length()]
		CODE
		ones, zeros, threes = out.values
		assert_equal 0, zeros
		assert_in_delta 250, ones, 50
		assert_in_delta 750, threes, 50
	end

	def test_weighted_pick_counts_nil_as_zero_and_gives_nil_with_no_weight
		assert_equal 1, run_random('Random(1).weighted_pick([nil, 2, nil])')
		assert_nil run_random('Random(1).weighted_pick([0, nil])')
		assert_nil run_random('Random(1).weighted_pick([])')
	end

	def test_bad_input_raises
		assert_raises(Code::Invalid_Random) { run_random 'Random(1).weighted_pick([1, -1])' }
		assert_raises(Code::Invalid_Random) { run_random "Random(1).weighted_pick([1, 'a'])" }
		assert_raises(Code::Invalid_Random) { run_random 'Random(1).int(5, 1)' }
	end
end
