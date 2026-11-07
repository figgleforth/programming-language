# Implemented by Claude
#
module Code
	# A random number generator with its own seed, so a run can be repeated. Inside `module Code`, a bare `Random` now means this class; write `::Random` for Ruby's.
	class Random < Instance
		def initialize name = 'Random'
			super name
		end

		# A nil seed lets Ruby pick one, which `seed` can read back.
		def proxy_start seed = nil
			@random = seed.nil? ? ::Random.new : ::Random.new(seed)
			self
		end

		# A type body reads this member before `Self` makes the generator.
		def proxy_seed
			@random&.seed
		end

		def proxy_int min, max
			raise Code::Invalid_Random, "`min` (#{min}) cannot be above `max` (#{max})." if min > max

			@random.rand min..max
		end

		def proxy_float max = 1.0
			@random.rand * max
		end

		def proxy_chance? probability
			@random.rand < probability
		end

		def proxy_pick list
			list.values.sample random: @random
		end

		# @return [::Array] a new list; the given list stays as it is
		def proxy_shuffle list
			list.values.shuffle random: @random
		end

		# A nil weight counts as 0, so the list from `neighbors` can go in as it is.
		# @return [::Integer | nil] the index it picked; nil when no weight is above 0
		def proxy_weighted_pick weights
			values = weights.values
			total  = 0.0
			values.each do |weight|
				next if weight.nil?
				raise Code::Invalid_Random, "A weight must be a number that is 0 or more, but one is #{weight.inspect}." unless weight.is_a?(::Numeric) && weight >= 0

				total += weight
			end
			return nil unless total > 0

			roll = @random.rand * total
			last = nil
			values.each_with_index do |weight, index|
				next if weight.nil? || weight == 0

				roll -= weight
				return index if roll < 0

				last = index
			end
			last # rounding can leave a tiny part of the roll
		end
	end
end
