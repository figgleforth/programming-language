require 'minitest/autorun'
require_relative '../lib/air'

class Parser_Test < Minitest::Test
	def test_identifiers
		zipped = %w(variable_or_function CONSTANT Type).zip %I(identifier IDENTIFIER Identifier)
		zipped.each do |code, type|
			out = _parse code
			assert_kind_of Identifier_Expr, out.first
			assert_equal code, out.first.value
			assert_nil out.first.type
		end
	end

	def test_integers_and_floats
		out = _parse '4'
		assert_kind_of Number_Expr, out.first
		assert_equal 4, out.first.value
		assert_equal :integer, out.first.type

		out = _parse '2.3'
		assert_kind_of Number_Expr, out.first
		assert_equal 2.3, out.first.value
		assert_equal :float, out.first.type
	end

	def test_numbers_with_prefixes
		out = _parse '-42'
		assert_kind_of Prefix_Expr, out.first
		assert_equal '-', out.first.operator
		assert_equal 42, out.first.expression.value
		assert_kind_of Number_Expr, out.first.expression

		out = _parse '+4.2'
		assert_kind_of Prefix_Expr, out.first
		assert_equal '+', out.first.operator
		assert_equal 4.2, out.first.expression.value
		assert_kind_of Number_Expr, out.first.expression
	end

	def test_numbers_with_underscores
		out = _parse '2_000'
		assert_equal 1, out.count
		assert_kind_of Number_Expr, out.first
		assert_equal 2000, out.first.value

		out = _parse '3_0_'
		assert_equal 2, out.count
		assert_kind_of Number_Expr, out.first
		assert_equal 30, out.first.value
		assert_kind_of Identifier_Expr, out.last
		assert_equal '_', out.last.value

		out = _parse '_2_00'
		assert_equal 1, out.count
		refute_kind_of Number_Expr, out.first
		refute_equal 200, out.first.value

		out = _parse '-20three'
		assert_equal 2, out.count
		assert_kind_of Prefix_Expr, out.first
		assert_kind_of Identifier_Expr, out.last
		assert_equal 20, out.first.expression.value
		assert_equal 'three', out.last.value

		out = _parse '40_two'
		assert_equal 2, out.count
		assert_kind_of Number_Expr, out.first
		assert_kind_of Identifier_Expr, out.last
		assert_equal 40, out.first.value
		assert_equal '_two', out.last.value

		out = _parse '4__5__2__2'
		assert_equal 2, out.count
		assert_kind_of Number_Expr, out.first
		assert_kind_of Identifier_Expr, out.last
		assert_equal 4, out.first.value
		assert_equal '__5__2__2', out.last.value

		out = _parse 'a1234'
		assert_equal 1, out.count
		assert_kind_of Identifier_Expr, out.first
		assert_equal 'a1234', out.first.value
		refute out.first.type
	end

	def test_strings
		out = _parse '"A string"'
		assert_kind_of String_Expr, out.first
		refute out.first.interpolated

		out = _parse "'Another string'"
		assert_kind_of String_Expr, out.first
		refute out.first.interpolated

		out = _parse '"An |interpolated| string"'
		assert_kind_of String_Expr, out.first
		assert out.first.interpolated

		out = _parse "'Another |interpolated| string'"
		assert_kind_of String_Expr, out.first
		assert out.first.interpolated
	end

	def test_compound_assignments
		out = _parse 'numbers += 1623'
		refute_kind_of Identifier_Expr, out.first
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Number_Expr, out.first.right
		assert_equal 1, out.count

		out = _parse 'numbers -= 1623'
		assert_kind_of Infix_Expr, out.first

		out = _parse 'flag |= 2'
		assert_kind_of Infix_Expr, out.first
	end

	def test_operator_precedence
		out = _parse '1 + 2 * 3 / 4 - 5 % 6'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Infix_Expr, out.first.left
		assert_kind_of Number_Expr, out.first.left.left
		assert_equal 1, out.first.left.left.value
		assert_equal '+', out.first.left.operator
		assert_kind_of Infix_Expr, out.first.left.right
		assert_kind_of Infix_Expr, out.first.left.right.left
		assert_kind_of Number_Expr, out.first.left.right.left.left
		assert_equal 2, out.first.left.right.left.left.value
		assert_kind_of Number_Expr, out.first.left.right.left.right
		assert_equal 3, out.first.left.right.left.right.value
		assert_equal '/', out.first.left.right.operator
		assert_kind_of Number_Expr, out.first.left.right.right
		assert_equal 4, out.first.left.right.right.value
		assert_equal '-', out.first.operator
		assert_kind_of Infix_Expr, out.first.right
		assert_kind_of Number_Expr, out.first.right.left
		assert_equal 5, out.first.right.left.value
		assert_equal '%', out.first.right.operator
		assert_kind_of Number_Expr, out.first.right.right
		assert_equal 6, out.first.right.right.value
	end

	def test_operator_precedence_with_parentheses
		out = _parse '1 + ((2*3) / 4) - (5 % 6)'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Infix_Expr, out.first.left
		assert_equal '+', out.first.left.operator
		assert_kind_of Number_Expr, out.first.left.left
		assert_equal 1, out.first.left.left.value
		assert_kind_of Circumfix_Expr, out.first.left.right
		assert_kind_of Infix_Expr, out.first.left.right.expressions.first
		assert_equal '/', out.first.left.right.expressions.first.operator
		assert_kind_of Circumfix_Expr, out.first.left.right.expressions.first.left
		assert_equal 2, out.first.left.right.expressions.first.left.expressions.first.left.value
		assert_equal '*', out.first.left.right.expressions.first.left.expressions.first.operator
		assert_equal 3, out.first.left.right.expressions.first.left.expressions.first.right.value
		assert_kind_of Number_Expr, out.first.left.right.expressions.first.right
		assert_equal 4, out.first.left.right.expressions.first.right.value
		assert_equal '-', out.first.operator
		assert_kind_of Circumfix_Expr, out.first.right
		assert_kind_of Number_Expr, out.first.right.expressions.first.left
		assert_equal 5, out.first.right.expressions.first.left.value
		assert_equal '%', out.first.right.expressions.first.operator
		assert_kind_of Number_Expr, out.first.right.expressions.first.right
		assert_equal 6, out.first.right.expressions.first.right.value
	end

	def test_other
		out = _parse 'numbers = 4815'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Number_Expr, out.first.right
		assert_equal 1, out.count

		out = _parse 'numbers;'
		assert_kind_of Postfix_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.expression
		assert_equal ';', out.first.operator

		out = _parse 'Type = {}'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.left
		assert_kind_of Circumfix_Expr, out.first.right
		assert_equal 1, out.count

		out = _parse 'time: Float'
		assert_equal 'Float', out.first.type.value

		out = _parse 'num: Int = 1 + 2'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Infix_Expr, out.first.right
		assert_equal 'Int', out.first.left.type.value
	end

	def test_more_fixities
		out = _parse '1 + 2 * 3 / 4'
		assert_kind_of Infix_Expr, out.first
		assert_equal 1, out.count

		out = _parse '1 < 2'
		assert_kind_of Infix_Expr, out.first
		assert_equal 1, out.count

		out = _parse '2 >= 1'
		assert_kind_of Infix_Expr, out.first
		assert_equal 1, out.count

		out = _parse '1 != 2'
		assert_kind_of Infix_Expr, out.first
		assert_equal 1, out.count

		out = _parse '1 == 2'
		assert_kind_of Infix_Expr, out.first
		assert_equal 1, out.count

		out = _parse '1 < 2, 4 > 3'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Infix_Expr, out.last
		assert_equal 2, out.count
	end

	def test_ranges
		out = _parse '1..2'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Number_Expr, out.first.left
		assert_equal '..', out.first.operator
		assert_kind_of Number_Expr, out.first.right
		assert_equal 1, out.first.left.value
		assert_equal 2, out.first.right.value

		out = _parse '3.0..4.0'
		assert_kind_of Number_Expr, out.first.left
		assert_kind_of Infix_Expr, out.first
		assert_equal '..', out.first.operator
		assert_kind_of Number_Expr, out.first.right
		assert_equal 3.0, out.first.left.value
		assert_equal 4.0, out.first.right.value

		out = _parse '3.<4'
		assert_kind_of Number_Expr, out.first.left
		assert_kind_of Infix_Expr, out.first
		assert_equal '.<', out.first.operator
		assert_kind_of Number_Expr, out.first.right
		assert_equal 3, out.first.left.value
		assert_equal 4, out.first.right.value

		out = _parse '5>.6'
		assert_kind_of Number_Expr, out.first.left
		assert_kind_of Infix_Expr, out.first
		assert_equal '>.', out.first.operator
		assert_kind_of Number_Expr, out.first.right
		assert_equal 5, out.first.left.value
		assert_equal 6, out.first.right.value

		out = _parse '7><8'
		assert_kind_of Number_Expr, out.first.left
		assert_kind_of Infix_Expr, out.first
		assert_equal '><', out.first.operator
		assert_kind_of Number_Expr, out.first.right
		assert_equal 7, out.first.left.value
		assert_equal 8, out.first.right.value

		out = _parse '1..2, 3.<4, 5>.6, 7><8'
		assert_equal 4, out.count
		out.each do
			assert_kind_of Infix_Expr, it
			assert_kind_of Number_Expr, it.left
			assert_kind_of Number_Expr, it.right
		end
	end

	def test_comma_separated_expressions
		out = _parse 'a, B, 5, "cool"'
		assert_equal 4, out.count
		assert_kind_of Identifier_Expr, out[0]
		assert_kind_of Identifier_Expr, out[1]
		assert_kind_of Number_Expr, out[2]
		assert_kind_of String_Expr, out[3]
	end

	def test_scope_operators
		out = _parse './this_instance'
		assert_kind_of Identifier_Expr, out.first
		assert_equal './', out.first.scope_operator

		out = _parse '../global_scope'
		assert_kind_of Identifier_Expr, out.first
		assert_equal '../', out.first.scope_operator

		out = _parse '.../third_party'
		assert_kind_of Identifier_Expr, out.first
		assert_equal '.../', out.first.scope_operator
	end

	def test_functions
		out = _parse '{;}'
		assert_kind_of Func_Expr, out.first
		assert_empty out.first.expressions
		refute out.first.name

		out = _parse '{;
		}'
		assert_empty out.first.expressions
		refute out.first.name

		out = _parse 'named_function {;}'
		assert_equal 'named_function', out.first.name.value
	end

	def test_function_params
		out = _parse '{ with_param; }'
		assert_equal 1, out.first.expressions.count
		out.first.expressions.each do
			assert_kind_of Param_Expr, it
		end

		out = _parse 'named { with_param; }'
		assert_equal 'named', out.first.name.value
		assert_equal 1, out.first.expressions.count
		out.first.expressions.each do
			assert_kind_of Param_Expr, it
		end
		refute out.first.expressions.first.label
		refute out.first.expressions.first.default
		refute out.first.expressions.first.type

		out = _parse '{ labeled param; }'
		assert_kind_of Param_Expr, out.first.expressions.first
		assert_equal 'labeled', out.first.expressions.first.label
		assert out.first.expressions.first.label
		refute out.first.expressions.first.default
		refute out.first.expressions.first.type

		out = _parse '{ default_values = 4; }'
		assert_kind_of Param_Expr, out.first.expressions.first
		assert out.first.expressions.first.default
		assert_kind_of Number_Expr, out.first.expressions.first.default

		out = _parse 'named { and_labeled with_default = 8; }'
		assert_kind_of Param_Expr, out.first.expressions.first
		assert_equal 'and_labeled', out.first.expressions.first.label
		assert_equal 'with_default', out.first.expressions.first.name
		assert_equal 'named', out.first.name.value

		out = _parse 'named { with, multiple, even labeled = 4, params = 5; }'
		assert_equal 4, out.first.expressions.count
		assert_equal out.first.expressions.map(&:label), [nil, nil, 'even', nil]
		assert_equal out.first.expressions.map(&:name), %w(with multiple labeled params)
		assert_equal out.first.expressions.map(&:default).map(&:nil?), [true, true, false, false]
	end

	def test_function_bodies
		out = _parse '
		square { input;
			input * input
		}'
		refute_empty out.first.expressions
		assert_kind_of Infix_Expr, out.first.expressions[1]

		out = _parse '
		nothing { input;
			return input
		}'
		assert_kind_of Prefix_Expr, out.first.expressions[1]
		assert_kind_of Identifier_Expr, out.first.expressions[1].expression
	end

	def test_function_signatures
		out = _parse 'nothing { input;
			return input
		}'
		assert_equal 'nothing{input;}', out.first.signature
	end

	def test_complex_function
		out = _parse '
		curr? { sequence;
			if not remainder or not lexemes?
				return false
			end

			slice = remainder.slice(0, sequence.count)
			slice.{;
				expected = sequence[at]

				if expected === Array
					expected.any? {;
						it == it2
					}
				else
					it == expected
				end
			}
		}'
		assert_kind_of Func_Expr, out.first
		assert_equal 'curr?', out.first.name.value
		assert_equal 4, out.first.expressions.count

		early_return = out.first.expressions[1]
		assert_kind_of Conditional_Expr, early_return
		assert_kind_of Infix_Expr, early_return.condition
		assert_equal 'or', early_return.condition.operator
		assert_kind_of Prefix_Expr, early_return.condition.left
		assert_kind_of Prefix_Expr, early_return.condition.right
		assert_equal 1, early_return.when_true.count # todo One for return and one for false in `return false`. Maybe I should make it a prefix keyword.

		slice = out.first.expressions[2]
		assert_kind_of Infix_Expr, slice

		tap = out.first.expressions.last
		assert_kind_of Infix_Expr, tap
		assert_kind_of Func_Expr, tap.right
		assert_equal 2, tap.right.expressions.count
		assert_kind_of Infix_Expr, tap.right.expressions.first
		assert_kind_of Conditional_Expr, tap.right.expressions.last

		conditional = tap.right.expressions.last
		assert_kind_of Infix_Expr, conditional.condition
		assert_equal '===', conditional.condition.operator
		assert_equal 1, conditional.when_true.count # todo I don't think when_true and when_false convey that they return an array
		assert_equal 1, conditional.when_false.count

		any = conditional.when_true.first
		assert_kind_of Infix_Expr, any
		assert_kind_of Func_Expr, any.right
		assert_kind_of Infix_Expr, any.right.expressions.first
		assert_equal 'it', any.right.expressions.first.left.value
		assert_equal 'it2', any.right.expressions.first.right.value
	end

	def test_function_calls
		out = _parse '{;}()'
		assert_kind_of Call_Expr, out.first
		assert_kind_of Func_Expr, out.first.receiver
		assert_empty out.first.arguments

		out = _parse '{;}(true)'
		refute_empty out.first.arguments
		assert_kind_of Identifier_Expr, out.first.arguments.first

		out = _parse '{;}(1, 2, 3)'
		out.first.arguments.each do
			assert_kind_of Number_Expr, it
		end
	end

	def test_types
		out = _parse 'String {}'
		assert_kind_of Type_Expr, out.first
		assert_equal 'String', out.first.name.value

		out = _parse 'Transform {
			position;
			rotation;
		}'
		assert_equal 2, out.first.expressions.count

		out = _parse 'Entity {
			|Transform
		}'
		assert_kind_of Composition_Expr, out.first.expressions.first
		assert_equal '|', out.first.expressions.first.operator
		assert_equal 'Transform', out.first.expressions.first.identifier.value
	end

	def test_mixed_inline_compositions
		out = _parse 'Xform | Transform ~ Vec2 & This ^ That {}'
		assert_kind_of Composition_Expr, out.first.expressions.first
		assert_equal '|', out.first.expressions[0].operator
		assert_equal 'Transform', out.first.expressions[0].identifier.value
		assert_equal '~', out.first.expressions[1].operator
		assert_equal 'Vec2', out.first.expressions[1].identifier.value
		assert_equal '&', out.first.expressions[2].operator
		assert_equal 'This', out.first.expressions[2].identifier.value
		assert_equal '^', out.first.expressions[3].operator
		assert_equal 'That', out.first.expressions[3].identifier.value
	end

	def test_control_flows
		out = _parse 'if true
			celebrate()
		end'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Call_Expr, out.first.when_true.first

		out = _parse 'wrap { number, limit;
			if number > limit
				number = 0
			end
		 }'
		assert_kind_of Conditional_Expr, out.first.expressions[2]

		out = _parse 'if 1 + 2 * 3 == 7
			"This one!"
		elif 1 + 2 * 3 == 9
			\'No, this one!\'
		else
			\'🤯\'
		end'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Conditional_Expr, out.first.when_false
		assert_kind_of String_Expr, out.first.when_false.when_false.first
	end

	def test_conditionals_at_end_of_line
		out = _parse 'eat while lexemes? && curr?()'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Infix_Expr, out.first.condition
		assert_kind_of Identifier_Expr, out.first.when_true.first
	end

	def test_unless_conditional
		out = _parse 'do_this unless the_condition'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.condition
		assert_equal 'unless', out.first.type
		assert_equal 'the_condition', out.first.condition.value
		assert_kind_of Identifier_Expr, out.first.when_false.first
		assert_equal 'do_this', out.first.when_false.first.value
	end

	def test_until_conditional
		out = _parse 'repeat_this until the_condition'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.condition
		assert_equal 'until', out.first.type
		assert_equal 'the_condition', out.first.condition.value
		assert_kind_of Identifier_Expr, out.first.when_false.first
		assert_equal 'repeat_this', out.first.when_false.first.value
	end

	def test_silly_elwhile
		out        = _parse '
		while a
			1
		elwhile b
			2
		elwhile c
			3
		else
			4
		end
		'
		while_case = out.first
		assert_kind_of Conditional_Expr, while_case
		assert_equal 'while', while_case.type
		assert_kind_of Number_Expr, while_case.when_true.first
		assert_equal 1, while_case.when_true.first.value
		assert_kind_of Conditional_Expr, while_case.when_false

		elwhile = while_case.when_false
		assert_equal 'elwhile', elwhile.type
		assert_kind_of Number_Expr, elwhile.when_true.first
		assert_equal 2, elwhile.when_true.first.value
		assert_kind_of Conditional_Expr, elwhile.when_false

		elwhile = elwhile.when_false
		assert_equal 'elwhile', elwhile.type
		assert_kind_of Number_Expr, elwhile.when_true.first
		assert_equal 3, elwhile.when_true.first.value
		assert_kind_of Number_Expr, elwhile.when_false.first
		assert_equal 4, elwhile.when_false.first.value
	end

	def test_if_else
		# Direct copy-past from test_silly_elwhile
		out = _parse '
		if a
			1
		elif b
			2
		elif c
			3
		else
			4
		end
		'

		# elif elif else
		if_case = out.first
		assert_kind_of Conditional_Expr, if_case
		assert_equal 'if', if_case.type
		assert_kind_of Number_Expr, if_case.when_true.first
		assert_equal 1, if_case.when_true.first.value
		assert_kind_of Conditional_Expr, if_case.when_false

		elif_case = if_case.when_false
		assert_equal 'elif', elif_case.type
		assert_kind_of Number_Expr, elif_case.when_true.first
		assert_equal 2, elif_case.when_true.first.value
		assert_kind_of Conditional_Expr, elif_case.when_false

		elif_case = elif_case.when_false
		assert_equal 'elif', elif_case.type
		assert_kind_of Number_Expr, elif_case.when_true.first
		assert_equal 3, elif_case.when_true.first.value
		assert_kind_of Number_Expr, elif_case.when_false.first
		assert_equal 4, elif_case.when_false.first.value
	end

	def test_circumfixes
		out = _parse '[], (), {}'
		assert_equal 3, out.count
		out.each do |it|
			assert_kind_of Circumfix_Expr, it
			assert_empty it.expressions
		end

		out = _parse '[1, 2, 3]'
		assert_equal 3, out.first.expressions.count
	end

	def test_type_init
		out = _parse 'Type()'
		assert_kind_of Call_Expr, out.first
	end

	def test_func_call
		out = _parse 'funk()'
		assert_kind_of Call_Expr, out.first
	end

	def test_call_expr_improvement
		out = _parse 'Some.thing(1)'
		assert_kind_of Call_Expr, out.first
		assert_kind_of Infix_Expr, out.first.receiver
		assert_kind_of Number_Expr, out.first.arguments.first
	end

	def test_return_is_an_identifier
		out = _parse 'return 1 + 2'
		assert_kind_of Prefix_Expr, out.first
	end

	def test_return_with_conditional_at_end_of_line
		out = _parse 'return x unless y'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Prefix_Expr, out.first.when_false.first
		assert_kind_of Identifier_Expr, out.first.when_false.first.expression
		assert_kind_of Identifier_Expr, out.first.condition
	end

	def test_return_with_conditionals
		out = _parse 'return 3 if true'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Prefix_Expr, out.first.when_true.first
		assert_kind_of Number_Expr, out.first.when_true.first.expression
		assert_kind_of Identifier_Expr, out.first.condition
	end

	def test_identifier_dot_integer_is_an_infix
		out = _parse 'something.4'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.left
		assert_kind_of Number_Expr, out.first.right
		assert_equal 4, out.first.right.value
	end

	def test_identifier_dot_float_is_an_infix
		out = _parse 'not_gonna_work.4.2'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.left
		assert_kind_of Array_Index_Expr, out.first.right
		assert_equal '4.2', out.first.right.value
		assert_equal [4, 2], out.first.right.indices_in_order
	end

	def test_multidot_number_lexeme
		out = _parse '4.8.15.16.23.42'
		assert_kind_of Array_Index_Expr, out.first
		assert_equal '4.8.15.16.23.42', out.first.value
		assert_equal [4, 8, 15, 16, 23, 42], out.first.indices_in_order
	end

	def test_complex_return_with_conditionals
		out = _parse 'return 4+2 if true'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Prefix_Expr, out.first.when_true.first
		assert_kind_of Infix_Expr, out.first.when_true.first.expression
		assert_kind_of Identifier_Expr, out.first.condition
	end

	def test_possibly_ambigous_type_and_func_syntax_mixture
		out = _parse 'x ; y ; z'
		assert_kind_of Postfix_Expr, out.first
		assert_kind_of Postfix_Expr, out[1]
		assert_kind_of Identifier_Expr, out.last

		out = _parse 'x , y , z'
		assert_kind_of Identifier_Expr, out.first
		assert_kind_of Identifier_Expr, out[1]
		assert_kind_of Identifier_Expr, out.last
	end

	# def test_infinite_loop_bug
	# 	skip "Causes infinite looping, I'll worry about it later."
	# 	out = _parse 'Identifier {;}'
	# 	assert_kind_of Type_Expr, out.first
	#
	# 	out = _parse 'x; , y; , z;'
	# 	assert_kind_of Postfix_Expr, out.first
	# 	assert_kind_of Postfix_Expr, out[1]
	# 	assert_kind_of Postfix_Expr, out.last
	# end
	#
	# def test_operator_overloading
	# 	skip "While I figure out what type of *_Expr this should produce."
	# 	out = _parse '+ { other; }'
	# 	assert_kind_of Func_Expr, out.first
	# end

	def test_double_less_than_is_operator
		out = _parse '<<'
		assert_kind_of Operator_Expr, out.first
	end

	def test_reference_decorator_on_identifier_expr
		out = _parse '@count'
		assert out.first.reference

		out = _parse 'count'
		refute out.first.reference
	end

	# TODO :incomplete
	def test_for_loops
		out = _parse '
		for []
		end'
		assert_empty out.first.body
		assert_instance_of Circumfix_Expr, out.first.iterable # note, The iterable becomes an Array in the interpreter.
		assert_equal '[]', out.first.iterable.grouping
	end

	def test_import_syntax
		out = _parse 'project_root = ~/'
	end

	def test_directive_identifier
		out = _parse '#whatever'
		assert_instance_of Identifier_Expr, out.first
		assert out.first.directive

		out = _parse '#whatever(a, b)'
		assert_instance_of Call_Expr, out.first
		assert_instance_of Identifier_Expr, out.first.receiver
		assert out.first.receiver.directive
	end

	def test_all_http_methods
		HTTP_DIRECTIVES.each do |m|
			assert_instance_of Route_Expr, _parse("##{m} 'path' {;}").first
		end
	end

	def test_route_declaration_with_http_method_directives
		out = _parse '#get "something" {;}'
		assert_instance_of Route_Expr, out.first
		assert_equal 'get', out.first.http_method.value
		assert_equal "something", out.first.path.value

		out = _parse '#put "book/:id" replace_book {id;}'
		assert_instance_of Route_Expr, out.first
		assert_equal 'put', out.first.http_method.value
		assert_equal "book/:id", out.first.path.value
		assert_equal 'replace_book', out.first.name.value
		assert_equal 1, out.first.expressions.count

		out = _parse '#pretend_method "endpoint" {;}'
		refute_instance_of Route_Expr, out.first
		assert_equal 3, out.count
		assert_instance_of Identifier_Expr, out[0]
		assert_instance_of String_Expr, out[1]
		assert_instance_of Func_Expr, out[2]
	end
end
