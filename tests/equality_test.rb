require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

# `===` compares shape, `==` compares values, and `@object_id` is identity. tests/conformance/tagged_type_equality.code, instance_equality.code and object_id.code cover the language-level behavior.
class Equality_Test < Base_Test
	TYPES = <<~CODE
		S {}
		A {}
		B {}
		Dog | A {}
		Options := <table_name: String, columns: Number>
		Point {
			x := 0
			y := 0
			Self ( x, y;
				self.x = x
				self.y = y
			)
		}
		Node {
			value := 0
			other := nil
			Self ( value;
				self.value = value
			)
		}
	CODE

	def setup
		@interp = Code::Interpreter.new
		@interp.run TYPES
	end

	def run_code source
		@interp.run source
	end

	def tag source
		run_code(source).tag_instance
	end

	# Tags

	def test_triple_equals_compares_only_the_shape_of_a_tag
		assert_equal true, run_code('Int\\<16, 8> === Int\\<32, 4>')
		assert_equal false, run_code('Int\\<16, 8> =!= Int\\<32, 4>')
		assert_equal false, run_code('Int\\<16, 8> === Int\\<16, "x">')
	end

	def test_double_equals_compares_the_values_of_a_tag
		assert_equal true, run_code('Int\\<16, 8> == Int\\<16, 8>')
		assert_equal false, run_code('Int\\<16, 8> == Int\\<32, 4>')
		assert_equal true, run_code('Int\\<16, 8> != Int\\<32, 4>')
	end

	def test_member_names_never_count
		assert_equal true, run_code('Int\\<bits := 16, fraction := 8> === Int\\<16, 8>')
		assert_equal true, run_code('Int\\<bits := 16, fraction := 8> == Int\\<16, 8>')
		assert_equal false, run_code('Int\\<bits := 16, fraction := 8> == Int\\<bits := 32, fraction := 4>')
	end

	def test_a_value_has_the_shape_of_its_type
		assert_equal true, run_code('Int\\<Int, String> === Int\\<1234, "asdf">')
		assert_equal false, run_code('Int\\<Int, String> == Int\\<1234, "asdf">')
	end

	def test_a_tag_that_is_one_value
		assert_equal true, run_code('S\\4 === S\\5')
		assert_equal true, run_code('S\\4 != S\\5')
		assert_equal true, run_code('S\\4 == S\\4')
	end

	def test_a_tag_that_is_a_type_compares_by_the_type
		assert_equal true, run_code('Array\\String == Array\\String')
		assert_equal false, run_code('Array\\String == Array\\Int')
		assert_equal false, run_code('Array == Array\\String')
	end

	def test_a_type_with_no_tag_compares_by_its_composed_types
		assert_equal true, run_code('A == A')
		assert_equal false, run_code('A == B')
		assert_equal false, run_code('Dog == A')
		assert_equal true, run_code('Dog =>= A')
		assert_equal true, run_code('A === A')
	end

	# Variants

	def test_the_values_decide_the_variant
		run_code <<~CODE
			Fixed {
				bits (;
					'base'
				)
			}
			Fixed\\<bits := 16> {
				bits (;
					'16'
				)
			}
			Fixed\\<bits := 32> {
				bits (;
					'32'
				)
			}
		CODE
		assert_equal 2, @interp.global.tagged_type_variants['Fixed'].length
		assert_equal '16', run_code('Fixed\\<bits := 16>().bits()')
		assert_equal '32', run_code('Fixed\\<32>().bits()')
		assert_equal 'base', run_code('Fixed\\<64>().bits()')
	end

	def test_a_variant_declared_with_a_type_still_matches_a_value
		run_code <<~CODE
			Generic\\<Int> {
				what (;
					'int'
				)
			}
		CODE
		assert_equal 'int', run_code('Generic\\<7>().what()')
	end

	def test_a_variant_with_a_typed_default_matches_without_the_value
		run_code <<~CODE
			Thing\\<opts: Options = Options> {
				Self (;)
			}
		CODE
		refute_nil run_code('Thing\\<opts: Options>().@tag.opts')
	end

	# Struct#value_member?

	def test_an_unnamed_value_is_a_value_member
		assert tag('S\\4').value_member?(0)
		assert tag('Int\\<16, 8>').value_member?(1)
	end

	def test_an_inferred_member_is_a_value_member
		assert tag('Int\\<bits := 16>').value_member?(0)
	end

	def test_a_type_is_not_a_value_member
		refute tag('Array\\String').value_member?(0)
		refute tag('Int\\<bits: Int>').value_member?(0)
	end

	def test_a_typed_member_with_a_default_is_not_a_value_member
		refute run_code('<opts: Options = Options>').value_member?(0)
	end

	def test_a_reference_keeps_its_value_members_after_it_matches_a_named_variant
		run_code 'Int\\<bits := 16, fraction := 8>'
		positional = tag('Int\\<16, 8>')
		assert_equal %w(bits fraction), positional.names
		assert positional.value_member?(0)
		assert positional.value_member?(1)
	end

	# The helpers

	def test_tag_member_types_gives_the_type_of_each_value
		types = @interp.send :tag_member_types, tag('Int\\<16, "x">')
		assert_equal %w(Integer String), types.map(&:name)
	end

	def test_tag_member_types_keeps_a_type_member
		types = @interp.send :tag_member_types, tag('Array\\String')
		assert_equal %w(String), types.map(&:name)
	end

	def test_tag_member_types_of_no_tag_is_empty
		assert_equal [], @interp.send(:tag_member_types, nil)
	end

	def test_same_tag_values_with_no_tags
		assert_equal true, @interp.send(:same_tag_values?, nil, nil)
		assert_equal false, @interp.send(:same_tag_values?, tag('S\\4'), nil)
	end

	def test_same_tag_values_compares_a_named_struct_tag_by_name
		run_code "@load 'lang/errors.code'\nClosed | Error <>\nUnending | Error <>"
		assert_equal true, @interp.send(:same_tag_values?, tag('nil\\Closed'), tag('nil\\Closed'))
		assert_equal false, @interp.send(:same_tag_values?, tag('nil\\Closed'), tag('nil\\Unending'))
	end

	def test_same_type_on_two_copies_of_one_variant
		a = run_code 'Array\\String'
		b = run_code 'Array\\String'
		refute a.equal?(b)
		assert @interp.send(:same_type?, a, b)
	end

	# Values of a user type

	def test_values_of_a_user_type_compare_by_their_members
		assert_equal true, run_code('Point(1, 2) == Point(1, 2)')
		assert_equal false, run_code('Point(1, 2) == Point(1, 3)')
		assert_equal true, run_code('Point(1, 2) != Point(1, 3)')
		assert_equal true, run_code('A() == A()')
	end

	def test_values_of_two_types_are_not_equal
		assert_equal false, run_code('A() == B()')
		assert_equal false, run_code('Point(0, 0) == A()')
	end

	def test_triple_equals_on_two_values_of_one_type
		assert_equal true, run_code('Point(1, 2) === Point(3, 4)')
	end

	def test_a_cycle_of_values_ends
		assert_equal true, run_code("n1 := Node(1)\nn2 := Node(1)\nn1.other = n2\nn2.other = n1\nn1 == n2")
		assert_empty @interp.instance_variable_get(:@instances_being_compared)
	end

	def test_an_operator_overload_still_decides
		run_code <<~CODE
			Never {
				@operator == @infix ( left, right;
					false
				)
			}
		CODE
		assert_equal false, run_code('Never() == Never()')
	end

	def test_include_finds_an_equal_value
		assert_equal true, run_code('[Point(1, 2)].include?(Point(1, 2))')
	end

	# @object_id

	def test_object_id_is_identity_for_an_instance
		assert_equal true, run_code("a := Point(1, 2)\nb := a\na.@object_id == b.@object_id")
		assert_equal false, run_code('Point(1, 2).@object_id == Point(1, 2).@object_id')
	end

	def test_object_id_of_a_plain_value_stays_the_same
		assert_equal true, run_code("x := 4\nx.@object_id == x.@object_id")
		assert_equal true, run_code("f := 1.5\nf.@object_id == f.@object_id")
		assert_equal true, run_code("yes := true\nyes.@object_id == yes.@object_id")
		assert_equal true, run_code("s := 'a'\nt := s\ns.@object_id == t.@object_id")
	end

	def test_object_id_of_two_string_literals_differs
		assert_equal false, run_code("'a'.@object_id == 'a'.@object_id")
	end

	def test_every_nil_has_one_object_id
		assert_equal nil.object_id, run_code('nil.@object_id')
		assert_equal true, run_code("n := nil\nn.@object_id == nil.@object_id")
	end

	def test_object_id_of_a_plain_value_is_its_ruby_value_id
		value = 'hello'
		assert_equal value.object_id, @interp.send(:context_vital, 'object_id', Code::String.new(value))
	end
end
