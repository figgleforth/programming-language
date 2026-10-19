module Code
	# A Symbol stays a plain Ruby ::Symbol until it is used as an object (`:onclick.to_s()`), the same as a String or a number. See Interpreter#maybe_instance.
	class Symbol < Instance
		extend Ruby_Proxies

		attr_reader :value

		def initialize value = :''
			super self.class.name
			self.value    = value
			self['value'] = @value
		end

		# `Symbol('onclick')` builds one from a String.
		def value= value
			value  = value.value if value.respond_to? :value
			@value = value.to_s.to_sym
		end

		proxy_delegate 'value'
		proxy :to_s
		proxy :length
		proxy :upcase
		proxy :downcase
		proxy :capitalize
		proxy :swapcase
		proxy :start_with?
		proxy :end_with?
		proxy :empty?

		def == other
			value == (other.is_a?(Code::Symbol) ? other.value : other)
		end

		def eql? other
			other.is_a?(Code::Symbol) ? value.eql?(other.value) : value.eql?(other)
		end

		def hash
			value.hash
		end
	end
end
