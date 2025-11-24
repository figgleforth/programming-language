##
# Parses Air test case files with literate test directives
#
# Supported directives:
#   `=> value            - Assert return value equals 'value'
#   `error: ErrorType    - Assert ErrorType exception is raised
#   `skip                - Skip this test
#   `skip: reason        - Skip this test with reason
#
# Directives can appear:
#   - Above the code block (applies to following code)
#   - At end of line (applies to that line only)
class Case_Parser
	EXPECT_DIRECTIVE = '=>'
	ERROR_DIRECTIVE  = 'error:'
	SKIP_DIRECTIVE   = 'skip'
	COMMENT_PREFIX   = '`'

	attr_reader :test_cases

	def initialize file_path
		@file_path  = file_path
		@test_cases = []
	end

	##
	# Parses the test case file and extracts test cases with their directives.
	#
	# Reads the file line by line and identifies two types of directives:
	# 1. Above-line directives - Appear on their own line and apply to the
	#    following block of code
	# 2. End-of-line directives - Appear at the end of a code line and apply
	#    only to that line
	#
	# Directives can be:
	# - `=> value - Assert return value equals 'value'
	# - `error: ErrorType - Assert ErrorType exception is raised
	# - `skip - Skip this test
	# - `skip: reason - Skip this test with reason
	#
	# ==== Above-line Directive Mechanism
	#
	# When an above-line directive is detected (a line starting with backtick
	# followed by a directive keyword), the parser:
	#
	# 1. Extracts the directive information
	# 2. Advances to the next line and begins collecting code lines
	# 3. Continues collecting lines until one of these conditions:
	#    - Another directive line is encountered (stops immediately)
	#    - A blank line is found, triggering a lookahead check:
	#      * Peeks at following lines to see if more code exists
	#      * If more non-comment code is found, includes the blank line and continues
	#      * If only blank lines or directives remain, stops collection
	# 4. Once collection stops, creates a test case from all collected lines
	#
	# This lookahead mechanism allows code blocks to contain internal blank lines
	# (for readability) while still correctly detecting the end of a test case.
	#
	# ==== Output
	#
	# Extracted test cases are stored in @test_cases as hashes containing:
	# - :code - The code to execute
	# - :directive - The directive type (:skip, :expect, or :error)
	# - :expected - The expected value or error class
	# - :line - Line number where the test starts (1-indexed)
	# - :file - Path to the source file
	def parse
		content = File.read @file_path
		lines   = content.lines.map &:chomp

		i = 0
		while i < lines.length
			line = lines[i]

			# Skip blank lines and regular comments (non-directive comments)
			if line.strip.empty? || (line.strip.start_with?(COMMENT_PREFIX) && !directive_line?(line))
				i += 1
				next
			end

			# Check for above-line directive
			if above_line_directive? line
				directive_info = extract_directive line
				i              += 1

				# Collect code block following the directive
				code_lines = []
				start_line = i + 1 # Line numbers are 1-indexed

				# Gather lines until we hit another directive or end of meaningful content
				while i < lines.length
					current = lines[i]

					# Stop at next directive
					break if directive_line? current

					# If blank line, peek ahead to see if there's more content
					if current.strip.empty?
						# Look ahead to see if there's more non-comment code
						peek_index    = i + 1
						has_more_code = false

						while peek_index < lines.length
							peek_line = lines[peek_index]
							break if peek_line.strip.empty?
							if directive_line? peek_line
								# Next directive found, stop here
								break
							elsif !peek_line.strip.start_with? COMMENT_PREFIX
								# Found more code
								has_more_code = true
								break
							end
							peek_index += 1
						end

						# If there's more code, include the blank line
						if has_more_code
							code_lines << current
							i += 1
							next
						else
							# No more code, stop here
							break
						end
					end

					code_lines << current
					i += 1
				end

				# Add the test case if we have code
				unless code_lines.empty?
					@test_cases << {
						code:      code_lines.join("\n").strip,
						directive: directive_info[:type],
						expected:  directive_info[:value],
						line:      start_line,
						file:      @file_path
					}
				end

				next
			end

			# Check for end-of-line directive
			if end_of_line_directive? line
				parts          = split_end_of_line_directive line
				directive_info = extract_directive parts[:directive]

				@test_cases << {
					code:      parts[:code].strip,
					directive: directive_info[:type],
					expected:  directive_info[:value],
					line:      i + 1,
					file:      @file_path
				}
			end

			i += 1
		end
	end

	private

	def directive_line? line
		above_line_directive?(line) || end_of_line_directive?(line)
	end

	def above_line_directive? line
		stripped = line.strip
		stripped.start_with?("`#{EXPECT_DIRECTIVE}") ||
			stripped.start_with?("`#{ERROR_DIRECTIVE}") ||
			stripped.start_with?("`#{SKIP_DIRECTIVE}")
	end

	def end_of_line_directive? line
		# Check if line has content, then whitespace, then a backtick directive
		return false unless line.include? COMMENT_PREFIX

		# Split on backtick to see if there's non-whitespace before it
		before_backtick = line.split(COMMENT_PREFIX).first
		return false if before_backtick.nil? || before_backtick.strip.empty?

		# Check if what's after backtick looks like a directive
		after_backtick = line[line.index(COMMENT_PREFIX)..-1]
		after_backtick.start_with?("`#{EXPECT_DIRECTIVE}") ||
			after_backtick.start_with?("`#{ERROR_DIRECTIVE}") ||
			after_backtick.start_with?("`#{SKIP_DIRECTIVE}")
	end

	def extract_directive line
		# Remove leading backtick
		stripped = line.strip
		stripped = stripped[1..-1] if stripped.start_with? COMMENT_PREFIX

		if stripped.start_with? SKIP_DIRECTIVE
			# Extract reason after "skip:" if present
			if stripped.start_with?("#{SKIP_DIRECTIVE}:")
				reason = stripped["#{SKIP_DIRECTIVE}:".length..-1].strip
				{ type: :skip, value: reason.empty? ? nil : reason }
			else
				{ type: :skip, value: nil }
			end

		elsif stripped.start_with? EXPECT_DIRECTIVE
			# Extract value after "=>"
			value = stripped[EXPECT_DIRECTIVE.length..-1].strip
			{ type: :expect, value: value }

		elsif stripped.start_with? ERROR_DIRECTIVE
			# Extract error type after "error:"
			error_type = stripped[ERROR_DIRECTIVE.length..-1].strip
			{ type: :error, value: error_type }

		else
			{ type: :unknown, value: nil }
		end
	end

	def split_end_of_line_directive line
		# Find the last backtick that starts a directive
		# We need to find the rightmost backtick followed by a directive keyword
		backtick_index = nil

		# Scan from right to left to find last backtick that starts a directive
		index = line.length - 1
		while index >= 0
			if line[index] == COMMENT_PREFIX
				# Check if this backtick starts a directive
				rest = line[index..-1]
				if rest.start_with?("`#{EXPECT_DIRECTIVE}") || rest.start_with?("`#{ERROR_DIRECTIVE}") || rest.start_with?("`#{SKIP_DIRECTIVE}")
					# Also verify there's some whitespace before it
					if index > 0 && (line[index - 1] == ' ' || line[index - 1] == "\t")
						backtick_index = index
						break
					end
				end
			end
			index -= 1
		end

		if backtick_index
			# Split at the whitespace before the backtick
			# Find the start of whitespace before backtick
			ws_start = backtick_index - 1
			ws_start -= 1 while ws_start > 0 && (line[ws_start - 1] == ' ' || line[ws_start - 1] == "\t")

			{
				code:      line[0...ws_start].strip,
				directive: line[backtick_index..-1]
			}

		else
			{ code: line, directive: '' }
		end
	end
end
