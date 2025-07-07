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

class Scope
	attr_accessor :name, :id, :hash
	@@next_id = 0

	def initialize
		@hash     = {}
		@id       = @@next_id
		@@next_id += 1
	end

	def [](x)
		@hash[x&.to_s]
	end

	def []=(x, value)
		@hash[x&.to_s] = value
	end
end

class Func < Scope
	attr_accessor :expressions, :params

	def initialize
		super
		@expressions = []
		@params      = []
	end
end

class Type < Scope
	attr_accessor :expressions, :compositions

	def initialize
		super
		@expressions  = []
		@compositions = []
	end
end

class Instance < Type
	# 7/5/25, For now I'm adding a default constructor here. Maybe there's a better way to do this but for now this is fine.
	# 7/7/25, I'm actually removing it because as I'm researching for src/types/number.e, I noticed that Ruby's Integer class does not have an initializer. But here's the code in case I need it for later.
	# constructor      = Func.new
	# constructor.name = 'new'
	# self[:new]       = constructor
end

class Runtime_Number < Instance
	attr_accessor :value
end
