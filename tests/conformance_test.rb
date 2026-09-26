require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'
require 'open3'

# This test runner assumes, correctly for now, that an Error crashes the program. In the future, I want to collect errors and keep lexing/parsing/interpreting if possible.

# Each tests/conformance/*.code file is one test. Expectations live in the file as comments:
#   @out 4         # out: 4               one expected stdout line
#   @err 4         # err: 4               one expected stderr line
#   x: String = 1  # error: Type_Mismatch the error that stops the program: a Code::Error class name, or else text its message contains
class Conformance_Test < Base_Test
	FILE_DIR = ::File.join __dir__, 'conformance'
	FILEPATH = ::File.join FILE_DIR, '*.code'
	PROGRAM  = ::File.expand_path '../bin/program', __dir__

	# @param out [[::String]]
	# @param err [[::String]]
	# @param error [::String | Nil]
	Streams = ::Data.define :out, :err, :error

	::Dir.glob(FILEPATH).sort.each do |filepath|
		name = ::File.basename filepath, '.code'

		define_method "test_#{name}" do
			stdout = []
			stderr = []
			error  = nil
			::File.readlines(filepath, chomp: true).each do |line|
				if (match = line.match(/#\s*out:\s+(.*)$/))
					stdout << match[1].rstrip
				elsif (match = line.match(/#\s*err:\s+(.*)$/))
					stderr << match[1].rstrip
				elsif (match = line.match(/#\s*error:\s+(.*)$/))
					error = match[1].rstrip
				end
			end
			stream = Streams[stdout, stderr, error]

			stdout_str, stderr_str, status = Open3.capture3 PROGRAM, 'interpf', filepath # see: https://docs.ruby-lang.org/en/3.4/Open3.html

			#######
			# todo; better error messages
			#
			if stream.error
				refute status.success?, "#{name}: expected #{stream.error}, but the program exited 0"
				assert_equal 1, status.exitstatus

				# Lines the program printed with @err come first, so only the rest of stderr is the error.
				printed, error_str = stderr_str.lines(chomp: true).then { [it.first(stream.err.length), it.drop(stream.err.length).join("\n")] }
				assert_equal stream.err, printed, "#{name}: wrong stderr before the error"

				if stream.error.match?(/\A[A-Z]\w*\z/) && Code.const_defined?(stream.error) && Code.const_get(stream.error) <= Code::Error
					# The CLI prints a Code::Error's formatted message to stderr, and the error's class name is its last word (`└─  Type_Mismatch`).
					assert_equal stream.error, error_str.strip.split(/\s+/).last, "#{name}: wrong error\n\n#{stderr_str}"
				else
					assert_includes error_str, stream.error, "#{name}: wrong error message"
				end
			else
				assert status.success?, "#{name}: exited #{status.exitstatus}\n\n#{stderr_str}"
				assert_equal stream.err, stderr_str.lines(chomp: true), "#{name}: wrong stderr"
			end

			# Compare the whole stdout, so extra output also fails the test. Output printed before an error still counts.
			assert_equal stream.out, stdout_str.lines(chomp: true), "#{name}: wrong stdout"
		end
	end
end
