require_relative '../ore'

module Ore
	class Scope
		attr_accessor :enclosing_scope, :sibling_scopes, :declarations
		attr_reader :name

		def initialize name = nil
			@name           = name || self.class.name
			@declarations   = {}
			@sibling_scopes = []
		end

		def declare identifier, value
			self[identifier] = value
		end

		def get key
			key_str = key&.to_s

			# todo: Currently there is no clear rule on multiple unpacks. :double_unpack
			@sibling_scopes.reverse_each do |sibling|
				return sibling[key_str] if sibling.has? key_str
			end

			@declarations[key_str]
		end

		def [] key
			get key
		end

		def []= key, value
			@declarations[key.to_s] = value
		end

		def is compare
			@name == compare
		end

		def has? identifier
			id_str = identifier.to_s

			# todo: Currently there is no clear rule on multiple unpacks. :double_unpack
			return true if @sibling_scopes.any? do |sibling|
				sibling.has? id_str
			end

			@declarations.key? id_str
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

		# Convenience method for loading files into this scope without a runtime
		# Creates a temporary Context to handle file loading
		def load_file filepath
			temp_runtime = Ore::Runtime.new
			temp_runtime.load_file filepath, self
			self
		end
	end

	class Global < Scope
	end

	class Type < Scope
		attr_accessor :expressions, :types, :routes, :static_declarations

		def initialize name = nil
			super name
			@types               = Set[name]
			@static_declarations = Set.new
		end

		def has? identifier
			super(identifier) || @static_declarations.include?(identifier)
		end
	end

	class Instance < Type
		def initialize name = 'Instance'
			super name
		end
	end

	class Func < Scope
		attr_accessor :expressions, :intrinsic, :static, :arguments
	end

	class Html_Element < Scope
		attr_accessor :expressions, :attributes, :types
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

	class String < Instance
		extend Intrinsic_Methods

		attr_accessor :value

		def initialize value = ""
			super self.class.name
			@value        = value
			self['value'] = value
		end

		intrinsic_delegate 'value'
		intrinsic :length
		intrinsic :ord
		intrinsic :upcase
		intrinsic :downcase
		intrinsic :split
		intrinsic :slice!, as: :slice
		intrinsic :strip, as: :trim
		intrinsic :lstrip, as: :trim_left
		intrinsic :rstrip, as: :trim_right
		intrinsic :chars
		intrinsic :index
		intrinsic :to_i
		intrinsic :to_f
		intrinsic :empty?
		intrinsic :include?
		intrinsic :reverse
		intrinsic :replace
		intrinsic :start_with?
		intrinsic :end_with?
		intrinsic :gsub

		def + other
			value + other.value
		end

		def * other
			value * other
		end
	end

	# note: Be sure to prefix with Ore:: whenever referencing this Array type to prevent ambiguity with Ruby's ::Array!
	class Array < Instance
		extend Intrinsic_Methods
		attr_accessor :values

		def initialize values = []
			super 'List'
			@values = values
		end

		intrinsic_delegate 'values'
		intrinsic :push
		intrinsic :pop
		intrinsic :shift
		intrinsic :unshift
		intrinsic :length
		intrinsic :first
		intrinsic :last
		intrinsic :slice
		intrinsic :reverse
		intrinsic :join
		intrinsic :sort
		intrinsic :uniq
		intrinsic :include?
		intrinsic :empty?

		def intrinsic_concat other_array
			values.concat other_array.values
		end

		def intrinsic_flatten depth = -1
			# Convert Ore::Array objects to Ruby arrays for flattening
			ruby_array = values.map { |v| v.is_a?(Ore::Array) ? v.values : v }
			Ore::Array.new ruby_array.flatten depth
		end

		def get key
			# note: This is required because Instance extends Scope whose [] method reads from @declarations
			key.is_a?(Integer) ? values[key] : super
		end

		def []= key, value
			values[key] = value
		end

		def == other
			# I think there's more to this than a simple evaluation. Tbd...
			values == other&.values
		end

		def to_s
			values.inspect
		end
	end

	class Dictionary < Instance
		extend Intrinsic_Methods
		attr_accessor :dict

		def initialize dict = {}
			super 'Dictionary'
			@dict = dict
		end

		intrinsic_delegate 'dict'
		intrinsic :has_key?
		intrinsic :delete
		intrinsic :count
		intrinsic :keys
		intrinsic :values
		intrinsic :empty?
		intrinsic :clear
		intrinsic :fetch

		def intrinsic_merge other_dict
			dict.merge other_dict.dict
		end

		def [] key
			dict[key]
		end

		def []= key, value
			dict[key] = value
		end

		def == other
			dict == other&.dict
		end

		def to_s
			dict.inspect
		end
	end

	class Tuple < Ore::Array
		def initialize values = []
			super values
		end
	end

	class Number < Instance
		extend Intrinsic_Methods
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

		intrinsic_delegate 'numerator'
		intrinsic :to_s
		intrinsic :abs
		intrinsic :floor
		intrinsic :ceil
		intrinsic :round
		intrinsic :even?
		intrinsic :odd?
		intrinsic :to_i
		intrinsic :to_f
		intrinsic :clamp

		def intrinsic_sqrt
			Math.sqrt numerator
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
			super((!!truthiness).to_s.capitalize) # Scope class only needs @name
			@truthiness = !!truthiness
		end
	end

	class Range < ::Range
	end

	class Server < Type
		attr_accessor :port, :routes

		def initialize
			super 'Server'

			@routes                 = {}
			@declarations['port']   = nil
			@declarations['routes'] = @routes
		end
	end

	class Request < Scope
		attr_accessor :path, :method, :query, :params, :headers, :body

		def initialize
			super 'Request'
			@path    = nil
			@method  = nil
			@query   = {} # Query string params (?key=value)
			@params  = {} # Url params (:id in route)
			@headers = {}
			@body    = nil

			@declarations['path']    = @path
			@declarations['method']  = @method
			@declarations['query']   = @query
			@declarations['params']  = @params
			@declarations['headers'] = @headers
			@declarations['body']    = @body
		end
	end

	class Response < Scope
		attr_accessor :status, :headers, :body_content

		def initialize
			super 'Response'
			@status       = 200
			@headers      = { 'Content-Type' => 'text/html; charset=utf-8' }
			@body_content = ''

			@declarations['status']  = @status
			@declarations['headers'] = @headers
			@declarations['body']    = @body_content
		end
	end
end
