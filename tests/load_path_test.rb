require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../ruby/main'
require_relative 'base_test'

# A relative @load resolves next to the file that holds it, then in the working directory, then in ROOT_PATH. See Declarator.resolve_load_filepath.
class Load_Path_Test < Base_Test
	# Writes each { 'path/name' => source } under a fresh temp dir, and yields the dir. The dir is deleted after the block.
	def with_files files
		Dir.mktmpdir do |dir|
			files.each do |name, source|
				path = File.join dir, "#{name}.code"
				FileUtils.mkdir_p File.dirname(path)
				File.write path, source
			end
			yield dir
		end
	end

	# Runs the block from another folder, the way `bin/program` runs when you start it somewhere else.
	def from_elsewhere
		Dir.mktmpdir { |elsewhere| Dir.chdir(elsewhere) { yield } }
	end

	def test_a_relative_load_resolves_next_to_its_own_file
		with_files('main' => "@load ./helper\nvalue", 'helper' => "value := 'next to main'") do |dir|
			assert_equal 'next to main', from_elsewhere { Code.interp_file File.join(dir, 'main.code') }
		end
	end

	def test_a_missing_load_names_every_place_it_looked
		with_files('main' => "@load 'lib/missing'") do |dir|
			error = assert_raises(Code::Load_File_Not_Found) { from_elsewhere { Code.interp_file File.join(dir, 'main.code') } }
			assert_equal 'lib/missing', error.filepath
			assert error.candidates.first.end_with?(File.join(File.basename(dir), 'lib/missing.code')), 'next to main.code comes first'
			assert_includes error.candidates, File.join(Code::ROOT_PATH, 'lib/missing.code')
			assert_equal 3, error.candidates.length, 'next to main.code, the working directory, and ROOT_PATH'
		end
	end

	def test_a_loaded_file_resolves_its_own_loads_next_to_itself
		files = {
			'main'      => "@load './lib/outer'\nvalue",
			'lib/outer' => "@load './inner'",
			'lib/inner' => "value := 'next to outer'"
		}
		with_files files do |dir|
			assert_equal 'next to outer', from_elsewhere { Code.interp_file File.join(dir, 'main.code') }
		end
	end

	# The Declarator resolves the path before the @load line runs, so a function from the loaded file works above that line.
	def test_a_hoisted_load_resolves_next_to_its_own_file
		files = {
			'app/main'      => "result := greet()\n@load ../shared/helper\nresult",
			'shared/helper' => "greet (; 'hi' )"
		}
		with_files files do |dir|
			main = File.join dir, 'app', 'main.code'

			assert_equal 'hi', from_elsewhere { Code.interp_file main }
			assert from_elsewhere { Code.declare_file main }.key?('greet')
		end
	end

	def test_a_named_load_resolves_next_to_its_own_file
		with_files('main' => "Lib := @load './helper'\nLib.greet()", 'helper' => "greet (; 'hi' )") do |dir|
			assert_equal 'hi', from_elsewhere { Code.interp_file File.join(dir, 'main.code') }
		end
	end

	def test_the_file_next_to_the_load_wins_over_the_working_directory
		with_files('main' => "@load './helper'\nvalue", 'helper' => "value := 'next to main'") do |dir|
			with_files('helper' => "value := 'in the working directory'") do |cwd|
				assert_equal 'next to main', Dir.chdir(cwd) { Code.interp_file File.join(dir, 'main.code') }
			end
		end
	end

	# Code with no file of its own (`bin/program interp`) still resolves against the working directory.
	def test_code_with_no_file_resolves_against_the_working_directory
		with_files('helper' => "value := 'in the working directory'") do |cwd|
			assert_equal 'in the working directory', Dir.chdir(cwd) { Code.interp "@load './helper'\nvalue" }
		end
	end

	def test_the_standard_library_loads_from_any_working_directory
		with_files('main' => "@load 'lang/html'\nDiv([P('hi')]).to_s()") do |dir|
			assert_equal '<div><p>hi</p></div>', from_elsewhere { Code.interp_file File.join(dir, 'main.code') }
		end
	end
end
