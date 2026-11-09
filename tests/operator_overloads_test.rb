require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../ruby/main'
require_relative 'base_test'

# More than one `@operator` with the same symbol, one for each set of param types. A declaration fits when each operand fits its param; inside one scope the most specific one wins; the search goes from the left operand's type, to the right operand's type, to the stack, nearest scope first; and when nothing fits, the built-in operator runs.
class Operator_Overloads_Test < Base_Test
	VEC2 = <<~CODE
		V2 <x: Number, y: Number>

		@operator / @infix (left: V2, right: Number -> V2;
			V2(left.x / right, left.y / right)
		)

		@operator / @infix (left: V2, right: V2 -> V2;
			V2(left.x / right.x, left.y / right.y)
		)
	CODE

	def values_of source
		Code.interp(source).values
	end

	def test_each_declaration_takes_its_own_operand_types
		assert_equal [2, 4], values_of("#{VEC2}\nV2(4, 8) / 2")
		assert_equal [2, 2], values_of("#{VEC2}\nV2(4, 8) / V2(2, 4)")
	end

	def test_the_built_in_runs_when_no_declaration_fits
		assert_equal 3, Code.interp("#{VEC2}\n9 / 3")
		assert_equal 2.5, Code.interp("#{VEC2}\n5.0 / 2")
	end

	def test_an_operator_body_can_use_the_built_in_of_its_own_symbol
		assert_equal [2, 4], values_of("#{VEC2}\nV2(4, 8) / 2"), 'left.x / right inside the body is the built-in /'
	end

	def test_a_nil_fits_only_an_untyped_param
		error = assert_raises(Code::Undeclared_Infix_Operator) { Code.interp "#{VEC2}\nnil / 2" }
		refute_kind_of Code::Undeclared_Operator, error
	end

	def test_the_most_specific_declaration_wins
		source = <<~CODE
			Base <x: Number>
			Child + Base <y: Number = 0>

			@operator + @infix (left: Base, right; 'any base')
			@operator + @infix (left: Child, right; 'a child')
			@operator + @infix (left: Child, right: Number; 'a child and a number')

			<Base(1) + 1, Child(1) + 'a', Child(1) + 1>
		CODE
		assert_equal ['any base', 'a child', 'a child and a number'], values_of(source)
	end

	def test_with_an_equal_fit_the_first_declared_wins
		source = <<~CODE
			@operator <+> @infix (left: Number, right; 'first')
			@operator <+> @infix (left: Number | String, right; 'second')
			1 <+> 2
		CODE
		assert_equal 'first', Code.interp(source)
	end

	def test_the_left_param_decides_before_the_right_one
		source = <<~CODE
			@operator <+> @infix (left, right: Number; 'right typed')
			@operator <+> @infix (left: Number, right; 'left typed')
			1 <+> 2
		CODE
		assert_equal 'left typed', Code.interp(source)
	end

	def test_the_same_param_types_replace_whatever_the_return_type
		source = <<~CODE
			@operator <+> @infix (left: Number, right: Number -> Number; 1)
			@operator <+> @infix (left: Number, right: Number -> String; 'replaced')
			2 <+> 3
		CODE
		assert_equal 'replaced', Code.interp(source)
	end

	def test_an_alias_is_the_type_it_names_in_the_key
		source = <<~CODE
			@operator <+> @infix (left: Int, right: Int; 'int')
			@operator <+> @infix (left: Integer, right: Integer; 'integer')
			2 <+> 3
		CODE
		assert_equal 'integer', Code.interp(source)
	end

	def test_a_composed_param_type_takes_each_of_its_types
		source = <<~CODE
			#{VEC2}
			@operator * @infix (left: V2, right: Number | V2 -> V2; V2(1, 1))
			<(V2(4, 8) * 2).x, (V2(4, 8) * V2(1, 1)).x, 3 * 4>
		CODE
		assert_equal [1, 1, 12], values_of(source)
	end

	def test_a_local_declaration_falls_back_outward_when_it_does_not_fit
		source = <<~CODE
			#{VEC2}
			draw (;
				@operator / @infix (left: V2, right: V2; 'local')
				<V2(4, 8) / V2(1, 1), (V2(4, 8) / 2).x, 9 / 3>
			)
			draw()
		CODE
		assert_equal ['local', 2, 3], values_of(source)
	end

	def test_the_nearest_scope_wins_even_when_an_outer_one_is_more_specific
		source = <<~CODE
			@operator <+> @infix (left: Number, right: Number; 'outer')
			inner (;
				@operator <+> @infix (left, right; 'inner')
				1 <+> 2
			)
			inner()
		CODE
		assert_equal 'inner', Code.interp(source)
	end

	def test_a_type_gives_an_operator_on_the_left_and_on_the_right
		source = <<~CODE
			Money {
				amount := 0

				Self ( amount := 0; self.amount = amount )

				@operator * @infix (left: Money, right: Number -> Money;
					Money(left.amount * right)
				)

				@operator * @infix (left: Number, right: Money -> Money;
					Money(left * right.amount)
				)
			}

			<(Money(5) * 3).amount, (3 * Money(5)).amount, 3 * 5>
		CODE
		assert_equal [15, 15, 15], values_of(source)
	end

	def test_an_untyped_right_param_is_not_found_through_the_right_operand
		error = assert_raises(Code::Invalid_Infix_Operands) { Code.interp '5 - [1]' }
		assert_equal '-', error.operator
	end

	def test_prefix_declarations_fall_back_to_the_built_in
		source = <<~CODE
			#{VEC2}
			@operator - @prefix (value: V2 -> V2; V2(0 - value.x, 0 - value.y))
			<(-V2(1, 2)).x, -5, 7 - 2>
		CODE
		assert_equal [-1, -5, 5], values_of(source)
	end

	def test_composition_joins_the_declarations_and_the_leftmost_wins
		source = <<~CODE
			A {
				@operator <+> @infix (left, right: Number; 'a number')
				@operator <+> @infix (left, right: String; 'a string from A')
			}
			B {
				@operator <+> @infix (left, right: String; 'a string from B')
				@operator <+> @infix (left, right: Bool; 'a bool')
			}
			Both + A + B {}
			b      := Both()
			number := b <+> 1
			string := b <+> 'x'
			bool   := b <+> true
			<number, string, bool>
		CODE
		assert_equal ['a number', 'a string from A', 'a bool'], values_of(source)
	end

	def test_composition_does_not_change_the_type_it_takes_the_declarations_from
		source = <<~CODE
			A { @operator <+> @infix (left, right: Number; 'a') }
			Both + A {
				@operator <+> @infix (left, right: String; 'both')
			}
			a := A()
			a <+> 'x'
		CODE
		error = assert_raises(Code::Undeclared_Operator) { Code.interp source }
		assert_equal '<+>', error.expression.value
	end

	def test_an_operator_is_hoisted_in_its_scope
		assert_equal 12, Code.interp("x := 1 <+> 2\n@operator <+> @infix (left, right; left * 10 + right)\nx")
		assert_equal 12, Code.interp("f (;\n\tx := 1 <+> 2\n\t@operator <+> @infix (left, right; left * 10 + right)\n\tx\n)\nf()")
	end

	def test_a_contract_error_in_an_operator_points_at_the_expression
		source = "@operator <+> @infix (left, right -> String; 1)\nx := 0\nx := 1 <+> 2"
		error  = assert_raises(Code::Type_Contract_Violation) { Code.interp source }
		refute_nil error.expression.line_start, 'it had no location'
		assert_equal 3, error.expression.line_start
	end

	# Writes each { 'name' => source } as name.code under a fresh temp dir, and gives the path of main.code.
	def with_files files
		Dir.mktmpdir do |dir|
			files.each { |name, source| File.write File.join(dir, "#{name}.code"), source }
			yield File.join(dir, 'main.code')
		end
	end

	def test_a_precedence_is_scoped_to_its_function_and_hoisted_there
		source = <<~CODE
			tight (;
				x := 1 + 2 * 3
				@operator + @infix 900 ( left: String, right; 0 )
				x
			)
			outside := 1 + 2 * 3
			<tight(), outside>
		CODE
		assert_equal [9, 7], values_of(source), '(1 + 2) * 3 inside, 1 + (2 * 3) outside'
	end

	def test_a_type_body_gives_its_operator_to_the_scope_around_it
		source = <<~CODE
			Ops {
				@operator <+> @infix 650 ( left, right; left * 10 + right )
			}
			1 <+> 2 * 3
		CODE
		error = assert_raises(Code::Undeclared_Operator) { Code.interp source }
		assert_equal '<+>', error.expression.value, 'it parses outside the type, but a type operator is found only through its operands'
	end

	def test_two_precedences_for_one_symbol_in_one_scope_raise
		source = "@operator <+> @infix 800 ( left: Number, right; 1 )\n@operator <+> @infix 900 ( left: String, right; 2 )"
		error  = assert_raises(Code::Operator_Precedence_Conflict) { Code.interp source }
		assert_equal [800, 900], [error.earlier_precedence, error.precedence]
	end

	def test_an_inner_scope_can_give_its_own_precedence
		source = <<~CODE
			@operator <+> @infix 800 ( left, right; left * 10 + right )
			inner (;
				@operator <+> @infix 300 ( left, right; left * 10 + right )
				1 <+> 2 * 3
			)
			<1 <+> 2 * 3, inner()>
		CODE
		assert_equal [36, 16], values_of(source), '(1 <+> 2) * 3 with 800, 1 <+> (2 * 3) with 300'
	end

	def test_a_bare_load_brings_the_operators_of_the_file
		files = {
			'main' => "@load ./ops\n1 <+> 2 * 3",
			'ops'  => "@operator <+> @infix 800 ( left, right; left * 10 + right )",
		}
		with_files(files) { |main| assert_equal 36, Code.interp_file(main) }
	end

	def test_a_named_load_gives_its_operators_through_its_name
		files = {
			'main' => "lib := @load './ops'\n1 lib.<+> 2 * 3",
			'ops'  => "@operator <+> @infix 800 ( left, right; left * 10 + right )",
		}
		with_files(files) { |main| assert_equal 36, Code.interp_file(main) }
	end

	def test_a_named_load_does_not_bring_its_operators_without_its_name
		files = {
			'main' => "lib := @load './ops'\n1 <+> 2",
			'ops'  => "@operator <+> @infix 800 ( left, right; left * 10 + right )",
		}
		with_files(files) { |main| assert_raises(Code::Undeclared_Operator) { Code.interp_file main } }
	end

	def test_a_named_operator_that_does_not_fit_raises
		files = {
			'main' => "lib := @load './ops'\n'a' lib.<+> 2",
			'ops'  => "@operator <+> @infix ( left: Number, right; 1 )",
		}
		with_files files do |main|
			error = assert_raises(Code::Undeclared_Operator) { Code.interp_file main }
			assert_equal 'lib', error.namespace
		end
	end

	# A struct that composes a type with operators keeps its data members first, so a positional argument fills a data member, and the operators work on its values.
	def test_a_struct_composed_with_operators_keeps_its_data_members_first
		source = <<~CODE
			Ops {
				@operator / @infix ( left, right: Number; left.x / right )
			}
			Other {
				@operator / @infix ( left, right: String; 'a string' )
			}
			V + Ops + Other <x: Number>
			v       := V(8)
			number  := v / 2
			string  := v / 'a'
			<v.x, number, string>
		CODE
		assert_equal [8, 4, 'a string'], values_of(source)
	end
end
