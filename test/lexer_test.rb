require 'minitest/autorun'
require './src/shared/helpers'

class Lexer_Test < Minitest::Test
	def test_single_linecomment
		out = lex_helper '`single line comment'
		assert_equal :comment, out.first.type
		assert_equal 'single line comment', out.first.value
		assert_kind_of Lexeme, out.first
	end

	def test_multiline_comment
		out = lex_helper '```many line comment```'
		assert_equal :comment, out.first.type
		assert_equal 'many line comment', out.first.value
		assert_kind_of Lexeme, out.first
	end

	def test_identifiers
		tests = %w(lowercase UPPERCASE Capitalized).zip %I(identifier IDENTIFIER Identifier)
		tests.all? do |code, type|
			out = lex_helper code
			assert_equal type, out.first.type
			assert_kind_of Lexeme, out.first
		end
	end

	def test_numbers
		assert_equal :number, lex_helper('4').first.type
		assert_equal :number, lex_helper('8.0').first.type
	end

	def test_prefixed_numbers

		out = lex_helper '-15'
		assert_equal %I(operator number), out.map(&:type)
		assert_equal '15', out.last.value # These are converted to numerical values once they become Number_Exprs
		assert_equal 2, out.count

		out = lex_helper '+1.6'
		assert_equal %I(operator number), out.map(&:type)
		assert_equal '1.6', out.last.value
		assert_equal 2, out.count
	end

	def test_unusual_number_situations
		out = lex_helper '20three'
		assert_equal %I(number identifier), out.map(&:type)
		assert_equal 2, out.count

		out = lex_helper '40__two'
		assert_equal %I(number identifier), out.map(&:type)
		assert_equal 2, out.count

		out = lex_helper '4_15_6_3_4'
		assert_equal :number, out.first.type
		assert_equal 1, out.count

		out = lex_helper 'abc123'
		assert_equal :identifier, out.first.type
		assert_equal 1, out.count
	end

	def test_strings
		out = lex_helper '"A string"'
		assert_equal :string, out.first.type

		out = lex_helper "'Another string'"
		assert_equal :string, out.first.type

	end

	def test_interpolated_strings
		out = lex_helper '"An |interpolated| string"'
		assert_equal :string, out.first.type

		out = lex_helper "'Another |interpolated| string'"
		assert_equal :string, out.first.type
	end

	def test_operators
		# todo Should this be such a long test?
		out = lex_helper 'numbers += 4815162342'
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper 'ENABLED = true'
		assert_equal %I(IDENTIFIER operator identifier), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper 'Type = {}'
		assert_equal %I(Identifier operator delimiter delimiter), out.map(&:type)
		assert_equal 4, out.count

		out = lex_helper 'numbers =;'
		assert_equal %I(identifier operator), out.map(&:type)
		assert_equal 2, out.count

		out = lex_helper 'number: Number = 1'
		assert_equal %I(identifier operator Identifier operator number), out.map(&:type)
		assert_equal 5, out.count

		out = lex_helper '1 + 2 * 3 / 4'
		assert_equal %I(number operator number operator number operator number), out.map(&:type)
		assert_equal 7, out.count

		out = lex_helper '1 <=> 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper '1 == 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper '1 != 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper '1 > 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper '1 <= 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper '1..2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper '3.0..4.0'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper '3.<4'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper '5>.6'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper '7><8'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper 'a, B, 5, "cool"'
		assert_equal %I(identifier delimiter IDENTIFIER delimiter number delimiter string), out.map(&:type)
		assert_equal 7, out.count

		out = lex_helper '1..2, 3.<4, 5>.6, 7><8'
		assert_equal %I(number operator number delimiter number operator number delimiter number operator number delimiter number operator number), out.map(&:type)
		assert_equal 15, out.count

		out = lex_helper './this_instance'
		assert_equal %I(operator identifier), out.map(&:type)
		assert_equal 2, out.count

		out = lex_helper '../global_scope'
		assert_equal %I(operator identifier), out.map(&:type)
		assert_equal 2, out.count

		out = lex_helper '.../third_party'
		assert_equal %I(operator identifier), out.map(&:type)
		assert_equal 2, out.count
	end

	def test_declaration_operators
		out = lex_helper 'numbers := 4815162342' # This parses but I'm not using this any longer. Maybe I'll repurpose it.
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count

		out = lex_helper 'numbers = 123'
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count
	end

	def test_functions
		out = lex_helper '{;}'
		assert_equal [:delimiter, :delimiter, :delimiter], out.map(&:type)

		out = lex_helper 'named_function {;}'
		assert_equal [:identifier, :delimiter, :delimiter, :delimiter], out.map(&:type)

		out = lex_helper '{ input; }'
		assert_equal [:delimiter, :identifier, :delimiter, :delimiter], out.map(&:type)

		out = lex_helper '{ labeled input; }'
		assert_equal [:delimiter, :identifier, :identifier, :delimiter, :delimiter], out.map(&:type)

		out = lex_helper '{ value = 123; }'
		assert_equal [:delimiter, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = lex_helper '{ labeled value = 123; }'
		assert_equal [:delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = lex_helper '{ mixed, labeled value = 456; }'
		assert_equal [:delimiter, :identifier, :delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = lex_helper 'square { input;
		 		input * input
		 	 }'
		assert_equal [
			             :identifier, :delimiter, :identifier, :delimiter, :delimiter,
			             :identifier, :operator, :identifier, :delimiter, :delimiter
		             ], out.map(&:type)

		out = lex_helper 'wrap { number, limit;
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
		out = lex_helper 'String {}'
		assert_equal [:Identifier, :delimiter, :delimiter], out.map(&:type)

		out = lex_helper 'Transform {
		 	position =;
		 	rotation =;
		 }'
		assert_equal [
			             :Identifier, :delimiter, :delimiter,
			             :identifier, :operator, :delimiter,
			             :identifier, :operator, :delimiter,
			             :delimiter
		             ], out.map(&:type)

		out = lex_helper 'Entity {
		 	|Transform
		}'
		assert_equal [
			             :Identifier, :delimiter, :delimiter,
			             :operator, :Identifier, :delimiter,
			             :delimiter
		             ], out.map(&:type)

		out = lex_helper 'Player > Entity {}'
		assert_equal [:Identifier, :operator, :Identifier, :delimiter, :delimiter], out.map(&:type)
	end

	def test_control_flow
		out = lex_helper 'if true
			celebrate()
		end'
		assert_equal [
			             :identifier, :identifier, :delimiter,
			             :identifier, :delimiter, :delimiter, :delimiter,
			             :identifier
		             ], out.map(&:type)

		out = lex_helper 'if 1 + 2 * 3 == 7
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

		out = lex_helper 'for [1, 2, 3, 4, 5]
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
			out = lex_helper operator
			assert_equal operator, out.first.value
		end
	end

	def test_conditional_keywords
		out = lex_helper 'and or'
		assert_equal :operator, out.first.type
		assert_equal :operator, out.last.type
	end

	def test_return_is_an_operator
		out = lex_helper 'return 1 + 2'
		assert_equal :operator, out.first.type
	end

	def test_identifier_dot_integer
		out = lex_helper 'array.0'
		assert_equal :identifier, out.first.type
		assert_equal 'array', out.first.value
		assert_equal :operator, out[1].type
		assert_equal '.', out[1].value
		assert_equal :number, out.last.type
		assert_equal '0', out.last.value
		# :lexeme_type_helper
	end

	def test_identifier_dot_float
		out = lex_helper 'array.2.0'
		assert_equal :identifier, out.first.type
		assert_equal 'array', out.first.value
		assert_equal :operator, out[1].type
		assert_equal '.', out[1].value
		assert_equal :number, out.last.type
		assert_equal '2.0', out.last.value
		# :lexeme_type_helper
	end

	def test_number_with_multiple_decimal_points
		out = lex_helper '1.2.3'
		assert_equal 1, out.count
		assert_equal :number, out.first.type
	end

end
