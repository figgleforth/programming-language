require_relative 'air'
require_relative 'constructs'

module Air
	# Just as a precaution, I want it to be obvious that references of the Array class in this module, so far, are meant for my implementation of Array, not the intrinsic Ruby array.
	class Air::Array < Instance
		attr_accessor :values

		def initialize values = []
			@values = values
		end

		def [] index
			values[index]
		end

		def []= index, value
			values[index] = value
		end
	end

	class Tuple < Air::Array
		def initialize values = []
			@values = values
		end
	end

	class Number < Instance
		attr_accessor :numerator, :denominator, :type

		def + other
			numerator + other.numerator
		end

		def - other
			numerator - other.numerator
		end

		def * other
			numerator * other.numerator
		end

		def ** other
			numerator ** other.numerator
		end

		def / other
			numerator / other.numerator
		end

		def % other
			numerator % other.numerator
		end

		def >> other
			numerator >> other.numerator
		end

		def << other
			numerator << other.numerator
		end

		def ^ other
			numerator ^ other.numerator
		end

		def & other
			numerator & other.numerator
		end

		def | other
			numerator | other.numerator
		end
	end

	class Nil < Scope # Like Ruby's NilClass, this represents the absence of a value.
		def self.shared
			@instance ||= new
		end

		private_class_method :new # prevent external instantiation

		def initialize
			super 'nil'
		end
	end

	class Bool < Scope
		attr_accessor :truthiness

		def !
			!@truthiness
		end

		def self.truthy
			@truthy ||= new(true)
		end

		def self.falsy
			@falsy ||= new(false)
		end

		private_class_method :new # prevent external instantiation

		def initialize truthiness
			super (!!truthiness).to_s.capitalize # Scope class only needs @name
			@truthiness = !!truthiness
		end
	end

	class Left_Exclusive_Range < Range
		def initialize first, last, exclude_end: false
			super first, last, exclude_end
		end

		def each
			skipped = false
			super do |x|
				if skipped
					yield x
				else
					skipped = true
				end
			end
		end

		def include? val
			val > self.first && (exclude_end? ? val < self.last : val <= self.last)
		end
	end

	class Server < Type
		attr_accessor :port, :routes

		def initialize
			super 'Server'

			@declarations['port']   = nil
			@declarations['routes'] = nil
		end
	end
end
