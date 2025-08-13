require 'minitest/autorun'
require './code/ruby/shared/helpers'

class Lexer_Test < Minitest::Test
	def test_single_linecomment
		out = _lex '`single line comment'
		assert_equal :comment, out.first.type
		assert_equal 'single line comment', out.first.value
		assert_kind_of Lexeme, out.first
	end

	def test_multiline_comment
		out = _lex '```many line comment```'
		assert_equal :comment, out.first.type
		assert_equal 'many line comment', out.first.value
		assert_kind_of Lexeme, out.first
	end

	def test_identifiers
		tests = %w(lowercase UPPERCASE Capitalized).zip %I(identifier IDENTIFIER Identifier)
		tests.all? do |code, type|
			out = _lex code
			assert_equal type, out.first.type
			assert_kind_of Lexeme, out.first
		end
	end

	def test_numbers
		assert_equal :number, _lex('4').first.type
		assert_equal :number, _lex('8.0').first.type
	end

	def test_prefixed_numbers

		out = _lex '-15'
		assert_equal %I(operator number), out.map(&:type)
		assert_equal '15', out.last.value # These are converted to numerical values once they become Number_Exprs
		assert_equal 2, out.count

		out = _lex '+1.6'
		assert_equal %I(operator number), out.map(&:type)
		assert_equal '1.6', out.last.value
		assert_equal 2, out.count
	end

	def test_unusual_number_situations
		out = _lex '20three'
		assert_equal %I(number identifier), out.map(&:type)
		assert_equal 2, out.count

		out = _lex '40__two'
		assert_equal %I(number identifier), out.map(&:type)
		assert_equal 2, out.count

		out = _lex '4_15_6_3_4'
		assert_equal :number, out.first.type
		assert_equal 1, out.count

		out = _lex 'abc123'
		assert_equal :identifier, out.first.type
		assert_equal 1, out.count
	end

	def test_strings
		out = _lex '"A string"'
		assert_equal :string, out.first.type

		out = _lex "'Another string'"
		assert_equal :string, out.first.type

	end

	def test_interpolated_strings
		out = _lex '"An |interpolated| string"'
		assert_equal :string, out.first.type

		out = _lex "'Another |interpolated| string'"
		assert_equal :string, out.first.type
	end

	def test_operators
		# todo Should this be such a long test?
		out = _lex 'numbers += 4815162342'
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex 'ENABLED = true'
		assert_equal %I(IDENTIFIER operator identifier), out.map(&:type)
		assert_equal 3, out.count

		out = _lex 'Type = {}'
		assert_equal %I(Identifier operator delimiter delimiter), out.map(&:type)
		assert_equal 4, out.count

		out = _lex 'numbers =;'
		assert_equal %I(identifier operator), out.map(&:type)
		assert_equal 2, out.count

		out = _lex 'number: Number = 1'
		assert_equal %I(identifier operator Identifier operator number), out.map(&:type)
		assert_equal 5, out.count

		out = _lex '1 + 2 * 3 / 4'
		assert_equal %I(number operator number operator number operator number), out.map(&:type)
		assert_equal 7, out.count

		out = _lex '1 <=> 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex '1 == 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex '1 != 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex '1 > 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex '1 <= 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex '1..2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex '3.0..4.0'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex '3.<4'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex '5>.6'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex '7><8'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex 'a, B, 5, "cool"'
		assert_equal %I(identifier delimiter IDENTIFIER delimiter number delimiter string), out.map(&:type)
		assert_equal 7, out.count

		out = _lex '1..2, 3.<4, 5>.6, 7><8'
		assert_equal %I(number operator number delimiter number operator number delimiter number operator number delimiter number operator number), out.map(&:type)
		assert_equal 15, out.count

		out = _lex './this_instance'
		assert_equal %I(operator identifier), out.map(&:type)
		assert_equal 2, out.count

		out = _lex '../global_scope'
		assert_equal %I(operator identifier), out.map(&:type)
		assert_equal 2, out.count

		out = _lex '.../third_party'
		assert_equal %I(operator identifier), out.map(&:type)
		assert_equal 2, out.count
	end

	def test_declaration_operators
		out = _lex 'numbers := 4815162342' # This parses but I'm not using this any longer. Maybe I'll repurpose it.
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count

		out = _lex 'numbers = 123'
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count
	end

	def test_functions
		out = _lex '{;}'
		assert_equal [:delimiter, :delimiter, :delimiter], out.map(&:type)

		out = _lex 'named_function {;}'
		assert_equal [:identifier, :delimiter, :delimiter, :delimiter], out.map(&:type)

		out = _lex '{ input; }'
		assert_equal [:delimiter, :identifier, :delimiter, :delimiter], out.map(&:type)

		out = _lex '{ labeled input; }'
		assert_equal [:delimiter, :identifier, :identifier, :delimiter, :delimiter], out.map(&:type)

		out = _lex '{ value = 123; }'
		assert_equal [:delimiter, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = _lex '{ labeled value = 123; }'
		assert_equal [:delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = _lex '{ mixed, labeled value = 456; }'
		assert_equal [:delimiter, :identifier, :delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = _lex 'square { input;
		 		input * input
		 	 }'
		assert_equal [
			             :identifier, :delimiter, :identifier, :delimiter, :delimiter,
			             :identifier, :operator, :identifier, :delimiter, :delimiter
		             ], out.map(&:type)

		out = _lex 'wrap { number, limit;
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
		out = _lex 'String {}'
		assert_equal [:Identifier, :delimiter, :delimiter], out.map(&:type)

		out = _lex 'Transform {
		 	position =;
		 	rotation =;
		 }'
		assert_equal [
			             :Identifier, :delimiter, :delimiter,
			             :identifier, :operator, :delimiter,
			             :identifier, :operator, :delimiter,
			             :delimiter
		             ], out.map(&:type)

		out = _lex 'Entity {
		 	|Transform
		}'
		assert_equal [
			             :Identifier, :delimiter, :delimiter,
			             :operator, :Identifier, :delimiter,
			             :delimiter
		             ], out.map(&:type)

		out = _lex 'Player > Entity {}'
		assert_equal [:Identifier, :operator, :Identifier, :delimiter, :delimiter], out.map(&:type)
	end

	def test_control_flow
		out = _lex 'if true
			celebrate()
		end'
		assert_equal [
			             :identifier, :identifier, :delimiter,
			             :identifier, :delimiter, :delimiter, :delimiter,
			             :identifier
		             ], out.map(&:type)

		out = _lex 'if 1 + 2 * 3 == 7
			"This one!"
		elif 1 + 2 * 3 == 9
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

		out = _lex 'for [1, 2, 3, 4, 5]
			remove it if randf() > 0.5
			skip
			stop
		end'
		assert_equal [
			             :operator, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :delimiter,
			             :identifier, :identifier, :identifier, :identifier, :delimiter, :delimiter, :operator, :number, :delimiter,
			             :identifier, :delimiter,
			             :identifier, :delimiter,
			             :identifier
		             ], out.map(&:type)
	end

	def test_compound_operators
		COMPOUND_OPERATORS.each do |operator|
			out = _lex operator
			assert_equal operator, out.first.value
		end
	end

	def test_conditional_keywords
		out = _lex 'and or'
		assert_equal :operator, out.first.type
		assert_equal :operator, out.last.type
	end

	def test_return_is_an_operator
		out = _lex 'return 1 + 2'
		assert_equal :operator, out.first.type
	end

	def test_identifier_dot_integer
		out = _lex 'array.0'
		assert_equal :identifier, out.first.type
		assert_equal 'array', out.first.value
		assert_equal :operator, out[1].type
		assert_equal '.', out[1].value
		assert_equal :number, out.last.type
		assert_equal '0', out.last.value
		# :lexeme_type_helper
	end

	def test_identifier_dot_float
		out = _lex 'array.2.0'
		assert_equal :identifier, out.first.type
		assert_equal 'array', out.first.value
		assert_equal :operator, out[1].type
		assert_equal '.', out[1].value
		assert_equal :number, out.last.type
		assert_equal '2.0', out.last.value
		# :lexeme_type_helper
	end

	def test_number_with_multiple_decimal_points
		out = _lex '1.2.3'
		assert_equal 1, out.count
		assert_equal :number, out.first.type
	end

	def test_double_less_than_is_operator
		out = _lex '<<'
		assert_equal :operator, out.first.type
	end

	def test_at_prefix
		out = _lex '@count'
		assert_equal :operator, out.first.type
	end

	def test_allowed_identifier_special_chars
		out = _lex 'what?;'
		assert_equal :identifier, out.first.type
		assert_equal 'what?', out.first.value

		out = _lex 'okay!;'
		assert_equal :identifier, out.first.type
		assert_equal 'okay!', out.first.value
	end

	def test_reference_prefix
		out = _lex '^reference'
		assert_equal :operator, out.first.type
		assert_equal '^', out.first.value
		assert_equal :identifier, out.last.type
		assert_equal 'reference', out.last.value
	end

	def test_for_keyword
		out = _lex 'for'
		assert_equal :operator, out.last.type
	end

	def test_single_line_code_location
		out = _lex 'abracadabra'
		assert_equal 1, out.last.l0
		assert_equal 1, out.last.c0
		assert_equal 1, out.last.l1
		assert_equal 12, out.last.c1

		out = _lex 'abracadabra = whatever'
		assert_equal 1, out.last.l0
		assert_equal 1, out.last.l1
		assert_equal 15, out.last.c0
		assert_equal 23, out.last.c1
	end

	def test_multiline_code_location
		out = _lex \
			"Thing {
	id;
	name;
}"
		assert_equal "1:1..1:6", out[0].line_col # Thing
		assert_equal "1:7..1:8", out[1].line_col # {
		assert_equal "1:8..2:1", out[2].line_col # \n
		assert_equal "2:2..2:4", out[3].line_col # id, Starts at column 2 because of indentation.
		assert_equal "2:4..2:5", out[4].line_col # ;
		assert_equal "2:5..3:1", out[5].line_col # \n
		assert_equal "3:2..3:6", out[6].line_col # name
		assert_equal "3:6..3:7", out[7].line_col # ;
		assert_equal "3:7..4:1", out[8].line_col # \n
		assert_equal "4:1..4:2", out[9].line_col # }
	end
end
