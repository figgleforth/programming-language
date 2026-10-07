require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

class Buffer_Test < Base_Test
	# --- construction and size ---

	def test_buffer_starts_with_the_given_number_of_zero_bytes
		assert_equal 8, Code.interp('Buffer(8).length()')
		assert_equal [0, 0, 0, 0], Code.interp('Buffer(4).bytes()').values
	end

	def test_buffer_with_no_size_is_empty
		assert_equal 0, Code.interp('Buffer().length()')
		assert_equal [], Code.interp('Buffer().bytes()').values
	end

	def test_buffer_is_a_buffer
		assert Code.interp('Buffer(4) === Buffer')
	end

	def test_each_buffer_has_its_own_bytes
		src = <<~CODE
			a := Buffer(2)
			b := Buffer(2)
			a.set(:U8, 0, 9)
			[a.get(:U8, 0), b.get(:U8, 0)]
		CODE
		assert_equal [9, 0], Code.interp(src).values
	end

	def test_a_buffer_passed_to_a_function_is_the_same_buffer
		src = <<~CODE
			poke ( buf; buf.set(:U8, 1, 7) )
			b := Buffer(2)
			poke(b)
			b.get(:U8, 1)
		CODE
		assert_equal 7, Code.interp(src)
	end

	def test_resize_grows_with_zero_bytes_and_keeps_old_bytes
		src = <<~CODE
			b := Buffer(2)
			b.set(:U8, 0, 5)
			b.resize(4)
			b.bytes()
		CODE
		assert_equal [5, 0, 0, 0], Code.interp(src).values
	end

	def test_resize_shrinks
		src = <<~CODE
			b := Buffer(4)
			b.fill(3)
			b.resize(2)
			b.bytes()
		CODE
		assert_equal [3, 3], Code.interp(src).values
	end

	def test_fill
		assert_equal [7, 7, 7], Code.interp('Buffer(3).fill(7).bytes()').values
		assert_equal [0, 0], Code.interp('Buffer(2).fill(7).fill().bytes()').values
	end

	# --- size_of ---

	def test_size_of_each_type
		src = '[:U8, :S8, :u16, :s16, :u32, :s32, :u64, :s64, :f32, :f64].map((it; Buffer().size_of(it)))'
		assert_equal [1, 1, 2, 2, 4, 4, 8, 8, 4, 8], Code.interp(src).values
	end

	def test_size_of_on_the_type
		assert_equal 4, Code.interp('Buffer.size_of(:u32)')
	end

	# --- get and set ---

	def test_set_returns_the_buffer_so_calls_chain
		assert_equal 42, Code.interp('Buffer(4).set(:U8, 0, 1).set(:U8, 1, 42).get(:U8, 1)')
	end

	def test_every_integer_type_round_trips
		src = <<~CODE
			b := Buffer(8)
			[
				b.set(:U8,  0, 255).get(:U8, 0),
				b.set(:S8,  0, -128).get(:S8, 0),
				b.set(:u16, 0, 65535).get(:u16, 0),
				b.set(:s16, 0, -32768).get(:s16, 0),
				b.set(:u32, 0, 0xDEADBEEF).get(:u32, 0),
				b.set(:s32, 0, -2147483648).get(:s32, 0),
				b.set(:u64, 0, 0xFFFFFFFFFFFFFFFF).get(:u64, 0),
				b.set(:s64, 0, -9223372036854775808).get(:s64, 0),
			]
		CODE
		assert_equal [255, -128, 65535, -32768, 0xDEADBEEF, -2147483648, 0xFFFFFFFFFFFFFFFF, -9223372036854775808], Code.interp(src).values
	end

	def test_float_types_round_trip
		assert_equal 1.5, Code.interp('Buffer(8).set(:f64, 0, 1.5).get(:f64, 0)')
		assert_equal 0.1, Code.interp('Buffer(8).set(:f64, 0, 0.1).get(:f64, 0)')
		assert_equal 1.5, Code.interp('Buffer(4).set(:f32, 0, 1.5).get(:f32, 0)')
	end

	def test_f32_loses_precision
		refute_equal 0.1, Code.interp('Buffer(4).set(:f32, 0, 0.1).get(:f32, 0)')
		assert_in_delta 0.1, Code.interp('Buffer(4).set(:f32, 0, 0.1).get(:f32, 0)'), 1e-7
	end

	def test_a_string_type_name_works_like_a_symbol
		assert_equal 9, Code.interp("Buffer(4).set('u32', 0, 9).get('u32', 0)")
	end

	# --- wrapping ---

	def test_a_value_too_big_for_its_type_wraps
		assert_equal 44, Code.interp('Buffer(1).set(:U8, 0, 300).get(:U8, 0)')
		assert_equal 0, Code.interp('Buffer(2).set(:u16, 0, 65536).get(:u16, 0)')
	end

	def test_signed_and_unsigned_views_of_the_same_bytes
		assert_equal 255, Code.interp('Buffer(1).set(:S8, 0, -1).get(:U8, 0)')
		assert_equal(-1, Code.interp('Buffer(1).set(:U8, 0, 255).get(:S8, 0)'))
	end

	def test_a_float_written_to_an_integer_type_truncates
		assert_equal 1, Code.interp('Buffer(1).set(:U8, 0, 1.7).get(:U8, 0)')
	end

	# --- byte order ---

	def test_lowercase_is_little_endian
		assert_equal [2, 1, 0, 0], Code.interp('Buffer(4).set(:u16, 0, 258).bytes()').values
		assert_equal [0xEF, 0xBE, 0xAD, 0xDE], Code.interp('Buffer(4).set(:u32, 0, 0xDEADBEEF).bytes()').values
	end

	def test_uppercase_is_big_endian
		assert_equal [1, 2, 0, 0], Code.interp('Buffer(4).set(:U16, 0, 258).bytes()').values
		assert_equal [0xDE, 0xAD, 0xBE, 0xEF], Code.interp('Buffer(4).set(:U32, 0, 0xDEADBEEF).bytes()').values
	end

	def test_reading_with_the_other_byte_order_swaps_the_bytes
		assert_equal 0x0201, Code.interp('Buffer(2).set(:U16, 0, 0x0102).get(:u16, 0)')
	end

	# --- offsets ---

	def test_a_wide_value_spans_its_bytes
		src = <<~CODE
			b := Buffer(8)
			b.set(:u32, 4, 0xDEADBEEF)
			[b.get(:U8, 3), b.get(:U8, 4), b.get(:U8, 7)]
		CODE
		assert_equal [0, 0xEF, 0xDE], Code.interp(src).values
	end

	def test_neighbour_values_do_not_overlap
		src = <<~CODE
			b := Buffer(8)
			b.set(:u32, 0, 1)
			b.set(:u32, 4, 2)
			[b.get(:u32, 0), b.get(:u32, 4)]
		CODE
		assert_equal [1, 2], Code.interp(src).values
	end

	def test_an_unaligned_offset_works
		assert_equal 0xDEADBEEF, Code.interp('Buffer(8).set(:u32, 3, 0xDEADBEEF).get(:u32, 3)')
	end

	def test_the_last_value_that_fits_works
		assert_equal 7, Code.interp('Buffer(8).set(:u32, 4, 7).get(:u32, 4)')
	end

	# --- errors ---

	def test_a_read_past_the_end_raises
		# Offset 1 is inside the buffer, but a 4-byte value there needs bytes 1 to 4.
		error = assert_raises(Code::Raised) { Code.interp('Buffer(4).get(:u32, 1)') }
		assert_equal 'Out_Of_Bounds: reading a 4-byte :u32 at offset 1 goes past the end: the buffer has 4 bytes (offsets 0 to 3)', error.message
		error = assert_raises(Code::Raised) { Code.interp('Buffer(4).get(:U8, 4)') }
		assert_equal 'Out_Of_Bounds: reading a 1-byte :U8 at offset 4 goes past the end: the buffer has 4 bytes (offsets 0 to 3)', error.message
	end

	def test_a_write_past_the_end_raises
		error = assert_raises(Code::Raised) { Code.interp('Buffer(4).set(:u32, 1, 0)') }
		assert_equal 'Out_Of_Bounds: writing a 4-byte :u32 at offset 1 goes past the end: the buffer has 4 bytes (offsets 0 to 3)', error.message
	end

	def test_a_negative_offset_raises
		error = assert_raises(Code::Raised) { Code.interp('Buffer(4).get(:U8, -1)') }
		assert_equal 'Out_Of_Bounds: reading at offset -1 is before the start: offsets start at 0', error.message
	end

	def test_bits_past_the_end_raise_in_bits
		error = assert_raises(Code::Raised) { Code.interp('Buffer(2).get_bits(10, 8)') }
		assert_equal 'Out_Of_Bounds: reading bits 10 to 17 goes past the end: the buffer has 16 bits (bits 0 to 15)', error.message
		error = assert_raises(Code::Raised) { Code.interp('Buffer(2).set_bits(10, 8, 0)') }
		assert_equal 'Out_Of_Bounds: writing bits 10 to 17 goes past the end: the buffer has 16 bits (bits 0 to 15)', error.message
		error = assert_raises(Code::Raised) { Code.interp('Buffer(2).get_bits_signed(12, 8)') }
		assert_equal 'Out_Of_Bounds: reading bits 12 to 19 goes past the end: the buffer has 16 bits (bits 0 to 15)', error.message
	end

	def test_the_last_bits_that_fit_work
		assert_equal 0, Code.interp('Buffer(2).get_bits(8, 8)')
	end

	def test_a_negative_bit_raises
		error = assert_raises(Code::Raised) { Code.interp('Buffer(2).get_bits(-1, 2)') }
		assert_equal 'Out_Of_Bounds: reading at bit -1 is before the start: bits start at 0', error.message
		error = assert_raises(Code::Raised) { Code.interp('Buffer(2).set_bits(-1, 2, 0)') }
		assert_equal 'Out_Of_Bounds: writing at bit -1 is before the start: bits start at 0', error.message
	end

	# The start is checked first, so a range that is wrong at both ends reports the start, not a range that begins below 0.
	def test_a_negative_offset_is_reported_before_a_wide_value_past_the_end
		error = assert_raises(Code::Raised) { Code.interp('Buffer(2).get(:u32, -1)') }
		assert_equal 'Out_Of_Bounds: reading at offset -1 is before the start: offsets start at 0', error.message
		error = assert_raises(Code::Raised) { Code.interp('Buffer(2).set(:u32, -1, 0)') }
		assert_equal 'Out_Of_Bounds: writing at offset -1 is before the start: offsets start at 0', error.message
	end

	def test_a_negative_bit_is_reported_before_bits_past_the_end
		error = assert_raises(Code::Raised) { Code.interp('Buffer(2).get_bits(-5, 30)') }
		assert_equal 'Out_Of_Bounds: reading at bit -5 is before the start: bits start at 0', error.message
		error = assert_raises(Code::Raised) { Code.interp('Buffer(2).set_bits(-5, 30, 0)') }
		assert_equal 'Out_Of_Bounds: writing at bit -5 is before the start: bits start at 0', error.message
	end

	# Inside or past the end, a width below 1 is always a mistake, so it never silently returns 0.
	def test_a_bit_width_below_1_raises
		['get_bits(10, 0)', 'get_bits(17, 0)', 'get_bits(0, -3)', 'set_bits(10, 0, 0)', 'get_bits_signed(0, 0)'].each do |call|
			error = assert_raises(RuntimeError, call) { Code.interp "Buffer(2).#{call}" }
			assert_match(/\Awidth must be at least 1, got -?\d+ \(Integer\)\z/, error.message, call)
		end
	end

	# The guards read length() each time, not a size stored at construction, so they stay right when the bytes change size.
	def test_bounds_follow_a_buffer_made_from_a_string
		assert_equal 105, Code.interp('Buffer.from_string("hi").get(:u8, 1)')
		error = assert_raises(Code::Raised) { Code.interp('Buffer.from_string("hi").get(:u8, 2)') }
		assert_equal 'Out_Of_Bounds: reading a 1-byte :u8 at offset 2 goes past the end: the buffer has 2 bytes (offsets 0 to 1)', error.message
	end

	def test_bounds_follow_a_resize
		assert_equal 0, Code.interp("b := Buffer(2)\nb.resize(4)\nb.get(:u8, 3)")
		error = assert_raises(Code::Raised) { Code.interp("b := Buffer(4)\nb.resize(2)\nb.get(:u8, 2)") }
		assert_equal 'Out_Of_Bounds: reading a 1-byte :u8 at offset 2 goes past the end: the buffer has 2 bytes (offsets 0 to 1)', error.message
	end

	def test_an_empty_buffer_says_it_is_empty
		error = assert_raises(Code::Raised) { Code.interp('Buffer(0).get(:u8, 0)') }
		assert_equal 'Out_Of_Bounds: reading a 1-byte :u8 at offset 0 goes past the end: the buffer is empty', error.message
		error = assert_raises(Code::Raised) { Code.interp('Buffer(0).set(:u8, 0, 1)') }
		assert_equal 'Out_Of_Bounds: writing a 1-byte :u8 at offset 0 goes past the end: the buffer is empty', error.message
		error = assert_raises(Code::Raised) { Code.interp('Buffer(0).get_bits(0, 1)') }
		assert_equal 'Out_Of_Bounds: reading bits 0 to 0 goes past the end: the buffer is empty', error.message
	end

	# Wrong kinds of argument raise a message about the argument, not a raw Ruby error.
	def test_a_size_must_be_an_integer_of_0_or_more
		{ 'Buffer(-1)' => '-1 (Integer)', 'Buffer(1.5)' => '1.5 (Float)', 'Buffer(2).resize(-1)' => '-1 (Integer)' }.each do |code, got|
			error = assert_raises(RuntimeError, code) { Code.interp code }
			assert_equal "size must be an Integer, 0 or more, got #{got}", error.message
		end
	end

	def test_an_offset_must_be_an_integer
		['Buffer(2).get(:u8, 1.5)', 'Buffer(2).set(:u8, 1.5, 0)'].each do |code|
			error = assert_raises(RuntimeError, code) { Code.interp code }
			assert_equal 'offset must be an Integer, got 1.5 (Float)', error.message
		end
		error = assert_raises(RuntimeError) { Code.interp 'Buffer(2).get_bits(1.5, 2)' }
		assert_equal 'bit and width must be Integers, got bit 1.5 (Float) and width 2 (Integer)', error.message
	end

	def test_a_value_must_be_a_number
		error = assert_raises(RuntimeError) { Code.interp 'Buffer(2).set(:u8, 0, "x")' }
		assert_equal 'value must be a Number, got x (String)', error.message
		error = assert_raises(RuntimeError) { Code.interp 'Buffer(2).set(:u8, 0, true)' }
		assert_equal 'value must be a Number, got true (Bool)', error.message
		error = assert_raises(RuntimeError) { Code.interp 'Buffer(2).set_bits(0, 2, 1.5)' }
		assert_equal 'value must be an Integer, got 1.5 (Float)', error.message
	end

	# A @ruby method's Array result is wrapped as a language Array, so `==` works with it on either side.
	def test_bytes_equals_an_array_on_either_side
		assert_equal true, Code.interp('Buffer(2).bytes() == [0, 0]')
		assert_equal true, Code.interp('[0, 0] == Buffer(2).bytes()')
		assert_equal false, Code.interp('Buffer(2).bytes() == [0, 1]')
		assert_equal true, Code.interp("b := Buffer(2)\nb.set(:u16, 0, 0x0102)\nb.bytes() == [2, 1]")
	end

	def test_an_unknown_type_raises
		error = assert_raises(Code::Invalid_Buffer_Type) { Code.interp('Buffer(4).get(:u4, 0)') }
		assert_includes error.message, ':u4 is not a Buffer type'
		assert_includes error.message, ':u8 :s8 :u16'

		assert_raises(Code::Invalid_Buffer_Type) { Code.interp('Buffer(4).set(:u128, 0, 1)') }
		assert_raises(Code::Invalid_Buffer_Type) { Code.interp('Buffer.size_of(:bogus)') }
	end
	def test_lowercase_u8_and_s8_mean_uppercase_u8_and_s8
		assert_equal 200, Code.interp('Buffer(1).set(:u8, 0, 200).get(:U8, 0)')
		assert_equal(-1, Code.interp('Buffer(1).set(:S8, 0, -1).get(:s8, 0)'))
		assert_equal 1, Code.interp('Buffer.size_of(:u8)')
	end

	# h e l l o, the u32 is little-endian
	HELLO = <<~CODE
	b := Buffer(5)
	b.set(:u32, 0, 0x6c6c6568)
	#  ———————————————————————|
	#  0  | l  | l  | e  | h  |
	#  ———————————————————————|
	#  00 | 6c | 6c | 65 | 68 |

	b.set(:u8, 4, 0x6f)
	#  ———————————————————————|
	#  o  | l  | l  | e  | h  |
	#  ———————————————————————|
	#  6f | 6c | 6c | 65 | 68 |
	CODE

	def test_get_string_reads_every_byte
		assert_equal 'hello', Code.interp("#{HELLO}
		b.get_string()")
	end

	def test_get_string_keeps_zero_bytes
		src = <<~CODE
			b := Buffer(3)
			b.set(:u8, 0, 104).set(:u8, 1, 105)
			b.get_string()
		CODE
		assert_equal "hi\0", Code.interp(src)
		refute Code.interp("#{src.chomp} == 'hi'")
	end

	def test_get_string_of_an_empty_buffer_is_empty
		assert_equal '', Code.interp('Buffer().get_string()')
	end

	def test_get_string_of_a_buffer_made_from_a_string
		assert_equal 'hello', Code.interp('Buffer.from_string("hello").get_string()')
	end

	def test_get_string_gives_raw_bytes
		assert_equal "\xE9".b, Code.interp('Buffer(1).set(:u8, 0, 233).get_string()')
		assert_equal Encoding::BINARY, Code.interp('Buffer(1).get_string()').encoding
	end

	def test_get_string_slice_reads_length_bytes_from_start
		assert_equal 'ell', Code.interp("#{HELLO}b.get_string_slice(1, 3)")
		assert_equal 'h', Code.interp("#{HELLO}b.get_string_slice(0, 1)")
	end

	def test_get_string_slice_with_no_length_reads_to_the_end
		assert_equal 'llo', Code.interp("#{HELLO}b.get_string_slice(2)")
		assert_equal 'hello', Code.interp("#{HELLO}b.get_string_slice(0)")
	end

	def test_get_string_slice_of_zero_length_is_empty
		assert_equal '', Code.interp("#{HELLO}b.get_string_slice(0, 0)")
		assert_equal '', Code.interp("#{HELLO}b.get_string_slice(5)")
	end

	def test_get_string_slice_past_the_end_raises
		error = assert_raises(Code::Raised) { Code.interp("#{HELLO}b.get_string_slice(4, 5)") }
		assert_equal 'Out_Of_Bounds: reading 5 bytes at offset 4 goes past the end: the buffer has 5 bytes (offsets 0 to 4)', error.message
		error = assert_raises(Code::Raised) { Code.interp("#{HELLO}b.get_string_slice(6)") }
		assert_equal 'Out_Of_Bounds: reading at offset 6 goes past the end: the buffer has 5 bytes (offsets 0 to 4)', error.message
	end

	def test_get_string_slice_before_the_start_raises
		error = assert_raises(Code::Raised) { Code.interp("#{HELLO}b.get_string_slice(-1)") }
		assert_equal 'Out_Of_Bounds: reading at offset -1 is before the start: offsets start at 0', error.message
	end

	def test_get_string_slice_rejects_a_bad_length
		error = assert_raises(RuntimeError) { Code.interp("#{HELLO}b.get_string_slice(0, -2)") }
		assert_equal 'length must be 0 or more, or -1 to read to the end, got -2 (Integer)', error.message
		error = assert_raises(RuntimeError) { Code.interp("#{HELLO}b.get_string_slice(0.5)") }
		assert_equal 'start_index and length must be Integers, got 0.5 (Float) and -1 (Integer)', error.message
	end

	# --- inspect ---

	def test_to_s
		assert_equal 'Buffer(4 bytes)', Code.interp('Buffer(4).to_s()')
	end

	def test_hexdump
		assert_includes Code.interp('Buffer(4).set(:U32, 0, 0xDEADBEEF).hexdump()'), 'de ad be ef'
	end
end
