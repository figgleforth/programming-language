require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

# Is-a on tags, at the Ruby level. tests/conformance/tagged_nil_when.code covers the language-level behavior.
class Tag_Is_A_Test < Base_Test
	TYPES = <<~CODE
		@load 'lang/errors.code'
		Client_Error | Error {}
		Bad_Header   | Client_Error {}
		Swimming {}
		Flying {}
		Duck | Swimming | Flying {}
	CODE

	def setup
		@interp = Code::Interpreter.new
		@interp.run TYPES
	end

	def run_code source
		@interp.run source
	end

	def is_a? own, other
		@interp.send :bare_type_is_a?, own, other
	end

	def test_bare_type_is_a_its_parent_type
		assert is_a?(run_code('Bad_Header'), run_code('Client_Error'))
		refute is_a?(run_code('Client_Error'), run_code('Bad_Header'))
	end

	def test_bare_type_is_a_type_name
		assert is_a?(run_code('Bad_Header'), 'Error')
		assert is_a?(run_code('Bad_Header'), 'Bad_Header')
		refute is_a?(run_code('Client_Error'), 'Bad_Header')
	end

	def test_bare_type_is_a_needs_a_bare_type_on_the_left
		refute is_a?(run_code('Duck()'), run_code('Swimming'))
		refute is_a?(5, run_code('Swimming'))
		refute is_a?(nil, 'Error')
	end

	def test_bare_type_is_a_needs_a_bare_type_on_the_right
		refute is_a?(run_code('Duck'), run_code('Duck()'))
		refute is_a?(run_code('Duck'), 5)
	end

	def test_a_type_with_two_parents_is_a_each_of_them
		assert is_a?(run_code('Duck'), run_code('Swimming'))
		assert is_a?(run_code('Duck'), run_code('Flying'))
		refute is_a?(run_code('Swimming'), run_code('Flying'))
	end

	def test_a_named_struct_tag_is_the_struct_itself
		tag = run_code('nil\\Error').tag_instance
		assert_kind_of Code::Struct, tag
		assert_equal 'Error', tag.name
	end

	def test_a_type_tag_holds_the_type_as_its_member
		tag = run_code('nil\\Bad_Header').tag_instance
		assert_equal %w(Bad_Header), tag.type_objects.map(&:name)
	end

	def test_superset_with_no_tags_compares_only_types
		superset = @interp.send :superset_of_types_and_tag?, Set['A', 'B'], nil, Set['A'], nil
		assert_equal true, superset
	end

	def test_superset_always_returns_a_boolean
		# A nil result once leaked out of `=>=` when the right tag had no name.
		assert_equal false, run_code('nil\\Client_Error =>= nil\\Bad_Header')
		assert_equal false, run_code('nil\\Bad_Header === nil\\Client_Error')
		assert_equal true,  run_code('nil\\Bad_Header =!= nil\\Client_Error')
	end

	def test_the_mirror_operator_matches_by_is_a_too
		assert_equal true,  run_code('nil\\Client_Error =<= nil\\Bad_Header')
		assert_equal false, run_code('nil\\Bad_Header =<= nil\\Client_Error')
	end

	def test_each_member_of_a_tag_with_several_members_matches_by_is_a
		run_code 'Pair\\<Swimming, Flying> {}'
		assert_equal true,  run_code('Pair\\<Duck, Duck> =>= Pair\\<Swimming, Flying>')
		assert_equal false, run_code('Pair\\<Swimming, Flying> =>= Pair\\<Duck, Duck>')
	end

	def test_a_named_struct_tag_still_matches_by_its_shape
		assert_equal true, run_code('nil\\Error =>= nil\\<message: String>')
	end

	def test_a_name_match_needs_a_type_that_composes_the_name
		run_code 'Unrelated {}'
		assert_equal false, run_code('nil\\Unrelated =>= nil\\Error')
	end

	def test_a_plain_nil_is_not_a_tagged_nil
		assert_equal false, run_code('nil =>= nil\\Error')
		assert_equal true,  run_code('nil\\Error =>= nil')
	end

	def test_when_takes_the_first_case_a_child_tag_matches
		result = run_code <<~CODE
			pick ( value;
				if value
					'value'
				else
				when nil\\Error
					'error'
				when nil\\Client_Error
					'client'
				end
			)
			pick(nil\\Bad_Header)
		CODE
		assert_equal 'error', result
	end
end
