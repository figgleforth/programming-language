class Tuple
	attr_accessor :values
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

class Func_Blueprint
	attr_accessor :name, :exprs, :params

	def self.to_h it
		require 'recursive-open-struct'
		RecursiveOpenStruct.new({
			                        __name:   it.name,
			                        __exprs:  it.exprs || [],
			                        __params: it.params || [],
		                        })
	end

	def to_h
		Func_Blueprint.to_h self
	end
end

class Type_Blueprint
	attr_accessor :name, :exprs, :compositions

	def initialize
		@exprs        = []
		@compositions = []
	end

	def self.to_h it
		require 'recursive-open-struct'
		RecursiveOpenStruct.new({
			                        __type:  :func,
			                        __name:  it.name,
			                        __exprs: it.exprs || [],
			                        __comps: it.compositions || [],
			                        new:     Func_Blueprint.to_h(Func_Blueprint.new)
		                        })
	end

	def to_h
		Type_Blueprint.to_h self
	end
end
