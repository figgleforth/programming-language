require_relative 'air'

module Air
	class Scope
		attr_accessor :enclosing_scope
		attr_reader :name, :declarations

		def initialize name = nil
			@name         = name
			@declarations = {}
		end

		def [] key
			@declarations[key&.to_s]
		end

		def []= key, value
			@declarations[key.to_s] = value
		end

		def is compare
			@name == compare
		end

		def has? identifier
			@declarations.key?(identifier.to_s)
		end

		# Unused, I think
		def dig * identifiers
			@declarations.dig *identifiers
		end

		def declarations= new_declarations
			@declarations = new_declarations
		end

		def delete key
			return nil unless key
			@declarations.delete(key.to_s)
		end
	end

	class Global < Scope
		def initialize
			super self.class.name
		end
	end

	class Type < Scope
		attr_accessor :expressions, :types

		def initialize name = nil
			super name
			@types = [name]
		end
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
