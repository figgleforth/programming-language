module Code
	# `Rational(1, 3)` -- backed by a Ruby Rational, so `1/3 + 1/6` is exactly `1/2`. No literal form yet.
	class Rational < Number
		# A Float goes through `rationalize`, so `Rational(0.34)` is `17/50`, not the Float's exact binary value.
		def value= numeric
			coerced = case numeric
				when ::Rational then numeric
				when ::Float    then numeric.rationalize
				when ::Numeric  then numeric.to_r
				when ::String   then (::Kernel.Rational(numeric) rescue 0r)
				else 0r
				end
			super(coerced)
		end
	end
end
