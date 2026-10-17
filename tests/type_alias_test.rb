require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'

# `Name :: type expression` -- see readme.md's "Type Aliases" section.
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
		assert_raises(Code::Invalid_Type_Alias) { Code.parse 'Five :: 5' }
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
		    ("`Expressions`", "`A`")
		CODE
		assert_equal ['Expressions :: Array\Bool | Number', 'A :: Number | Array\Bool\Int | Array\<...>'], out.values
	end

	# A contract never checks a tag, the same as a plain `x: Array\Bool` annotation: only the base type counts. A tag is for the user's own code to read and use.
	def test_a_tagged_operand_checks_its_base_type
		out = Code.interp <<~CODE
		    Expressions :: Array\\Bool | Number
		    (5 =>= Expressions, [true] =>= Expressions, [5] =>= Expressions, :x =>= Expressions)
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
		    (Strumber.@name, Strumber.@types, Strumber.@composed_types.count(), "`Strumber`")
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
		    (5 =>= Strumber, 'a' =>= Strumber, :a =>= Strumber, nil =>= Strumber, Strumber =<= 5)
		CODE
		assert_equal [true, true, false, false, true], out.values
	end

	def test_triple_equals_compares_by_identity
		out = Code.interp <<~CODE
		    Strumber :: String | Number
		    Other :: String | Number
		    (Strumber === Strumber, Strumber === Other, 5 === Strumber, Strumber =!= Other)
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
		    (5 =>= Wide, :a =>= Wide, true =>= Wide)
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
		    (rule =>= Css, 5 =>= Css)
		CODE
		assert_equal [true, false], out.values
	end

	def test_standard_library_aliases_are_the_type_itself
		out = Code.interp '(Int === Integer, Dict === Dictionary, Str === String, Args === Arguments)'
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
end
