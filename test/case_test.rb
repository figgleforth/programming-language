require 'minitest/autorun'
require_relative '../lib/air'
require_relative 'case_parser'

class Case_Test < Minitest::Test
	cases_dir = File.join __dir__, 'cases'

	if Dir.exist? cases_dir
		test_files = File.join(cases_dir, '**', '*.air')
		test_cases = Dir.glob(test_files).sort

		test_cases.each do |file_path|
			parser = Case_Parser.new file_path
			parser.parse

			relative_path = file_path.sub "#{cases_dir}/", ''

			parser.test_cases.each_with_index do |test_case, index|
				# Create unique test name from file path and line number
				test_name = "#{relative_path}:#{test_case[:line]}".gsub(/\//, '_').gsub(/_{2,}/, '_')

				define_method "test_#{test_name}" do
					run_test_case test_case
				end
			end
		end
	end

	private

	##
	# Executes a single test case based on its directive type.
	#
	# Handles three directive types:
	# - :skip - Skips the test with an optional reason
	# - :expect - Runs the code and asserts the result matches the expected value
	# - :error - Runs the code and asserts it raises the expected error class
	#
	# For :expect directives, the method first checks if the expected value is a
	# class name and performs an instance check. Otherwise, it evaluates both
	# the expected and actual values for comparison.
	#
	# ==== Parameters
	# * +test_case+ - Hash containing:
	#   * :code - The Air code to execute
	#   * :directive - The directive type (:skip, :expect, or :error)
	#   * :expected - The expected value or error class name
	#   * :line - Line number in the source file
	#   * :file - Source file path
	def run_test_case test_case
		case test_case[:directive]
		when :skip
			reason = test_case[:expected] || 'No reason provided'
			skip reason

		when :expect
			begin
				result       = _interp test_case[:code]
				expected_str = test_case[:expected]

				# Check if expected is a class name (like "Air::Func")
				if expected_str =~ /^[A-Z][a-zA-Z0-9_:]*$/
					expected_class = Object.const_get(expected_str) rescue nil
					if expected_class.is_a?(Class) || expected_class.is_a?(Module)
						assert_instance_of expected_class, result, failure(test_case, "Expected instance of #{expected_str} but got #{result.class}")
						return
					end
				end

				# Otherwise, evaluate and compare values
				expected = eval_expected_value expected_str
				actual   = normalize_value result

				assert_equal expected, actual, failure(test_case, "Expected #{expected.inspect} but got #{actual.inspect}")

			rescue StandardError => e
				flunk failure(test_case, "#{e.class}: #{e.message}")
			end

		when :error
			error_class = Object.const_get test_case[:expected]

			assert_raises error_class do
				_interp test_case[:code]
			end

		else
			flunk "Unknown directive type: #{test_case[:directive]}"
		end
	end

	# Try to evaluate the expected value as Ruby code
	# This allows for: numbers, strings, booleans, nil, arrays, etc.
	# If eval fails, return as string
	def eval_expected_value expected_str
		eval expected_str
	rescue StandardError
		expected_str
	end

	# Convert Air types to comparable Ruby values
	def normalize_value value
		case value
		when Air::Array
			value.values
		when Air::Tuple
			value.values
		when Air::Return
			value.value
		else
			value
		end
	end

	def failure test_case, message
		"#{message}\nCode: #{test_case[:code]}\nFile: #{test_case[:file]}:#{test_case[:line]}"
	end
end
