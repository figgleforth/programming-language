module Emerald
end

class Scope
	attr_accessor :enclosing_scope

	def initialize name, data = {}
		@name = name
		@data = data
	end

	def [] key
		@data[key&.to_s] || @data[key&.to_sym] || enclosing_scope&.[](key)
	end

	def []= key, value
		@data[key] = value
	end

	def is desired_name
		@name == desired_name
	end

	def has? identifier
		@data.include?(identifier.to_s) || @data.include?(identifier.to_sym) || enclosing_scope&.has?(identifier)
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

	def data= new_data
		@data = new_data
	end

	def delete key
		@data.delete(key.to_s) || @data.delete(key.to_sym)
	end
end

class Global < Scope
end

class Type < Scope
	attr_accessor :expressions, :types
end

class Instance < Type
end

class Return < Scope
	attr_accessor :value

	def initialize value
		super 'Return'
		@value = value
	end
end

class Emerald::Array < Instance
	attr_accessor :values

	def initialize values = []
		super 'Emerald::Array'
		@values = values
	end

	def [] index
		values[index]
	end

	def []= index, value
		values[index] = value
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

class Func < Scope
	attr_accessor :expressions
end

class Nil < Scope # Like Ruby's NilClass, this represents the absence of a value.
	def initialize
		super 'nil'
	end
end

class Tuple < Emerald::Array
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
