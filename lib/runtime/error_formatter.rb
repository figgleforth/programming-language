module Ore
	module Colors
		RESET  = "\e[0m"
		RED    = "\e[31m"
		YELLOW = "\e[33m"
		CYAN   = "\e[36m"
		BOLD   = "\e[1m"

		def self.enabled?
			$stdout.tty? && ENV['TERM'] != 'dumb' && !ENV['NO_COLOR']
		end

		def self.red str
			enabled? ? "#{RED}#{str}#{RESET}" : str
		end

		def self.yellow str
			enabled? ? "#{YELLOW}#{str}#{RESET}" : str
		end

		def self.cyan str
			enabled? ? "#{CYAN}#{str}#{RESET}" : str
		end

		def self.bold str
			enabled? ? "#{BOLD}#{str}#{RESET}" : str
		end
	end

	class Error_Formatter
		attr_reader :error, :expression, :lexeme, :context

		def initialize error
			@error      = error
			@expression = error.expression
			@lexeme     = error.lexeme
			@context    = error.context
		end

		def format
			parts = []

			parts << Colors.bold(Colors.red(error.class.name.split('::').last))
			parts << ""

			if location_available?
				parts << location_line
				parts << ""
				parts << source_snippet if source_available?
				parts << ""
			end

			parts << error.custom_message if error.custom_message

			parts.join "\n"
		end

		def location_available?
			(expression && expression.l0) ||
			(lexeme && lexeme.l0) ||
			error.manual_location
		end

		def source_available?
			context && location_available?
		end

		def location_line
			if expression && expression.l0
				file = expression.source_file || '<input>'
				Colors.cyan "#{file}:#{expression.l0}:#{expression.c0}"
			elsif lexeme && lexeme.l0
				file = error.source_file || '<input>'
				Colors.cyan "#{file}:#{lexeme.l0}:#{lexeme.c0}"
			elsif error.manual_location
				Colors.cyan error.manual_location
			else
				Colors.yellow "<unknown>"
			end
		end

		def source_snippet
			return nil unless context

			l0, c0, l1, c1 = get_location_coords
			return nil unless l0

			source_file = get_source_file
			lines       = context.get_source_lines source_file
			return nil if lines.empty?

			start_line = [l0 - 1, 1].max
			end_line   = [l1 + 1, lines.length].min

			snippet_lines = []
			(start_line..end_line).each do |line_num|
				line_content = lines[line_num - 1] || ""
				prefix       = Colors.cyan("#{line_num.to_s.rjust(4)} | ")

				if line_num >= l0 && line_num <= l1
					if line_num == l0 && line_num == l1
						before     = line_content[0...c0 - 1]
						error_span = line_content[c0 - 1...c1]
						after      = line_content[c1..-1] || ""
						snippet_lines << prefix + before + Colors.red(Colors.bold(error_span)) + after

						arrow_prefix = "     | "
						arrow_line   = " " * (c0 - 1) + Colors.red("^" * (c1 - c0 + 1))
						snippet_lines << arrow_prefix + arrow_line
					elsif line_num == l0
						before     = line_content[0...c0 - 1]
						error_span = line_content[c0 - 1..-1]
						snippet_lines << prefix + before + Colors.red(Colors.bold(error_span))
					elsif line_num == l1
						error_span = line_content[0...c1]
						after      = line_content[c1..-1] || ""
						snippet_lines << prefix + Colors.red(Colors.bold(error_span)) + after
					else
						snippet_lines << prefix + Colors.red(Colors.bold(line_content))
					end
				else
					snippet_lines << prefix + line_content
				end
			end

			snippet_lines.join "\n"
		end

		private

		def get_location_coords
			if expression && expression.l0
				[expression.l0, expression.c0, expression.l1 || expression.l0, expression.c1 || expression.c0]
			elsif lexeme && lexeme.l0
				[lexeme.l0, lexeme.c0, lexeme.l1 || lexeme.l0, lexeme.c1 || lexeme.c0]
			else
				[nil, nil, nil, nil]
			end
		end

		def get_source_file
			expression&.source_file || error.source_file || '<input>'
		end
	end
end