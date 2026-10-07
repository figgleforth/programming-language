require 'fiddle'

module Code
	class Pointer < Instance
		extend Ruby_Proxies

		# The runtime pointer to this pointer
		# @return Code::Point
		attr_accessor :fiddle_pointer
		proxy_delegate :fiddle_pointer

		proxy :size
		proxy :null?
		proxy :freed?
		proxy :call_free
		proxy :to_i
		proxy :to_s

		def proxy_resize size
			old                     = @fiddle_pointer
			@fiddle_pointer         = ::Fiddle::Pointer.malloc size, ::Fiddle::RUBY_FREE
			len                     = [old&.size, size].min
			@fiddle_pointer[0, len] = old[0, len] unless old.null?
			self
		end

		# Analogous to `&thing` in C
		def proxy_reference
			ptr                = Code::Pointer.new
			ptr.fiddle_pointer = @fiddle_pointer.ref
			ptr
		end

		# Analogous to `*thing` in C
		def proxy_pointer
			raise Code::Null_Pointer_Dereference if @fiddle_pointer.null?
			ptr                = Code::Pointer.new
			ptr.fiddle_pointer = @fiddle_pointer.ptr
			ptr
		end

		# @param address Code::Number
		# @param len Code::Number
		def proxy_read address, len
			::Fiddle::Pointer.read address, len
		end

		# @param address Code::Number
		# @param str Code::String
		# @return self
		def proxy_write address, str
			::Fiddle::Pointer.write address, str
		end

		# @param anything Code::Scope of some kind
		# @return Code::Pointer
		def proxy_to_pointer anything
			ptr                = Code::Pointer.new
			ptr.fiddle_pointer = ::Fiddle::Pointer.to_ptr anything
			ptr
		end

		def proxy_malloc size
			Code::Pointer.new.proxy_resize size
		end

		def proxy_call_free
			@fiddle_pointer.call_free()
			self
		end

		def initialize _name = nil
			super 'Pointer'
			@fiddle_pointer = Fiddle::NULL
		end

		def to_s
			"Pointer(...TO_DO...)"
		end
	end
end
