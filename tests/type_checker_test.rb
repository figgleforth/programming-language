require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

class Type_Checker_Test < Base_Test
	def assert_type_error & block
		assert_raises Code::Type_Checking_Failed, &block
	end

	def refute_type_error & block
		refute_raises Code::Type_Checking_Failed, &block
	end

	# --- Happy paths ---

	def test_string_annotation_with_string_literal
		refute_type_error { Code.type_check "x: String = 'hello'" }
	end

	def test_number_annotation_with_number_literal
		refute_type_error { Code.type_check 'x: Number = 42' }
	end

	def test_symbol_annotation_with_symbol_literal
		refute_type_error { Code.type_check 'x: Symbol = :ok' }
	end

	def test_unannotated_assignment_is_not_checked
		refute_type_error { Code.type_check "x := 123" }
		refute_type_error { Code.type_check "x := 'hello'" }
		refute_type_error { Code.type_check "x := :sym" }
	end

	def test_unknown_rhs_is_skipped
		# Identifier on RHS with unknown type, so no error. todo: Maybe print a warning?
		refute_type_error { Code.type_check "y := 1, x: Number = y" }
	end

	# --- Mismatches at top level ---

	def test_string_annotation_with_number_literal
		assert_type_error { Code.type_check "x: String = 123" }
	end

	def test_string_annotation_with_symbol_literal
		assert_type_error { Code.type_check "x: String = :hello" }
	end

	def test_number_annotation_with_string_literal
		assert_type_error { Code.type_check "x: Number = 'hello'" }
	end

	def test_number_annotation_with_symbol_literal
		assert_type_error { Code.type_check "x: Number = :hello" }
	end

	def test_symbol_annotation_with_string_literal
		assert_type_error { Code.type_check "x: Symbol = 'hello'" }
	end

	def test_symbol_annotation_with_number_literal
		assert_type_error { Code.type_check "x: Symbol = 42" }
	end

	# --- Nested in function body ---

	def test_mismatch_nested_in_func_body
		assert_type_error { Code.type_check "go (; x: Number = 'oops' )" }
	end

	def test_valid_annotation_nested_in_func_body
		refute_type_error { Code.type_check "go (; x: Number = 42 )" }
	end

	def test_mismatch_in_func_param_default_is_caught
		assert_type_error { Code.type_check "go ( x: Number := 'bad'; x )" }
	end

	# --- Nested in type body ---

	def test_mismatch_nested_in_type_body
		assert_type_error { Code.type_check "Point { x: Number = 'bad' }" }
	end

	def test_valid_annotation_nested_in_type_body
		refute_type_error { Code.type_check "Point { x: Number = 0 }" }
	end

	# --- Nested in conditional ---

	def test_mismatch_in_if_when_true_branch
		assert_type_error { Code.type_check "if true \n x: String = 99 \n end" }
	end

	def test_mismatch_in_if_when_false_branch
		assert_type_error { Code.type_check "if true \n y = 1 \n else \n x: String = 99 \n end" }
	end

	def test_valid_annotation_in_conditional
		refute_type_error { Code.type_check "if true \n x: String = 'ok' \n end" }
	end

	# --- Nested in for loop ---

	def test_mismatch_in_for_loop_body
		assert_type_error { Code.type_check "for [1, 2, 3] \n x: String = 99 \n end" }
	end

	def test_valid_annotation_in_for_loop_body
		refute_type_error { Code.type_check "for [1, 2, 3] \n x: Number = 1 \n end" }
	end

	# --- Nested in prefix expression ---

	def test_mismatch_inside_prefix_expression
		assert_type_error { Code.type_check "!(x: Number = 'bad')" }
	end

	# --- Call site argument type checking ---

	def test_call_site_string_arg_where_number_expected
		assert_type_error { Code.type_check "add ( a: Number, b: Number; a + b ), add(1, 'oops')" }
	end

	def test_call_site_number_arg_where_string_expected
		assert_type_error { Code.type_check "greet ( name: String; name ), greet(42)" }
	end

	def test_call_site_symbol_arg_where_number_expected
		assert_type_error { Code.type_check "double ( x: Number; x + x ), double(:bad)" }
	end

	def test_call_site_correct_args_passes
		refute_type_error { Code.type_check "add ( a: Number, b: Number; a + b ), add(1, 2)" }
	end

	def test_call_site_correct_string_arg_passes
		refute_type_error { Code.type_check "greet ( name: String; name ), greet('hello')" }
	end

	def test_call_site_unknown_arg_is_skipped
		# Identifier arg — type unknown statically, no error
		refute_type_error { Code.type_check "x = 'oops', add ( a: Number; a ), add(x)" }
	end

	def test_call_site_only_typed_params_are_checked
		# Second param has no type annotation — should not error
		refute_type_error { Code.type_check "add ( a: Number, b; a ), add(1, 'anything')" }
	end

	def test_call_site_first_arg_mismatch_caught
		assert_type_error { Code.type_check "add ( a: Number, b: Number; a + b ), add('bad', 2)" }
	end

	def test_method_call_arg_mismatch_is_caught
		assert_type_error do
			Code.type_check <<~CODE
				Box { push ( item: String; item ) }
				b := Box()
				b.push(123)
			CODE
		end
	end

	def test_method_call_correct_arg_passes
		refute_type_error do
			Code.type_check <<~CODE
				Box { push ( item: String; item ) }
				b := Box()
				b.push('ok')
			CODE
		end
	end

	def test_method_call_unannotated_param_is_not_checked
		refute_type_error do
			Code.type_check <<~CODE
				Box { drop ( item; item ) }
				b := Box()
				b.drop(123)
			CODE
		end
	end

	def test_tagged_type_method_call_arg_mismatch_is_caught
		assert_type_error do
			Code.type_check <<~CODE
				Tag {}
				Box\\Tag { push ( item: String; item ) }
				b := Box\\Tag()
				b.push(123)
			CODE
		end
	end

	def test_tagged_type_method_call_unannotated_param_is_not_checked
		refute_type_error do
			Code.type_check <<~CODE
				Tag {}
				Box\\Tag { drop ( item; item ) }
				b := Box\\Tag()
				b.drop(123)
			CODE
		end
	end

	def test_method_call_through_a_type_alias_is_caught
		# `Aliased := Box\Tag` (a bare, uncalled type reference) is recorded in @type_aliases,
		# mapping the alias's own name to the real qualified type name ("Box\Tag") that
		# @type_info's methods/members were actually registered under (#check_inferred_declaration).
		# #constructed_type_name resolves an Identifier_Expr receiver through that map before
		# falling back to the identifier's own name, so `b := Aliased()` still statically knows
		# `b` is really a `Box\Tag`.
		assert_type_error do
			Code.type_check <<~CODE
				Tag {}
				Box\\Tag { push ( item: String; item ) }
				Aliased := Box\\Tag
				b := Aliased()
				b.push(123)
			CODE
		end
	end

	def test_method_call_through_a_type_alias_with_correct_arg_passes
		refute_type_error do
			Code.type_check <<~CODE
				Tag {}
				Box\\Tag { push ( item: String; item ) }
				Aliased := Box\\Tag
				b := Aliased()
				b.push('ok')
			CODE
		end
	end

	def test_method_return_type_mismatch_is_caught
		error = assert_raises Code::Type_Contract_Violation do
			Code.type_check <<~CODE
				Box { pop (-> String; 123 ) }
				b := Box()
				b.pop()
			CODE
		end
		assert_equal 'String', error.contract
		assert_equal 'Integer', error.actual
	end

	def test_method_return_type_match_passes
		refute_type_error do
			Code.type_check <<~CODE
				Box { pop (-> String; 'ok' ) }
				b := Box()
				b.pop()
			CODE
		end
	end

	def test_method_return_type_with_non_literal_body_is_skipped
		# Last expression is an identifier, not a literal -- unknown statically, so no error.
		refute_type_error do
			Code.type_check <<~CODE
				Box { pop (-> String; x := 123, x ) }
				b := Box()
				b.pop()
			CODE
		end
	end

	def test_bug_that_needs_fixing
		# todo: This test should fail
		refute_type_error { Code.type_check "name: String = nil\nname = 1234" }
	end

	# --- Union annotations (`x: A | B`) ---

	def test_union_annotation_with_literal_matching_first_alternative
		refute_type_error { Code.type_check 'x: Number | Symbol = 42' }
	end

	def test_union_annotation_with_literal_matching_second_alternative
		refute_type_error { Code.type_check 'x: Number | Symbol = :ok' }
	end

	def test_union_annotation_with_literal_matching_neither_alternative
		assert_type_error { Code.type_check "x: Number | Symbol = 'oops'" }
	end

	def test_union_param_default_matching_either_alternative
		refute_type_error { Code.type_check 'f ( a: Number | Symbol := 42; a )' }
		refute_type_error { Code.type_check 'f ( a: Number | Symbol := :ok; a )' }
	end

	def test_union_param_default_matching_neither_alternative
		assert_type_error { Code.type_check "f ( a: Number | Symbol := 'oops'; a )" }
	end
end
