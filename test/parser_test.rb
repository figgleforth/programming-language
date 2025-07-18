require 'minitest/autorun'
require './src/shared/helpers'

class Parser_Test < Minitest::Test
	def test_identifiers
		zipped = %w(variable_or_function CONSTANT Type).zip %I(identifier IDENTIFIER Identifier)
		zipped.each do |code, type|
			out = parse_helper code
			assert_kind_of Identifier_Expr, out.first
			assert_equal code, out.first.value
			assert_nil out.first.type
		end
	end

	def test_integers_and_floats
		out = parse_helper '4'
		assert_kind_of Number_Expr, out.first
		assert_equal 4, out.first.value
		assert_equal :integer, out.first.type

		out = parse_helper '2.3'
		assert_kind_of Number_Expr, out.first
		assert_equal 2.3, out.first.value
		assert_equal :float, out.first.type
	end

	def test_numbers_with_prefixes
		out = parse_helper '-42'
		assert_kind_of Prefix_Expr, out.first
		assert_equal '-', out.first.operator
		assert_equal 42, out.first.expression.value
		assert_kind_of Number_Expr, out.first.expression

		out = parse_helper '+4.2'
		assert_kind_of Prefix_Expr, out.first
		assert_equal '+', out.first.operator
		assert_equal 4.2, out.first.expression.value
		assert_kind_of Number_Expr, out.first.expression
	end

	def test_numbers_with_underscores
		out = parse_helper '2_000'
		assert_equal 1, out.count
		assert_kind_of Number_Expr, out.first
		assert_equal 2000, out.first.value

		out = parse_helper '3_0_'
		assert_equal 2, out.count
		assert_kind_of Number_Expr, out.first
		assert_equal 30, out.first.value
		assert_kind_of Identifier_Expr, out.last
		assert_equal '_', out.last.value

		out = parse_helper '_2_00'
		assert_equal 1, out.count
		refute_kind_of Number_Expr, out.first
		refute_equal 200, out.first.value

		out = parse_helper '-20three'
		assert_equal 2, out.count
		assert_kind_of Prefix_Expr, out.first
		assert_kind_of Identifier_Expr, out.last
		assert_equal 20, out.first.expression.value
		assert_equal 'three', out.last.value

		out = parse_helper '40_two'
		assert_equal 2, out.count
		assert_kind_of Number_Expr, out.first
		assert_kind_of Identifier_Expr, out.last
		assert_equal 40, out.first.value
		assert_equal '_two', out.last.value

		out = parse_helper '4__5__2__2'
		assert_equal 2, out.count
		assert_kind_of Number_Expr, out.first
		assert_kind_of Identifier_Expr, out.last
		assert_equal 4, out.first.value
		assert_equal '__5__2__2', out.last.value

		out = parse_helper 'a1234'
		assert_equal 1, out.count
		assert_kind_of Identifier_Expr, out.first
		assert_equal 'a1234', out.first.value
		refute out.first.type
	end

	def test_strings
		out = parse_helper '"A string"'
		assert_kind_of String_Expr, out.first
		refute out.first.interpolated

		out = parse_helper "'Another string'"
		assert_kind_of String_Expr, out.first
		refute out.first.interpolated

		out = parse_helper '"An |interpolated| string"'
		assert_kind_of String_Expr, out.first
		assert out.first.interpolated

		out = parse_helper "'Another |interpolated| string'"
		assert_kind_of String_Expr, out.first
		assert out.first.interpolated
	end

	def test_compound_assignments
		out = parse_helper 'numbers += 1623'
		refute_kind_of Identifier_Expr, out.first
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Number_Expr, out.first.right
		assert_equal 1, out.count

		out = parse_helper 'numbers -= 1623'
		assert_kind_of Infix_Expr, out.first

		out = parse_helper 'flag = 0'
		assert_kind_of Infix_Expr, out.first

		out = parse_helper 'flag |= 2'
		assert_kind_of Infix_Expr, out.first
	end

	def test_infixes_regression # This is old but I'm keeping it around anyway. I just renamed it to reflect its purpose.
		COMPOUND_OPERATORS.each do |operator|
			code = "left #{operator} right"
			out  = parse_helper(code)
			assert_kind_of Infix_Expr, out.first
		end
	end

	def test_operator_precedence
		out = parse_helper '1 + 2 * 3 / 4 - 5 % 6'
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
		out = parse_helper '1 + ((2*3) / 4) - (5 % 6)'
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
		out = parse_helper 'numbers = 4815'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Number_Expr, out.first.right
		assert_equal 1, out.count

		out = parse_helper 'numbers;'
		assert_kind_of Postfix_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.expression
		assert_equal ';', out.first.operator

		out = parse_helper 'Type = {}'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.left
		assert_kind_of Circumfix_Expr, out.first.right
		assert_equal 1, out.count

		out = parse_helper 'time: Float'
		assert_equal 'Float', out.first.type

		out = parse_helper 'num: Int = 1 + 2'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Infix_Expr, out.first.right
		assert_equal 'Int', out.first.left.type
	end

	def test_more_fixities
		out = parse_helper '1 + 2 * 3 / 4'
		assert_kind_of Infix_Expr, out.first
		assert_equal 1, out.count

		out = parse_helper '1 < 2'
		assert_kind_of Infix_Expr, out.first
		assert_equal 1, out.count

		out = parse_helper '2 >= 1'
		assert_kind_of Infix_Expr, out.first
		assert_equal 1, out.count

		out = parse_helper '1 != 2'
		assert_kind_of Infix_Expr, out.first
		assert_equal 1, out.count

		out = parse_helper '1 == 2'
		assert_kind_of Infix_Expr, out.first
		assert_equal 1, out.count

		out = parse_helper '1 < 2, 4 > 3'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Infix_Expr, out.last
		assert_equal 2, out.count
	end

	def test_ranges
		out = parse_helper '1..2'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Number_Expr, out.first.left
		assert_equal '..', out.first.operator
		assert_kind_of Number_Expr, out.first.right
		assert_equal 1, out.first.left.value
		assert_equal 2, out.first.right.value

		out = parse_helper '3.0..4.0'
		assert_kind_of Number_Expr, out.first.left
		assert_kind_of Infix_Expr, out.first
		assert_equal '..', out.first.operator
		assert_kind_of Number_Expr, out.first.right
		assert_equal 3.0, out.first.left.value
		assert_equal 4.0, out.first.right.value

		out = parse_helper '3.<4'
		assert_kind_of Number_Expr, out.first.left
		assert_kind_of Infix_Expr, out.first
		assert_equal '.<', out.first.operator
		assert_kind_of Number_Expr, out.first.right
		assert_equal 3, out.first.left.value
		assert_equal 4, out.first.right.value

		out = parse_helper '5>.6'
		assert_kind_of Number_Expr, out.first.left
		assert_kind_of Infix_Expr, out.first
		assert_equal '>.', out.first.operator
		assert_kind_of Number_Expr, out.first.right
		assert_equal 5, out.first.left.value
		assert_equal 6, out.first.right.value

		out = parse_helper '7><8'
		assert_kind_of Number_Expr, out.first.left
		assert_kind_of Infix_Expr, out.first
		assert_equal '><', out.first.operator
		assert_kind_of Number_Expr, out.first.right
		assert_equal 7, out.first.left.value
		assert_equal 8, out.first.right.value

		out = parse_helper '1..2, 3.<4, 5>.6, 7><8'
		assert_equal 4, out.count
		out.each do
			assert_kind_of Infix_Expr, it
			assert_kind_of Number_Expr, it.left
			assert_kind_of Number_Expr, it.right
		end
	end

	def test_comma_separated_expressions
		out = parse_helper 'a, B, 5, "cool"'
		assert_equal 4, out.count
		assert_kind_of Identifier_Expr, out[0]
		assert_kind_of Identifier_Expr, out[1]
		assert_kind_of Number_Expr, out[2]
		assert_kind_of String_Expr, out[3]
	end

	def test_scope_operators
		out = parse_helper './this_instance'
		assert_kind_of Prefix_Expr, out.first
		assert_equal 1, out.count

		out = parse_helper '../global_scope'
		assert_kind_of Prefix_Expr, out.first
		assert_equal 1, out.count

		out = parse_helper '.../third_party'
		assert_kind_of Prefix_Expr, out.first
		assert_equal 1, out.count
	end

	def test_functions
		out = parse_helper '{;}'
		assert_kind_of Func_Expr, out.first
		assert_empty out.first.expressions
		refute out.first.name

		out = parse_helper '{;
		}'
		assert_empty out.first.expressions
		refute out.first.name

		out = parse_helper 'named_function {;}'
		assert_equal 'named_function', out.first.name
	end

	def test_function_params
		out = parse_helper '{ with_param; }'
		assert_equal 1, out.first.expressions.count
		out.first.expressions.each do
			assert_kind_of Param_Expr, it
		end

		out = parse_helper 'named { with_param; }'
		assert_equal 'named', out.first.name
		assert_equal 1, out.first.expressions.count
		out.first.expressions.each do
			assert_kind_of Param_Expr, it
		end
		refute out.first.expressions.first.label
		refute out.first.expressions.first.default
		refute out.first.expressions.first.type

		out = parse_helper '{ labeled param; }'
		assert_kind_of Param_Expr, out.first.expressions.first
		assert_equal 'labeled', out.first.expressions.first.label
		assert out.first.expressions.first.label
		refute out.first.expressions.first.default
		refute out.first.expressions.first.type

		out = parse_helper '{ default_values = 4; }'
		assert_kind_of Param_Expr, out.first.expressions.first
		assert out.first.expressions.first.default
		assert_kind_of Number_Expr, out.first.expressions.first.default

		out = parse_helper 'named { and_labeled with_default = 8; }'
		assert_kind_of Param_Expr, out.first.expressions.first
		assert_equal 'and_labeled', out.first.expressions.first.label
		assert_equal 'with_default', out.first.expressions.first.name
		assert_equal 'named', out.first.name

		out = parse_helper 'named { with, multiple, even labeled = 4, params = 5; }'
		assert_equal 4, out.first.expressions.count
		assert_equal out.first.expressions.map(&:label), [nil, nil, 'even', nil]
		assert_equal out.first.expressions.map(&:name), %w(with multiple labeled params)
		assert_equal out.first.expressions.map(&:default).map(&:nil?), [true, true, false, false]
	end

	def test_function_bodies
		out = parse_helper '
		square { input;
			input * input
		}'
		refute_empty out.first.expressions
		assert_kind_of Infix_Expr, out.first.expressions[1]

		out = parse_helper '
		nothing { input;
			return input
		}'
		assert_kind_of Prefix_Expr, out.first.expressions[1]
		assert_kind_of Identifier_Expr, out.first.expressions[1].expression
	end

	def test_function_signatures
		out = parse_helper 'nothing { input;
			return input
		}'
		assert_equal 'nothing{input;}', out.first.signature
	end

	def test_complex_function
		out = parse_helper '
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
		assert_equal 'curr?', out.first.name
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
		out = parse_helper '{;}()'
		assert_kind_of Call_Expr, out.first
		assert_kind_of Func_Expr, out.first.receiver
		assert_empty out.first.arguments

		out = parse_helper '{;}(true)'
		refute_empty out.first.arguments
		assert_kind_of Identifier_Expr, out.first.arguments.first

		out = parse_helper '{;}(1, 2, 3)'
		out.first.arguments.each do
			assert_kind_of Number_Expr, it
		end
	end

	def test_types
		out = parse_helper 'String {}'
		assert_kind_of Type_Expr, out.first
		assert_equal 'String', out.first.name

		out = parse_helper 'Transform {
			position;
			rotation;
		}'
		assert_equal 2, out.first.expressions.count

		out = parse_helper 'Entity {
			|Transform
		}'
		assert_kind_of Composition_Expr, out.first.expressions.first
		assert_equal '|', out.first.expressions.first.operator
		assert_equal 'Transform', out.first.expressions.first.name.value
	end

	def test_control_flows
		out = parse_helper 'if true
			celebrate()
		end'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Call_Expr, out.first.when_true.first

		out = parse_helper 'wrap { number, limit;
			if number > limit
				number = 0
			end
		 }'
		assert_kind_of Conditional_Expr, out.first.expressions[2]

		out = parse_helper 'if 1 + 2 * 3 == 7
			"This one!"
		elsif 1 + 2 * 3 == 9
			\'No, this one!\'
		else
			\'🤯\'
		end'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Conditional_Expr, out.first.when_false
		assert_kind_of String_Expr, out.first.when_false.when_false.first
	end

	def test_conditionals_at_end_of_line
		out = parse_helper 'eat while lexemes? && curr?()'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Infix_Expr, out.first.condition
		assert_kind_of Identifier_Expr, out.first.when_true.first
	end

	def test_unless_conditional
		out = parse_helper 'do_this unless the_condition'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.condition
		assert_equal 'unless', out.first.type
		assert_equal 'the_condition', out.first.condition.value
		assert_kind_of Identifier_Expr, out.first.when_false.first
		assert_equal 'do_this', out.first.when_false.first.value
	end

	def test_until_conditional
		out = parse_helper 'repeat_this until the_condition'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.condition
		assert_equal 'until', out.first.type
		assert_equal 'the_condition', out.first.condition.value
		assert_kind_of Identifier_Expr, out.first.when_false.first
		assert_equal 'repeat_this', out.first.when_false.first.value
	end

	def test_silly_elswhile
		out        = parse_helper '
		while a
			1
		elwhile b
			2
		elswhile c
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

		elswhile = elwhile.when_false
		assert_equal 'elswhile', elswhile.type
		assert_kind_of Number_Expr, elswhile.when_true.first
		assert_equal 3, elswhile.when_true.first.value
		assert_kind_of Number_Expr, elswhile.when_false.first
		assert_equal 4, elswhile.when_false.first.value
	end

	def test_if_else
		# Direct copy-past from test_silly_elswhile
		out = parse_helper '
		if a
			1
		elif b
			2
		elsif c
			3
		else
			4
		end
		'

		# el elif elsif else
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

		elsif_case = elif_case.when_false
		assert_equal 'elsif', elsif_case.type
		assert_kind_of Number_Expr, elsif_case.when_true.first
		assert_equal 3, elsif_case.when_true.first.value
		assert_kind_of Number_Expr, elsif_case.when_false.first
		assert_equal 4, elsif_case.when_false.first.value
	end

	def test_circumfixes
		out = parse_helper '[], (), {}'
		assert_equal 3, out.count
		out.each do |it|
			assert_kind_of Circumfix_Expr, it
			assert_empty it.expressions
		end

		out = parse_helper '[1, 2, 3]'
		assert_equal 3, out.first.expressions.count
	end

	def test_type_init
		out = parse_helper 'Type()'
		assert_kind_of Call_Expr, out.first
	end

	def test_func_call
		out = parse_helper 'funk()'
		assert_kind_of Call_Expr, out.first
	end

	def test_self_scope_prefixes
		out = parse_helper './x = 123'
		assert_kind_of Prefix_Expr, out.first
		assert_equal './', out.first.operator
		assert_kind_of Infix_Expr, out.first.expression
		assert_equal '=', out.first.expression.operator
	end

	def test_call_expr_improvement
		out = parse_helper 'Some.thing(1)'
		assert_kind_of Call_Expr, out.first
		assert_kind_of Infix_Expr, out.first.receiver
		assert_kind_of Number_Expr, out.first.arguments.first
	end

	def test_return_is_an_identifier
		out = parse_helper 'return 1 + 2'
		assert_kind_of Prefix_Expr, out.first
	end

	def test_return_with_conditional_at_end_of_line
		out = parse_helper 'return x unless y'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Prefix_Expr, out.first.when_false.first
		assert_kind_of Identifier_Expr, out.first.when_false.first.expression
		assert_kind_of Identifier_Expr, out.first.condition
	end

	def test_return_with_conditionals
		out = parse_helper 'return 3 if true'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Prefix_Expr, out.first.when_true.first
		assert_kind_of Number_Expr, out.first.when_true.first.expression
		assert_kind_of Identifier_Expr, out.first.condition
	end

	def test_identifier_dot_integer_is_an_infix
		out = parse_helper 'something.4'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.left
		assert_kind_of Number_Expr, out.first.right
		assert_equal 4, out.first.right.value
	end

	def test_identifier_dot_float_is_an_infix
		out = parse_helper 'not_gonna_work.4.2'
		assert_kind_of Infix_Expr, out.first
		assert_kind_of Identifier_Expr, out.first.left
		assert_kind_of Array_Index_Expr, out.first.right
		assert_equal '4.2', out.first.right.value
		assert_equal [4, 2], out.first.right.indices_in_order
	end

	def test_multidot_number_lexeme
		out = parse_helper '4.8.15.16.23.42'
		assert_kind_of Array_Index_Expr, out.first
		assert_equal '4.8.15.16.23.42', out.first.value
		assert_equal [4, 8, 15, 16, 23, 42], out.first.indices_in_order
	end

	def test_complex_return_with_conditionals
		out = parse_helper 'return 4+2 if true'
		assert_kind_of Conditional_Expr, out.first
		assert_kind_of Prefix_Expr, out.first.when_true.first
		assert_kind_of Infix_Expr, out.first.when_true.first.expression
		assert_kind_of Identifier_Expr, out.first.condition
	end

	def test_possibly_ambigous_type_and_func_syntax_mixture
		out = parse_helper 'x ; y ; z'
		assert_kind_of Postfix_Expr, out.first
		assert_kind_of Postfix_Expr, out[1]
		assert_kind_of Identifier_Expr, out.last

		out = parse_helper 'x , y , z'
		assert_kind_of Identifier_Expr, out.first
		assert_kind_of Identifier_Expr, out[1]
		assert_kind_of Identifier_Expr, out.last
	end

	def test_infinite_loop_bug
		skip "Causes infinite looping, I'll worry about it later."
		out = parse_helper 'Identifier {;}'
		assert_kind_of Type_Expr, out.first

		out = parse_helper 'x; , y; , z;'
		assert_kind_of Postfix_Expr, out.first
		assert_kind_of Postfix_Expr, out[1]
		assert_kind_of Postfix_Expr, out.last
	end
end
