class Scope
	def initialize name, data = {}
		@name = name
		@data = data
	end

	def [] key
		@data[key&.to_s] || @data[key&.to_sym]
	end

	def []= key, value
		@data[key] = value
	end

	def is desired_name
		@name == desired_name
	end

	def has? identifier
		@data.include?(identifier.to_s) || @data.include?(identifier.to_sym)
	end

	def dig * identifiers
		@data.dig *identifiers
	end

	def name
		@name
	end

	def data
		@data
	end
end

class Type < Scope
	attr_accessor :expressions, :types
end

class Instance < Scope
	attr_accessor :expressions
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

class Func < Scope
	attr_accessor :expressions
end

class Nil < Scope
	def initialize
		super 'nil'
	end
end

class Tuple < Scope
	attr_accessor :values
end

######

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
