require 'minitest/autorun'
require './test/helper'

class Lexer_Test < Minitest::Test
	def test_single_linecomment
		out = lex '`single line comment'
		assert_equal :comment, out.first.type
		assert_equal 'single line comment', out.first.value
		assert_kind_of Lexeme, out.first
	end

	def test_multiline_comment
		out = lex '```many line comment```'
		assert_equal :comment, out.first.type
		assert_equal 'many line comment', out.first.value
		assert_kind_of Lexeme, out.first
	end

	def test_identifiers
		tests = %w(lowercase UPPERCASE Capitalized).zip %I(identifier IDENTIFIER Identifier)
		tests.all? do |code, type|
			out = lex code
			assert_equal type, out.first.type
			assert_kind_of Lexeme, out.first
		end
	end

	def test_numbers
		assert_equal :number, lex('4').first.type
		assert_equal :number, lex('8.0').first.type
	end

	def test_prefixed_numbers

		out = lex '-15'
		assert_equal %I(operator number), out.map(&:type)
		assert_equal '15', out.last.value # These are converted to numerical values once they become Number_Exprs
		assert_equal 2, out.count

		out = lex '+1.6'
		assert_equal %I(operator number), out.map(&:type)
		assert_equal '1.6', out.last.value
		assert_equal 2, out.count
	end

	def test_unusual_number_situations
		out = lex '20three'
		assert_equal %I(number identifier), out.map(&:type)
		assert_equal 2, out.count

		out = lex '40__two'
		assert_equal %I(number identifier), out.map(&:type)
		assert_equal 2, out.count

		out = lex '4_15_6_3_4'
		assert_equal :number, out.first.type
		assert_equal 1, out.count

		out = lex 'abc123'
		assert_equal :identifier, out.first.type
		assert_equal 1, out.count
	end

	def test_strings
		out = lex '"A string"'
		assert_equal :string, out.first.type

		out = lex "'Another string'"
		assert_equal :string, out.first.type

	end

	def test_interpolated_strings
		out = lex '"An `interpolated` string"'
		assert_equal :string, out.first.type

		out = lex "'Another `interpolated` string'"
		assert_equal :string, out.first.type
	end

	def test_operators
		# todo Should this be such a long test?
		out = lex 'numbers := 4815162342'
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex 'numbers += 4815162342'
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex 'numbers = 123'
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex 'ENABLED = true'
		assert_equal %I(IDENTIFIER operator identifier), out.map(&:type)
		assert_equal 3, out.count

		out = lex 'Type = {}'
		assert_equal %I(Identifier operator delimiter delimiter), out.map(&:type)
		assert_equal 4, out.count

		out = lex 'numbers =;'
		assert_equal %I(identifier operator), out.map(&:type)
		assert_equal 2, out.count

		out = lex 'number: Number = 1'
		assert_equal %I(identifier operator Identifier operator number), out.map(&:type)
		assert_equal 5, out.count

		out = lex '1 + 2 * 3 / 4'
		assert_equal %I(number operator number operator number operator number), out.map(&:type)
		assert_equal 7, out.count

		out = lex '1 <=> 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex '1 == 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex '1 != 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex '1 > 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex '1 <= 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex '1..2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex '3.0..4.0'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex '3.<4'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex '5>.6'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex '7><8'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex 'a, B, 5, "cool"'
		assert_equal %I(identifier delimiter IDENTIFIER delimiter number delimiter string), out.map(&:type)
		assert_equal 7, out.count

		out = lex '1..2, 3.<4, 5>.6, 7><8'
		assert_equal %I(number operator number delimiter number operator number delimiter number operator number delimiter number operator number), out.map(&:type)
		assert_equal 15, out.count

		out = lex './this_instance'
		assert_equal %I(operator identifier), out.map(&:type)
		assert_equal 2, out.count

		out = lex '../global_scope'
		assert_equal %I(operator identifier), out.map(&:type)
		assert_equal 2, out.count

		out = lex '.../third_party'
		assert_equal %I(operator identifier), out.map(&:type)
		assert_equal 2, out.count
	end

	def test_functions
		out = lex '{;}'
		assert_equal [:delimiter, :delimiter, :delimiter], out.map(&:type)

		out = lex 'named_function {;}'
		assert_equal [:identifier, :delimiter, :delimiter, :delimiter], out.map(&:type)

		out = lex '{ input; }'
		assert_equal [:delimiter, :identifier, :delimiter, :delimiter], out.map(&:type)

		out = lex '{ labeled input; }'
		assert_equal [:delimiter, :identifier, :identifier, :delimiter, :delimiter], out.map(&:type)

		out = lex '{ value = 123; }'
		assert_equal [:delimiter, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = lex '{ labeled value = 123; }'
		assert_equal [:delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = lex '{ mixed, labeled value = 456; }'
		assert_equal [:delimiter, :identifier, :delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = lex 'square { input;
		 		input * input
		 	 }'
		assert_equal [
			             :identifier, :delimiter, :identifier, :delimiter, :delimiter,
			             :identifier, :operator, :identifier, :delimiter, :delimiter
		             ], out.map(&:type)

		out = lex 'wrap { number, limit;
		 		if number > limit
		 			number = 0
		 		end
		 	 }'
		assert_equal [
			             :identifier, :delimiter, :identifier, :delimiter, :identifier, :delimiter, :delimiter,
			             :identifier, :identifier, :operator, :identifier, :delimiter,
			             :identifier, :operator, :number, :delimiter,
			             :identifier, :delimiter, :delimiter
		             ], out.map(&:type)
	end

	def test_types
		out = lex 'String {}'
		assert_equal [:Identifier, :delimiter, :delimiter], out.map(&:type)

		out = lex 'Transform {
		 	position =;
		 	rotation =;
		 }'
		assert_equal [
			             :Identifier, :delimiter, :delimiter,
			             :identifier, :operator, :delimiter,
			             :identifier, :operator, :delimiter,
			             :delimiter
		             ], out.map(&:type)

		out = lex 'Entity {
		 	|Transform
		}'
		assert_equal [
			             :Identifier, :delimiter, :delimiter,
			             :operator, :Identifier, :delimiter,
			             :delimiter
		             ], out.map(&:type)

		out = lex 'Player > Entity {}'
		assert_equal [:Identifier, :operator, :Identifier, :delimiter, :delimiter], out.map(&:type)
	end

	def test_control_flow
		out = lex 'if true
			celebrate()
		end'
		assert_equal [
			             :identifier, :identifier, :delimiter,
			             :identifier, :delimiter, :delimiter, :delimiter,
			             :identifier
		             ], out.map(&:type)

		out = lex 'if 1 + 2 * 3 == 7
			"This one!"
		elsif 1 + 2 * 3 == 9
			\'No, this one!\'
		else
			\'🤯\'
		end'
		assert_equal [
			             :identifier, :number, :operator, :number, :operator, :number, :operator, :number, :delimiter,
			             :string, :delimiter,
			             :identifier, :number, :operator, :number, :operator, :number, :operator, :number, :delimiter,
			             :string, :delimiter,
			             :identifier, :delimiter,
			             :string, :delimiter,
			             :identifier
		             ], out.map(&:type)

		out = lex 'for [1, 2, 3, 4, 5]
			remove it if randf() > 0.5
			skip
			stop
		end'
		assert_equal [
			             :identifier, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :delimiter,
			             :identifier, :identifier, :identifier, :identifier, :delimiter, :delimiter, :operator, :number, :delimiter,
			             :identifier, :delimiter,
			             :identifier, :delimiter,
			             :identifier
		             ], out.map(&:type)
	end

	def test_compound_operators
		COMPOUND_OPERATORS.each do |operator|
			out = lex operator
			assert_equal operator, out.first.value
		end
	end

	def test_conditional_keywords
		out = lex 'and or'
		assert_equal :operator, out.first.type
		assert_equal :operator, out.last.type
	end
end
