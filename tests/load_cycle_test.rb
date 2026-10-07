require 'minitest/autorun'
require 'tmpdir'
require_relative '../ruby/main'
require_relative 'base_test'

# Files that @load each other in a cycle. See Interpreter#load_file_into_scope and #resolve_forward_declaration.
class Load_Cycle_Test < Base_Test
	# Write each { name => source } into a fresh temp dir and return the dir. `DIR` in a source becomes the dir, so the files can @load each other by absolute path, whatever the cwd.
	def write_files files
		dir = Dir.mktmpdir
		files.each do |name, source|
			File.write File.join(dir, "#{name}.code"), source.gsub('DIR', dir)
		end
		dir
	end

	def plain message
		message.gsub /\e\[[\d;]*m/, ''
	end

	def test_functions_can_call_each_other_across_a_cycle
		dir = write_files(
			a: "@load 'DIR/b'\nfa (; fb() + 1 )",
			b: "@load 'DIR/a'\nfb (; 41 )"
		)
		assert_equal 42, Code.interp("@load '#{dir}/a'\nfa()")
	end

	def test_a_file_can_load_itself
		dir = write_files(me: "@load 'DIR/me'\nx := 5")
		assert_equal 5, Code.interp("@load '#{dir}/me'\nx")
	end

	def test_a_type_can_use_a_type_declared_later_in_the_other_file_while_loading
		dir = write_files(
			c: "@load 'DIR/d'\nThing | Base {}\nBase {}",
			d: "@load 'DIR/c'\nX | Thing {}"
		)
		assert_equal 'X', Code.interp("@load '#{dir}/c'\nX.@name")
		assert_equal true, Code.interp("@load '#{dir}/c'\nX =>= Base")
	end

	def test_every_file_in_the_cycle_is_reachable_not_only_the_one_it_closes_into
		# a -> b -> c -> a: c needs Middle from b, which is part of the cycle but is not the file c's @load points at.
		dir = write_files(
			a: "@load 'DIR/b'\nTop {}",
			b: "@load 'DIR/c'\nMiddle {}",
			c: "@load 'DIR/a'\nBottom | Middle | Top {}"
		)
		assert_equal 'Bottom', Code.interp("@load '#{dir}/a'\nBottom.@name")
	end

	def test_a_forced_declaration_lands_in_the_scope_its_file_loads_into
		dir = write_files(
			c: "@load 'DIR/d'\nThing | Base {}\nBase {}",
			d: "@load 'DIR/c'\nX | Thing {}"
		)
		assert_equal 'Thing', Code.interp("Lib {\n\t@load '#{dir}/c'\n}\nLib.Thing.@name")
		assert_raises Code::Undeclared_Identifier do
			Code.interp "Lib {\n\t@load '#{dir}/c'\n}\nThing"
		end
	end

	def test_a_declaration_forced_in_one_scope_still_runs_when_its_file_loads_into_another
		# The first load forces Thing into Global. Parsed files are cached, so the named load runs the same `Thing` expression object, and must not skip it as already run.
		dir = write_files(
			c: "@load 'DIR/d'\nThing | Base {}\nBase {}",
			d: "@load 'DIR/c'\nX | Thing {}"
		)
		assert_equal 'Thing', Code.interp("@load '#{dir}/c'\nlib := @load '#{dir}/c'\nlib.Thing.@name")
	end

	def test_a_plain_value_across_a_cycle_says_which_file_is_still_loading
		dir = write_files(
			v1: "@load 'DIR/v2'\nlimit := 10",
			v2: "@load 'DIR/v1'\ny := limit + 1"
		)
		error = assert_raises Code::Undeclared_Identifier do
			Code.interp "@load '#{dir}/v1'"
		end
		assert_includes plain(error.message), 'limit has not been declared yet: v1.code declares it, but v1.code is still loading (v1.code → v2.code → v1.code)'
	end

	def test_the_hint_names_the_file_that_declares_the_name_not_one_that_only_loads_it
		# f only has `val` through its own @load line, so the hint must name g. And h did not close a cycle into g through f, so the chain does not loop back.
		dir = write_files(
			f: "@load 'DIR/g'",
			g: "@load 'DIR/h'\nval := 1",
			h: "y := val"
		)
		error = assert_raises Code::Undeclared_Identifier do
			Code.interp "@load '#{dir}/f'"
		end
		assert_includes plain(error.message), 'val has not been declared yet: g.code declares it, but g.code is still loading (g.code → h.code)'
	end

	def test_an_unrelated_undeclared_name_has_no_hint
		dir = write_files(a: "@load 'DIR/b'\nlimit := 10", b: "@load 'DIR/a'\ny := nope")
		error = assert_raises Code::Undeclared_Identifier do
			Code.interp "@load '#{dir}/a'"
		end
		assert_includes plain(error.message), 'nope has not been declared'
		refute_includes plain(error.message), 'still loading'
	end

	def test_a_cycle_through_named_loads_raises
		dir = write_files(
			n1: "lib := @load 'DIR/n2'",
			n2: "lib := @load 'DIR/n1'"
		)
		error = assert_raises Code::Load_Cycle do
			Code.interp "@load '#{dir}/n1'"
		end
		assert_equal 'load cycle: n1 → n2 → n1', error.message
	end

	def test_a_failed_load_is_not_marked_loaded
		dir         = write_files(bad: "x := needed + 1")
		interpreter = Code::Interpreter.new
		assert_raises Code::Undeclared_Identifier do
			interpreter.run "@load '#{dir}/bad'"
		end
		# If the failed load had stayed marked, this @load would return early and `x` would not exist.
		assert_equal 2, interpreter.run("needed := 1\n@load '#{dir}/bad'\nx")
	end
end
