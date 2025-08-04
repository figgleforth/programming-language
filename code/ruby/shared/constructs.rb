require './code/ruby/shared/helpers.rb'

module Emerald
end

class Scope
	attr_accessor :enclosing_scope
	attr_reader :name, :data

	def initialize name, data = {}
		@name = name
		@data = data
	end

	def [] key
		@data[key&.to_s]
	end

	def []= key, value
		@data[key.to_s] = value
	end

	def is compare
		@name == compare
	end

	def has? identifier
		@data.key?(identifier.to_s)
	end

	# Unused, I think
	def dig * identifiers
		@data.dig *identifiers
	end

	def data= new_data
		@data = new_data
	end

	def delete key
		return nil unless key
		@data.delete(key.to_s)
	end

	def declarations
		@data.values
	end
end

class Global < Scope
	def initialize
		super self.class.name
	end
end

class Type < Scope
	attr_accessor :expressions, :types
end

class Instance < Type
	def initialize name
		super (name || 'Instance')
	end
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
		@values = values
	end

	def [] index
		values[index]
	end

	def []= index, value
		values[index] = value
	end
end

class Tuple < Emerald::Array
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

class Func < Scope
	attr_accessor :expressions
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
