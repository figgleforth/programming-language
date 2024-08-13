require_relative '../source/lexer/lexer'
require_relative '../source/parser/parser'
require_relative '../source/interpreter/runtime'
require 'benchmark'
@tests_ran = 0

output_lexed   = false
output_parsed  = true
output_runtime = false

# Load all example files from the ./example directory
example_files = Dir['./example/*.em'].sort
example_files = ['./example/_.em']

max_width = example_files.max do |a, b|
	a.length <=> b.length
end.length

Benchmark.bm(max_width) do |x|
	example_files.each do |file|
		# next unless file == './example/references.em' # nocheckin
		x.report(file) do
			begin
				puts "\n\n"

				code   = File.read(file).to_s
				tokens = Lexer.new(code).lex
				if output_lexed
					puts "         LEXING"
					puts "‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿\n"
					puts "tokens #{tokens.inspect}\n\n"
					puts tokens.reject {
						_1 == Delimiter_Token
					}.map &:inspect
					puts "⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀"
				end

				ast = Parser.new(tokens, code).to_expr
				if output_parsed
					puts "         PARSING"
					puts "‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿\n"
					ast.reject {
						_1 == "\n"
					}.each {
						puts PP.pp(_1, '').chomp
						puts
					}
					puts "⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀"
				end

				# output = Runtime.new(ast).evaluate_expressions
				if output_runtime
					puts "         RUNTIME"
					puts "‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿‿\n"
					puts output
					puts "⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀⁀"
					puts "\n"
				end
			rescue Exception => e
				puts "\nFILE #{file}\n#{e}\n\n"
				raise
			end
			@tests_ran += 1
		end
	end
end

puts "\n◼︎ #{@tests_ran} tests passed"
