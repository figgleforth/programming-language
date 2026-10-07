module Code
	class Buffer < Instance
		extend Ruby_Proxies

		# @param io_buffer ::IO::Buffer
		attr_accessor :io_buffer

		# Ruby prints a one-time "IO::Buffer is experimental" warning on first use -- silence only that one call, not the whole process.
		def self.new_io_buffer size
			previous               = Warning[:experimental]
			Warning[:experimental] = false
			::IO::Buffer.new size
		ensure
			Warning[:experimental] = previous
		end

		def initialize _name = nil
			super 'Buffer'
			@io_buffer = Code::Buffer.new_io_buffer 0
		end

		TYPES = %i(U8 S8 u16 U16 s16 S16 u32 U32 s32 S32 u64 U64 s64 S64 f32 F32 f64 F64)

		proxy_delegate 'io_buffer'
		proxy :size, as: :length

		# Ruby's IO::Buffer wants a Symbol (:u32) -- accept a `.code` symbol or string too. A single byte has no byte order, so Ruby only names :U8/:S8; accept :u8/:s8 as the same thing.
		def type_symbol type
			name = type.to_s.delete_prefix ':'
			name = name.upcase if %w(u8 s8).include? name
			return name.to_sym if TYPES.include? name.to_sym

			raise Code::Invalid_Buffer_Type, ":#{name} is not a Buffer type. Use one of: :u8 :s8 #{TYPES.drop(2).map { ":#{it}" }.join ' '} (lowercase is little-endian, uppercase is big-endian)"
		end

		def proxy_resize size
			@io_buffer.resize size
			self
		end

		# @return ::String
		def proxy_get_string
			@io_buffer.get_string
		end

		def proxy_get_string_slice start_index = 0, length = -1
			@io_buffer.get_string start_index, (length == -1 ? nil : length)
		end

		# Offset over/underflow is going to be tested in .code
		def proxy_get type, offset
			@io_buffer.get_value type_symbol(type), offset
		end

		# Offset over/underflow is going to be tested in .code
		def proxy_set type, offset, value
			@io_buffer.set_value type_symbol(type), offset, value
			self
		end

		def proxy_fill value = 0
			@io_buffer.clear value
			self
		end

		def proxy_size_of type
			::IO::Buffer.size_of type_symbol(type)
		end

		# @param string Code::String
		def proxy_from_string string
			# b = Code::Buffer.new
			buf           = Code::Buffer.new
			buf.io_buffer = ::IO::Buffer.new string.size
			buf.io_buffer.set_string string
			buf
		end

		# todo; @slow converting this to a Ruby array. API for getting slices is better
		def proxy_bytes
			@io_buffer.each_byte.to_a
		end

		def proxy_hexdump
			@io_buffer.hexdump.to_s
		end

		# def number_of_bytes
		# 	@io_buffer
		# end

		# def number_of_bits
		# 	@io_buffer
		# end

		def to_s
			"Buffer(#{@io_buffer.size} bytes)"
		end
	end
end
