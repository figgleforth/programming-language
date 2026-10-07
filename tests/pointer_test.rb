require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

# note; Every read and write here gets its address from a real, live allocation (`p.to_i()`). A made-up address segfaults the whole Ruby process, which no assertion can catch.
class Pointer_Test < Base_Test
	# --- construction ---

	def test_pointer_allocates_the_given_number_of_bytes
		assert_equal 8, Code.interp('Pointer(8).size')
	end

	def test_pointer_is_a_pointer
		assert Code.interp('Pointer(8) === Pointer')
	end

	def test_a_new_pointer_is_not_null_and_not_freed
		refute Code.interp('Pointer(8).null?')
		refute Code.interp('Pointer(8).freed?')
	end

	def test_to_i_is_the_memory_address
		assert Code.interp('Pointer(8).to_i() > 0')
	end

	def test_each_pointer_has_its_own_memory
		refute Code.interp('Pointer(8).to_i() == Pointer(8).to_i()')
	end

	def test_malloc_is_the_same_as_the_constructor
		assert_equal 8, Code.interp('Pointer.malloc(8).size')
		refute Code.interp('Pointer.malloc(8).null?')
		assert Code.interp('Pointer.malloc(8) === Pointer')
	end

	# --- read and write ---

	def test_write_then_read_round_trips
		src = <<~CODE
			p := Pointer(4)
			Pointer.write(p.to_i(), "hi")
			Pointer.read(p.to_i(), 2)
		CODE
		assert_equal 'hi', Code.interp(src)
	end

	def test_write_returns_the_string_it_wrote
		assert_equal 'hi', Code.interp("p := Pointer(4)\nPointer.write(p.to_i(), \"hi\")")
	end

	def test_write_at_an_offset
		src = <<~CODE
			p := Pointer(4)
			Pointer.write(p.to_i(), "ab")
			Pointer.write(p.to_i() + 2, "cd")
			Pointer.read(p.to_i(), 4)
		CODE
		assert_equal 'abcd', Code.interp(src)
	end

	def test_read_a_part
		src = <<~CODE
			p := Pointer(4)
			Pointer.write(p.to_i(), "abcd")
			Pointer.read(p.to_i() + 1, 2)
		CODE
		assert_equal 'bc', Code.interp(src)
	end

	def test_new_memory_is_zero
		assert_equal "\0\0\0\0", Code.interp("p := Pointer(4)\nPointer.read(p.to_i(), 4)")
	end

	def test_to_s_reads_up_to_the_first_zero_byte
		src = <<~CODE
			p := Pointer(4)
			Pointer.write(p.to_i(), "hi")
			p.to_s()
		CODE
		assert_equal 'hi', Code.interp(src)
	end

	# --- resize ---

	def test_resize_grows_and_keeps_the_old_bytes
		src = <<~CODE
			p := Pointer(4)
			Pointer.write(p.to_i(), "hi")
			p.resize(8)
			[p.size, Pointer.read(p.to_i(), 2)]
		CODE
		assert_equal [8, 'hi'], Code.interp(src).values
	end

	def test_resize_shrinks_and_keeps_the_bytes_that_fit
		src = <<~CODE
			p := Pointer(4)
			Pointer.write(p.to_i(), "hiya")
			p.resize(2)
			[p.size, Pointer.read(p.to_i(), 2)]
		CODE
		assert_equal [2, 'hi'], Code.interp(src).values
	end

	def test_resize_returns_the_pointer
		assert_equal 16, Code.interp('Pointer(4).resize(16).size')
	end

	# --- reference and pointer ---

	def test_reference_is_a_new_pointer
		assert Code.interp('Pointer(8).reference() === Pointer')
		refute Code.interp('Pointer(8).reference().null?')
	end

	def test_dereferencing_a_reference_gives_the_same_address
		assert Code.interp("p := Pointer(8)\np.reference().pointer().to_i() == p.to_i()")
	end

	def test_dereferencing_memory_that_holds_zero_gives_a_null_pointer
		assert Code.interp('Pointer(8).pointer().null?')
	end

	def test_dereferencing_a_null_pointer_raises
		error = assert_raises(Code::Null_Pointer_Dereference) { Code::Pointer.new.proxy_pointer }
		assert_kind_of Code::Error, error
	end

	# --- to_pointer ---

	def test_to_pointer_points_at_a_string
		refute Code.interp('Pointer.to_pointer("hi").null?')
		assert Code.interp('Pointer.to_pointer("hi") === Pointer')
	end

	# --- free ---

	def test_call_free_marks_the_pointer_freed
		assert Code.interp("p := Pointer(8)\np.call_free()\np.freed?")
	end

	def test_call_free_returns_the_pointer
		assert Code.interp('Pointer(8).call_free() === Pointer')
	end
end
