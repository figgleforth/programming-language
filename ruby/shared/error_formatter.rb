module Code
	class Error_Formatter
		attr_reader :error, :expression, :highlighted

		def initialize error
			@error       = error
			@expression  = error.expression
			@highlighted = (error.respond_to?(:highlighted_expression) && error.highlighted_expression) || @expression
		end

		def error_name
			error.class.name.split('::').last
		end

		def error_name_styled
			Code::Ascii.bold(Code::Ascii.red(error_name))
		end

		# The snippet already carries everything -- why, where, and what, branching off the
		# highlighted span itself so it all reads at a glance. Falls back to a plain
		# "detail message, then name at location" when there's no snippet to hang that tree off
		# of (no location at all, or its source was never registered).
		def format
			source_snippet || fallback
		end

		def fallback
			[error.detail_message, name_at_location].compact.join("\n\n")
		end

		def name_at_location
			"#{error_name_styled} at #{location_coords}"
		end

		def location_coords
			return 'unknown location' unless located?
			Ascii.underline "#{display_source_file}:#{expression.line_start}:#{expression.column_start}"
		end

		# note; `expression.source_file` is either an absolute path, or the literal `'<inline>'`
		# sentinel `Interpreter#run`/`#register_source` key plain (non-file) source under.
		def display_source_file
			file = expression&.source_file
			return "inline_source" if file.nil? || file == '<inline>'
			file.start_with?("#{Dir.pwd}/") ? file.delete_prefix("#{Dir.pwd}/") : file
		end

		# The literal source around `expression` (its own lines, plus a little surrounding context),
		# with `highlighted`'s own span bolded/reddened in place -- usually `expression` itself, but
		# can be a smaller piece of it (one identifier inside a whole call, say) -- and a small
		# branching pointer under the *end* of that span naming why, where, and what: the detail
		# message, the exact file:line:col, and the error's own name, one glance. Nil when there's
		# nothing to show: no location at all, or that source was never registered (see
		# Interpreter#register_source) -- e.g. an error whose `expression` isn't a real parsed node.
		def source_snippet
			return nil unless located?

			lines = Code::Interpreter.cached_source_by_filename[expression.source_file] || []
			return nil if lines.empty?

			ctx_start, _, ctx_end, _ = coords_for expression
			surrounding_lines        = 3
			start_line               = [ctx_start - surrounding_lines, 1].max
			end_line                 = [ctx_end + surrounding_lines, lines.length].min
			_, _, hl_line_end, _     = coords_for highlighted
			pointer_line             = [hl_line_end, end_line].min

			(start_line..end_line).flat_map { |line_num| format_line line_num, lines[line_num - 1] || '', pointer_line }.join("\n")
		end

		private

		def located?
			(expression.is_a?(Code::Expression) || expression.is_a?(Code::Lexeme)) && expression.line_start
		end

		# Defensively falls back to the start when an end wasn't recorded (an `expression` that
		# didn't go through the parser's own location helpers), same as before this class existed.
		def coords_for expr
			[expr.line_start, expr.column_start, expr.line_end || expr.line_start, expr.column_end || expr.column_start]
		end

		# Returns an Array of one or more rendered lines (a plain context line is just one; a
		# highlighted line gets its own colored span, plus -- only on the *last* highlighted line,
		# not repeated on every one of a multi-line span -- the branching pointer underneath it).
		def format_line line_num, line_content, pointer_line
			hl_line, hl_column, hl_line_end, hl_column_end = coords_for highlighted
			visual_content                                 = line_content.gsub("\t", "    ")
			prefix                                         = Code::Ascii.cyan("#{line_num.to_s.rjust(5)}: ")

			return [prefix + visual_content] unless line_num.between?(hl_line, hl_line_end)

			start_char = line_num == hl_line ? hl_column - 1 : 0
			end_char   = line_num == hl_line_end ? hl_column_end : visual_content.length

			# Character indices above are into the raw line -- re-derive them against the
			# tab-expanded `visual_content` so the highlight lines up with what's actually printed.
			visual_start = line_content[0...start_char].gsub("\t", "    ").length
			visual_end   = line_content[0...end_char].gsub("\t", "    ").length

			before = visual_content[0...visual_start]
			span   = visual_content[visual_start...visual_end]
			after  = visual_content[visual_end..] || ""

			styled_span = if hl_line == pointer_line
				Code::Ascii.bold(Code::Ascii.make(span))
			else
				Code::Ascii.bold(Code::Ascii.red(span))
			end

			line = "#{prefix}#{before}#{styled_span}#{after}"
			line_num == pointer_line ? [line, *pointer_tree(visual_start), "\n"] : [line]
		end

		# One branch per item, hanging off a `┆` continuation gutter directly under wherever the
		# highlighted span starts on its last line: `detail_message` (why), `location_coords`
		# (where), `error_name` (what) -- whichever of those are actually present, most-specific
		# first. A single item skips the branch entirely (`╰──` straight to it, no `┬`).
		def pointer_tree visual_start
			items = [error.detail_message, location_coords, error_name_styled].compact
			return [] if items.empty?

			gutter = Code::Ascii.cyan("#{' '.rjust(5)}  ") + (" " * visual_start)

			if items.one?
				return ["#{gutter}#{Code::Ascii.cyan('╰─ ')}#{items.first}"]
			end

			items.each_with_index.map do |text, index|
				connector = if index.zero?
					'╰─┬─'
				elsif index == items.length - 1
					'  └─'
				else
					'  ├─'
				end
				"#{gutter}#{Code::Ascii.cyan(connector)}  #{text}"
			end
		end
	end
end
