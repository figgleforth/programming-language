require_relative 'air'

module Air
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

	class Func < Scope
		attr_accessor :expressions
	end

	class Return < Scope
		attr_accessor :value

		def initialize value
			super 'Return'
			@value = value
		end
	end
end
