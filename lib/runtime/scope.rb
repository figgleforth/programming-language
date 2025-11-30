require_relative '../ore'

module Ore
	class Scope
		attr_accessor :enclosing_scope
		attr_reader :name, :declarations

		def initialize name = nil
			@name         = name || self.class.name
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

		def declarations= new_declarations
			@declarations = new_declarations
		end

		def delete key
			return nil unless key
			@declarations.delete(key.to_s)
		end

		def self.with_standard_library
			global = new
			global.load_standard_library
			global
		end

		def load_standard_library
			load_file STANDARD_LIBRARY_PATH
		end

		# Convenience method for loading files into this scope without a context
		# Creates a temporary Context to handle file loading
		def load_file filepath
			temp_context = Ore::Context.new
			temp_context.load_file filepath, self
			self
		end
	end

	class Global < Scope
	end

	class Html_Element < Scope
		attr_accessor :expressions, :attributes, :types
	end

	class Type < Scope
		attr_accessor :expressions, :types, :routes

		def initialize name = nil
			super name
			@types = [name].compact
		end
	end

	class Instance < Type
		def initialize name = 'Instance'
			super name
		end
	end

	class Func < Scope
		attr_accessor :expressions
	end

	class Route < Func
		attr_accessor :http_method, :path, :handler, :parts, :param_names
	end

	class Return < Scope
		attr_accessor :value

		def initialize value
			super 'Return'
			@value = value
		end
	end
end
