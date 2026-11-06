require 'minitest/autorun'
require 'tmpdir'
require_relative '../ruby/main'
require_relative 'base_test'

# A named load (`This := @load 'this'`) is a namespace: its types are reached as `This.That`, also in a type position, and it can declare a name that another loaded file already has.
class Namespace_Test < Base_Test
	THIS = <<~CODE
		@load 'lang/errors.code'

		Version <
			major: Int
			minor: Int
		>

		That <
			name: String
			value: String
		>

		Other <
			version: Version
			thats: Array\\That
		>

		Failure + Error <>

		make_other ( -> Other;
			Other(version := Version(1, 1), thats := [That('color', 'red')])
		)
	CODE

	# Writes THIS to this.code in a fresh temp dir, then runs `source` from main.code next to it.
	def interp_with_this source
		Dir.mktmpdir do |dir|
			File.write File.join(dir, 'this.code'), THIS
			File.write File.join(dir, 'main.code'), "This := @load './this'\n\n#{source}"
			Code.interp_file File.join(dir, 'main.code')
		end
	end

	# A String built from a literal comes back as a Code::String.
	def text value
		value.is_a?(Code::String) ? value.value : value
	end

	def test_a_qualified_type_annotates_a_variable
		source = <<~CODE
			that: This.That = This.That('color', 'red')
			that.value
		CODE
		assert_equal 'red', text(interp_with_this(source))

		assert_raises(Code::Type_Contract_Violation) { interp_with_this "that: This.That = 5" }
	end

	def test_a_qualified_type_annotates_a_param_and_a_return_type
		source = <<~CODE
			that_count ( other: This.Other -> Int;
				other.thats.count()
			)

			first_other ( -> This.Other;
				This.make_other()
			)

			that_count(first_other())
		CODE
		assert_equal 1, interp_with_this(source)

		wrong_param = <<~CODE
			that_count ( other: This.Other;
				other.thats.count()
			)

			that_count(This.That('color', 'red'))
		CODE
		assert_raises(Code::Type_Contract_Violation) { interp_with_this wrong_param }

		wrong_return = <<~CODE
			first_other ( -> This.Other;
				5
			)

			first_other()
		CODE
		assert_raises(Code::Type_Contract_Violation) { interp_with_this wrong_return }
	end

	def test_a_qualified_type_is_one_operand_of_a_composed_type
		source = <<~CODE
			describe ( other: Nil | This.Other -> String | This.That;
				return 'none' unless other
				other.thats.0
			)

			<describe(nil), describe(This.make_other()).name>
		CODE
		result = interp_with_this source
		assert_equal %w(none color), result.values.map { text it }

		assert_raises(Code::Type_Contract_Violation) { interp_with_this "that: This.That | Int = 'text'" }
	end

	def test_a_qualified_type_is_a_tag
		source = <<~CODE
			thats: Array\\This.That = [This.That('color', 'red')]
			thats.0.name
		CODE
		assert_equal 'color', text(interp_with_this(source))
	end

	def test_a_qualified_type_is_a_nil_tag_in_when
		source = <<~CODE
			check ( value;
				if value
					'value'
				else
				when nil\\This.Failure
					'failure'
				else
					'other'
				end
			)

			<check(nil\\This.Failure), check(nil\\Error)>
		CODE
		result = interp_with_this source
		assert_equal ['failure', 'other'], result.values.map { text it }
	end

	# A `That` in Global is not the `That` of the namespace.
	def test_a_qualified_struct_member_checks_the_type_of_the_namespace
		source = <<~CODE
			That {
				name := 'color'
			}

			Box <that: This.That>

			Box(That())
		CODE
		assert_raises(Code::Type_Contract_Violation) { interp_with_this source }
	end

	def test_a_qualified_type_can_name_a_nested_type
		source = <<~CODE
			Outer {
				Inner {
					Leaf <value: Int>
				}
			}

			leaf: Outer.Inner.Leaf = Outer.Inner.Leaf(5)
			leaf.value
		CODE
		assert_equal 5, Code.interp(source)
	end

	def test_a_tag_on_a_qualified_type_is_not_supported_yet
		assert_raises(RuntimeError) { Code.parse "that: This.That\\<Int> = nil" }
	end

	def test_a_value_dot_after_a_type_is_still_member_access
		assert_equal 'red', text(interp_with_this("This.That('color', 'red').value"))
	end

	# A second file that also declares `Other`, with another shape.
	SECOND = <<~CODE
		Other {
			path := '/'
		}
	CODE

	def test_a_named_load_can_declare_a_name_that_global_has
		source = <<~CODE
			@load './second'
			This := @load './this'

			This.make_other().version.minor
		CODE
		Dir.mktmpdir do |dir|
			File.write File.join(dir, 'this.code'), THIS
			File.write File.join(dir, 'second.code'), SECOND
			File.write File.join(dir, 'main.code'), source
			assert_equal 1, Code.interp_file(File.join(dir, 'main.code'))
		end
	end

	# The library uses its own `Other` above the line that declares it, and Global has another `Other`.
	LIBRARY_USES_ITS_OWN_NAME_EARLY = <<~CODE
		first := Other(5).value

		make_other (;
			Other(7)
		)

		Other <value: Int>
	CODE

	def test_a_file_declaration_shadows_an_outer_name_above_its_own_line
		source = <<~CODE
			@load './second'
			Lib := @load './library'

			<Lib.first, Lib.make_other().value, Other().path>
		CODE
		Dir.mktmpdir do |dir|
			File.write File.join(dir, 'second.code'), SECOND
			File.write File.join(dir, 'library.code'), LIBRARY_USES_ITS_OWN_NAME_EARLY
			File.write File.join(dir, 'main.code'), source
			result = Code.interp_file File.join(dir, 'main.code')
			assert_equal [5, 7, '/'], result.values.map { text it }
		end
	end

	def test_a_declaration_in_a_branch_does_not_shadow_an_outer_name
		library = <<~CODE
			first := Other().path

			if false
				Other <value: Int>
			end
		CODE
		source = <<~CODE
			@load './second'
			Lib := @load './library'

			Lib.first
		CODE
		Dir.mktmpdir do |dir|
			File.write File.join(dir, 'second.code'), SECOND
			File.write File.join(dir, 'library.code'), library
			File.write File.join(dir, 'main.code'), source
			assert_equal '/', text(Code.interp_file(File.join(dir, 'main.code')))
		end
	end

	# `Array := Mine` at the top level of a library is for the library's arrays only.
	def test_a_library_replacement_of_a_built_in_stays_in_the_library
		library = <<~CODE
			Mine + Array {
				extra := true
			}

			Array := Mine

			made_here := [].extra

			make_array (;
				[]
			)
		CODE
		source = <<~CODE
			Lib := @load './library'

			<Lib.made_here, Lib.make_array().extra, [].@types>
		CODE
		Dir.mktmpdir do |dir|
			File.write File.join(dir, 'library.code'), library
			File.write File.join(dir, 'main.code'), source
			result = Code.interp_file(File.join(dir, 'main.code')).values
			assert_equal [true, true], result.take(2)
			assert_equal %w(Array), result.last.values
		end
	end

	def test_a_bare_load_still_collides_with_a_name_in_the_same_scope
		source = <<~CODE
			@load './second'
			@load './this'
		CODE
		Dir.mktmpdir do |dir|
			File.write File.join(dir, 'this.code'), THIS
			File.write File.join(dir, 'second.code'), SECOND
			File.write File.join(dir, 'main.code'), source
			assert_raises(Code::Name_Already_Declared) { Code.interp_file File.join(dir, 'main.code') }
		end
	end

	def test_a_composition_reaches_a_type_in_a_named_load_in_either_casing
		library = <<~CODE
			Thing {
				x := 1
			}

			THING {
				x := 1
			}
		CODE
		%w(Thing THING).each do |name|
			source = <<~CODE
				Lib := @load './library'

				With_Body + Lib.#{name} {}

				With_Members + Lib.#{name} <y: Int>

				[With_Body().x, With_Members(1, 2).y]
			CODE
			Dir.mktmpdir do |dir|
				File.write File.join(dir, 'library.code'), library
				File.write File.join(dir, 'main.code'), source
				assert_equal [1, 2], Code.interp_file(File.join(dir, 'main.code')).values
			end
		end
	end
end
