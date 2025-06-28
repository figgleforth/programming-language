require 'minitest/autorun'
require './lang/lexer/lexer'

class Lexer_Test < Minitest::Test
	CASES = {
		comments:    {
			'`single line comment':    [:comment],
			'```many line comment```': [:comment],
		},
		identifiers: {
			'a_variable':       [:identifier],
			'some_function':    [:identifier],
			'GRAVITY_CONSTANT': [:IDENTIFIER],
			'Some_Type':        [:Identifier]
		},
		numbers:     {
			'4':          [:number],
			'+8':         [:operator, :number],
			'-1.5':       [:operator, :number],
			'1.6':        [:number],
			'-20three':   [:operator, :number, 'three'],
			'40_two':     [:number, '_two'],
			'4__5__2__2': [:number, '__5__2__2'],
			'a12345':     [:identifier]
		},
		strings:     {
			'"A string"':                      [:string],
			"'Another string'":                [:string],
			'"An `interpolated` string"':      [:string],
			"'Another `interpolated` string'": [:string],
		},
		operators:   {
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
		functions:   {
			'{;}':                             [:delimiter, :delimiter, :delimiter],
			'named_function {;}':              [:identifier, :delimiter, :delimiter, :delimiter],
			'{ input; }':                      [:delimiter, :identifier, :delimiter, :delimiter],
			'{ labeled input; }':              [:delimiter, :identifier, :identifier, :delimiter, :delimiter],
			'{ value = 123; }':                [:delimiter, :identifier, :delimiter, :number, :delimiter, :operator],
			'{ labeled value = 123; }':        [:delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter],
			'{ mixed, labeled value = 456; }': [:delimiter, :identifier, :delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter],
			'square { input;
				input * input
			 }':                     [:identifier, :delimiter, :identifier, :delimiter, "\n",
			                          :identifier, :operator, :identifier, "\n",
			                          :delimiter],
			'wrap { number, limit;
				if number > limit
					number = 0
				end
			 }':                     [:identifier, :delimiter, :identifier, :delimiter, :identifier, :delimiter, "\n",
			                          :identifier, :identifier, :operator, :identifier, "\n",
			                          :identifier, :operator, :number, "\n",
			                          :identifier, "\n",
			                          :delimiter],
		},
		types:       {
			'String {}': [:Identifier, :delimiter, :delimiter],
		}
	}

	CASES.each do |case_name, case_examples|
		case_examples.each do |code, expected|
			name = "test_#{case_name}_#{code.to_s.gsub(/[^a-zA-Z0-9]/, '_')[..25]}_#{Time.now.hash}"
			define_method name do
				# Hash of the current time is added to make sure two tests don't have name collisions, like 1 == 2 and 1 != 2 would both become test_1__2. Ruby will warn me if there are duplicates but I don't want to be required to change tests because of it.
				results = lex code
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

	private

	def lex code
		Lexer.new(code).output
	end
end
