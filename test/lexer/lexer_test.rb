require 'minitest/autorun'
require_relative '../../lang/lexer/lexer'
require_relative '../../lang/lexer/errors'


class Lexer_Test < Minitest::Test
	def setup
		@lexer = Lexer.new
	end

	def test_create_token
		skip
	end

	def test_chars_remaining
		@lexer.input = 'ab'
		assert @lexer.chars_remaining?

		@lexer.eat
		assert @lexer.chars_remaining?

		@lexer.eat
		refute @lexer.chars_remaining?
	end

	def test_curr_and_prev_char
		@lexer.input = 'abc'

		@lexer.i = 0
		assert_equal 'a', @lexer.curr_char
		assert_nil @lexer.prev_char

		@lexer.i = 1
		assert_equal 'b', @lexer.curr_char
		assert_equal 'a', @lexer.prev_char

		@lexer.i = 2
		assert_equal 'c', @lexer.curr_char
		assert_equal 'b', @lexer.prev_char

		@lexer.i = 3
		assert_nil @lexer.curr_char
		assert_equal 'c', @lexer.prev_char
	end

	def test_peek
		@lexer.input = 'peek test'

		assert_equal 'e', @lexer.peek
		assert_equal 'k', @lexer.peek(3, 1)
		assert_equal 'tes', @lexer.peek(5, 3)

		@lexer.i = 2
		assert_equal 'k', @lexer.peek

		@lexer.i = 6
		assert_equal 's', @lexer.peek
	end

	def add_to_clipboard
		skip
	end

	def test_eat
		skip
	end

	def test_eat_many
		skip
	end

	def test_eat_number
		skip
	end

	def test_make_identifier_token
		skip
	end

	def test_eat_until_delimiter
		skip
	end

	def test_eat_string
		skip
	end

	def test_reduce_delimiters
		skip
	end

	def test_lowercase
		skip
	end

	def test_uppercase
		skip
	end

	def test_lex
		skip
	end

	def test_output_blank_input
		assert_instance_of EOF_Token, lex('').last
	end

	def test_raises_when_nil_input
		error = assert_raises(Lexing_Error) { lex(nil) }
		assert_match /input is nil/, error.message
	end

	def test_reserved_operator_tokens
		Language::RESERVED_OPERATOR_IDENTIFIERS.each do |operator|
			lex(operator) do |output|
				assert output.all? do |token|
					assert_instance_of Reserved_Operator_Token, token
					3
				end
			end
		end
		refute_instance_of Reserved_Operator_Token, lex('unreserved').first
	end

	def test_reserved_identifier_tokens
		all_identifiers = Language::RESERVED_IDENTIFIERS.join(' ')
		lex(all_identifiers) do |output|
			assert output.all? do |token|
				assert_instance_of Reserved_Identifier_Token, token
			end
		end
		refute_instance_of Reserved_Identifier_Token, lex('unreserved').first
	end

	def test_output_number_token
		%w[1 1_2_3 1_000 1.1 .1 1. 00.1 01.0 1_2._3_4_5].each do |number|
			assert_instance_of Number_Token, lex(number).first
		end
	end

	def test_raises_when_too_many_dots_in_a_number
		error = assert_raises(Lexing_Error) { lex('1.2.3') }
		assert_match /already contains a period/, error.message
	end

	def test_output_string_token
		['"abc"', "'abc'", '"abc `expression`"', "'abc `expression`'"].each do |string|
			lex(string) do |output|
				assert_instance_of String_Token, output.first
			end
		end
	end

	def test_identifier_tokens
		%w(~nice~ !@#$ _this_works@ <...> # pm : ....? || ).each do |input|
			lex(input) do
				assert_instance_of Identifier_Token, _1.first
			end
		end
	end

	def test_output_basic_arithmetic
		lex('x = 1 + 2 - nil') do |output|
			assert_instance_of Identifier_Token, output[0]
			assert_instance_of Identifier_Token, output[1]
			assert_instance_of Number_Token, output[2]
			refute_instance_of Number_Token, output[3]
			assert_instance_of Identifier_Token, output[3]
			assert_instance_of Number_Token, output[4]
			assert_instance_of Identifier_Token, output[5]
			assert_instance_of Reserved_Identifier_Token, output[6]
		end
	end

	def test_output_reserved_operators
		Language::RESERVED_OPERATOR_IDENTIFIERS.each do |operator|
			lex(operator) do |output|
				assert output.all? do |token|
					assert_instance_of Reserved_Operator_Token, token
					3
				end
			end
		end
		refute_instance_of Reserved_Operator_Token, lex('unreserved').first
	end

	def test_output_reserved_identifiers
		all_identifiers = Language::RESERVED_IDENTIFIERS.join(' ')
		lex(all_identifiers) do |output|
			assert output.all? do |token|
				assert_instance_of Reserved_Identifier_Token, token
			end
		end
		refute_instance_of Reserved_Identifier_Token, lex('unreserved').first
	end

	def test_output_class_expression
		lex('Class {}') do |output|
			assert_instance_of Identifier_Token, output[0]
			assert_instance_of Reserved_Operator_Token, output[1]
			assert_instance_of Reserved_Operator_Token, output[2]
		end
	end

	def test_output_functions
		lex('funk {;}') do
			assert_instance_of Identifier_Token, _1[0]
			assert_instance_of Reserved_Operator_Token, _1[1]
			assert_instance_of Reserved_Operator_Token, _1[2]
			assert_instance_of Reserved_Operator_Token, _1[3]
		end
	end

	def test_output_comments
		lex('`single line comment') do |output|
			assert_instance_of Comment_Token, output[0]
			refute output[0].multiline
		end
		lex('```multiline comment```') do |output|
			assert_instance_of Comment_Token, output[0]
			assert output[0].multiline
		end
	end

	def test_output_delimiters
		lex(%W(\s ; , \n \r \t).join) do |output|
			# the last token is EOF
			output[...-1].each do |token|
				assert_instance_of Delimiter_Token, token
			end
		end
	end

	def test_whitespace?
		assert_helper :whitespace?, ["\t", "\s", ' ']
		refute_helper :whitespace?, %W(the island \n)
	end

	def test_newline?
		assert_helper :newline?, %W(\n \r\n)
		refute_helper :newline?, %w(a b c)
	end

	def test_delimiter?
		assert_helper :delimiter?, %W(; , \n \s \t \r)
		refute_helper :delimiter?, %w(d e f)
	end

	def test_numeric?
		assert_helper :numeric?, %w(4 8 15 16 23 42)
		refute_helper :numeric?, %w(g h i)
	end

	def test_alpha?
		assert_helper :alpha?, %w(j K l)
		refute_helper :alpha?, %w(1 2 3)
	end

	def test_alphanumeric?
		assert_helper :alphanumeric?, %w(b 0)
		refute_helper :alphanumeric?, %w(! @ # $)
	end

	def test_symbol?
		assert_helper :symbol?, %w(! @ # $)
		refute_helper :symbol?, %w(a B 1 0)
	end

	def test_identifier?
		assert_helper :identifier?, %w(a B C)
		refute_helper :identifier?, %W(1 2 \n \t \r)
	end

	def test_legal_identifier_special_char?
		samples = Language::LEGAL_IDENT_SPECIAL_CHARS
		assert_helper :legal_identifier_special_char?, samples
		refute_helper :legal_identifier_special_char?, %w(+= -=)
	end

	def test_reserved?
		samples = Language::RESERVED_OPERATOR_IDENTIFIERS
		assert_helper :reserved?, samples
		refute_helper :reserved?, %w(*= /=)
	end

	private

	def assert_helper(method, samples)
		samples.each { |sample| assert @lexer.send(method, sample) }
	end

	def refute_helper(method, samples)
		samples.each { |sample| refute @lexer.send(method, sample) }
	end

	# @param input [String, nil] Code to lex
	# @yieldparam [Array<Atom>] output Array of tokens generated by the lexer
	# @return [Array<Lexeme>] Array of tokens generated by the lexer
	def lex input
		output = @lexer.send :lex, input # note using #send instead of () to suppress warning about nil argument, so I can test nil input
		assert_instance_of EOF_Token, output.last
		yield(output) if block_given?
		output
	end
end
