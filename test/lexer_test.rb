require 'minitest/autorun'
require './lang/lexer/lexer'

# Example test that is created using #define_method below
#  test_comments__single_line_comment
#  test_numbers_1_6
#  etc

# Each key inside a case is a code snippet.
# The matching value is an array representing the final Tokens generated.

class Lexer_Test < Minitest::Test
	CASES = {
		comments:     {
			'`single line comment':    [:comment],
			'```many line comment```': [:comment],
		},
		identifiers:  {
			'a_variable':       [:identifier],
			'some_function':    [:identifier],
			'GRAVITY_CONSTANT': [:IDENTIFIER],
			'Some_Type':        [:Identifier]
		},
		numbers:      {
			'4':          [:number],
			'+8':         [:operator, :number],
			'-1.5':       [:operator, :number],
			'1.6':        [:number],
			'-20three':   [:operator, :number, 'three'],
			'40_two':     [:number, '_two'],
			'4__5__2__2': [:number, '__5__2__2'],
			'a12345':     [:identifier]
		},
		strings:      {
			'"A string"':                      [:string],
			"'Another string'":                [:string],
			'"An `interpolated` string"':      [:string],
			"'Another `interpolated` string'": [:string],
		},
		operators:    {
			'numbers := 4815162342': [:identifier, :operator, :number],
			'numbers =;':            [:identifier, :operator],
			'numbers = 123':         [:identifier, :operator, :number],
			'ENABLED = true':        [:IDENTIFIER, :operator, :number],
			'Type = {}':             [:Identifier, :operator, :delimiter, :delimiter],
			'number: Number = 1':    [:identifier, :operator, :Identifier, :operator, :number],
			'1 + 2 * 3 / 4':         [:number, :operator, :number, :operator, :number, :operator, :number],
			'1 <=> 2':               [:number, :operator, :number],
			'1 == 2':                [:number, :operator, :number],
			'1 != 2':                [:number, :operator, :number],
			'1 > 2':                 [:number, :operator, :number],
			'1 <= 2':                [:number, :operator, :number],
			'1..2':                  [:number, :operator, :number],
			'3.0..4.0':              [:number, :operator, :number],
			'3.<4':                  [:number, :operator, :number],
			'5>.6':                  [:number, :operator, :number],
			'7><8':                  [:number, :operator, :number],
			'a, B, 5, "cool"':       [:identifier, :delimiter, :IDENTIFIER, :delimiter, :number, :delimiter, :string], # Should `B` be a Type B or CONSTANT B? I think it can be either, and should be either. I like having single letter
			'1..2, 3.<4, 5>.6, 7><8': [:number, :operator, :number, :delimiter,
			                           :number, :operator, :number, :delimiter,
			                           :number, :operator, :number, :delimiter,
			                           :number, :operator, :number],
			'./this_instance':        [:operator, :identifier],
			'../global_scope':        [:operator, :identifier],
			'.../third_party':        [:operator, :identifier],
		},
		functions:    {
			'{;}':                             [:delimiter, :delimiter, :delimiter],
			'named_function {;}':              [:identifier, :delimiter, :delimiter, :delimiter],
			'{ input; }':                      [:delimiter, :identifier, :delimiter, :delimiter],
			'{ labeled input; }':              [:delimiter, :identifier, :identifier, :delimiter, :delimiter],
			'{ value = 123; }':                [:delimiter, :identifier, :delimiter, :number, :delimiter, :operator],
			'{ labeled value = 123; }':        [:delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter],
			'{ mixed, labeled value = 456; }': [:delimiter, :identifier, :delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter],
			'square { input;
				input * input
			 }':                     [:identifier, :delimiter, :identifier, :delimiter, :delimiter,
			                          :identifier, :operator, :identifier, :delimiter,
			                          :delimiter],
			'wrap { number, limit;
				if number > limit
					number = 0
				end
			 }':                     [:identifier, :delimiter, :identifier, :delimiter, :identifier, :delimiter, :delimiter,
			                          :identifier, :identifier, :operator, :identifier, :delimiter,
			                          :identifier, :operator, :number, :delimiter,
			                          :identifier, :delimiter,
			                          :delimiter],
		},
		types:        {
			'String {}':          [:Identifier, :delimiter, :delimiter],
			'Transform {
				position =;
				rotation =;
			}':         [:Identifier, :delimiter, :delimiter,
			             :identifier, :operator, :delimiter,
			             :identifier, :operator, :delimiter,
			             :delimiter],
			'Entity {
				|Transform
			}':         [:Identifier, :delimiter, :delimiter,
			             :operator, :Identifier, :delimiter,
			             :delimiter],
			'Player > Entity {}': [:Identifier, :operator, :Identifier, :delimiter, :delimiter]
		},
		control_flow: {
			'if true
				celebrate()
			end':                                                       [:identifier, :identifier, :delimiter,
			                                                             :identifier, :delimiter, :delimiter, :delimiter,
			                                                             :identifier],

			'if 1 + 2 * 3 == 7
				"This one!"
			elsif 1 + 2 * 3 == 9
				\'No, this one!\'
			else
				\'🤯\'
			end': [:identifier, :number, :operator, :number, :operator, :number, :operator, :number, :delimiter,
			       :string, :delimiter,
			       :identifier, :number, :operator, :number, :operator, :number, :operator, :number, :delimiter,
			       :string, :delimiter,
			       :identifier, :delimiter,
			       :string, :delimiter,
			       :identifier],

			'for [1, 2, 3, 4, 5]
				remove it if randf() > 0.5
				skip
				stop
			end':                                             [:identifier, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :delimiter,
			                                                   :identifier, :identifier, :identifier, :identifier, :delimiter, :delimiter, :operator, :number, :delimiter,
			                                                   :identifier, :delimiter,
			                                                   :identifier, :delimiter,
			                                                   :identifier]
		}
	}

	CASES.each do |case_name, case_examples|
		case_examples.each do |code, expected|
			test_name = "test_#{case_name}_#{code.to_s.gsub(/[^a-zA-Z0-9]/, '_')[..25]}_#{Time.now.hash}" # Time.now.hash is added to make sure two tests don't have name collisions, like 1 == 2 and 1 != 2 would both become methods with the name test_1__2. Ruby will warn me if there are duplicate methods but I don't want to have to think about it.

			define_method test_name do
				results = Lexer.new(code).output
				results.zip(expected).each do |res, exp|
					case exp
						when String, Symbol
							res.is exp
						else
							res.is exp
					end
				end
				assert results.count == expected.count, "#{"test_#{case_name}_#{code.to_s.gsub(/[^a-zA-Z0-9]/, '_')[..25]}_#{Time.now.hash}"}: results.count != expected.count"
			end
		end
	end
end
