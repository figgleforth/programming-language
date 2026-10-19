require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

# `Name :: type expression` -- see reference.md's "Type Aliases" section.
class Type_Alias_Test < Base_Test
	# --- Parsing ---

	def test_a_composition_parses_to_a_type_alias_expr
		out = Code.parse('Strumber :: String | Number').first
		assert_instance_of Code::Type_Alias_Expr, out
		assert_kind_of Code::Infix_Expr, out
		assert_equal 'Strumber', out.left.value
		assert_equal '::', out.operator.value
		assert_instance_of Code::Type_Expr, out.right
		assert out.right.anonymous_composition
	end

	def test_one_type_parses_to_an_identifier
		out = Code.parse('Int32 :: Integer').first
		assert_instance_of Code::Identifier_Expr, out.right
		assert_equal 'Integer', out.right.value
	end

	def test_a_tagged_type_keeps_its_tag
		out = Code.parse('Expressions :: Array\Expression').first
		assert_equal 'Array', out.right.value
		assert_equal 'Expression', out.right.tag.value
	end

	# `\` binds tighter than `|`, so this is `(Array\Bool) | Number`. The tag hides the `|` from a one-token look ahead, which used to leave `| Number` outside the alias.
	def test_a_tagged_first_type_keeps_the_chain
		out = Code.parse('Expressions :: Array\Bool | Number').first
		assert_instance_of Code::Type_Expr, out.right
		assert out.right.anonymous_composition
		assert_equal 'Array', out.right.name
		assert_equal 'Bool', out.right.tag.value

		annotation = Code.parse('x: Array\Bool | Number = 5').first.left.type
		assert annotation.anonymous_composition
	end

	# A bare `(;)` is an empty function everywhere else, but after `::` it can only be a signature.
	def test_a_bare_paren_list_parses_to_a_signature
		[['Func :: (;)', 0], ['Pair :: (a, b;)', 2], ['Format :: (Number -> String;)', 1]].each do |code, param_count|
			out = Code.parse(code).first
			assert_instance_of Code::Func_Signature_Expr, out.right, code
			assert_equal param_count, out.right.params.length, code
		end
	end

	def test_a_function_with_a_body_raises
		assert_raises(Code::Invalid_Type_Alias) { Code.parse 'Doubler :: (n; n * 2)' }
	end

	def test_a_value_on_the_right_raises
		assert_raises(Code::Invalid_Type_Alias) { Code.parse 'Bad :: five' }
	end

	def test_the_next_statement_is_separate
		out = Code.parse "Strumber :: String | Number\nx := 1"
		assert_equal 2, out.length
		assert_instance_of Code::Type_Alias_Expr, out.first
	end

	# --- Code::Type_Alias ---

	def test_the_tree_follows_precedence
		tree = Code::Type_Alias.tree_from_chain %w(A B C), %w(| &)
		assert_equal ['|', 'A', ['&', 'B', 'C']], tree

		tree = Code::Type_Alias.tree_from_chain %w(A B C), %w(| ~)
		assert_equal ['~', ['|', 'A', 'B'], 'C'], tree

		tree = Code::Type_Alias.tree_from_chain %w(A B C), %w(| |)
		assert_equal ['|', ['|', 'A', 'B'], 'C'], tree # left to right
	end

	def test_each_operator_keeps_its_set_meaning
		cases = {
			'|' => [[true, true], [true, false], [false, true]],
			'&' => [[true, true]],
			'~' => [[true, false]],
			'^' => [[true, false], [false, true]],
		}
		cases.each do |operator, satisfied|
			type_alias = Code::Type_Alias.new [operator, 'A', 'B']
			[[true, true], [true, false], [false, true], [false, false]].each do |a, b|
				result = type_alias.satisfied? { it == 'A' ? a : b }
				assert_equal satisfied.include?([a, b]), result, "A #{operator} B with A=#{a}, B=#{b}"
			end
		end
	end

	def test_to_s_shows_the_name_and_the_expression
		named = Code::Type_Alias.new ['|', 'String', 'Number'], 'Strumber'
		assert_equal 'Strumber :: String | Number', named.to_s
		assert_equal 'Strumber', named.display_name

		anonymous = Code::Type_Alias.new ['|', 'String', 'Number']
		assert_equal 'String | Number', anonymous.to_s
		assert_equal 'String | Number', anonymous.display_name
	end

	def test_parentheses_show_where_precedence_needs_them
		tree = Code::Type_Alias.tree_from_chain %w(A B C), %w(| ~)
		assert_equal 'A | B ~ C', Code::Type_Alias.new(tree).expression_to_s

		assert_equal '(A | B) & C', Code::Type_Alias.new(['&', ['|', 'A', 'B'], 'C']).expression_to_s
	end

	def test_a_tagged_operand_shows_its_tag
		out = Code.interp <<~CODE
		    Expressions :: Array\\Bool | Number
		    A :: Number | Array\\Bool\\Int | Array\\<String>
		    <"`Expressions`", "`A`">
		CODE
		assert_equal ['Expressions :: Array\Bool | Number', 'A :: Number | Array\Bool\Int | Array\<...>'], out.values
	end

	# A contract never checks a tag, the same as a plain `x: Array\Bool` annotation: only the base type counts. A tag is for the user's own code to read and use.
	def test_a_tagged_operand_checks_its_base_type
		out = Code.interp <<~CODE
		    Expressions :: Array\\Bool | Number
		    <(5 =>= Expressions), ([true] =>= Expressions), ([5] =>= Expressions), (:x =>= Expressions)>
		CODE
		assert_equal [true, true, true, false], out.values

		out = Code.interp <<~CODE
		    x: Array\\Bool | Number = 5
		    x = [true]
		    x
		CODE
		assert_equal [true], out.values
	end

	def test_two_aliases_with_the_same_tree_are_equal
		assert_equal Code::Type_Alias.new(['|', 'A', 'B']), Code::Type_Alias.new(['|', 'A', 'B'], 'Named')
		refute_equal Code::Type_Alias.new(['|', 'A', 'B']), Code::Type_Alias.new(['&', 'A', 'B'])
	end

	# --- Running ---

	def test_an_alias_of_a_composition_is_a_contract
		out = Code.interp <<~CODE
		    Strumber :: String | Number
		    x: Strumber = 5
		    x = 'five'
		    x
		CODE
		assert_equal 'five', out

		err = assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    Strumber :: String | Number
			    x: Strumber = 5
			    x = :five
			CODE
		end
		assert_match 'Strumber', err.message
		assert_match 'Symbol', err.message
	end

	def test_an_alias_of_one_type_is_that_type
		assert Code.interp("Int32 :: Integer\nInt32 === Integer")
		assert Code.interp("Int32 :: Integer\n4 === Int32")
		assert_instance_of Code::Type, Code.interp("Int32 :: Integer\nInt32")
	end

	def test_an_alias_of_a_composition_is_not_a_composed_type
		assert_instance_of Code::Type_Alias, Code.interp('Strumber :: String | Number')

		# `:=` stays a value: one new Type that composes both
		out = Code.interp 'x := String | Number'
		assert_instance_of Code::Type, out
		assert_equal %w(String Number), out.types.to_a
	end

	def test_reflection
		out = Code.interp <<~CODE
		    Strumber :: String | Number
		    <Strumber.@name, Strumber.@types, Strumber.@composed_types.count(), "`Strumber`">
		CODE
		assert_equal ['Strumber', 'String | Number', 0, 'Strumber :: String | Number'], out.values
	end

	def test_a_signature_alias
		out = Code.interp <<~CODE
		    Callback :: (;)
		    run ( callback: Callback;
		    	callback()
		    )
		    run((; 'ran'))
		CODE
		assert_equal 'ran', out

		assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    Callback :: (;)
			    run ( callback: Callback;
			    	callback()
			    )
			    run(5)
			CODE
		end
	end

	def test_a_typed_signature_alias_checks_the_shape
		code = <<~CODE
		    Format :: (Number -> String;)
		    apply ( format: Format;
		    	format(4)
		    )
		    label ( n: Number -> String;
		    	"n=`n`"
		    )
		    count ( s: String -> Number;
		    	s.length
		    )
		CODE
		assert_equal 'n=4', Code.interp(code + 'apply(label)')
		assert_raises(Code::Type_Contract_Violation) { Code.interp code + 'apply(count)' }
	end

	def test_greater_or_equal_asks_whether_a_value_satisfies_it
		out = Code.interp <<~CODE
		    Strumber :: String | Number
		    <(5 =>= Strumber), ('a' =>= Strumber), (:a =>= Strumber), (nil =>= Strumber), (Strumber =<= 5)>
		CODE
		assert_equal [true, true, false, false, true], out.values
	end

	def test_triple_equals_compares_by_identity
		out = Code.interp <<~CODE
		    Strumber :: String | Number
		    Other :: String | Number
		    <(Strumber === Strumber), (Strumber === Other), (5 === Strumber), (Strumber =!= Other)>
		CODE
		assert_equal [true, false, false, true], out.values
	end

	def test_an_alias_in_a_list_still_prints
		assert_match 'Strumber', Code.interp("Strumber :: String | Number\n\"`[Strumber]`\"")
	end

	def test_construction_raises
		assert_raises(Code::Type_Alias_Is_Not_A_Type) { Code.interp "Strumber :: String | Number\nStrumber()" }
	end

	def test_disjoint_raises
		assert_raises(Code::Type_Alias_Is_Not_A_Type) { Code.interp "Strumber :: String | Number\n5 =/= Strumber" }
	end

	def test_a_second_alias_replaces_the_first
		assert Code.interp("Strumber :: String | Number\nStrumber :: String\nStrumber === String")
	end

	# A lock names the alias, so it reads the alias when the check runs.
	def test_a_lock_follows_a_replaced_alias
		assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    Strumber :: String | Number
			    x: Strumber = 5
			    Strumber :: String
			    x = 6
			CODE
		end
	end

	def test_an_alias_is_hoisted
		out = Code.interp <<~CODE
		    x: Later = :early
		    Later :: String | Symbol
		    x
		CODE
		assert_equal :early, out

		out = Code.interp <<~CODE
		    run ( callback: Callback;
		    	callback()
		    )
		    result := run((; 'ran'))
		    Callback :: (;)
		    result
		CODE
		assert_equal 'ran', out
	end

	def test_an_alias_can_name_another_alias
		out = Code.interp <<~CODE
		    Strumber :: String | Number
		    Wide :: Strumber | Symbol
		    <(5 =>= Wide), (:a =>= Wide), (true =>= Wide)>
		CODE
		assert_equal [true, true, false], out.values
	end

	def test_an_alias_in_a_struct_member
		out = Code.interp <<~CODE
		    Circle <radius: Number>
		    Square <side: Number>
		    Shape :: Circle | Square
		    Canvas <focus: Shape = nil>
		    Canvas(Square(2)).focus.side
		CODE
		assert_equal 2, out

		err = assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    Circle <radius: Number>
			    Square <side: Number>
			    Shape :: Circle | Square
			    Canvas <focus: Shape = nil>
			    Canvas(5)
			CODE
		end
		assert_match 'Shape', err.message
	end

	def test_an_alias_in_a_tag
		out = Code.interp <<~CODE
		    Circle <radius: Number>
		    Square <side: Number>
		    Shape :: Circle | Square
		    Drawing <shapes: Array\\Shape>
		    "`Drawing([Circle(1), Square(2)])`"
		CODE
		assert_equal '<shapes: Array\\Shape = [<radius: Number = 1>, <side: Number = 2>]>', out
	end

	# lang/css.code declares `Css :: Style_Rule | At_Rule | ...`, so any one rule is a Css.
	def test_the_standard_library_css_alias
		out = Code.interp <<~CODE
		    @load 'lang/css'
		    rule := Style_Rule(['p'], [])
		    <(rule =>= Css), (5 =>= Css)>
		CODE
		assert_equal [true, false], out.values
	end

	def test_standard_library_aliases_are_the_type_itself
		out = Code.interp '<(Int === Integer), (Dict === Dictionary), (Str === String), (Args === Arguments)>'
		assert_equal [true, true, true, true], out.values
	end

	# --- Annotations use the same Type_Alias ---

	def test_a_composed_annotation_shows_its_operator_in_the_error
		%w(| & ^ ~).each do |operator|
			err = assert_raises Code::Type_Contract_Violation do
				Code.interp <<~CODE
				    no (;
				    	:no
				    )
				    x: Integer #{operator} String = no()
				CODE
			end
			assert_match "Integer #{operator} String", err.message

			# A literal is caught before the program runs, and that error shows the operator too
			err = assert_raises(Code::Type_Checking_Failed) { Code.type_check "x: Integer #{operator} String = :no" }
			assert_match "Integer #{operator} String", err.message
		end
	end

	def test_a_composed_return_type_signature_matches_the_same_composition
		out = Code.interp <<~CODE
		    Lookup :: (String -> Number | Nil;)
		    find ( key: String -> Number | Nil;
		    	nil
		    )
		    use ( lookup: Lookup;
		    	lookup('a')
		    )
		    use(find)
		CODE
		assert_nil out
	end

	# --- Static checks and declarations ---

	def test_the_static_checker_resolves_an_alias_of_one_type
		assert_raises(Code::Type_Checking_Failed) { Code.type_check "Int32 :: Integer\nx: Int32 = 'a'" }
		refute_raises(Code::Type_Checking_Failed) { Code.type_check "Int32 :: Integer\nx: Int32 = 4" }
	end

	def test_the_static_checker_lets_an_alias_of_a_composition_pass
		refute_raises(Code::Type_Checking_Failed) { Code.type_check "Strumber :: String | Number\nx: Strumber = 5" }
	end

	def test_the_declarator_declares_an_alias
		decls = Code.declare 'Strumber :: String | Number'
		assert decls.key? 'Strumber'
		assert_instance_of Code::Type_Alias_Expr, decls['Strumber'].expr
	end
	# --- Literal types: a literal allows only that one value ---

	def test_a_literal_parses_in_each_type_position
		{
			'Mode :: "fill" | "line"'          => ->(e) { e.right },
			'Five :: 5'                        => ->(e) { e.right },
			'm: "fill" | "line" = "fill"'      => ->(e) { e.left.type },
			'S <m: "fill" | "line">'           => ->(e) { e.types.first.type },
			'f ( m: "fill" | "line"; m )'      => ->(e) { e.parameters.first.type },
			'f (-> "fill" | "line"; "fill")'   => ->(e) { e.type },
		}.each do |code, type_of|
			type = type_of.call Code.parse(code).first
			assert_instance_of Code::Type_Expr, type, code
			assert type.anonymous_composition, code
			assert_includes [Code::String_Expr, Code::Number_Expr], type.leading_literal.class, code
		end
	end

	# A named argument is `name := value`, and a Dictionary entry is `key = value`, so `name: "fill"` is free to be an annotation.
	def test_a_colon_after_a_name_is_an_annotation_not_a_named_argument
		assert_raises(Code::Colon_Named_Argument) { Code.parse 'f(m: "a")' }
		assert_raises(Code::Colon_Dictionary_Entry) { Code.parse '{m: "a", n: 5}' }
		assert_equal 3, Code.interp("f ( flags: Any;\n\tflags\n)\nf(flags := 1 | 2)")
		assert_equal({ m: 'a', 'n' => 5 }, Code.interp('{:m = "a", "n" = 5}').hash)
	end

	def test_a_literal_type_on_a_variable
		out = Code.interp <<~CODE
		    mode: "fill" | "line" = "fill"
		    mode = "line"
		    mode
		CODE
		assert_equal 'line', out

		# With no value, it declares nil locked to the type, the same as `x: Int`
		out = Code.interp <<~CODE
		    mode: "fill" | "line"
		    first := mode
		    mode = "fill"
		    <first, mode>
		CODE
		assert_equal [nil, 'fill'], out.values

		err = assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    value := "dash"
			    mode: "fill" | "line" = "fill"
			    mode = value
			CODE
		end
		assert_match '"fill" | "line"', err.message
	end

	def test_a_literal_type_on_a_struct_member_param_and_return
		assert_equal ['a', 'b'], Code.interp("f ( m: \"a\" | \"b\" = \"a\";\n\tm\n)\n<f(), f(\"b\")>").values
		assert_equal 'line', Code.interp("S <mode: \"fill\" | \"line\" = \"fill\">\nS(\"line\").mode")
		assert_raises(Code::Type_Contract_Violation) { Code.interp "S <mode: \"fill\" | \"line\">\nv := \"dash\"\nS(v)" }

		code = <<~CODE
		    pick ( mode: "fill" | "line" -> :ok | :no;
		    	if mode == "fill"
		    		:ok
		    	else
		    		:no
		    	end
		    )
		CODE
		assert_equal :ok, Code.interp(code + 'pick("fill")')
		assert_raises(Code::Type_Contract_Violation) { Code.interp code + "v := \"dash\"\npick(v)" }
	end

	def test_a_literal_alias
		out = Code.interp <<~CODE
		    Mode :: "fill" | 'line'
		    m: Mode = "fill"
		    <"`Mode`", ("line" =>= Mode), ("dash" =>= Mode)>
		CODE
		assert_equal ["Mode :: \"fill\" | 'line'", true, false], out.values
	end

	# `Five :: 5` is a type that only 5 satisfies, not a value, so it cannot be computed with.
	def test_an_alias_of_one_literal_is_a_type_not_a_value
		out = Code.interp <<~CODE
		    Five :: 5
		    <(5 =>= Five), (6 =>= Five), (5.0 =>= Five), (Five == Five)>
		CODE
		assert_equal [true, false, true, true], out.values

		["Five()", "Five + 1", "1 + Five", "Five | 4", "-Five", "Five < 6", "x := 5\nx += Five", "y := Five | Number"].each do |code|
			assert_raises(Code::Type_Alias_Is_Not_A_Type, code) { Code.interp "Five :: 5\n#{code}" }
		end
	end

	def test_every_literal_kind_mixed_with_type_names
		out = Code.interp <<~CODE
		    A :: Int | "auto" | :x | true | nil | 2.5
		    <"`A`", (:x =>= A), ('auto' =>= A), (true =>= A), (false =>= A), (4 =>= A), (2.5 =>= A), (3.5 =>= A), (:y =>= A)>
		CODE
		assert_equal ['A :: Int | "auto" | :x | true | nil | 2.5', true, true, true, false, true, true, false, false], out.values
	end

	def test_operators_keep_their_set_meaning_with_literals
		out = Code.interp <<~CODE
		    Port :: Int ~ 0
		    <(80 =>= Port), (0 =>= Port)>
		CODE
		assert_equal [true, false], out.values
	end

	def test_a_string_literal_does_not_match_a_symbol
		assert_equal [true, false], Code.interp("A :: \"fill\"\n<(\"fill\" =>= A), (:fill =>= A)>").values
	end

	# A literal default or argument is checked before the program runs.
	def test_the_static_checker_checks_literal_values
		{
			'm: "fill" | "line" = "fil"'      => '"fil"',
			'm: "fill" | "line" = :fill'      => ':fill',
			'f ( m: "a" | "b" = "c"; m )'     => '"c"',
			"f ( m: \"a\" | \"b\"; m )\nf(\"c\")" => '"c"',
			'x: Int | "auto" = 2.5'           => '2.5',
		}.each do |code, shown|
			err = assert_raises(Code::Type_Checking_Failed, code) { Code.type_check code }
			assert_match shown, err.message, code
		end

		['m: "fill" | "line" = "line"', 'x: Int | "auto" = "auto"', 'x: Int | "auto" = 4', "f ( m: \"a\" | \"b\"; m )\nf(\"a\")"].each do |code|
			refute_raises(Code::Type_Checking_Failed) { Code.type_check code }
		end
	end

	def test_a_literal_then_a_value_operator_in_a_return_type_raises
		assert_raises(Code::Invalid_Return_Type_In_Function) { Code.parse 'f (-> 1+2; 3)' }
	end

	# --- The name of an alias ---

	def test_a_lowercase_alias_name_raises
		err = assert_raises(Code::Invalid_Type_Alias_Name) { Code.parse 'lowercase :: true' }
		assert_match 'capitalized', err.message
	end
	# Named literals shared by several types, as in CSS: one name for each, no typos.
	def test_aliases_of_literals_shared_by_several_types
		out = Code.interp <<~CODE
		    Auto    :: "auto"
		    Inherit :: "inherit"
		    Width   :: Number | Auto | Inherit
		    Margin  :: Number | Auto
		    <(12 =>= Width), ("auto" =>= Width), ("inherit" =>= Width), ("inherit" =>= Margin), ("12px" =>= Width), "`Width`">
		CODE
		assert_equal [true, true, true, false, false, 'Width :: Number | Auto | Inherit'], out.values

		out = Code.interp <<~CODE
		    Auto   :: "auto"
		    Margin :: Number | Auto
		    Box <margin: Margin = "auto">
		    <Box().margin, Box(4).margin>
		CODE
		assert_equal ['auto', 4], out.values
		assert_raises(Code::Type_Contract_Violation) { Code.interp "Auto :: \"auto\"\nMargin :: Number | Auto\nBox <margin: Margin>\nv := \"inherit\"\nBox(v)" }
	end

	# "Anything except one value"
	def test_anything_except_one_literal
		out = Code.interp <<~CODE
		    Port    :: Int ~ 0
		    Nonzero :: Number ~ 0
		    <(80 =>= Port), (0 =>= Port), (2.5 =>= Nonzero), (0 =>= Nonzero), (0.0 =>= Nonzero)>
		CODE
		assert_equal [true, false, true, false, false], out.values
	end

	def test_negative_literals
		out = Code.interp <<~CODE
		    Sign :: -1 | 0 | 1
		    Offset :: Int ~ -1
		    <(-1 =>= Sign), (2 =>= Sign), (-1 =>= Offset), (5 =>= Offset), "`Sign`">
		CODE
		assert_equal [true, false, false, true, 'Sign :: -1 | 0 | 1'], out.values
		assert_equal [-1, 1], Code.interp("S <n: -1 | 1 = -1>\n<S().n, S(1).n>").values
		assert_raises(Code::Type_Checking_Failed) { Code.type_check 'n: -1 | 1 = 2' }
	end
end
