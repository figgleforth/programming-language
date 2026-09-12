module Code
	Code_Location = ::Data.define(:l0, :c0, :l1, :c1) do
		def < other
			self != other && other.include?(self)
		end

		def > other
			self != other && include?(other)
		end

		def <= other
			self == other || other.include?(self)
		end

		def >= other
			self == other || include?(other)
		end

		def == other
			other.l0 == l0 && other.l1 == l1 &&
				other.c0 == c0 && other.c1 == c1
		end

		def <=> other
			return 0 if self == other
			return -1 if other.include? self
			return 1 if include? other
		end

		def include? other
			([other.l0, other.c0] <=> [l0, c0]) >= 0 &&
				([other.l1, other.c1] <=> [l1, c1]) <= 0
		end
	end
end
