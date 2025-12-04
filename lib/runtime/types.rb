require_relative '../ore'

# todo: Some way to denote which methods or attributes are to be exposed in the standard library equivalent. Then I don't have to manually add them to the type in types.rb (like I did for Dictionary)

module Ore
	class List < Instance
		attr_accessor :values

		def initialize values = []
			super 'List'
			@values = values
		end

		def [] index
			values[index]
		end

		def []= index, value
			values[index] = value
		end

		def == other
			# I think there's more to this than a simple evaluation. Tbd...
			values == other.values
		end

		def to_s
			values.inspect
		end

		def each & block
			values.each &block
		end
	end

	class Dictionary < Instance
		attr_accessor :dict

		def initialize dict = {}
			super 'Dictionary'
			@dict = dict
		end

		def [] index
			dict[index]
		end

		def []= index, value
			dict[index] = value
		end

		def == other
			dict == other&.dict
		end

		def to_s
			dict.inspect
		end

		def keys
			dict.keys
		end

		def values
			dict.values
		end

		def count
			dict.count
		end
	end

	class Tuple < List
		def initialize values = []
			super values
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
