class Func
	attr_accessor :name, :expressions, :params

	def self.to_h it
		require 'recursive-open-struct'
		RecursiveOpenStruct.new({
			                        __name:        it.name,
			                        __expressions: it.expressions || [],
			                        __params:      it.params || [],
		                        })
	end

	def to_h
		Func.to_h self
	end
end

class Type
	attr_accessor :name, :expressions, :compositions

	def initialize
		@expressions  = []
		@compositions = []
	end

	def self.to_h it
		require 'recursive-open-struct'
		RecursiveOpenStruct.new({
			                        __type:         :func,
			                        __name:         it.name,
			                        __expressions:  it.expressions || [],
			                        __compositions: it.compositions || [],
			                        new:            Func.to_h(Func.new)
		                        })
	end

	def to_h
		Type.to_h self
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

class Tuple
	attr_accessor :values
end

class Scope < Hash
	attr_reader :name, :id

	def initialize name, id
		@name = name
		@id   = id
	end
end

class Runtime < Scope
end
