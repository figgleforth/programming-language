require 'minitest/autorun'
require_relative '../source/main'
require_relative 'base_test'

# These tests are mostly in chronological order. I may have inserted some at times. It would be great to preserve this order.

class Interpreter_Test < Base_Test
	def test_global_program
		refute_raises RuntimeError do
			Code.interp_file './source/code/global.code'
		end
	end

	def test_numeric_literals
		assert_equal 48, Code.interp('48')
		assert_equal 15.16, Code.interp('15.16')
		assert_equal 2342, Code.interp('23_42')
	end

	def test_true_false_nil_literals
		assert_equal true, Code.interp('true')
		assert_equal false, Code.interp('false')
		assert_instance_of NilClass, Code.interp('nil')
	end

	def test_uninterpolated_strings
		assert_equal 'Walt!', Code.interp('"Walt!"')
		assert_equal 'Vincent!', Code.interp("'Vincent!'")
	end

	def test_raises_undeclared_identifier_when_reading
		assert_raises Code::Undeclared_Identifier do
			Code.interp 'hatch'
		end
	end

	def test_does_not_raise_undeclared_identifier_when_declaring
		refute_raises Code::Undeclared_Identifier do
			Code.interp 'found := true'
		end
	end

	def test_variable_assignment_and_lookup
		out = Code.interp 'name := "Locke", name'
		assert_equal 'Locke', out
	end

	def test_constant_assignment_and_lookup
		out = Code.interp 'ENVIRONMENT := :development, ENVIRONMENT'
		assert_equal :development, out
	end

	def test_cannot_assign_incompatible_type
		# todo; raises Cannot_Reassign_Undeclared_Identifier
		assert_raises Code::Cannot_Assign_Incompatible_Type do
			Code.interp 'MyType {}
			My_Type = :anything'
		end

		refute_raises Code::Cannot_Assign_Incompatible_Type do
			Code.interp 'MyType {}
			My_Type = Other {}'
		end
	end

	def test_nil_assignment_operator
		out = Code.interp 'nothing,'
		assert_instance_of NilClass, out
	end

	def test_anonymous_func_expr
		out = Code.interp '(;)'
		assert_instance_of Code::Func, out
		assert_empty out.expressions
		refute out.name
	end

	def test_empty_func_declaration
		out = Code.interp 'open (;)'
		assert_instance_of Code::Func, out
		assert_empty out.expressions
		assert_equal 'open', out.name.value
	end

	def test_basic_func_declaration
		out = Code.interp 'enter ( numbers := "4815162342"; )'
		assert_equal 1, out.parameters.count
		assert_empty out.expressions
		assert_instance_of Code::Param_Expr, out.parameters.first
		assert_instance_of Code::String_Expr, out.parameters.first.default
	end

	def test_advanced_func_declaration
		out = Code.interp 'add ( a, b; a + b )'
		assert_equal 2, out.parameters.count
		assert_equal 1, out.expressions.count
		assert_instance_of Code::Infix_Expr, out.expressions.last
		refute out.parameters.first.default
	end

	def test_complex_func_declaration
		out = Code.interp 'run ( a, labeled b, c := 4, labeled d := 8;
			c + d
		)'
		assert_equal 4, out.parameters.count
		assert_equal 1, out.expressions.count

		a = out.parameters[0]
		assert_equal 'a', a.name.value
		refute a.label
		refute a.default

		b = out.parameters[1]
		assert b.label
		assert_equal 'labeled', b.label.value
		refute b.default

		c = out.parameters[2]
		assert c.default
		refute c.label

		d = out.parameters[3]
		assert d.label
		assert d.default

		assert_instance_of Code::Infix_Expr, out.expressions.last
	end

	def test_empty_type_declaration
		out = Code.interp 'Island {}'
		assert_instance_of Code::Type, out
		assert_empty out.expressions
		assert_equal 'Island', out.name
	end

	def test_basic_type_declaration
		out = Code.interp 'Hatch {
			computer := nil

			enter ( numbers;
				# do something with the numbers
			)
		}'
		assert_instance_of Code::Type, out
		assert_instance_of NilClass, out[:computer]
		assert_instance_of Code::Func, out[:enter]
	end

	def test_inline_type_composition_declaration
		out = Code.interp 'Number {}
		Integer | Number {}'
		assert_instance_of Code::Type, out
		assert_equal Set['Integer', 'Number'], out.types
	end

	def test_inbody_type_composition_declaration
		out = Code.interp 'Numeric {
			numerator,
		}
		Number | Numeric {}
		Float {
			| Number
		}'
		assert_instance_of Code::Type, out
		assert_equal Set['Float', 'Number', 'Numeric'], out.types
	end

	def test_invalid_type_declaration
		assert_raises Code::Undeclared_Identifier do
			Code.interp 'Number | Numeric {}'
		end
	end

	def test_potential_colon_ambiguity
		out = Code.interp 'assign_to_nil,'
		assert_instance_of NilClass, out

		out = Code.interp 'func ( assign_to_nil; )'
		assert_instance_of Code::Func, out
		assert_instance_of Code::Param_Expr, out.parameters.first
		assert_equal 'assign_to_nil', out.parameters.first.name.value
	end

	def test_infix_arithmetic
		assert_equal 12, Code.interp('4 + 8')
		assert_equal 4, Code.interp('1 + 2 * 3 / 4 % 5 ^ 6')
		assert_equal 8, Code.interp('(1 + (2 * 3 / 4) % 5) << 2')
	end

	def test_nested_type_declaration
		out = Code.interp '
		Computer {
		}

		Island {
			Hatch {
				Commodore_64 | Computer {}
			}
		}

		Island.Hatch.Commodore_64'
		assert_instance_of Code::Type, out
	end

	def test_constants_cannot_be_reassigned
		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp 'ENVIRONMENT := :development
			ENVIRONMENT = :production'
		end
	end

	def test_variable_declarations
		out = Code.interp 'cool := "Cooper"'
		assert_equal 'Cooper', out

		out = Code.interp 'delta := 0.017'
		assert_equal 0.017, out
	end

	def test_declared_variable_lookup
		out = Code.interp 'number := 42
		number'
		assert_equal 42, out
	end

	def test_variable_can_be_reassigned
		out = Code.interp 'number := 42'
		assert_equal 42, out

		out = Code.interp 'number := 42
		number = 8'
		assert_equal 8, out
	end

	# Code::Range is now an Instance wrapping a Ruby ::Range (`.range`), not a ::Range subclass -- so
	# the raw-Range comparison is against `out.range`; `out.include?` still works via Enumerable.
	def test_inclusive_range
		out = Code.interp '4..42'
		assert_instance_of Code::Range, out
		assert_equal 4..42, out.range
		assert out.include? 4
		assert out.include? 23
		assert out.include? 42
	end

	def test_right_exclusive_range
		out = Code.interp '4..<42'
		assert_instance_of Code::Range, out
		assert_equal 4...42, out.range
		assert out.include? 4
		assert out.include? 41
		refute out.include? 42
	end

	def test_left_exclusive_range
		out = Code.interp '4>..42'
		assert_instance_of Code::Range, out
		assert_equal 5..42, out.range
		refute out.include? 4
		assert out.include? 5
		assert out.include? 42
	end

	def test_left_and_right_exclusive_range
		out = Code.interp '4>..<42'
		assert_instance_of Code::Range, out
		assert_equal 5...42, out.range
		refute out.include? 4
		assert out.include? 5
		assert out.include? 41
		refute out.include? 42
	end

	def test_empty_left_and_right_exclusive_range
		out = Code.interp '0>..<0'
		assert_equal 1...0, out.range
		refute out.include? -1
		refute out.include? 0
		refute out.include? 1
		refute out.include? 0.5
	end

	def test_simple_comparison_operators
		assert Code.interp '1 == 1'
		refute Code.interp '1 != 1'
		assert Code.interp '1 != 2'
		assert Code.interp '1 < 2'
		refute Code.interp '1 > 2'

		# It doesn't make sense to test all these since I'm just calling through to Ruby
	end

	def test_boolean_logic
		assert Code.interp 'true && true'
		refute Code.interp 'true && false'
		assert Code.interp 'true and true'
		refute Code.interp 'true and false'
	end

	def test_arithmetic_operators
		out = Code.interp '1 + 2 / 3 - 4 * 5'
		assert_equal -19, out

		# Right now this functions like the Ruby operator, but it could also be the power operator
		out = Code.interp '2 ^ 3'
		assert_equal 1, out

		out = Code.interp '1 << 2'
		assert_equal 4, out

		out = Code.interp '1 << 3'
		assert_equal 8, out
	end

	def test_double_operators
		out = Code.interp '1 - -9'
		assert_equal 10, out

		out = Code.interp '4 + -8'
		assert_equal -4, out

		out = Code.interp '8 - +15'
		assert_equal -7, out
	end

	def test_empty_array
		out = Code.interp '[]'
		assert_equal [], out.values
		assert_instance_of Code::Array, out
	end

	def test_non_empty_arrays
		out = Code.interp '[1]'
		assert_instance_of Code::Array, out
		assert_equal [1], out.values

		out = Code.interp '[1, "test", 5]'
		assert_instance_of Code::Array, out
		assert_equal Code::Array.new([1, 'test', 5]).values, out.values
	end

	def test_tuples
		out = Code.interp '(1, 2)'
		assert_kind_of Code::Tuple, out
		assert_equal [1, 2], out.values

		out = Code.interp 't := ("Hello", "from" ,"Tuple")
		t_first := t.0
		t2 := (t.0, t.1, t.2)
		(t_first, t == t2, t_first == t2, t2)'
		assert_equal "Hello", out.values.first
		assert out.values[1]
		refute out.values[2]
		assert_equal ["Hello", "from", "Tuple"], out.values.last.values
	end

	def test_tuple_reports_its_own_type_not_array
		out = Code.interp '
			t := (1, 2)
			(t.@type, t.@types, t.@name)'
		type, types, name = out.values
		assert_equal 'Tuple', type
		assert_equal ['Tuple'], types.values
		assert_equal 'Tuple', name
	end

	def test_empty_dictionary
		out = Code.interp '{}'
		assert_kind_of Code::Dictionary, out
		assert_equal out.hash, {}
	end

	def test_create_dictionary_with_identifiers_as_keys_without_commas
		out = Code.interp '{a b c}'
		assert_equal %i(a b c), out.hash.keys
		out.hash.values.each do |value|
			assert_instance_of NilClass, value
		end
	end

	def test_create_dictionary_with_identifiers_as_keys_with_commas
		out = Code.interp '{a, b}'
		out.hash.values.each do |value|
			assert_instance_of NilClass, value
		end
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation
		out = Code.interp '{ x:0 y=1 z}'
		refute_instance_of NilClass, out.hash.values.first
		refute_instance_of NilClass, out.hash.values[1]
		assert_instance_of NilClass, out.hash.values.last
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation_and_commas
		out = Code.interp '{ x:4, y=8, z}'
		assert_equal 4, out.hash.values.first
		assert_equal 8, out.hash.values[1]
		assert_instance_of NilClass, out.hash.values.last
	end

	def test_create_dictionary_with_local_value
		out = Code.interp 'x:=4, y:=2, { x=x, y=y }'
		assert_equal out.hash, { x: 4, y: 2 }
	end

	def test_symbol_as_dictionary_keys
		out = Code.interp '{ :x = 1 }'
		assert_equal out.hash, { x: 1 }
	end

	def test_string_as_dictionary_keys
		out = Code.interp '{ "x" = 1 }'
		assert_equal out.hash, { x: 1 }
	end

	def test_colon_as_dictionary_infix_operator
		out = Code.interp 'x := 123, { x: x }'
		assert_equal out.hash, { x: 123 }
	end

	def test_equals_as_dictionary_infix_operator
		out = Code.interp 'x := 123, { x = x }'
		assert_equal out.hash, { x: 123 }
	end

	def test_dictionary_keys
		out = Code.interp '{ a b c }.keys()'
		assert_equal [:a, :b, :c], out.values
	end

	def test_dictionary_values
		out = Code.interp '{ a b c }.values()'
		assert_equal [nil, nil, nil], out.values

		out = Code.interp '{ a=1, b= "two", c: :three }.values()'
		assert_equal [1, "two", :three], out.values

		out = Code.interp '{ a=1, b="two", c: :three }.values()'
		assert_equal [1, "two", :three], out.values

		out = Code.interp '{ a=1, b:"two", c: :three }.values()'
		assert_equal [1, "two", :three], out.values
	end

	def test_dictionary_subscript
		out = Code.interp "dict := {x}
		original := dict[:x]
		dict[:x] = 4815
		(original, dict[:x])"
		assert_equal [nil, 4815], out.values
	end

	def test_dictionary_subscript_string_and_symbol_do_not_behave_differently
		out = Code.interp "dict := {x=4815}
		(dict['x'], dict[:x])"
		assert_equal [4815, 4815], out.values
	end

	# `[]`/`[]=` (#proxy_get/#proxy_set) normalize a key to a Symbol before touching the underlying hash -- `has_key?`/`delete`/`fetch` used to skip that normalization entirely, so a String key that matched what `[]=` actually stored (a Symbol) silently never matched.
	def test_dictionary_has_key_with_string_key_matches_what_bracket_assignment_stored
		out = Code.interp "d := {}
		d['color'] = 1
		d.has_key?('color')"
		assert_equal true, out
	end

	def test_dictionary_delete_with_string_key_removes_the_entry
		out = Code.interp "d := {a: 1}
		d.delete('a')
		d.count()"
		assert_equal 0, out
	end

	def test_dictionary_fetch_with_string_key_finds_the_value
		out = Code.interp "d := {a: 1}
		d.fetch('a', 99)"
		assert_equal 1, out
	end

	def test_dictionary_fetch_missing_key_returns_the_default
		out = Code.interp "d := {}
		d.fetch('missing', 42)"
		assert_equal 42, out
	end

	# The key normalization fix has to work for a real Code::String value (an ordinary call argument, e.g. a variable), not just a raw Ruby string literal interpreted directly by `[]`/`[]=`'s own subscript handling.
	def test_dictionary_has_key_with_a_variable_holding_a_string_still_matches
		out = Code.interp "d := {}
		d[:x] = 1
		s := 'x'
		d.has_key?(s)"
		assert_equal true, out
	end

	# `:=` declares an identifier -- a subscript target isn't one, so `d[key] := value` isn't meaningful the way `d[key] = value` is (and used to silently declare a bogus identifier instead of writing to the dictionary).
	def test_dictionary_subscript_assignment_via_declare_operator_raises
		assert_raises Code::Cannot_Declare_Subscript_Target do
			Code.interp "d := {}
			d[:x] := 5"
		end
	end

	# Code::Array had no `[]=` of its own, so `a[i] = value` fell through to the generic declarations-hash write every other Scope uses, silently declaring a bogus member instead of writing into `.values`.
	# A Code::Range subscript slices an Array -- each of the four range operators keeps its own
	# inclusive/exclusive end behavior (`..` inclusive, `..<` exclusive end, `>..` exclusive start).
	def test_array_range_subscript
		assert_equal [20, 30, 40], Code.interp('[10, 20, 30, 40, 50][1..3]').values
		assert_equal [20, 30], Code.interp('[10, 20, 30, 40, 50][1..<3]').values
		assert_equal [30, 40], Code.interp('[10, 20, 30, 40, 50][1>..3]').values
		assert_equal [30], Code.interp('[10, 20, 30, 40, 50][1>..<3]').values

		# the result is a real, linked Array -- methods chain off it
		assert_equal [21, 31, 41], Code.interp('[10, 20, 30, 40, 50][1..3].map((x; x + 1))').values

		# a range held in a variable works too
		assert_equal [20, 30, 40], Code.interp("r := 1..3\n[10, 20, 30, 40, 50][r]").values

		# an out-of-bounds start yields nil, same as Ruby
		assert_nil Code.interp('[1, 2, 3][5..9]')
	end

	# `xs[2..]` -- an endless range (the operator with nothing after it): from the start index to the end.
	def test_endless_range_subscript
		assert_equal [30, 40, 50], Code.interp('[10, 20, 30, 40, 50][2..]').values
		assert_equal [40, 50], Code.interp('[10, 20, 30, 40, 50][2>..]').values # exclusive start
		assert_equal 'world', Code.interp('"hello world"[6..]')
		assert_equal 5, Code.interp('[1, 2, 3, 4, 5][0..].length()')
		assert_equal [3, 4, 5], Code.interp("r := 2..\n[1, 2, 3, 4, 5][r]").values
		assert_nil Code.interp('[1, 2, 3][10..]')
	end

	# `xs[..3]` -- a beginless range (the operator with no left operand): from the start up to the end
	# index. Negative end indices count from the end (`..-1` is the whole thing, `..-2` all but last).
	def test_beginless_range_subscript
		assert_equal [10, 20, 30], Code.interp('[10, 20, 30, 40, 50][..2]').values
		assert_equal [10, 20], Code.interp('[10, 20, 30, 40, 50][..<2]').values # exclusive end
		assert_equal [10, 20, 30, 40, 50], Code.interp('[10, 20, 30, 40, 50][..-1]').values
		assert_equal [10, 20, 30, 40], Code.interp('[10, 20, 30, 40, 50][..-2]').values
		assert_equal [10, 20, 30, 40], Code.interp('[10, 20, 30, 40, 50][..<-1]').values
		assert_equal 'hello worl', Code.interp('"hello world"[..-2]')

		# a range operator glued to a following `-` must not lex as one token (`..` then prefix `-`)
		assert_equal [20, 30, 40, 50], Code.interp('[10, 20, 30, 40, 50][1..-1]').values
	end

	def test_string_range_subscript
		assert_equal 'bcd', Code.interp('"abcdef"[1..3]') # inclusive
		assert_equal 'bc', Code.interp('"abcdef"[1..<3]') # exclusive end
		assert_equal 'WORLD', Code.interp('"hello world"[6..11].upcase()')
	end

	def test_array_subscript_assignment_mutates_in_place
		out = Code.interp "a := [1, 2, 3]
		a[1] = 99
		a"
		assert_equal [1, 99, 3], out.values
	end

	def test_array_subscript_assignment_out_of_bounds_raises
		assert_raises Code::Invalid_Array_Index do
			Code.interp "a := [1, 2, 3]
			a[10] = 99"
		end
	end

	def test_array_subscript_assignment_via_declare_operator_raises
		assert_raises Code::Cannot_Declare_Subscript_Target do
			Code.interp "a := [1, 2, 3]
			a[1] := 99"
		end
	end

	def test_too_many_dictionary_subscript_arguments
		assert_raises Code::Too_Many_Subscript_Expressions do
			Code.interp "dict := {x=4815}
			dict[:x, 123]"
		end

		assert_raises Code::Too_Many_Subscript_Expressions do
			Code.interp "dict := {x=4815}
			dict[:x, 123] = 162342"
		end
	end

	def test_nested_dictionary_subscript
		out = Code.interp '{ a: { b: 42 } }[:a][:b]'
		assert_equal 42, out
	end

	def test_dictionary_subscript_nonexistent_key
		out = Code.interp '{ a: 1 }[:nonexistent]'
		assert_nil out
	end

	def test_dictionary_subscript_with_variable
		out = Code.interp 'key := :a, dict := { a: 99 }, dict[key]'
		assert_equal 99, out
	end

	def test_dictionary_subscript_in_expression
		out = Code.interp '{ x: 10 }[:x] + 5'
		assert_equal 15, out
	end

	def test_empty_dictionary_subscript
		out = Code.interp '{}[:key]'
		assert_nil out
	end

	def test_invalid_dictionary_infix
		assert_raises Code::Invalid_Dictionary_Infix_Operator do
			Code.interp '{ x > x }'
		end
	end

	def test_assigning_function_to_variable
		out = Code.interp 'funk := ( a, b, c; )'
		assert_equal 3, out.parameters.count
	end

	def test_composed_type_declaration
		out = Code.interp '
		Transform {}
		Rotation {}
		Entity {
			| Transform
			~ Rotation
		}'
		assert_kind_of Code::Type, out
		assert_kind_of Code::Composition_Expr, out.expressions.first
		assert_kind_of Code::Composition_Expr, out.expressions.last
		assert_equal 'Rotation', out.expressions.last.identifier.value
		assert_equal '~', out.expressions.last.operator.value
	end

	def test_composed_type_declaration_before_body
		out = Code.interp '
		Transform {}, Physics {}
		Entity | Transform ~ Physics {}'
		assert_kind_of Code::Type, out
		assert_kind_of Code::Composition_Expr, out.expressions.first
		assert_kind_of Code::Composition_Expr, out.expressions.last
		assert_equal 'Physics', out.expressions.last.identifier.value
		assert_equal '~', out.expressions.last.operator.value
	end

	def test_complex_type_declaration
		out = Code.interp 'Transform {
			position,
			rotation,

			x := 0
			y := 0

			to_s (;
				"Transform!"
			)
		}'
		assert_kind_of Code::Infix_Expr, out.expressions[0]
		assert_kind_of Code::Infix_Expr, out.expressions[1]
		assert_kind_of Code::Infix_Expr, out.expressions[2]
		assert_kind_of Code::Infix_Expr, out.expressions[3]
		assert_kind_of Code::Func_Expr, out.expressions[4]
	end

	def test_undeclared_type_init_via_call
		assert_raises Code::Undeclared_Identifier do
			Code.interp 'Type()'
		end
	end

	# `Self` is deleted off an instance right after construction finishes, so a dot-access to it from an already-built value (a lowercase-receiver `x.Self`, as opposed to a Type's own `Ident.Self`) just fails like any other missing member.
	def test_ident_dot_self_fails_after_construction
		assert_raises Code::Undeclared_Identifier do
			Code.interp 'x := 1, x.Self'
		end
	end

	def test_declared_type_init_via_call
		out = Code.interp 'Type {}, Type()'
		assert_instance_of Code::Instance, out
		assert_equal 'Type', out.name
	end

	# Bare `X.Self` is equivalent to `X()` — it runs `Self(;)`, so required constructor params raise.
	# Bare `X.Self` (no parens) is an ordinary reference to the declared function, same as any other unnamed function access -- it does not call it, let alone construct an instance. `X()` remains the real, documented way to construct.
	def test_bare_self_returns_function_reference
		out = Code.interp 'Thing {
			x,
			Self (;
				self.x = 123
			)
		}, Thing.Self'
		assert_kind_of Code::Func, out

		out = Code.interp 'Thing {
			x,
			Self (;
				self.x = 123
			)
		}, Thing().x'
		assert_equal 123, out
	end

	def test_complex_type_init
		out = Code.interp 'Transform {
			position,
			rotation,

			x := 4
			y := 8

			to_s (;
				"Transform!"
			)

			Self ( position := 0; )
		}, Transform()'
		assert_kind_of Code::Instance, out
		assert_equal 'Transform', out.name
		assert_kind_of ::Array, out.expressions
		assert_equal 6, out.expressions.count
		assert_kind_of Code::Func_Expr, out.expressions.last
	end

	def test_complex_type_with_value_lookup
		out = Code.interp 'Vector1 { x := 4 }
		Vector1().x
		'
		assert_equal 4, out
	end

	def test_instance_complex_value_lookup
		out = Code.interp 'Vector2 { x := 1, y := 2 }
		Transform {
			position := Vector2()
		}
		t := Transform()
		(t.position, t.position.y)
		'
		assert_kind_of Code::Tuple, out
		assert_kind_of Code::Instance, out.values.first
		assert_equal 2, out.values.last
	end

	def test_type_declaration_with_parens
		out = Code.interp 'Vector2 { x := 0, y := 1 }
		pos := Vector2()'
		assert_instance_of Code::Instance, out
		data = { 'x' => 0, 'y' => 1 }
		assert_equal data, out.declarations
	end

	# `.name`/`.types` are `@`-only (`@.name`/`@.composed_types`), stored as plain Ruby attrs; when the backing Ruby class is shared with a *composed* type (`Tasks | Table {}` resolves to Code::Table, a Ruby-backed builtin), that class's own Type#initialize baked its own name ("Table") into the attr at construction, which `build_instance_of_type` must overwrite with the real composed type's name.
	def test_composed_instance_reports_its_own_name_not_the_proxy_ruby_class_regression
		out = Code.interp "@load 'code/table'
			Tasks | Table {}
			t := Tasks()
			(t.@name, t.@composed_types)"
		assert_equal 'Tasks', out.values.first
		assert_equal %w(Tasks Table), out.values.last.set.to_a
	end

	def test_self_scope_write_outside_instance
		assert_raises Code::Cannot_Use_Instance_Scope_Operator_Outside_Instance do
			Code.interp 'self.x := 123'
		end
	end

	def test_type_scope_write_outside_type
		assert_raises Code::Cannot_Use_Type_Scope_Operator_Outside_Type do
			Code.interp 'Self.x := 123'
		end
	end

	def test_global_scope_operator_lookup
		out = Code.interp 'Global.y := 543
		Global.y'
		assert_equal 543, out
	end

	def test_function_call_with_arguments
		out = Code.interp '
		add ( a, b; a+b )
		add(4, 8)'
		assert_equal 12, out
	end

	def test_named_call_arguments_bind_by_declared_name_regardless_of_order
		src = 'sub ( a, b; a - b )'
		assert_equal -1, Code.interp("#{src}\nsub(a := 1, b := 2)")
		assert_equal -1, Code.interp("#{src}\nsub(b := 2, a := 1)") # reordered -- same result
	end

	def test_named_call_arguments_can_follow_positional_arguments
		src = 'sub ( a, b; a - b )'
		assert_equal -1, Code.interp("#{src}\nsub(1, b := 2)")
	end

	def test_positional_argument_after_named_raises
		assert_raises Code::Positional_Argument_After_Named do
			Code.interp 'add ( a, b; a + b )
				add(a := 1, 2)'
		end
	end

	def test_duplicate_named_argument_raises
		assert_raises Code::Duplicate_Named_Argument do
			Code.interp 'add ( a, b; a + b )
				add(a := 1, a := 2)'
		end
	end

	def test_argument_given_by_name_and_position_raises
		assert_raises Code::Argument_Given_By_Name_And_Position do
			Code.interp 'add ( a, b; a + b )
				add(1, a := 2)'
		end
	end

	# An unknown name is the actual mistake, so it has to be reported even when some other (unrelated) param is also left without a value as a side effect of that same typo -- not masked by a confusing Missing_Argument that never mentions the real problem.
	def test_unknown_named_argument_raises_even_when_another_param_is_also_left_missing
		assert_raises Code::Unknown_Named_Argument do
			Code.interp 'add ( a, b; a + b )
				add(a := 1, c := 2)' # `c` isn't a param; `b` is consequently never filled
		end
	end

	def test_named_call_arguments_fall_back_to_defaults_when_omitted
		out = Code.interp <<~CODE
		    greet ( name := "World"; "Hello, `name`" )
		    (greet(), greet(name := "Backend"))
		CODE
		assert_equal ['Hello, World', 'Hello, Backend'], out.values
	end

	def test_named_call_arguments_do_not_leak_into_caller_scope
		assert_raises Code::Undeclared_Identifier do
			Code.interp 'add ( a, b; a + b )
				add(a := 1, b := 2)
				a' # `a` was never declared in the caller -- only inside add's own call scope
		end
	end

	def test_named_call_arguments_work_through_constructors
		out = Code.interp <<~CODE
		    Point {
		    	x,
		    	y,
		    	Self ( x, y;
		    		self.x = x
		    		self.y = y
		    	)
		    }
		    p := Point(y := 4, x := 3)
		    (p.x, p.y)
		CODE
		assert_equal [3, 4], out.values
	end

	# Labels (`:`, checked positionally against the declared label) and named arguments (`:=`, bound by declared name) are separate mechanisms with separate syntax -- a call can use a label on an early positional argument, then switch to named arguments for the rest.
	def test_named_call_arguments_are_distinct_from_labels
		out = Code.interp <<~CODE
		    send ( to person, subject := 'hi'; "`person`: `subject`" )
		    send(to: 'Alice', subject := 'bye')
		CODE
		assert_equal 'Alice: bye', out
	end

	def test_variadic_parameter_collects_the_positional_tail
		out = Code.interp <<~CODE
		    sum ( nums...;
		    	acc := 0
		    	for nums
		    		acc += it
		    	end
		    	acc
		    )
		    (sum(1, 2, 3, 4), sum())
		CODE
		assert_equal [10, 0], out.values
	end

	def test_variadic_after_a_fixed_parameter
		out = Code.interp <<~CODE
		    f ( a, rest...; (a, rest) )
		    f(1, 2, 3)
		CODE
		assert_equal 1, out.values[0]
		assert_equal [2, 3], out.values[1].values
	end

	def test_args_annotation_is_the_same_as_the_ellipsis_form
		out = Code.interp <<~CODE
		    g ( xs: Args; (xs, xs === Arguments) )
		    g(9, 8, 7)
		CODE
		assert_equal [9, 8, 7], out.values[0].values
		assert_equal true, out.values[1]
	end

	# A variadic param binds an `Arguments` (an Array subtype).
	def test_variadic_parameter_is_an_arguments_instance
		out = Code.interp <<~CODE
		    f ( xs...; (xs === Arguments, xs =>= Array) )
		    f(1)
		CODE
		assert_equal [true, true], out.values
	end

	# `rest := <value>` at the call site: an Array spreads, anything else is a type error.
	def test_variadic_named_argument_spreads_an_array_and_rejects_a_scalar
		out = Code.interp <<~CODE
		    f ( a, rest...; rest )
		    f(1, rest := [9, 8])
		CODE
		assert_equal [9, 8], out.values

		assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    f ( a, rest...; rest )
			    f(1, rest := 99)
			CODE
		end
	end

	# With a variadic param, an unknown named arg binds by its own name instead of raising.
	def test_variadic_function_binds_unknown_named_arguments_by_name
		out = Code.interp <<~CODE
		    h ( args...; value )
		    h(value := 42)
		CODE
		assert_equal 42, out
	end

	def test_variadic_is_the_only_parameter
		out = Code.interp <<~CODE
		    f ( xs...; (xs.length(), xs) )
		    f()
		CODE
		assert_equal 0, out.values[0]
		assert_equal [], out.values[1].values
	end

	def test_variadic_arguments_instance_has_array_methods
		out = Code.interp <<~CODE
		    f ( xs...; xs.map(( n; n * 2 )) )
		    f(1, 2, 3)
		CODE
		assert_equal [2, 4, 6], out.values
	end

	# A param after a variadic is keyword-only -- it can't be filled positionally.
	def test_parameter_after_a_variadic_is_keyword_only
		out = Code.interp <<~CODE
		    f ( a, mid..., z; (a, mid, z) )
		    f(1, 2, 3, z := 9)
		CODE
		assert_equal 1, out.values[0]
		assert_equal [2, 3], out.values[1].values
		assert_equal 9, out.values[2]

		assert_raises Code::Missing_Argument do
			Code.interp <<~CODE
			    f ( a, mid..., z; z )
			    f(1, 2, 3)
			CODE
		end
	end

	# A real param declared after a variadic still takes its default / named value.
	def test_defaulted_parameter_after_a_variadic
		out = Code.interp <<~CODE
		    f ( args..., flag := 5; (args, flag) )
		    (f(1, 2).1, f(1, 2, flag := 8).1)
		CODE
		assert_equal [5, 8], out.values
	end

	# Naming the variadic param itself (`rest := ...`) goes through the spread/reject path, never
	# the by-name nicety -- regression for a bug where it silently overwrote `rest` with a scalar.
	def test_naming_the_variadic_parameter_does_not_bypass_the_spread_check
		assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    f ( a, rest...; rest )
			    f(1, rest := 99)
			CODE
		end
	end

	def test_variadic_keeps_the_positional_before_named_ordering_rules
		assert_raises Code::Positional_Argument_After_Named do
			Code.interp <<~CODE
			    f ( a, rest...; a )
			    f(a := 1, 2)
			CODE
		end

		assert_raises Code::Argument_Given_By_Name_And_Position do
			Code.interp <<~CODE
			    f ( a, rest...; a )
			    f(1, a := 2)
			CODE
		end

		assert_raises Code::Duplicate_Named_Argument do
			Code.interp <<~CODE
			    f ( args...; x )
			    f(x := 1, x := 2)
			CODE
		end
	end

	def test_labeled_argument_with_a_variadic_tail
		out = Code.interp <<~CODE
		    f ( to a, rest...; (a, rest) )
		    f(to: 1, 2, 3)
		CODE
		assert_equal 1, out.values[0]
		assert_equal [2, 3], out.values[1].values
	end

	# A call site with typed fixed params + a variadic doesn't trip the static Type_Checker.
	def test_variadic_call_site_is_not_statically_type_checked
		refute_raises do
			Code.interp <<~CODE
			    f ( a: Number, rest...; a )
			    f(1, "two", :three, [4])
			CODE
		end
	end

	def test_variadic_parameter_in_a_constructor
		out = Code.interp <<~CODE
		    Bag {
		    	items,
		    	Self ( things...; self.items = things )
		    }
		    Bag(1, 2, 3).items
		CODE
		assert_equal [1, 2, 3], out.values
	end

	# Reopening `Arguments` to restrict what a variadic accepts.
	def test_arguments_push_can_be_overridden_for_a_typed_variadic
		src = <<~CODE
		    Arguments | Array {
		    	push ( item;
		    		unless item =>= Number
		    			return nil
		    		end
		    		self.append(item)
		    	)
		    }
		    collect ( nums...; nums )
		    r := collect()
		    r.push(1)
		    r.push("nope")
		    r.push(2)
		    r
		CODE
		assert_equal [1, 2], Code.interp(src).values
	end

	# --- Callsite splat (`...arr`) -- the calling-end mirror of a variadic param's `x...` --------

	def test_callsite_splat_spreads_an_array_into_positional_arguments
		out = Code.interp <<~CODE
		    sum ( a, b, c; a + b + c )
		    nums := [1, 2, 3]
		    sum(...nums)
		CODE
		assert_equal 6, out
	end

	def test_callsite_splat_can_follow_ordinary_positional_arguments
		out = Code.interp <<~CODE
		    sum ( a, b, c, d; a + b + c + d )
		    tail := [2, 3, 4]
		    sum(1, ...tail)
		CODE
		assert_equal 10, out
	end

	def test_callsite_splat_into_a_variadic_parameter
		out = Code.interp <<~CODE
		    total ( nums...; acc := 0
		        for nums
		            acc += it
		        end
		        acc
		    )
		    xs := [10, 20, 30]
		    total(...xs)
		CODE
		assert_equal 60, out
	end

	def test_callsite_splat_works_in_a_constructor_call
		out = Code.interp <<~CODE
		    Point { x, y, Self ( x, y; self.x = x, self.y = y ) }
		    coords := [3, 4]
		    p := Point(...coords)
		    (p.x, p.y)
		CODE
		assert_equal [3, 4], out.values
	end

	def test_callsite_splat_of_a_non_array_raises
		error = assert_raises Code::Invalid_Callsite_Splat_Argument do
			Code.interp "sum ( a, b; a + b ), sum(...5)"
		end
		assert_match 'Integer', error.message
	end

	def test_callsite_splat_after_named_argument_raises
		assert_raises Code::Positional_Argument_After_Named do
			Code.interp "sum ( a, b, c; a + b + c ), sum(a := 1, ...[2, 3])"
		end
	end

	# --- Callsite splat of a Dictionary/Struct/plain Instance -- spreads by name -------------------

	def test_callsite_splat_of_a_dictionary_binds_by_name_not_position
		out = Code.interp <<~CODE
		    f ( a, b; a - b )
		    f(...{a: 10, b: 3})
		CODE
		assert_equal 7, out

		# Order inside the dictionary doesn't matter, unlike an Array splat -- each key names its own param.
		out = Code.interp <<~CODE
		    f ( a, b; a - b )
		    f(...{b: 3, a: 10})
		CODE
		assert_equal 7, out
	end

	def test_callsite_splat_of_a_struct_binds_by_name
		out = Code.interp <<~CODE
		    f ( a, b; a - b )
		    f(...<a := 10, b := 3>)
		CODE
		assert_equal 7, out
	end

	def test_callsite_splat_of_a_plain_instance_binds_by_declared_member_name
		out = Code.interp <<~CODE
		    Coords { a, b, Self ( a, b; self.a = a, self.b = b ) }
		    f ( a, b; a - b )
		    f(...Coords(10, 3))
		CODE
		assert_equal 7, out
	end

	def test_callsite_splat_of_a_plain_instance_spreads_every_declaration_including_methods
		# A plain Instance/Type splat has no way to tell a "data" member apart from a method one --
		# #plain_type_or_instance? spreads the whole `.declarations` hash as-is. A method member
		# becomes a named argument holding its own uncalled Code::Func, not whatever value calling it
		# would produce -- worth knowing before splatting an arbitrary instance: it's everything
		# declared on it, methods included, not just the fields that look like plain data.
		out = Code.interp <<~CODE
		    Coords { x, y, Self ( x, y; self.x = x, self.y = y ), magnitude (; (x * x + y * y) ) }
		    c := Coords(3, 4)
		    describe ( x, y, magnitude; (x, y, magnitude) )
		    describe(...c)
		CODE
		x, y, magnitude = out.values
		assert_equal [3, 4], [x, y]
		assert_instance_of Code::Func, magnitude
		assert_equal 'magnitude', magnitude.name.value
	end

	def test_callsite_splat_of_a_number_still_raises
		# A bare Number is a Code::Instance under the hood too (every language value is), but it has
		# its own dedicated proxy class -- #plain_type_or_instance? checks `instance_of?`, not `is_a?`,
		# specifically so this doesn't silently spread `{'value' => 42}` as a named argument.
		error = assert_raises Code::Invalid_Callsite_Splat_Argument do
			Code.interp "f ( a, b; a - b ), f(...42)"
		end
		assert_match 'Integer', error.message
	end

	def test_callsite_splat_of_a_dictionary_can_be_followed_by_more_named_arguments
		out = Code.interp <<~CODE
		    f ( a, b, c; "`a`-`b`-`c`" )
		    f(...{a: 1}, b := 2, c := 3)
		CODE
		assert_equal '1-2-3', out
	end

	def test_callsite_splat_of_a_dictionary_then_a_positional_argument_raises
		assert_raises Code::Positional_Argument_After_Named do
			Code.interp "f ( a, b, c; a ), f(...{a: 1}, 2)"
		end
	end

	def test_callsite_splat_of_a_dictionary_with_unknown_key_raises
		error = assert_raises Code::Unknown_Named_Argument do
			Code.interp "f ( a, b; a - b ), f(...{a: 1, z: 2})"
		end
		assert_match 'z', error.message
	end

	def test_callsite_splat_of_two_dictionaries_with_a_duplicate_key_raises
		assert_raises Code::Duplicate_Named_Argument do
			Code.interp "f ( a, b; a - b ), f(...{a: 1}, ...{a: 2, b: 3})"
		end
	end

	def test_compound_operator
		out = Code.interp 'add ( amount := 1, to := 0;
			to += amount
		)
		add(5, 37)'
		assert_equal 42, out
	end

	def test_long_dot_chain
		shared_code = '
		A {
			B {
				C {
					d := 4
				}
			}
		}'

		out = Code.interp "#{shared_code}
		A.B"
		assert_instance_of Code::Type, out

		out = Code.interp "#{shared_code}
		A.B.C()"
		assert_instance_of Code::Instance, out

		out = Code.interp "#{shared_code}
		A.B.C().d"
		assert_equal 4, out
	end

	def test_closures_do_capture_values
		out = Code.interp '
		counter := -1
		increment ( count;
			counter += count
		)
		increment(counter)
		counter
		'
		assert_equal -2, out
	end

	def test_calling_functions
		refute_raises RuntimeError do
			out = Code.interp '
			square ( input;
				input * input
			)

			result := square(5)
			result'
			assert_equal 25, out
		end
	end

	def test_function_call_as_argument
		out = Code.interp '
		add ( amount := 1, to := 4;
			to + amount
		)
		inc := add() # should return 5
		add(inc, 1)'
		assert_equal 6, out
	end

	def test_complex_return_with_simple_conditional
		out = Code.interp 'return (1+2*3/4) + (1+2*3/4) if 1 + 2 > 2'
		assert_equal 4, out.value
	end

	def test_truthy_falsy_logic
		assert_equal 1, Code.interp('if true 1 else 0 end')
		assert_equal 1, Code.interp('if 0 1 else 0 end') # truthiness follows Ruby's own rules -- only nil/false are falsy, 0 is truthy
		assert_equal 0, Code.interp('if nil 1 else 0 end')
	end

	def test_returns_with_end_of_line_conditional
		out = Code.interp 'return 3 if true'
		assert_equal 3, out.value
	end

	def test_standalone_array_index_expr
		out = Code.interp '4.8.15.16.23.42'
		assert_equal [4, 8, 15, 16, 23, 42], out.values
	end

	def test_array_access_by_dot_index
		out = Code.interp 'things := [4, 8, 15]
		things.0'
		assert_equal 4, out
	end

	def test_array_nested_non_array_dot_index
		assert_raises Code::Invalid_Dot_Infix_Left_Operand do
			Code.interp 'things := [4, 8, 15]
		things.0.1'
		end
	end

	def test_nested_array_access_by_dot_index
		out = Code.interp 'things := [4, [8, 15, 16], 23, [42, 108, 418, 3]]
		(things.1.0, things.3.1)'
		assert_instance_of Code::Tuple, out
		assert_equal 8, out.values.first
		assert_equal 108, out.values.last
	end

	def test_function_scope
		out = Code.interp 'x := 123
		double (; x * 2 )
		double()'
		assert_equal 246, out
	end

	def test_function_scope_some_more
		out = Code.interp 'x := 108

		Doubler {
			double (; x * 2 )
		}

		Doubler().double()'
		assert_equal 216, out
	end

	def test_returns
		out = Code.interp 'return 1'
		assert_instance_of Code::Return, out
		assert_equal 1, out.value

		out = Code.interp '
		eject (;
			if true
				return "true!"
			end

			return "should not get here"
		)
		eject()'
		assert_equal "true!", out
	end

	def test_type_does_have_self_function
		out = Code.interp '
		Atom {
			Self (;)
		}'
		assert out.has? :Self
	end

	def test_instance_does_not_have_self_function
		out = Code.interp '
		Atom {
			Self (;)
		}
		Atom()'
		refute out.has? :Self
	end

	def test_while_loops
		out = Code.interp '
		x := 0
		while x < 4
			x += 1
		end
		x'
		assert_equal 4, out
	end

	def test_fancy_while_loops
		out = Code.interp '
		x := 0
		y := 0
		z := 0
		while x < 4
			x += 1
		elwhile y > -8
			y -= 1
		else
			z = 1_516
		end
		(x, y, z)'
		assert_equal [4, -8, 1516], out.values
	end

	def test_until_loops
		out = Code.interp '
		x := 1
		until x >= 23
			x += 2
		end
		'
		assert_equal 23, out
	end

	def test_fancy_until_loops
		out = Code.interp '
		x := 1
		y := 0
		until x >= 23
			x += 2
		else
			y = x
		end
		(x, y)
		'
		assert_equal [23, 23], out.values
	end

	def test_control_flows_as_expressions
		out = Code.interp '
		condition := false
		x := unless condition # Equivalent to "if !condition"
			4
		else
			-4
		end
		'
		assert_equal 4, out
	end

	def test_if_and_unless_control_flows
		out = Code.interp '
		a := if true
			4
		end

		b := if false
			8
		end

		c := unless true
			15
		end

		d := if not true
			23
		else
			16
		end

		(a, b, c, d)
		'
		assert_equal [4, nil, nil, 16], out.values
	end

	def test_nil_instances_are_shared
		out = Code.interp '
		x,
		y,

		equal := x == y
		(x, y, equal)'
		assert_equal out.values[0].object_id, out.values[1].object_id
		assert_equal true, out.values[2]
	end

	def test_accessing_declarations_through_type_composition
		out = Code.interp "
		Vec2 {
			x := 0, y := 0

			Self ( x, y;
				self.x = x
				self.y = y
			)

			multiply! ( times;
				self.x *= times
				self.y *= times
			)

		}

		Transform | Vec2 {
			Self ( position := Vec2();
				self.x = position.x
				y = position.y
			)

			to_s (;
				'Transform(`x`,`y`)'
			)

			scale! ( value;
				multiply!(value)
			)
		}

		pos := Vec2(4, 8)
		t := Transform(pos)
		a := t.to_s()
		t.scale!(3)
		b := t.to_s()

		# Let's remove Vec2 from a type that composes with Transform
		Xform | Transform ~ Vec2 {}

		(a, b, t)"

		# Testing in order of the values in the tuple
		assert_equal "Transform(4,8)", out.values[0]
		assert_equal "Transform(12,24)", out.values[1]

		assert_instance_of Code::Instance, out.values[2]
		assert_equal 12, out.values[2][:x]
		assert_equal 24, out.values[2][:y]
	end

	def test_random_composition_example
		refute_raises Code::Undeclared_Identifier do
			out = Code.interp "
			Vec2 {
				x := 0, y := 0

				Self ( x, y;
					self.x = x
					self.y = y
				)
			}
			v := Vec2(4, 8)

			Transform | Vec2 {
				Self ( position := Vec2();
					self.x = position.x
					y = position.y
				)
			}
			t := Transform(Vec2(15, 16))

			Xform | Transform ~ Vec2 {
				# ~Vec2 removes x and y declarations, but retains Transform's Self(;) so unless you declare a new initializer here, you are still required to pass in position arg from Transform, which depends on x and y, which have been removed.
				Self ( p: Vec2; )
			}
			x := Xform(v)
			"
			assert_instance_of Code::Instance, out
			assert_equal Set['Xform', 'Transform'], out.types
		end
	end

	def test_union_composition
		refute_raises Code::Undeclared_Identifier do
			out = Code.interp '
			Aa {
				a := 1
			}
			Bb {
				a := 4, b := 2, unique := 10
			}

			Union | Aa | Bb {}

			u := Union()
			(u.a, u.b, u.unique)
			'
			assert_equal [1, 2, 10], out.values
		end
	end

	def test_difference_composition
		shared_code = "
			Aa {
				a := 8
				common := 15
			}

			Bb {
				b := 42
				common := 16
			}

			AaBb | Aa | Bb {}

			Diff | AaBb ~ Bb {
				common := 23
			}

			d := Diff()".freeze

		refute_raises Code::Undeclared_Identifier do
			out = Code.interp "#{shared_code}
			a := Aa()
			b := Bb()
			(d.a, a.common, b.common, d.common)"
			assert_equal [8, 15, 16, 23], out.values
		end

		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code}
			d.b"
		end
	end

	def test_intersection_composition
		shared_code = "
			Aa { a := 4,  common := 8 }
			Bb { b := 15, common := 16 }

			Intersected | Aa & Bb {}

			i := Intersected()"

		refute_raises Code::Undeclared_Identifier do
			out = Code.interp "#{shared_code}
			i.common"
			assert_equal 8, out
		end

		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code}
			i.a"
		end

		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code}
			i.b"
		end
	end

	def test_symmetric_difference_composition
		shared_code = "
			Aa { a := 4, common := 10 }
			Bb { b := 8, common := 10 }

			Sym_Diff | Aa ^ Bb {}
			s := Sym_Diff()\n"

		out = Code.interp "#{shared_code} (s.a, s.b)"
		assert_equal [4, 8], out.values

		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code} s.common"
		end
	end

	def test_union_composition_is_left_biased
		out = Code.interp "
		Aa { a := 4 }
		Bb { a := 8 }
		Union | Aa | Bb {}
		Union().a"
		assert_equal 4, out
	end

	def test_composition_with_inbody_declarations
		out = Code.interp "
		Aa { a := 15 }
		Bb { a := 16, b, }
		Union {
			# With or without space is valid
			| Aa
			|Bb
		}
		u := Union()
		(u.a, u.b)"
		assert_equal [15, nil], out.values
	end

	def test_routes
		out = Code.interp 'get://some/thing/:id ( id;
			do_something()
		)'

		assert_instance_of Code::Route, out
		assert_equal 'get', out.http_method.value
		assert_equal 'some/thing/:id', out.path
		assert_equal 1, out.handler.parameters.count
		assert_equal 1, out.handler.expressions.count
	end

	def test_html_element
		out = Code.interp "My_Div {
			element := 'div'

			id := 'my_div'
			class := 'my_class'
			data_something := 'some data attribute'

			render (;
				'Text content of this div'
			)
		}

		it := My_Div()
		(My_Div, it, it.render())"
		assert_instance_of Code::Type, out.values[0]
		assert_instance_of Code::Instance, out.values[1]
		assert_instance_of String, out.values[2]
		assert_equal 'Text content of this div', out.values[2]
	end

	def test_loading_external_source_files
		out = Code.interp "@load 'code/global.code'
		(Bool, Bool())"

		assert_instance_of Code::Type, out.values[0]
		assert_kind_of Code::Instance, out.values[1]
		assert_instance_of Code::Bool, out.values[1]
	end

	def test_standalone_load_into_current_scope
		out = Code.interp "@load 'tests/fixtures/test_module.code'
		(MODULE_NAME, MODULE_VALUE, module_func(10))"

		assert_instance_of Code::Tuple, out
		assert_equal "Test_Module", out.values[0]
		assert_equal 42, out.values[1]
		assert_equal 20, out.values[2]
	end

	def test_load_assignment_into_variable_identifier
		out = Code.interp "mod := @load 'tests/fixtures/test_module.code'
		(mod, mod.MODULE_NAME, mod.MODULE_VALUE, mod.module_func(10))"

		assert_instance_of Code::Tuple, out
		assert_instance_of Code::Scope, out.values[0]
		assert_equal "Test_Module", out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 20, out.values[3]

		# Verify declarations are NOT in current scope
		assert_raises Code::Undeclared_Identifier do
			Code.interp "mod := @load 'tests/fixtures/test_module.code'
			MODULE_NAME"
		end
	end

	def test_load_assignment_into_class_identifier
		out = Code.interp "Module := @load 'tests/fixtures/test_module.code'
		(Module, Module.MODULE_NAME, Module.MODULE_VALUE, Module.module_func(10))"

		assert_instance_of Code::Tuple, out
		assert_instance_of Code::Scope, out.values[0]
		assert_equal "Test_Module", out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 20, out.values[3]

		# Verify declarations are NOT in current scope
		assert_raises Code::Undeclared_Identifier do
			Code.interp "Module := @load 'tests/fixtures/test_module.code'
			MODULE_NAME"
		end
	end

	def test_load_assignment_into_constant_identifier
		out = Code.interp "MODULE := @load 'tests/fixtures/test_module.code'
		(MODULE, MODULE.MODULE_NAME, MODULE.MODULE_VALUE, MODULE.module_func(10))"

		assert_instance_of Code::Tuple, out
		assert_instance_of Code::Scope, out.values[0]
		assert_equal "Test_Module", out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 20, out.values[3]

		# Verify declarations are NOT in current scope
		assert_raises Code::Undeclared_Identifier do
			Code.interp "MODULE := @load 'tests/fixtures/test_module.code'
			MODULE_NAME"
		end
	end

	def test_load_same_file_into_multiple_scopes
		out = Code.interp "
		lib1 := @load 'tests/fixtures/test_module.code'
		lib2 := @load 'tests/fixtures/test_module.code'

		(lib1, lib2, lib1.MODULE_VALUE, lib2.MODULE_VALUE, lib1 != lib2)"

		assert_instance_of Code::Tuple, out
		assert_instance_of Code::Scope, out.values[0]
		assert_instance_of Code::Scope, out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 42, out.values[3]
		assert out.values[4]

		# Scopes are different objects even though loaded from same file
		refute_equal out.values[0].object_id, out.values[1].object_id
	end

	def test_double_loading_file
		assert_raises Code::Cannot_Reassign_Constant do
			out = Code.interp "
			@load 'tests/fixtures/constants.code'
			CODE = 123"
		end
	end

	def test_for_loop
		out = Code.interp "
		NUMBERS := [4, 8, 15, 16, 23, 42]
		numbers := []

		for NUMBERS
			numbers << it
		end

		(numbers == NUMBERS, numbers, NUMBERS)"
		assert out.values[0]
	end

	def test_for_loop_with_scopes
		out = Code.interp <<~CODE
		    Numbers {
		    	numbers := []

				Self ( numbers;
					self.numbers = numbers
				)

		    	multiply ( by;
					result := []
		    		for self.numbers
		    			result.push(it * by)
		    		end
		    		result
		    	)
		    }

		    Numbers([1, 2, 3]).multiply(2)
		CODE
		assert_equal [2, 4, 6], out.values
	end

	def test_for_loop_by_strides
		out = Code.interp "
		NUMBERS := [4, 8, 15, 16, 23, 42]
		numbers := []

		for NUMBERS by 2
			numbers << it
		end

		numbers"
		assert_equal [[4, 8], [15, 16], [23, 42]], out.values.map(&:values)
	end

	def test_for_loop_at_and_it_builtins
		out = Code.interp "
		indices := []

		for [4, 8, 15, 16, 23, 42]
			indices << '`at`: `it`'
		end

		indices"
		assert_equal ['0: 4', '1: 8', '2: 15', '3: 16', '4: 23', '5: 42'], out.values
	end

	def test_for_loop_with_ranges
		out = Code.interp "
		zero := []
		one := []
		two := []
		three := []

		for 1..5
			zero << it
		end

		for 1>..<5
			one << it
		end

		for 1>..5
			two << it
		end

		for 1..<5
			three << it
		end


		(zero, one, two, three)"
		assert_equal [1, 2, 3, 4, 5], out.values[0].values
		assert_equal [2, 3, 4], out.values[1].values
		assert_equal [2, 3, 4, 5], out.values[2].values
		assert_equal [1, 2, 3, 4], out.values[3].values
	end

	# `for <Integer>` -- sugar for `for 1..<Integer>`: N iterations, `it` running 1..N (same as
	# `at`, the positional index, running 0..N-1). Reuses the Range machinery verbatim (stride,
	# map/select/reject/count), so this exercises that it isn't its own special, narrower case.
	def test_for_loop_over_a_bare_integer
		out = Code.interp <<~CODE
		    collected := []
		    for 5
		        collected << it
		    end
		    collected
		CODE
		assert_equal [1, 2, 3, 4, 5], out.values
	end

	def test_for_loop_over_a_bare_integer_zero_iterates_zero_times
		out = Code.interp <<~CODE
		    count := 0
		    for 0
		        count += 1
		    end
		    count
		CODE
		assert_equal 0, out
	end

	def test_for_loop_over_a_bare_integer_supports_verbs_and_stride
		out = Code.interp <<~CODE
		    doubled := for 6 map by 2
		        (it.0, it.1)
		    end
		    doubled
		CODE
		assert_equal [[1, 2], [3, 4], [5, 6]], out.values.map(&:values)
	end

	def test_for_loop_skip
		out = Code.interp "
		result := []
		for [1, 2, 3, 4, 5]
			if it == 3
				skip
			end
			result << it
		end
		result"
		assert_equal [1, 2, 4, 5], out.values
	end

	def test_for_loop_stop
		out = Code.interp "
		result := []
		for [1, 2, 3, 4, 5]
			if it == 3
				stop
			end
			result << it
		end
		result"
		assert_equal [1, 2], out.values
	end

	def test_for_loop_skip_with_index
		out = Code.interp "
		result := []
		for ['a', 'b', 'c', 'd']
			if at == 1 or at == 2
				skip
			end
			result << it
		end
		result"
		assert_equal ['a', 'd'], out.values
	end

	def test_for_loop_stop_with_index
		out = Code.interp "
		result := []
		for ['a', 'b', 'c', 'd']
			if at == 2
				stop
			end
			result << it
		end
		result"
		assert_equal ['a', 'b'], out.values
	end

	def test_nested_for_loop_stop
		out = Code.interp "
		result := []

		for 0..10
			skip if it == 4

			if it % 2 == 0
				result << 'START `it`'
				for 0..10
					result << it
					stop if it == 2
				end
				result << 'STOP `it`'
			end

			if it == 6
				stop
			end
		end

		result
		"
		assert_equal ["START 0", 0, 1, 2, "STOP 0", "START 2", 0, 1, 2, "STOP 2", "START 6", 0, 1, 2, "STOP 6"], out.values
	end

	def test_for_loop_map
		out = Code.interp "
		for [1, 2, 3, 4, 5] map
			it * 2
		end"
		assert_equal [2, 4, 6, 8, 10], out.values
	end

	def test_for_loop_map_with_index
		out = Code.interp "
		for ['a', 'b', 'c'] map
			'`at`:`it`'
		end"
		assert_equal ['0:a', '1:b', '2:c'], out.values
	end

	def test_for_loop_map_with_stride
		out = Code.interp "
		for [1, 2, 3, 4, 5, 6] map by 2
			it.0 + it.1
		end"
		assert_equal [3, 7, 11], out.values
	end

	def test_for_loop_select
		out = Code.interp "
		for [1, 2, 3, 4, 5, 6] select
			it % 2 == 0
		end"
		assert_equal [2, 4, 6], out.values
	end

	def test_for_loop_select_with_index
		out = Code.interp "
		for ['a', 'b', 'c', 'd', 'e'] select
			at < 3
		end"
		assert_equal ['a', 'b', 'c'], out.values
	end

	def test_for_loop_select_with_stride
		out = Code.interp "
		for [1, 2, 3, 4, 5, 6, 7, 8] select by 2
			it.0 + it.1 > 5
		end"
		assert_equal [[3, 4], [5, 6], [7, 8]], out.values.map(&:values)
	end

	def test_for_loop_reject
		out = Code.interp "
		for [1, 2, 3, 4, 5, 6] reject
			it % 2 == 0
		end"
		assert_equal [1, 3, 5], out.values
	end

	def test_for_loop_reject_with_index
		out = Code.interp "
		for ['a', 'b', 'c', 'd', 'e'] reject
			at < 2
		end"
		assert_equal ['c', 'd', 'e'], out.values
	end

	def test_for_loop_reject_with_stride
		out = Code.interp "
		for [1, 2, 3, 4, 5, 6, 7, 8] reject by 2
			it.0 + it.1 > 5
		end"
		assert_equal [[1, 2]], out.values.map(&:values)
	end

	def test_for_loop_count
		out = Code.interp "
		for [1, 2, 3, 4, 5, 6] count
			it % 2 == 0
		end"
		assert_equal 3, out
	end

	def test_for_loop_count_with_index
		out = Code.interp "
		for ['a', 'b', 'c', 'd', 'e'] count
			at >= 2
		end"
		assert_equal 3, out
	end

	def test_for_loop_count_with_stride
		out = Code.interp "
		for [1, 2, 3, 4, 5, 6, 7, 8] count by 2
			it.0 + it.1 > 5
		end"
		assert_equal 3, out
	end

	def test_for_loop_by_stride_with_overlap
		# `by 2,1` walks every consecutive pair -- stride 2, sliding forward by (stride - overlap) = 1
		# each step, instead of jumping a full 2 like plain `by 2` would.
		out = Code.interp "
		for [1, 2, 3, 4, 5, 6] map by 2,1
			if it.?1 # I'm guarding here because it would raise on not being able to add integer and nil
				it.0 + it.?1
			else
				it.0
			end
		end"
		assert_equal [3, 5, 7, 9, 11, 6], out.values
	end

	def test_for_loop_by_stride_with_overlap_wider_window
		# `by 3,1` walks 3-wide windows, each sharing its last element with the next window's first --
		# a step of (3 - 1) = 2.
		out = Code.interp "
		for [1, 2, 3, 4, 5, 6, 7] map by 3,1
			(it.0, it.?1, it.?2)
		end"
		assert_equal [[1, 2, 3], [3, 4, 5], [5, 6, 7],  [7, nil, nil]], out.values.map(&:values)
	end

	def test_for_loop_overlap_drops_a_trailing_short_window
		# Unlike the plain (no-overlap) stride chunking, which keeps a final undersized chunk
		# (`each_slice`'s own behavior), an overlapping window that can't reach the full stride is
		# dropped instead of kept short -- there's no well-formed final pair to make from a single
		# leftover `5` here.
		out = Code.interp "
		for [1, 2, 3, 4, 5] map by 2,1
			(it.0, it.?1)
		end"
		assert_equal [[1, 2], [2, 3], [3, 4], [4, 5], [5, nil]], out.values.map(&:values)
	end

	def test_for_loop_overlap_works_with_select_reject_and_count
		select_out = Code.interp "
		for [1, 2, 3, 4, 5, 6] select by 2,1
			if it.?1
				it.0 + it.1 > 5
			else
				it.0 > 5
			end
		end"
		assert_equal [[3, 4], [4, 5], [5, 6], [6]], select_out.values.map(&:values)

		reject_out = Code.interp "
		for [1, 2, 3, 4, 5, 6] reject by 2,1
			if it.?1
				it.0 + it.1 > 5
			else
				it.0 > 5
			end
		end"
		assert_equal [[1, 2], [2, 3]], reject_out.values.map(&:values)

		count_out = Code.interp "
		for [1, 2, 3, 4, 5, 6] count by 2,1
			if it.?1
				it.0 + it.1 > 5
			else
				it.0 > 5
			end
		end"
		assert_equal 4, count_out
	end

	def test_for_loop_by_stride_with_odd_overlap
		# stride 5, overlap 3 -> step = 2. The last two starting positions (index 6 and index 8)
		# can't fill a full 5-wide window from a 9-element array, so both get dropped -- the same
		# "drop an incomplete trailing window" rule as the even-overlap tests above, just exercised
		# with more than one dropped window this time.
		out = Code.interp "
		for [1, 2, 3, 4, 5, 6, 7, 8, 9] map by 5,3
			it
		end"
		assert_equal [[1, 2, 3, 4, 5], [3, 4, 5, 6, 7], [5, 6, 7, 8, 9], [7, 8, 9], [9]], out.values.map(&:values)
	end

	def test_for_loop_stride_and_overlap_from_variables
		# `by` and its overlap both go through #begin_expression, same as any other value there --
		# no reason they'd have to be number literals.
		out = Code.interp "
		stride := 2
		overlap := 1
		for [1, 2, 3, 4, 5, 6] map by stride,overlap
			(it.0, it.?1)
		end"
		assert_equal [[1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, nil]], out.values.map(&:values)
	end

	def test_for_loop_overlap_must_be_smaller_than_stride
		assert_raises RuntimeError do
			Code.interp "
			for [1, 2, 3] map by 2,2
				it
			end"
		end
	end

	def test_for_loop_overlap_must_be_an_integer
		assert_raises RuntimeError do
			Code.interp "
			for [1, 2, 3] map by 2,'x'
				it
			end"
		end
	end

	def test_for_loop_map_with_skip
		out = Code.interp "
		for [1, 2, 3, 4, 5] map
			skip if it == 3
			it * 2
		end"
		assert_equal [2, 4, nil, 8, 10], out.values
	end

	def test_for_loop_map_with_stop
		out = Code.interp "
		for [1, 2, 3, 4, 5] map
			stop if it == 4
			it * 2
		end"
		assert_equal [2, 4, 6], out.values
	end

	def test_for_loop_verbs_do_not_mutate
		out = Code.interp "
		original := [1, 2, 3, 4, 5]
		doubled := for original map
			it * 2
		end
		original"
		assert_equal [1, 2, 3, 4, 5], out.values
	end

	def test_while_loop_skip
		out = Code.interp "
		result := []
		x := 0
		while x < 5
			x += 1
			if x == 3
				skip
			end
			result << x
		end
		result"
		assert_equal [1, 2, 4, 5], out.values
	end

	def test_while_loop_stop
		out = Code.interp "
		result := []
		x := 0
		while x < 10
			x += 1
			if x == 4
				stop
			end
			result << x
		end
		result"
		assert_equal [1, 2, 3], out.values
	end

	def test_until_loop_skip
		out = Code.interp "
		result := []
		x := 0
		until x >= 5
			x += 1
			if x == 2 or x == 4
				skip
			end
			result << x
		end
		result"
		assert_equal [1, 3, 5], out.values
	end

	def test_until_loop_stop
		out = Code.interp "
		result := []
		x := 0
		until x >= 10
			x += 1
			if x == 3
				stop
			end
			result << x
		end
		result"
		assert_equal [1, 2], out.values
	end

	def test_readable_unpack_parameter
		out = Code.interp "
		Vector {
			x := 0
			y := 0

			Self ( x, y;
				self.x = x
				self.y = y
			)
		}

		add ( @splatr vec;
			x + y
		)

		v := Vector(3, 4)
		add(v)"
		assert_equal 7, out
	end

	def test_readable_unpack_with_identifier
		out = Code.interp "
		Point {
			a := 0
			b := 0


			Self ( a, b;
				self.a = a
				self.b = b
			)
		}

		calc (;
			p := Point(10, 20)
			@splatr p
			a + b
		)

		calc()"
		assert_equal 30, out
	end

	def test_readable_unpack_with_local_declarations
		out = Code.interp "
		Point {
			a := 0
			b := 0

			Self ( a, b;
				self.a = a
				self.b = b
			)
		}

		p := Point(4, 8)
		@splatr p
		one := a + b
		@unsplat p

		@splatr Point(15, 16)
		(one, a + b)"
		assert_equal [12, 31], out.values
	end

	def test_unpack_and_nested_functions
		out = Code.interp "
		Point {
			a := 0
			b := 0

			Self ( a, b;
				self.a = a
				self.b = b
			)
		}

		outer (;
			p := Point(23, 42)
			@splatr p

			inner (;
				a + b
			)

			inner()
		)
		outer()"
		assert_equal 65, out
	end

	def test_readable_unpack_write_shadows_local_and_leaves_source_untouched
		# `x = 999` is allowed (finds x via the readable fallback), but Scope#[]= never routes through readable_scopes, so it lands as a fresh local instead, leaving vec untouched.
		out = Code.interp "
		Vector {
			x := 0
			Self ( x; self.x = x )
		}

		add ( @splatr vec;
			x = 999
			x
		)

		v := Vector(3)
		local_result := add(v)
		(local_result, v.x)"
		assert_equal [999, 3], out.values
	end

	def test_privacy_and_binding
		shared_code = <<~CODE
		    Type {
				# Instance declarations
		    	number := 4
		    	_private := 8

				# Static declarations
				Self.nilled,
		    	Self.static := 15
		    	Self._static_private := 16

				calling_private_through_instance (; _private )
		    	calling_static_through_instance (; static )
		    	calling_static_private_through_instance (; _static_private )

		    	Self.calling_static_through_static (; static )
		    	Self.calling_static_private_through_static (; _static_private )
		    }
		CODE

		out = Code.interp "#{shared_code}
		Type().number"
		assert_equal 4, out

		out = Code.interp "#{shared_code}
		Type().calling_private_through_instance()"
		assert_equal 8, out

		out = Code.interp "#{shared_code}
		Type().static"
		assert_equal 15, out

		out = Code.interp "#{shared_code}
		Type().calling_static_through_instance()"
		assert_equal 15, out

		out = Code.interp "#{shared_code}
		Type().calling_static_private_through_instance()"
		assert_equal 16, out

		out = Code.interp "#{shared_code}
		Type.calling_static_through_static()"
		assert_equal 15, out

		out = Code.interp "#{shared_code}
		Type.calling_static_private_through_static()"
		assert_equal 16, out

		assert_raises Code::Cannot_Call_Private_Instance_Member do
			Code.interp "#{shared_code}
			Type()._private"
		end

		assert_raises Code::Cannot_Call_Private_Instance_Member do
			Code.interp "#{shared_code}
			Type()._static_private"
		end

		assert_raises Code::Cannot_Call_Private_Static_Member_On_Type do
			Code.interp "#{shared_code}
			Type._static_private"
		end

		assert_raises Code::Cannot_Call_Private_Instance_Member do
			Code.interp "
			Inner { _secret := 42 }
		    Outer { inner := Inner() }
            Outer().inner._secret"
		end

		out = Code.interp "#{shared_code}
		Type.static = 4815
		Type.static"
		assert_equal 4815, out

		out = Code.interp "#{shared_code}
		Type.nilled"
		assert_nil out

		assert_raises Code::Cannot_Call_Private_Instance_Member do
			Code.interp "#{shared_code}
			Type()._private = 100"
		end

		assert_raises Code::Cannot_Call_Private_Static_Member_On_Type do
			Code.interp "#{shared_code}
		    Type._static_private = 100"
		end

		assert_raises Code::Cannot_Call_Instance_Member_On_Type do
			Code.interp "#{shared_code}
			Type.number"
		end

		assert_raises Code::Cannot_Use_Type_Scope_Operator_Outside_Type do
			Code.interp "Self.whatever"
		end
	end

	def test_proxy_string_members
		out = Code.interp "String().length"
		assert_equal 0, out

		out = Code.interp "'hello'.length"
		assert_equal 5, out

		out = Code.interp "'a'.ord"
		assert_equal 97, out

		out = Code.interp "'A'.ord"
		assert_equal 65, out

		out = Code.interp "'walt!'.upcase()"
		assert_equal "WALT!", out

		out = Code.interp "'WALT!'.downcase()"
		assert_equal "walt!", out

		assert_raises Code::Invalid_Ruby_Proxy_Usage do
			Code.interp "@ruby whatever"
		end

		assert_raises Code::Invalid_Ruby_Proxy_Usage do
			Code.interp "@ruby 123"
		end

		assert_raises Code::Invalid_Ruby_Proxy_Usage do
			Code.interp "Type { @ruby 123, }"
		end
	end

	def test_binding_and_privacy_with_composition
		shared_code = <<~CODE
		    Base {
		    	base_instance_public := 1
		    	_base_instance_private := 2

		    	Self.base_static_public := 10
		    	Self._base_static_private := 20
		    }

		    Other {
		    	other_instance := 3
		    	_other_private := 4

		    	Self.other_static_public := 30
		    	Self._other_static_private := 40
		    }
		CODE

		# Union composition - should merge all members
		out = Code.interp "#{shared_code}
		Merged | Base | Other {}
		m := Merged()
		(m.base_instance_public, m.other_instance)"
		assert_equal [1, 3], out.values

		# Static members accessible from union
		out = Code.interp "#{shared_code}
		Merged | Base | Other {}
		Merged.base_static_public"
		assert_equal 10, out

		out = Code.interp "#{shared_code}
		Merged | Base | Other {}
		Merged.other_static_public"
		assert_equal 30, out

		# Instance can access static from union
		out = Code.interp "#{shared_code}
		Merged | Base | Other {}
		Merged().base_static_public"
		assert_equal 10, out

		# Privacy preserved through union
		assert_raises Code::Cannot_Call_Private_Instance_Member do
			Code.interp "#{shared_code}
			Merged | Base | Other {}
			Merged()._base_instance_private"
		end

		assert_raises Code::Cannot_Call_Private_Instance_Member do
			Code.interp "#{shared_code}
			Merged | Base | Other {}
			Merged()._other_private"
		end

		assert_raises Code::Cannot_Call_Private_Static_Member_On_Type do
			Code.interp "#{shared_code}
			Merged | Base | Other {}
			Merged._base_static_private"
		end

		# Binding preserved - cannot access instance members on Type
		assert_raises Code::Cannot_Call_Instance_Member_On_Type do
			Code.interp "#{shared_code}
			Merged | Base | Other {}
			Merged.base_instance_public"
		end

		assert_raises Code::Cannot_Call_Instance_Member_On_Type do
			Code.interp "#{shared_code}
			Merged | Base | Other {}
			Merged.other_instance"
		end

		# Difference composition - static members removed correctly
		out = Code.interp "#{shared_code}
		Diff | Base ~ Other {}
		Diff().base_instance_public"
		assert_equal 1, out

		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code}
			Diff | Base ~ Other {}
			Diff().other_instance"
		end

		# Static members also removed
		out = Code.interp "#{shared_code}
		Diff | Base ~ Other {}
		Diff.base_static_public"
		assert_equal 10, out

		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code}
			Diff | Base ~ Other {}
			Diff.other_static_public"
		end

		# Privacy maintained after difference
		assert_raises Code::Cannot_Call_Private_Instance_Member do
			Code.interp "#{shared_code}
			Diff | Base ~ Other {}
			Diff()._base_instance_private"
		end

		# Intersection composition - keeps only shared members
		shared_code = <<~CODE
		    Left {
		    	shared_instance := 1
		    	_shared_private := 2
		    	left_only := 3

		    	Self.shared_static := 10
		    	Self._shared_static_private := 20
		    	Self.left_static_only := 30
		    }

		    Right {
		    	shared_instance := 4
		    	_shared_private := 5
		    	right_only := 6

		    	Self.shared_static := 40
		    	Self._shared_static_private := 50
		    	Self.right_static_only := 60
		    }
		CODE

		# Intersection keeps shared instance members
		out = Code.interp "#{shared_code}
		Inter | Left & Right {}
		Inter().shared_instance"
		assert_equal 1, out

		# Intersection removes non-shared instance members
		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code}
			Inter | Left & Right {}
			Inter().left_only"
		end

		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code}
			Inter | Left & Right {}
			Inter().right_only"
		end

		# Intersection keeps shared static members
		out = Code.interp "#{shared_code}
		Inter | Left & Right {}
		Inter.shared_static"
		assert_equal 10, out

		# Intersection removes non-shared static members
		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code}
			Inter | Left & Right {}
			Inter.left_static_only"
		end

		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code}
			Inter | Left & Right {}
			Inter.right_static_only"
		end

		# Privacy preserved through intersection
		assert_raises Code::Cannot_Call_Private_Instance_Member do
			Code.interp "#{shared_code}
			Inter | Left & Right {}
			Inter()._shared_private"
		end

		assert_raises Code::Cannot_Call_Private_Static_Member_On_Type do
			Code.interp "#{shared_code}
			Inter | Left & Right {}
			Inter._shared_static_private"
		end

		# Binding preserved through intersection
		assert_raises Code::Cannot_Call_Instance_Member_On_Type do
			Code.interp "#{shared_code}
			Inter | Left & Right {}
			Inter.shared_instance"
		end

		# Symmetric difference composition - keeps only non-shared members
		# Symmetric diff keeps unique instance members from Left
		out = Code.interp "#{shared_code}
		Sym | Left ^ Right {}
		Sym().left_only"
		assert_equal 3, out

		# Symmetric diff keeps unique instance members from Right
		out = Code.interp "#{shared_code}
		Sym | Left ^ Right {}
		Sym().right_only"
		assert_equal 6, out

		# Symmetric diff removes shared instance members
		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code}
			Sym | Left ^ Right {}
			Sym().shared_instance"
		end

		# Symmetric diff keeps unique static members from Left
		out = Code.interp "#{shared_code}
		Sym | Left ^ Right {}
		Sym.left_static_only"
		assert_equal 30, out

		# Symmetric diff keeps unique static members from Right
		out = Code.interp "#{shared_code}
		Sym | Left ^ Right {}
		Sym.right_static_only"
		assert_equal 60, out

		# Symmetric diff removes shared static members
		assert_raises Code::Undeclared_Identifier do
			Code.interp "#{shared_code}
			Sym | Left ^ Right {}
			Sym.shared_static"
		end

		# Binding preserved through symmetric difference
		assert_raises Code::Cannot_Call_Instance_Member_On_Type do
			Code.interp "#{shared_code}
			Sym | Left ^ Right {}
			Sym.left_only"
		end
	end

	def test_static_declarations_fixture
		out = Code.interp_file 'tests/fixtures/static_declarations.code'
		assert_equal true, out
	end

	def capture_stdout
		out, $stdout = $stdout, StringIO.new
		yield
		$stdout.string
	ensure
		$stdout = out
	end

	def test_puts_directive
		printed = nil
		result  = nil
		printed = capture_stdout { result = Code.interp "@puts 'Walt!'" }
		assert_equal 'Walt!', result
		assert_equal "'Walt!'\n", printed # strings always display single-quoted
	end

	# `@puts` is a Context method now (backend/context.code) -- multiple args, parens optional, and
	# it can be captured / aliased.
	def test_puts_takes_multiple_args_and_returns_them
		printed = nil
		result  = nil
		printed = capture_stdout { result = Code.interp '@puts 1, 2, 3' }
		assert_equal "1\n2\n3\n", printed
		assert_equal [1, 2, 3], result.values

		capture_stdout { result = Code.interp('@puts(7)') } # explicit parens, single arg -> passthrough
		assert_equal 7, result
	end

	def test_puts_can_be_captured_and_wrapped
		printed = capture_stdout do
			out = Code.interp <<~CODE
			    shout ( x; @puts(x.upcase()) )
			    shout('hey')
			CODE
			assert_equal 'HEY', out
		end
		assert_equal "'HEY'\n", printed
	end

	def test_puts_is_a_passthrough_inline
		result = nil
		capture_stdout { result = Code.interp("double ( n; n * 2 )\ndouble(@puts 21)") }
		assert_equal 42, result
	end

	# `@root_path` is a no-arg Context property (moved from a directive).
	def test_root_is_the_project_path
		assert_equal Code::ROOT_PATH, Code.interp('@root_path')
		assert_equal Code::ROOT_PATH, Code.interp('@.root_path')
		assert_equal "at #{Code::ROOT_PATH}", Code.interp('"at `@root_path`"')
	end

	# `@` resolves to a Context -- reflective vitals computed on demand, the functions (`to_s`/`puts`/..)
	# as shared callable stand-ins.
	def test_context_resolves_to_a_context
		assert_kind_of Code::Context, Code.interp('@')
		assert_equal '@Global', Code.interp('@.to_s()')
		assert_equal 'Point', Code.interp("Point { x, }\nPoint.@name")
		assert_equal '@Point', Code.interp("Point { x, }\nPoint().@to_s()")
		# a function member is callable; a vital resolves to its value
		capture_stdout { assert_equal 'hi', Code.interp("shout := @puts\nshout('hi')") }
	end

	# `@` alone (and a bare `@` reached off a receiver) carries the `Context` type identity.
	def test_bare_context_has_type_identity
		assert_equal true, Code.interp('@ === Context')
		assert_equal true, Code.interp("D { n := 1 }\nD.@ === Context")
	end

	# `@foo` is exactly `@.foo` -- the prefix form and the dotted form reach the same member.
	def test_at_word_and_at_dot_word_are_the_same
		assert_equal true, Code.interp("@name == @.name")
		assert_equal Code::ROOT_PATH, Code.interp('@root_path')
		assert_equal Code::ROOT_PATH, Code.interp('@.root_path')
	end

	# A function stand-in captured deep in a call still works when invoked from anywhere else.
	def test_a_context_function_can_be_captured_out_of_its_scope
		out = capture_stdout do
			assert_equal 'deep', Code.interp(<<~CODE)
			    grab (; @puts )
			    p := grab()
			    p('deep')
			CODE
		end
		assert_equal "'deep'\n", out
	end

	# A vital is computed against whatever scope the `@` is reached from -- two instances give two ids.
	def test_a_vital_is_per_subject
		assert_equal true, Code.interp("Two { x, }\nTwo().@object_id != Two().@object_id")
	end

	# `@.type` / `@.types` work on any value, not just a Type/Instance (plain `.type`/`.types` stays
	# user-space). Falls out of #context_for working on any Scope + #maybe_instance wrapping every value.
	def test_context_type_reads_on_a_plain_value
		assert_equal 'Array', Code.interp('[1, 2, 3].@type')
		assert_equal 'Integer', Code.interp('4.@type')
		assert_equal 'String', Code.interp('"hi".@type')
		assert_equal 'Range', Code.interp('(1..5).@type')
		assert_equal 'Nil', Code.interp('nil.@type') # #maybe_instance's nil now goes through #adopt_type
		assert Code.interp("4.@types.include?('Number')")
	end

	# `@sleep n` is a Context method; passes through to Ruby's sleep (returns seconds slept).
	def test_sleep_intrinsic
		assert_equal 0, Code.interp('@sleep 0.00001')
		assert_equal 0, Code.interp('nap := @sleep, nap(0.00001)')
	end

	def test_assert_and_refute_intrinsics
		assert_equal true, Code.interp('@assert 1 == 1')
		assert_equal false, Code.interp('@refute 1 == 2')

		err = assert_raises(Code::Assert_Triggered) { Code.interp "@assert 1 == 2, 'nope'" }
		assert_equal 'nope', err.assertion_message

		assert_raises(Code::Refute_Triggered) { Code.interp '@refute true' }

		# a parenthesized condition followed by more of the expression, then the message
		refute_raises { Code.interp "@assert (1 == 1) == true, 'grouped condition'" }
	end

	# ### user-declarable `@` members on a Type ###

	def test_context_member_declared_on_a_type_is_readable
		out = Code.interp <<~CODE
		    Thing {
		    	@label: String = "widget"
		    	@meta := 42
		    }
		    (Thing.@label, Thing.@meta)
		CODE
		assert_equal ['widget', 42], out.values
	end

	def test_context_member_is_visible_through_an_instance
		out = Code.interp <<~CODE
		    Thing { @label: String = "widget" }
		    Thing().@label
		CODE
		assert_equal 'widget', out
	end

	def test_context_annotation_without_a_value_is_nil
		assert_nil Code.interp("Thing { @rank: Number }\nThing.@rank")
	end

	def test_context_member_is_readable_bare_inside_the_type_body
		out = Code.interp <<~CODE
		    Thing {
		    	@label := "w"
		    	describe (; @label )
		    }
		    Thing().describe()
		CODE
		assert_equal 'w', out
	end

	def test_context_member_can_be_overwritten_but_must_already_exist
		out = Code.interp <<~CODE
		    Thing { @label: String = "widget" }
		    Thing.@label = "gadget"
		    Thing.@label
		CODE
		assert_equal 'gadget', out

		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp "Thing { @a := 1 }\nThing.@b = 2"
		end
	end

	def test_context_declaration_outside_a_type_raises
		assert_raises Code::Context_Declaration_Outside_Type do
			Code.interp '@x := 1'
		end
	end

	def test_context_declaration_cannot_shadow_a_builtin_member
		assert_raises Code::Cannot_Override_Context_Member do
			Code.interp 'Thing { @name := "x" }'
		end
		assert_raises Code::Cannot_Override_Context_Member do
			Code.interp 'Thing { @types := "x" }'
		end
	end

	def test_context_member_does_not_leak_into_plain_dot_access
		assert_raises Code::Undeclared_Identifier do
			Code.interp "Thing { @label := \"w\" }\nThing.label"
		end
	end

	# A user `@x` member is stored on the declaring Type's `at_members` Hash, not its `@declarations`
	# (so it can never collide with a plain member) -- and `at_members` stays nil for a type with none.
	def test_context_member_is_stored_on_at_members
		i = Code::Interpreter.new
		i.run "Plain { x := 1 }\nTagged { @meta := 9 }"

		assert_nil i.global['Plain'].at_members
		assert_equal({ 'meta' => 9 }, i.global['Tagged'].at_members)
		refute i.global['Tagged'].declarations.key?('meta')
	end

	def test_multiple_unpacks
		shared_code = <<~CODE
		    Point {
		    	a := 0
		    	b := 0

		    	Self ( a, b;
		    		self.a = a
		    		self.b = b
		    	)
		    }
		CODE

		out = Code.interp "#{shared_code}
		p := Point(4, 8)
		@splatr p
		(a, b)"
		assert_equal [4, 8], out.values

		# note: Unpacks function like a stack, the most recent unpack is the one whose identifier takes precedence.
		out = Code.interp "#{shared_code}
		p := Point(4, 8)
		p2 := Point(15, 16)
		@splatr p
		@splatr p2
		(a, b)"
		assert_equal [15, 16], out.values

		out = Code.interp "#{shared_code}
		p := Point(4, 8)
		p2 := Point(15, 16)
		@splatr p
		@unsplat p2
		(a, b)"
		assert_equal [4, 8], out.values
	end

	def test_using_pound_proxy_as_expression
		code = <<~CODE
		    String | String {
		        upcase (;
		        	@ruby + " (SWIZZLED)"
		        )
		    }
			"test".upcase()
		CODE
		assert_equal "TEST (SWIZZLED)", Code.interp(code)
	end

	def test_reading_files
		out = Code.interp "File.read_file_to_string('tests/fixtures/hello_read.txt')"
		assert_equal "Hello, Read!\n", out.value # note: There is a newline at the end of the file, so it has to be included here
	end

	def test_html_fence_with_interpolation
		out = Code.interp "
		name := 'Cooper'
		```html
		<h1>Welcome `name`</h1>
		```"
		assert_instance_of ::String, out
		assert_equal '<h1>Welcome Cooper</h1>', out.strip
	end

	def test_html_fence_without_interpolation
		out = Code.interp '```html
		<p>Plain text</p>
		```'
		assert out.include?('<p>Plain text</p>')
	end

	def test_html_fence_in_route_handler
		out = Code.interp "
		@load 'code/server.code'

		App | Server {
			get:// home (;
				title := 'My Page'
				```html
				<h1>`title`</h1>
				```
			)
		}

		app := App()
		app.home()"
		assert out.include?('<h1>My Page</h1>')
	end

	def test_html_fence_multiline_with_interpolation
		out = Code.interp "
		name := 'Alice'
		count := 42
		```html
		<div>
			<h1>Hello `name`</h1>
			<p>You have `count` messages</p>
		</div>
		```"
		assert out.include?('Hello Alice')
		assert out.include?('You have 42 messages')
	end

	# note: The idea is, given (abc,1)
	# if abc exists, use that value
	# if not abc exists, declare abc=nil
	def test_walrus_basic_assignment
		assert_equal 4, Code.interp('x := 4, x')
		assert_equal 'hello', Code.interp('x := "hello", x')
	end

	def test_walrus_reinitializes_type
		assert_equal 'hello', Code.interp('x := 4, x := "hello", x')
	end

	def test_walrus_same_type_reassign_with_equals
		assert_equal 8, Code.interp('x := 4, x = 8, x')
	end

	def test_walrus_type_contract_violation
		assert_raises Code::Type_Contract_Violation do
			Code.interp 'x := 4, x = "hello"'
		end
	end

	def test_walrus_contract_violation_message
		err = assert_raises Code::Type_Contract_Violation do
			Code.interp 'x := 4, x = "hello"'
		end
		assert_match 'Number', err.message
		assert_match 'String', err.message
	end

	def test_manual_type_annotation_contract
		err = assert_raises Code::Type_Contract_Violation do
			Code.interp 'x: Number = 4, x = "hey"'
		end
		assert_match 'Number', err.message
		assert_match 'String', err.message

		# Fine if redeclared
		Code.interp 'x: Number = 4, x := "hey"'

		err = assert_raises Code::Type_Contract_Violation do
			Code.interp 'x: Number = 4, x := "hey", x = 8'
		end
		assert_match 'Number', err.message # the actual value 8 -- reported as the family name
		assert_match 'String', err.message
	end

	# `x: A | B` union annotations -- a composition chain in the annotation position (`Int | Nil`)
	# used to mis-parse the *whole* `x: Int` expression as the left operand of `|`, crashing.
	# Satisfying any *one* alternative is enough (OR), unlike composition's usual is-both merge --
	# nothing can literally be both an Int and a String at once.
	def test_union_type_annotation_accepts_either_alternative
		assert_equal 1, Code.interp('x: Int | Nil = 1, x')
		assert_nil Code.interp('x: Int | Nil = nil, x')
	end

	def test_union_type_annotation_rejects_value_satisfying_neither_alternative
		err = assert_raises Code::Type_Contract_Violation do
			Code.interp 'x: Int | String = true'
		end
		assert_match 'Int | String', err.message
		assert_match 'Bool', err.message
	end

	def test_union_type_annotation_reassignment_is_also_checked
		assert_raises Code::Type_Contract_Violation do
			Code.interp 'x: Int | String = 1, x = true'
		end
		# Either alternative is still fine on reassignment, once the union is locked in.
		assert_equal 'hi', Code.interp('x: Int | String = 1, x = "hi", x')
	end

	def test_union_return_type_accepts_either_alternative
		src = <<~CODE
		    f ( n := nil -> Int | Nil;
		    	return n
		    )
		    (f(4), f())
		CODE
		out = Code.interp src
		assert_equal [4, nil], out.values
	end

	def test_union_return_type_rejects_value_satisfying_neither_alternative
		err = assert_raises Code::Type_Contract_Violation do
			Code.interp "f (-> Int | Nil; 'oops' ), f()"
		end
		assert_match 'Int | Nil', err.message
		assert_match 'String', err.message
	end

	def test_union_type_annotation_in_destructuring_target
		out = Code.interp '(x: Int | Nil, y) := (1, 2), (x, y)'
		assert_equal [1, 2], out.values

		out = Code.interp '(a: Int | Nil, b) := (nil, 5), (a, b)'
		assert_equal [nil, 5], out.values
	end

	# Regression: `x: Int | Nil = 42` used to crash with a raw Ruby RuntimeError
	# (Helpers#type_of_identifier: unknown identifier type nil) rather than working or raising a
	# proper Code error -- `| Nil` was silently mis-parsed as composing the whole `x: Int`
	# expression instead of continuing the annotation.
	def test_union_type_annotation_does_not_crash_regression
		assert_equal 42, Code.interp('x: Int | Nil = 42, x')
	end

	# The four tests above only ever spell the annotation with `|`. In annotation position, though,
	# `#annotation_type_names` walks a composition chain's operand names regardless of which operator
	# joins them -- `&`/`^`/`~` are accepted by the parser here too, and every one of them means the
	# exact same OR-alternative check `|` does (see the comment on #annotation_type_names/
	# #type_contract_satisfied? in interpreter.rb). An annotation only ever *lists* alternative type
	# names; it never actually composes two types together the way `#interp_composition` does for a
	# real `Type | Other {}` declaration, so the operator's usual meaning (union/intersection/
	# difference/symmetric-difference of *declarations*) simply doesn't apply here.
	def test_non_union_composition_operators_in_annotation_position_mean_the_same_or_check
		%w(& ^ ~).each do |op|
			assert_equal 1, Code.interp("x: Int #{op} Nil = 1, x")
			assert_nil Code.interp("x: Int #{op} Nil = nil, x")

			err = assert_raises Code::Type_Contract_Violation do
				Code.interp "x: Int #{op} String = true"
			end
			# The error message always renders with ` | ` too, whatever operator was actually written.
			assert_match 'Int | String', err.message
			assert_match 'Bool', err.message
		end
	end

	def test_non_union_composition_operators_in_annotation_reassignment
		%w(& ^ ~).each do |op|
			assert_raises Code::Type_Contract_Violation do
				Code.interp "x: Int #{op} String = 1, x = true"
			end
			assert_equal 'hi', Code.interp("x: Int #{op} String = 1, x = \"hi\", x")
		end
	end

	def test_non_union_composition_operators_in_return_type_annotation
		%w(& ^ ~).each do |op|
			out = Code.interp <<~CODE
			    f ( n := nil -> Int #{op} Nil;
			    	return n
			    )
			    (f(4), f())
			CODE
			assert_equal [4, nil], out.values

			err = assert_raises Code::Type_Contract_Violation do
				Code.interp "f (-> Int #{op} Nil; 'oops' ), f()"
			end
			assert_match 'Int | Nil', err.message
			assert_match 'String', err.message
		end
	end

	def test_non_union_composition_operators_in_destructuring_target
		%w(& ^ ~).each do |op|
			out = Code.interp "(x: Int #{op} Nil, y) := (1, 2), (x, y)"
			assert_equal [1, 2], out.values

			out = Code.interp "(a: Int #{op} Nil, b) := (nil, 5), (a, b)"
			assert_equal [nil, 5], out.values
		end
	end

	# Pre-declaring the union as a real type and annotating with its name does NOT reproduce the OR
	# check above. `x: Int | Nil` special-cases a chain written directly in the annotation (split into
	# alternatives, accept any one). A single name has no chain to split, so that never fires -- instead
	# it's an ordinary is-a check: the value must have EVERYTHING the named type composes. Int_Or_Nil
	# composes Int_Or_Nil + Int + Nil all at once, which no real value satisfies except `nil` itself
	# (exempt from every contract) or an actual Int_Or_Nil() instance.
	def test_named_union_type_does_not_behave_like_an_inline_union_annotation
		err = assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    Int_Or_Nil | Int | Nil {}
			    n := 4
			    x: Int_Or_Nil = n
			CODE
		end
		assert_match 'Int_Or_Nil', err.message
		assert_match 'Number', err.message

		out = Code.interp <<~CODE
		    Int_Or_Nil | Int | Nil {}
		    m := nil
		    x: Int_Or_Nil = m
		    x
		CODE
		assert_nil out

		out = Code.interp <<~CODE
		    Int_Or_Nil | Int | Nil {}
		    v := Int_Or_Nil()
		    x: Int_Or_Nil = v
		    x =>= Int_Or_Nil
		CODE
		assert_equal true, out
	end

	# Same failure via `:=` instead of a named declaration -- `Int_Or_Nil := Int | Nil` just aliases
	# Int_Or_Nil to the anonymous type `Int | Nil` builds (see Alias vs. subtype), with the exact same
	# composed set {Integer, Number, Nil} (minus its own name, since an anonymous composition has none
	# to add). One name at the annotation site either way, so the same is-a/superset check applies and
	# fails the same way.
	def test_walrus_aliased_union_type_does_not_behave_like_an_inline_union_annotation
		err = assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    Int_Or_Nil := Int | Nil
			    n := 4
			    x: Int_Or_Nil = n
			CODE
		end
		assert_match 'Int_Or_Nil', err.message
		assert_match 'Number', err.message

		out = Code.interp <<~CODE
		    Int_Or_Nil := Int | Nil
		    m := nil
		    x: Int_Or_Nil = m
		    x
		CODE
		assert_nil out
	end

	# `x: Number = 'oops'` (a literal RHS) is caught statically before the interpreter ever runs (see type_checker_test.rb) -- these cover the gap that leaves open: a *non-literal* RHS (an identifier, a function, ..) whose actual value mismatches the annotation on the very first, self-declaring assignment. The static checker silently skips non-literal RHS entirely, so this has to be caught dynamically in #interp_infix_assignment, the same place reassignment already is.
	def test_first_assignment_type_contract_with_non_literal_rhs
		# Plain nominal annotation.
		err = assert_raises Code::Type_Contract_Violation do
			Code.interp 'bad := "oops"
				x: Number = bad'
		end
		assert_match 'Number', err.message
		assert_match 'String', err.message

		# Signature-typed annotation, assigning a real function whose actual shape doesn't match.
		err = assert_raises Code::Type_Contract_Violation do
			Code.interp 'wrong ( a, b; a + b )
				x: (Number -> String;) = wrong'
		end
		assert_match '(Number -> String;)', err.message

		# Inline signature form (no separate alias), same check.
		assert_raises Code::Type_Contract_Violation do
			Code.interp 'wrong ( a, b; a + b )
				x: (Number -> String;) = wrong'
		end

		# Same check applies to a typed member declared inside a Type/Instance body, not just top level.
		assert_raises Code::Type_Contract_Violation do
			Code.interp 'bad := "oops"
				Thing {
					x: Number = bad
				}
				Thing()'
		end

		# And inside a constructor, self-declaring from a param.
		assert_raises Code::Type_Contract_Violation do
			Code.interp 'Thing {
					Self ( v;
						x: Number = v
					)
				}
				Thing("oops")'
		end
	end

	def test_new_comma_nil_init
		assert_raises(Code::Undeclared_Identifier) do
			Code.interp <<~CODE
			    x := (abc,1)
				(x, abc)
			CODE
		end

		out = Code.interp <<~CODE
		    abc := 2, (abc,1),
		CODE
		assert_equal [2, 1], out.values
	end

	def test_neat_usage_of_operator_overloads
		prelude = <<~CODE
		    Clock {
		    	hour, minute, second,
		    	period, # am/pm
		    }

		    @operator : @infix 700 ( hour, minute;
		    	time := Clock()
		    	time.hour = hour
		    	time.minute = minute
		    	time
		    )

		    @operator pm @postfix 600 ( left: Clock;
		        left.period = 'pm'
		        left
		    )
		CODE

		out = Code.interp <<~CODE
		    #{prelude}
			# You can now make `11:22pm` evaluate to something!
			11:22pm
		CODE
		assert_instance_of Code::Instance, out
		assert_equal 11, out.get('hour')
		assert_equal 22, out.get('minute')
		assert_equal 'pm', out.get('period')
	end

	def test_prefix_operator_overload
		out = Code.interp <<~CODE
		    Currency {
		    	amount,
		    	name,
		    	code,
		    }

		    @operator $ @prefix 900 ( amount;
		    	c := Currency()
		    	c.amount = amount
		    	c.name = 'US Dollar'
		    	c.code = 'USD'
		    	c
		    )

		    $42
		CODE
		assert_instance_of Code::Instance, out
		assert_equal 42, out.get('amount')
		assert_equal 'US Dollar', out.get('name')
		assert_equal 'USD', out.get('code')
	end

	def test_operator_overload_scoped_to_function
		out = Code.interp <<~CODE
		    scoped_result := compute (;
		    	@operator + @infix 700 ( left, right;
		    		left * right
		    	)
		    	3 + 4
		    )

		    normal_result := 3 + 4

		    [scoped_result(), normal_result]
		CODE

		assert_equal [12, 7], out.values
	end

	def test_whacky_prefix_operator_overload
		out = Code.interp <<~CODE
		    @operator !! @prefix 900 ( n;
		    	n * n
		    )

		    !!5
		CODE
		assert_equal 25, out
	end

	def test_pipeing_with_operator_overloads
		out = Code.interp <<~CODE
		    @operator -> @infix 300 ( left, right;
		    	right(left)
		    )

		    double ( n;
				n * 2
			)

		    add_fifteen ( n;
				n + 15
			)

		    4 -> double -> add_fifteen
		CODE
		assert_equal 23, out
	end

	# #interp_string's own interpolation-region regex used `.` with no /m flag, so a sub-expression
	# containing a real embedded newline (a nested `"\n"` escape, e.g. `` `arr.join("\n")` ``) couldn't
	# be matched end to end -- `.*?` can't cross a newline without /m -- so the scan silently found no
	# match and the whole `` `...` `` region was left as literal, un-interpolated text in the output.
	def test_string_interpolation_handles_a_sub_expression_containing_a_real_newline
		out = Code.interp '
		arr := ["a", "b"]
		"X:\n`arr.join(\"\n\")`:Y"'
		assert_equal "X:\na\nb:Y", out
	end

	def test_string_interpolation_can_see_custom_operators_declared_elsewhere_in_the_program
		# Same operators/functions as the test above, interpolated instead -- used to only evaluate to "4" (stopped at the first token it didn't recognize), since interp_string re-parsed the substring in total isolation from the rest of the program's @operator registrations.
		out = Code.interp <<~CODE
		    @operator -> @infix 300 ( left, right;
		    	right(left)
		    )

		    double ( n;
		    	n * 2
		    )

		    add_fifteen ( n;
		    	n + 15
		    )

		    "`4 -> double -> add_fifteen`"
		CODE
		assert_equal '23', out
	end

	def test_dictionary_in_for_loops
		out = Code.interp <<~CODE
		    dict := {
		    	x = 4,
		    	y = 8
		    }

		    collection := []
		    for dict
		    	collection << (at, it) # at is the string key, it is the vlaue
		    end

		    collection
		CODE
		assert_equal 2, out.values.count
		assert_equal [Code::Tuple.new([:x, 4]), Code::Tuple.new([:y, 8])], out.values
	end

	def test_dictionary_in_for_loops_key_and_value_builtins
		out = Code.interp <<~CODE
		    dict := {
		    	x = 4,
		    	y = 8
		    }

		    collection := []
		    for dict
		    	collection << (key, value)
		    end

		    collection
		CODE
		assert_equal 2, out.values.count
		assert_equal [Code::Tuple.new([:x, 4]), Code::Tuple.new([:y, 8])], out.values
	end

	def test_dictionary_in_for_loops_stride_is_ignored
		out = Code.interp <<~CODE
		    dict := {
		    	a = 15,
		    	b = 16,
				c = 23
		    }

		    collection := []
		    for dict by 2
		    	collection << (at, it) # at is the string key, it is the vlaue
		    end

		    collection
		CODE
		assert_equal 3, out.values.count
		assert_equal [Code::Tuple.new([:a, 15]), Code::Tuple.new([:b, 16]), Code::Tuple.new([:c, 23])], out.values
	end

	def test_type_comparison_operators
		shared = <<~CODE
		    Base {}
		CODE
		out = Code.interp <<~CODE
			#{shared}
		    Left | Base {}
		    Right | Base {}
			l := Left()
			r := Right()
			(Left === Right, Left === Left, l === r, l === l)
		CODE
		assert_equal [false, true, false, true], out.values

		out = Code.interp <<~CODE
			#{shared}
		    Left | Base {}
		    Right | Base {}
			l := Left()
			r := Right()
			(Left =!= Right, Right =!= Right, l =!= r, r =!= r)
		CODE
		assert_equal [true, false, true, false], out.values

		# Siblings that only share a common composed base (Base) are NOT comparable via =/= -- neither one's types are a subset of theother's, even though they overlap. This is what distinguishes =/= from a plain "do these share any composed type" check.
		out = Code.interp <<~CODE
			#{shared}
		    Left | Base {}
		    Right | Base {}
			l := Left()
			r := Right()
			(Left =>= Right, Right =>= Left, l =>= r, r =>= l)
		CODE
		assert_equal [false, false, false, false], out.values

		out = Code.interp <<~CODE
			#{shared}
		    Left | Base {}
		    Right | Base {}
			l := Left()
			r := Right()
			(Left =<= Right, Right =<= Left, l =<= r, r =<= l)
		CODE
		assert_equal [false, false, false, false], out.values

		# `A =>= B` is true when A's composed types are a superset of B's -- i.e. A composes with at least everything B does. Left composes Base, so Left has "at least" Base, but not the other way around.
		out = Code.interp <<~CODE
			#{shared}
		    Left | Base {}
			l := Left()
			n := Base()
			(Left =>= Base, Base =>= Left, Left =>= Left, l =>= n, n =>= l)
		CODE
		assert_equal [true, false, true, true, false], out.values

		# =<= mirrors =>= with the operands' roles reversed.
		out = Code.interp <<~CODE
			#{shared}
		    Left | Base {}
			l := Left()
			n := Base()
			(Base =<= Left, Left =<= Base, Left =<= Left, n =<= l, l =<= n)
		CODE
		assert_equal [true, false, true, true, false], out.values

		# `A =/= B` is true when A and B share no composed types at all. A/B share nothing. Left/Right both compose Base, so they're not disjoint even though neither composes the other. Left/Base aren't disjoint either, since Left composes Base directly.
		out = Code.interp <<~CODE
			#{shared}
		    Aa {}
		    Bb {}
		    Left | Base {}
		    Right | Base {}
			a := Aa()
			b := Bb()
			l := Left()
			r := Right()
			(Aa =/= Bb, Aa =/= Aa, Left =/= Right, Left =/= Base, a =/= b, l =/= r, l =/= Base)
		CODE
		assert_equal [true, false, false, false, true, false, false], out.values
	end

	# `#interp_composition` (interpreter.rb) only ever touches a type's own *composed-type identity set*
	# (`.types` -- what `===`/`=>=`/etc. above all compare) in the `|` and `~` branches: `|` unions the
	# whole operand's composed set in, `~` deletes just the operand's own literal name back out. `&` and
	# `^` merge/keep *declarations* (composition_test.rb covers that thoroughly) but never write to
	# `.types` at all -- not even for the operand whose unique members `^` just copied in. So a type
	# built via `&`/`^` can genuinely have another type's members without that other type ever being
	# `=>=` true for it.
	def test_intersection_and_symmetric_difference_do_not_extend_composed_type_identity
		out = Code.interp <<~CODE
		    Aa {}
		    Bb {}
		    Sym | Aa ^ Bb {}
		    (Sym =>= Aa, Sym =>= Bb)
		CODE
		assert_equal [true, false], out.values

		out = Code.interp <<~CODE
		    Aa { a := 1 }
		    Bb { a := 2, b := 3 }
		    Inter | Aa & Bb {}
		    (Inter =>= Aa, Inter =>= Bb)
		CODE
		assert_equal [true, false], out.values
	end

	# `~`'s own bookkeeping is narrower than it looks: it deletes only the *operand's own written name*
	# from `.types`, never that operand's whole composed set. So removing a type that itself got composed
	# in secondhand (through another type) leaves whatever *that* other type had already contributed
	# behind -- here, `Table` reaches `Task` only via `Other`, and survives `~ Other` untouched.
	def test_difference_removes_only_the_operands_own_name_not_its_whole_composed_set
		out = Code.interp <<~CODE
		    Table {}
		    Other | Table {}
		    Task | Other ~ Other {}
		    (Task =>= Table, Task =>= Other)
		CODE
		assert_equal [true, false], out.values
	end

	# `Any` (backend/global.code) is a universal wildcard for `==` -- everything except nil counts as
	# Any, with no composition required (`Thing | Any {}` isn't needed).
	def test_any_type_is_universally_equal_via_double_equals
		out = Code.interp <<~CODE
		    Thing { x := 1 }
		    t := Thing()
		    (String == Any, Any == String, Number == Any, Thing == Any, t == Any, Any == t, 4 == Any, 'hi' == Any)
		CODE
		assert_equal [true, true, true, true, true, true, true, true], out.values
	end

	# `===` deliberately does NOT wildcard Any -- it's exact composed-type-SET equality, used
	# throughout as a structural type-dispatch check (`node === Element`); if Any wildcarded it too,
	# a bare Any value would satisfy every such dispatch check instead of just its own, misrouting it
	# into whatever branch happened to run first. `Any === Any` still holds (identical sets), but Any
	# against any *other* type is false in both directions -- neither composes the other.
	def test_any_type_is_not_exactly_equal_to_other_types_via_triple_equals
		out = Code.interp <<~CODE
		    Thing { x := 1 }
		    t := Thing()
		    (String === Any, Any === String, t === Any, Any === t)
		CODE
		assert_equal [false, false, false, false], out.values

		assert_equal true, Code.interp('Any === Any')
	end

	# nil is the one thing that doesn't count as Any -- "if you're not nil, you're Any at the very least" stops short of nil itself.
	def test_nil_is_not_any
		out = Code.interp '(nil == Any, Any == nil, nil === Any, Any === nil)'
		assert_equal [false, false, false, false], out.values
	end

	# != / =!= are the natural negation, kept consistent with == / === above rather than falling through to identity-based comparison.
	# `"Flying" == Flying` -- a String equals a bare Type (either operand order) when it spells the
	# type's own name. `==`/`!=` only. This is what makes `set.include?(SomeType)` work against a Set
	# that stores only type-name strings (`@.composed_types`).
	def test_string_equals_a_bare_type_by_name
		out = Code.interp <<~CODE
		    Flying { airborne := true }
		    ('Flying' == Flying, Flying == 'Flying', 'Swimming' == Flying, 'Flying' != Flying)
		CODE
		assert_equal [true, true, false, false], out.values

		# an instance is not a bare type -- ordinary comparison applies
		assert_equal false, Code.interp("Flying { x, }\n'Flying' == Flying()")

		# the point of it: include? against a Set / Array of type names
		out = Code.interp <<~CODE
		    Flying { airborne := true }
		    Swimming { submerged := true }
		    Duck | Flying { name := 'duck' }
		    (Duck.@composed_types.include?(Flying), Duck.@composed_types.include?(Swimming))
		CODE
		assert_equal [true, false], out.values
	end

	# `!=` mirrors `==`'s wildcard (stays false -- String IS "equal-ish" to Any either way). `=!=`
	# mirrors `===`'s deliberate lack of one (see test_any_type_is_not_exactly_equal_to_other_types_via_triple_equals)
	# -- true, since String and Any are genuinely different composed-type sets.
	def test_any_type_negated_comparisons_stay_consistent
		out = Code.interp '(String != Any, Any != String, String =!= Any, Any =!= String)'
		assert_equal [false, false, true, true], out.values

		out = Code.interp '(nil != Any, Any != nil, nil =!= Any, Any =!= nil)'
		assert_equal [true, true, true, true], out.values
	end

	# `===` is documented as "mutual `=>=`" -- Any wouldn't actually be a universal supertype if `X === Any` were true while `X =>= Any` stayed false, so `=>=`/`=<=`/`=/=` get the same wildcard treatment as `==`/`===` above, not just the two operators the feature originally shipped with.
	def test_any_type_is_universal_via_superset_and_disjoint_operators
		out = Code.interp '(String =>= Any, Any =>= String, String =<= Any, Any =<= String)'
		assert_equal [true, true, true, true], out.values

		# Any is never disjoint from anything non-nil -- the same "you're Any at the very least" rule.
		out = Code.interp '(String =/= Any, Any =/= String)'
		assert_equal [false, false], out.values

		# nil stays the one exception here too: not a superset relationship, and disjoint (shares nothing).
		out = Code.interp '(nil =>= Any, Any =>= nil, nil =<= Any, Any =<= nil, nil =/= Any, Any =/= nil)'
		assert_equal [false, false, false, false, true, true], out.values
	end

	def test_regex_match_operators
		# =~ behaves like Ruby's String#=~: returns the match index, or nil.
		assert_equal 5, Code.interp("'hello123' =~ '\\d+'")
		assert_nil Code.interp("'hello' =~ '\\d+'")

		# !~ is the boolean negation of a match.
		assert_equal false, Code.interp("'hello123' !~ '\\d+'")
		assert_equal true, Code.interp("'hello' !~ '\\d+'")

		# Works through variables too, not just literals.
		out = Code.interp <<~CODE
		    x := 'foo_bar'
		    x =~ '_'
		CODE
		assert_equal 3, out

		out = Code.interp <<~CODE
		    x := 'foobar'
		    x !~ '_'
		CODE
		assert_equal true, out
	end

	def test_function_signatures
		out = Code.interp 'Num_To_Str := (Number -> String;)'
		assert_kind_of Code::Func_Signature, out
		assert_equal ['Number'], out.param_types
		assert_equal 'String', out.return_type

		# Named + typed param — the name is discarded, only the type survives.
		out = Code.interp '(a: Number -> String;)'
		assert_equal ['Number'], out.param_types
		assert_equal 'String', out.return_type

		# Zero-arg signature.
		out = Code.interp '(-> String;)'
		assert_equal [], out.param_types
		assert_equal 'String', out.return_type

		# Bare and named+typed params can mix in the same param list.
		out = Code.interp '(Number, a: Number -> String;)'
		assert_equal %w(Number Number), out.param_types
		assert_equal 'String', out.return_type

		# A named param with no type annotation is no longer rejected -- its own name stands in for a
		# type (Interpreter#describe_param_type), so `f (a, b; ...)` and `f (b, c; ...)` read as
		# distinct signatures instead of both being unrepresentable.
		out = Code.interp '(a -> String;)'
		assert_equal ['a'], out.param_types
		assert_equal 'String', out.return_type

		# Bare as a top-level expression, not just as the RHS of :=.
		out = Code.interp '(Number -> String;)'
		assert_kind_of Code::Func_Signature, out

		# `name: (..)` with no return type is still a signature (the colon form opts in) -- a bare
		# `foo (;)` without the colon stays a real empty function.
		out = Code.interp 'takes_a_number: (Number;)'
		assert_kind_of Code::Func_Signature, out
		assert_equal ['Number'], out.param_types
		assert_nil out.return_type

		assert_kind_of Code::Func_Signature, Code.interp('does_nothing: (;)')
		assert_kind_of Code::Func, Code.interp('empty (;)') # no colon -> a real function, not a signature

		# Regression: an ordinary Type declaration with a method must still parse as a real type — now unambiguous, since a signature literal never starts with a Capitalized type name anymore.
		out = Code.interp <<~CODE
		    Person {
		    	greet (; "hi" )
		    }
		    Person().greet()
		CODE
		assert_equal 'hi', out
	end

	# An untyped param in a signature falls back to its own declared name -- lets two same-arity,
	# differently-named declarations of the same func name (`f (a, b; ...)` / `f (b, c; ...)`) read as
	# distinct shapes instead of both collapsing to a blank, unrepresentable `(,;)`.
	def test_untyped_signature_param_falls_back_to_its_own_name
		out = Code.interp 'func (a,b -> Int;)'
		assert_kind_of Code::Func_Signature, out
		assert_equal %w(a b), out.param_types
		assert_equal 'Int', out.return_type
		assert_equal '(a, b -> Int;)', out.to_s

		# Typed and untyped params can mix in the same signature -- only the untyped slot falls back.
		out = Code.interp 'func (a, b, c: String -> Int;)'
		assert_equal %w(a b String), out.param_types
	end

	# Regression: a signature-literal param slot that's itself a nested, unnamed signature (`(Any,
	# (Any,Any;) -> Any;)`) used to silently vanish from `param_types`/`#to_s` -- `param.type&.value`
	# is nil for a func-shaped param type, not a plain type name, so the nested shape was dropped
	# entirely instead of rendered back out.
	def test_nested_signature_param_type_is_not_dropped
		out = Code.interp 'watch: (Any, (Any,Any;) -> Any;)'
		assert_kind_of Code::Func_Signature, out
		assert_equal 2, out.param_types.length
		assert_equal 'Any', out.param_types.first
		assert_kind_of Code::Func_Signature, out.param_types[1]
		assert_equal %w(Any Any), out.param_types[1].param_types
		assert_equal '(Any, (Any, Any;) -> Any;)', out.to_s
	end

	def test_function_return_type_enforcement
		# Declared return type matches what's actually returned.
		out = Code.interp <<~CODE
		    identity ( a: Number -> Number; a )
		    identity(5)
		CODE
		assert_equal 5, out

		# Return types are not validated until the functino is called, so this will not raise a contra t violation
		refute_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    identity ( a: Number -> String; 'not a number' )
			CODE
		end

		# Declared return type doesn't match the actual value.
		error = assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    identity ( a: Number -> Number; 'not a number' )
			    identity(5)
			CODE
		end
		assert_equal 'Number', error.contract
		assert_equal 'String', error.actual

		# A signature has no implementation, so it can't be called.
		assert_raises Code::Cannot_Call_Func_Signature do
			Code.interp <<~CODE
			    double: (Number -> Number;)
			    double()
			CODE
		end

		refute_raises Code::Cannot_Call_Func_Signature do
			Code.interp <<~CODE
			    double: (Number -> Number;) = (a: Number -> Number; a*2)
			    double(2)
			CODE
		end

		# No declared return type — nothing is checked, any value is fine.
		out = Code.interp <<~CODE
		    identity ( a; 'anything' )
		    identity(5)
		CODE
		assert_equal 'anything', out

		# Signature-only declarations have no body, so there's nothing to enforce against — declaring one must not raise.
		out = Code.interp <<~CODE
		    double: (Number -> Number;)
		    'ok'
		CODE
		assert_equal 'ok', out

		# A function (anonymous or named) can declare its own return type inline, at the end of its param list, instead of via the `name: Type { }` prefix.
		out = Code.interp <<~CODE
		    f := ( a: Number -> Number; a * 2 )
		    f(21)
		CODE
		assert_equal 42, out

		out = Code.interp <<~CODE
		    example ( a: Number -> Number; a * 2 )
		    example(21)
		CODE
		assert_equal 42, out

		error = assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    f := ( a: Number -> Number; 'oops' )
			    f(1)
			CODE
		end
		assert_equal 'Number', error.contract
		assert_equal 'String', error.actual
	end

	# The return-type check used to compare only the value's own primary type name, not its full composed-type set -- a value composed with (not literally named) the declared return type was wrongly rejected as a mismatch, even though returning it is exactly the safe, covariant case (every Task IS a Table).
	def test_function_return_type_enforcement_accepts_composed_types
		out = Code.interp <<~CODE
		    Table {}
		    Task | Table {}
		    make ( -> Table; Task() )
		    make().@composed_types
		CODE
		assert_equal %w(Task Table), out.set.to_a

		error = assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    Table {}
			    Unrelated {}
			    make ( -> Table; Unrelated() )
			    make()
			CODE
		end
		assert_equal 'Table', error.contract
		assert_equal 'Unrelated', error.actual
	end

	def test_function_signature_matching
		# A function whose actual shape matches the signature succeeds, both on first declaration and on reassignment.
		out = Code.interp <<~CODE
		    Num_to_str := (Number -> String;)
		    stringify ( n: Number -> String; 'x' )
		    to_string: Num_to_str = stringify
		    another ( n: Number -> String; 'y' )
		    to_string = another
		    'ok'
		CODE
		assert_equal 'ok', out

		# First declaration with a mismatched shape raises immediately.
		error = assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    Num_to_str := (Number -> String;)
			    to_string: Num_to_str = ( x, y; x + y )
			CODE
		end
		assert_equal '(Number -> String;)', error.contract
		assert_equal '(x, y;)', error.actual

		# Reassigning an already-valid signature-typed identifier to a mismatched shape raises too, comparing structurally rather than as a plain type name.
		error = assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    Num_to_str := (Number -> String;)
			    stringify ( n: Number -> String; 'x' )
			    to_string: Num_to_str = stringify
			    to_string = ( x, y; x + y )
			CODE
		end
		assert_equal '(Number -> String;)', error.contract
		assert_equal '(x, y;)', error.actual

		# Ordinary nominal type annotations are unaffected by signature resolution.
		out = Code.interp <<~CODE
		    x: Number = 4
		    x = 8
		    x
		CODE
		assert_equal 8, out

		assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    x: Number = 4
			    x = 'oops'
			CODE
		end

		# First declaration of an ordinary nominal type is now checked too, even
		# with a non-literal RHS the static checker can't see.
		assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    n := 4
			    x: String = n
			CODE
		end
	end

	def test_tuple_and_struct_destructuring
		# Tuple source.
		out = Code.interp <<~CODE
		    (a, b) := (1, 2)
		    a + b
		CODE
		assert_equal 3, out

		# Struct source.
		out = Code.interp <<~CODE
		    (a, b) := <1, 2>
		    a + b
		CODE
		assert_equal 3, out

		# Both targets are declared in the current scope, independently readable afterward.
		out = Code.interp <<~CODE
		    (a, b) := <Number,Number>(10, 20)
		    (a, b)
		CODE
		assert_equal [10, 20], out.values

		# An explicit `: Type` per target is checked against that position's extracted value.
		out = Code.interp <<~CODE
		    (x: Number, y) := (1, 2)
		    x
		CODE
		assert_equal 1, out

		error = assert_raises Code::Type_Contract_Violation do
			Code.interp '(x: String, y) := (1, 2)'
		end
		assert_equal 'String', error.contract
		assert_equal 'Number', error.actual

		# Asking for more values than the source has raises, rather than padding with nil.
		error = assert_raises Code::Destructuring_Arity_Mismatch do
			Code.interp '(a, b, c) := <Number, Number>(1, 2)'
		end
		assert_equal 3, error.expected
		assert_equal 2, error.actual

		# Asking for fewer is fine -- the rest are just discarded.
		out = Code.interp '(a, b) := <1, 2, 3>
			a + b'
		assert_equal 3, out

		# Only a Tuple/Struct can be destructured.
		assert_raises Code::Invalid_Destructuring_Source do
			Code.interp '(a, b) := 5'
		end

		# Every target must be a plain identifier or an existing-member dot-target.
		assert_raises Code::Invalid_Destructuring_Target do
			Code.interp '(1, c) := (1, 2)'
		end

		out = Code.interp 'a := 0
			(a, b) := (1, 2)
			(a,b)'
		assert_equal [1, 2], out.values
	end

	def test_member_destructuring_targets
		# `thing.member` reassigns an existing member, same as plain `thing.member = value`.
		out = Code.interp <<~CODE
		    Thing { member, Self (; self.member = 0 ) }
		    thing := Thing()
		    (thing.member, local) := <Number, Number>(1, 1)
		    (thing.member, local)
		CODE
		assert_equal [1, 1], out.values

		# The member must already exist -- destructuring can't silently create one.
		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp <<~CODE
			    Thing { member, Self (; self.member = 0 ) }
			    thing := Thing()
			    (thing.missing, local) := <Number, Number>(1, 1)
			CODE
		end

		# A constant member can't be reassigned this way either.
		assert_raises Code::Cannot_Reassign_Constant do
			Code.interp <<~CODE
			    Thing { MEMBER, Self (; self.MEMBER = 0 ) }
			    thing := Thing()
			    (thing.MEMBER, local) := <Number, Number>(1, 1)
			CODE
		end

		# If the member has a previously-recorded type (via `:=`), the extracted value must match it.
		error = assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    Thing {
					member,
					Self (;
						self.member := 0
					)
				}
			    thing := Thing()
			    (thing.member, local) := <String, Number>("oops", 1)
			CODE
		end
		assert_equal 'Number', error.contract
		assert_equal 'String', error.actual
	end

	# String values always display single-quoted (String#to_string), regardless of the source literal.
	def test_struct_member_display_regression
		%w(" ').each do |q|
			out = Code.interp <<~CODE
			    @load 'code/struct.code'
			    quad := <1, id := 2, ix: Number, String>(4, 8, 1, #{q}five#{q})
			    quad.to_s()
			CODE
			assert_equal "<4, id: Number = 8, ix: Number = 1, 'five'>", out
		end
	end

	def test_string_equality_regression
		assert Code.interp('String("Alice") == String("Alice")')
		out = Code.interp <<~CODE
		    @load 'code/struct.code'
		    s := <name: String>("Alice")
		    s.@members.0.value == "Alice"
		CODE
		assert out
	end

	# `!=` derives from a declared `==` (see the `!=` note two entries up) -- backend/string.code's own `==` overload used to assume its right operand was always another String and crashed reading `.value` off anything else. `!= nil` is the common case this broke (a String compared against something that turned out not to exist).
	def test_string_not_equal_to_nil_regression
		refute_raises do
			assert Code.interp("String('hi') != nil")
			refute Code.interp("String('hi') == nil")
			refute Code.interp("String('hi') == 5")
		end
	end

	# Same class of bug in backend/member.code/backend/struct.code's own `==` overloads -- each assumed its right operand was already Member/Struct-shaped.
	def test_member_and_struct_not_equal_to_nil_regression
		refute_raises do
			out = Code.interp <<~CODE
			    @load 'code/struct.code'
			    m := Member('x', String, 4)
			    s := <1, 2>
			    (m != nil, m == nil, s != nil, s == nil)
			CODE
			assert_equal [true, false, true, false], out.values
		end
	end

	def test_self_declaration_no_longer_works_anywhere_regression
		# `self.member := value` used to self-declare a brand-new member for the whole window a
		# constructor was running (`#still_under_construction?`'s old `instance.has?('Self')`
		# check) -- that's gone now. `self`/`Self` never get to self-declare a new member, not even
		# from inside `Self(;)` itself; the member has to already exist in the type's own body.
		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp <<~CODE
			    Thing {
			        Self (;
			            self.member := 123
			        )
			    }
			    t := Thing()
			    t.member
			CODE
		end

		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp <<~CODE
			    Thing {
			        not_new_func (;
			            self.member := 123
			        )
			    }
			    t := Thing()
			    t.not_new_func()
			CODE
		end

		# Pre-declared in the body -- `self.member := ...` from inside `Self(;)` now just writes
		# to (re-infers the type of) an already-existing member, same as any other method would.
		out = Code.interp <<~CODE
		    Thing {
		        member,
		        Self (;
		            self.member := 123
		        )
		    }
		    t := Thing()
		    t.member
		CODE
		assert_equal 123, out

		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp 'Number.yolo = 123'
		end

		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp 'Number.yolo := 123'
		end

		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp <<~CODE
			    Thing { member, Self (; self.member = 0 ) }
			    thing := Thing()
			    thing.missing = 5
			CODE
		end
	end

	def test_declare_command_on_structs
		assert_raises Code::Undeclared_Identifier do
			Code.interp <<~CODE
			    # @declare <id: Number, name: String = "Locke">
				(it, name)
			CODE
		end

		out = Code.interp <<~CODE
		    @declare <id: Number, name: String = "Locke">
			(id, name)
		CODE
		assert_equal [nil, "Locke"], out.values
	end

	def test_declare_name_only_self_declares_to_nil
		out = Code.interp <<~CODE
		    @declare "foo"
		    foo
		CODE
		assert_nil out
	end

	def test_declare_name_and_value
		out = Code.interp <<~CODE
		    @declare "foo", 42
		    foo
		CODE
		assert_equal 42, out
	end

	def test_declare_name_value_and_type
		out = Code.interp <<~CODE
		    @declare "foo", 42, Number
		    foo
		CODE
		assert_equal 42, out
	end

	def test_declare_value_can_be_any_expression
		out = Code.interp <<~CODE
		    @declare "foo", 1 + 2
		    foo
		CODE
		assert_equal 3, out
	end

	def test_declare_with_no_value_argument_still_registers_the_name
		# Undeclared before, so a plain (non-annotated) read would normally raise --
		# @declare "foo" alone should self-declare it, same as the nil-init idiom.
		refute_raises Code::Undeclared_Identifier do
			Code.interp '@declare "foo"
			foo'
		end
	end

	def test_declare_too_many_arguments_raises
		assert_raises Code::Invalid_Context_Function_Usage do
			Code.interp '@declare "foo", 42, Number, "extra"'
		end
	end

	def test_declare_with_type_allows_matching_reassignment
		out = Code.interp <<~CODE
		    @declare "foo", 42, Number
		    foo = 99
		    foo
		CODE
		assert_equal 99, out
	end

	def test_declare_with_type_rejects_mismatched_reassignment
		assert_raises Code::Type_Contract_Violation do
			Code.interp <<~CODE
			    @declare "foo", 42, Number
			    foo = "oops"
			CODE
		end
	end

	def test_declare_without_type_allows_any_reassignment
		out = Code.interp <<~CODE
		    @declare "foo", 42
		    foo = "now a string"
		    foo
		CODE
		assert_equal 'now a string', out
	end

	def test_declare_inside_function_scope_is_local
		out = Code.interp <<~CODE
		    make (;
		    	@declare "local_thing", 5
		    	local_thing
		    )
		    make()
		CODE
		assert_equal 5, out
	end

	def test_declare_inside_function_scope_does_not_leak_out
		assert_raises Code::Undeclared_Identifier do
			Code.interp <<~CODE
			    make (;
			    	@declare "local_thing", 5
			    )
			    make()
			    local_thing
			CODE
		end
	end

	def test_percent_string_literals
		# %string preserves each identifier's own casing.
		out = Code.interp "%string(boo Hoo COOL).values"
		assert_equal %w(boo Hoo COOL), out
		assert out.all? { |it| it.is_a? ::String }

		# %str forces lowercase.
		assert_equal %w(boo hoo cool), Code.interp("%str(Boo hOO COOL).values")

		# %Str forces Capitalcase.
		assert_equal %w(Boo Hoo Cool), Code.interp("%Str(boo HOO cOOl).values")

		# %STR forces UPPERCASE.
		assert_equal %w(BOO HOO COOL), Code.interp("%STR(boo Hoo cool).values")

		# Casing has no effect on numbers or symbols
		assert_equal %w(123 ^^^ + - * /), Code.interp("%string(123 ^^^ + - * /).values")
		assert_equal %w(123 ^^^ + - * /), Code.interp("%str(123 ^^^ + - * /).values")
		assert_equal %w(123 ^^^ + - * /), Code.interp("%Str(123 ^^^ + - * /).values")
		assert_equal %w(123 ^^^ + - * /), Code.interp("%STR(123 ^^^ + - * /).values")
	end

	def test_percent_symbol_literals
		# %symbol preserves each identifier's own casing.
		out = Code.interp "%symbol(BOO hoo Cool).values"
		assert_equal %i(BOO hoo Cool), out
		assert out.all? { |it| it.is_a? ::Symbol }

		# %sym forces lowercase.
		assert_equal %i(boo hoo cool), Code.interp("%sym(Boo HOO cOOl).values")

		# %Sym forces Capitalcase.
		assert_equal %i(Boo Hoo Cool), Code.interp("%Sym(boo HOO cOOl).values")

		# %SYM forces UPPERCASE.
		assert_equal %i(BOO HOO COOL), Code.interp("%SYM(boo Hoo cool).values")

		assert_equal %i(123 ^^^ + - * /), Code.interp("%symbol(123 ^^^ + - * /).values")
		assert_equal %i(123 ^^^ + - * /), Code.interp("%sym(123 ^^^ + - * /).values")
		assert_equal %i(123 ^^^ + - * /), Code.interp("%Sym(123 ^^^ + - * /).values")
		assert_equal %i(123 ^^^ + - * /), Code.interp("%SYM(123 ^^^ + - * /).values")
	end

	def test_percent_literal_is_a_real_array
		out = Code.interp "%str(a b c)"
		assert_kind_of Code::Array, out
		assert_equal 3, out.values.count
	end

	def test_percent_literal_interpolation
		out = Code.interp <<~CODE
		    cool := 2342
		    %str(481516 `cool`)
		CODE
		assert_equal ['481516', '2342'], out.values
		# assert out.values.all? { _1.is_a? Code::String } # todo; this is currently false
	end

	def test_statement_expressions
		out = Code.interp "`1+2`"
		assert_kind_of Code::Statement, out
		assert_kind_of Code::Infix_Expr, out.expression
		assert_equal "Statement{Code::Infix_Expr}", out.proxy_to_s

		out = Code.interp "`1+2`()"
		assert_equal 3, out
	end

	def test_statement_expression_stored_in_a_variable
		# The whole point of Statement -- build it once, call it later, wherever it ends up.
		out = Code.interp <<~CODE
		    x := `1+2`
		    x()
		CODE
		assert_equal 3, out

		# Same thing, but via a `: Statement` type annotation instead of `:=`.
		out = Code.interp <<~CODE
		    x: Statement = `1+2`
		    x()
		CODE
		assert_equal 3, out
	end

	def test_statement_expression_re_evaluates_on_every_call
		# Not memoized -- each `()` call re-interprets the wrapped expression fresh.
		out = Code.interp <<~CODE
		    counter := 0
		    increment := `counter += 1`
		    increment()
		    increment()
		    increment()
		    counter
		CODE
		assert_equal 3, out
	end

	def test_statement_expression_can_be_displayed
		# Code::Statement is a real Instance -- @puts must not crash on one, called or not.
		output          = StringIO.new
		original_stdout = $stdout
		$stdout         = output

		begin
			Code.interp "@puts `1+2`"
			refute_empty output.string
		ensure
			$stdout = original_stdout
		end
	end

	def test_fancier_statement_example
		out = Code.interp "x := `@load 'code/string'`"
		assert_kind_of Code::Statement, out
	end

	def test_nested_statements_with_mixed_memoization
		# outer wraps two inner Statements, one memoized and one not, and is itself memoized too -- calling outer() a second time shouldn't re-run any of them.
		out = Code.interp <<~CODE
		    calls_memoized   := 0
		    calls_unmemoized := 0

		    memoized_inner := `calls_memoized += 1`
		    memoized_inner.memoize = true

		    plain_inner := `calls_unmemoized += 1`

		    outer := `memoized_inner() + memoized_inner() + plain_inner() + plain_inner()`
		    outer.memoize = true

		    first  := outer()
		    second := outer()

		    (first, second, calls_memoized, calls_unmemoized)
		CODE

		first, second, calls_memoized, calls_unmemoized = out.values
		assert_equal 5, first # 1 + 1 + 1 + 2 -- memoized_inner's second call is cached, plain_inner's isn't
		assert_equal 5, second # outer is memoized too -- same cached result, nothing re-ran
		assert_equal 1, calls_memoized
		assert_equal 2, calls_unmemoized
	end

	def test_self_resolves_to_nearest_instance
		out = Code.interp <<~CODE
		    Thing {
		        value := 42
		        get_val (; self.value )
		    }
		    Thing().get_val()
		CODE
		assert_equal 42, out
	end

	def test_Self_resolves_to_nearest_type
		out = Code.interp <<~CODE
		    Thing {
		        klass (; Self )
		    }
		    Thing().klass() === Thing
		CODE
		assert out
	end

	def test_Self_dot_access_identical_to_class_name_dot_access
		out = Code.interp <<~CODE
		    Thing {
		        Self.count := 5
		        get_via_Self (; Self.count )
		        get_via_name (; Thing.count )
		    }
		    t := Thing()
		    (t.get_via_Self(), t.get_via_name())
		CODE
		assert_equal [5, 5], out.values
	end

	def test_self_raises_outside_instance_context
		assert_raises Code::Cannot_Use_Instance_Scope_Operator_Outside_Instance do
			Code.interp 'self'
		end
	end

	def test_Self_raises_outside_type_context
		assert_raises Code::Cannot_Use_Type_Scope_Operator_Outside_Type do
			Code.interp 'Self'
		end
	end

	def test_self_dot_declare_no_longer_declares_a_new_member_during_construction
		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp <<~CODE
			    Thing {
			        Self (;
			            self.member := 123
			        )
			    }
			    Thing().member
			CODE
		end

		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp <<~CODE
			    Thing {
			        not_new_func (;
			            self.member := 123
			        )
			    }
			    Thing().not_new_func()
			CODE
		end
	end

	def test_Self_dot_declare_self_declares_new_static_during_type_body
		out = Code.interp <<~CODE
		    Thing {
		        Self.count := 0
		    }
		    Thing.count
		CODE
		assert_equal 0, out

		assert_raises Code::Cannot_Assign_Undeclared_Identifier do
			Code.interp <<~CODE
			    Thing {
			        bump_late (; Self.new_static := 1 )
			    }
			    Thing().bump_late()
			CODE
		end
	end

	def test_self_dot_func_declares_instance_method
		out = Code.interp <<~CODE
		    Thing {
		        self.greet (; 'hi' )
		    }
		    Thing().greet()
		CODE
		assert_equal 'hi', out
	end

	def test_Self_dot_func_declares_static_method
		out = Code.interp <<~CODE
		    Thing {
		        Self.count := 0
		        Self.increment (; count += 1 )
		    }
		    Thing.increment()
		    Thing.increment()
		    Thing.count
		CODE
		assert_equal 2, out
	end

	def test_Self_is_callable_like_the_type_name_with_and_without_args
		out = Code.interp <<~CODE
		    Thing {
		        value := 42
		        make_bare (; Self() )
		    }
		    Thing().make_bare().value
		CODE
		assert_equal 42, out

		out = Code.interp <<~CODE
		    Thing {
		        value,
		        Self ( v; self.value = v )
		        make_with_arg (; Self(99) )
		    }
		    Thing(1).make_with_arg().value
		CODE
		assert_equal 99, out
	end

	def test_block_comments_are_ignored
		out = Code.interp <<~CODE
		    ###
		    this whole block, including this fake declaration, is discarded
		    x := 999
		    ###
		    4 + 8
		CODE
		assert_equal 12, out

		# a block comment as the very last expression shouldn't leak its text out as the return value, same as a trailing # comment
		out = Code.interp <<~CODE
		    add ( a, b;
		        a + b
		        ### sum me ###
		    )
		    add(4, 8)
		CODE
		assert_equal 12, out
	end

	def test_function_body_arg_with_other_arguments
		out = Code.interp <<~CODE
		    f ( callable: (;), num: Number;
		    	(callable(), num)
		    )

		    f( (; 4), 42 )
		CODE
		assert_equal [4, 42], out.values
	end

	def test_number_rand
		100.times do
			out = Code.interp 'Number.rand(10)'
			assert_includes 0..10, out
		end
	end

	def test_number_rand_zero
		out = Code.interp 'Number.rand(0)'
		assert_equal 0, out
	end

	def test_string_positional_dot_index
		assert_equal 'a', Code.interp('"abc".0')
		assert_equal 'c', Code.interp('"abc".2')
	end

	def test_string_positional_dot_index_negative
		assert_equal 'c', Code.interp('"abc".-1')
	end

	def test_string_positional_dot_index_out_of_range_raises
		assert_raises Code::Invalid_Array_Index do
			Code.interp '"abc".5'
		end
	end

	def test_string_positional_dot_index_result_is_a_real_string_with_methods
		assert_equal 'A', Code.interp('"abc".0.upcase()')
	end

	def test_stored_method_reference_keeps_calling_its_own_instances_sibling_methods
		out = Code.interp "
		Greeter {
			greeting := 'Hello'
			greet ( name; \"`shout(greeting)`, `name`!\" )
			shout ( text; text.upcase() )
		}
		g := Greeter()
		f := g.greet
		f('World')"
		assert_equal 'HELLO, World!', out
	end

	def test_end_of_line_for_loop
		out = Code.interp <<~CODE
		    items := []		
		    items.push(it) for 1..5
		    items
		CODE
		assert_equal [1, 2, 3, 4, 5], out.values
	end

	def test_end_of_line_for_loop_with_parenless_call_in_body
		printed = capture_stdout do
			Code.interp '@puts it for 1..5'
		end

		assert_equal "1\n2\n3\n4\n5\n", printed
	end

	def test_end_of_line_for_loop_with_map_verb_assigned_to_a_variable
		# `for`'s precedence has to sit above `:=` (90), or `:=`'s own right-hand side parse
		# stops at `it * 2` and hands `for [...] map` the whole assignment as its body instead
		# of the value being assigned -- `doubled` would then never escape the loop.
		out = Code.interp <<~CODE
		    doubled := it * 2 for [1, 2, 3] map
		    doubled
		CODE
		assert_equal [2, 4, 6], out.values
	end

	def test_for_loop_body_scope_still_reaches_the_enclosing_scope
		out = Code.interp <<~CODE
		    items := []
		    items.push(it + 1) for [10, 20, 30]
		    items
		CODE
		assert_equal [11, 21, 31], out.values
	end

	def test_eol_for_stride
		out = Code.interp <<~CODE
			items := []
			items.push(it) for [4, 8, 15, 16, 23, 42] by 2
			items
		CODE
		assert_equal [[4,8], [15,16], [23,42]], out.values.map(&:values)
	end

	def test_eol_for_stride_and_overlap
		out = Code.interp <<~CODE
			items := []
			items.push(it) for [4, 8, 15, 16, 23, 42] by 3,1
			items
		CODE
		assert_equal [[4,8,15], [15,16,23], [23,42]], out.values.map(&:values)
	end
end
