require_relative '../source/lexer/lexer'
require_relative '../source/parser/parser'
require_relative '../source/interpreter/runtime'
require 'benchmark'
@tests_ran = 0

# Load all example files from the ./examples directory
example_files = Dir['./examples/*.em']

max_width = example_files.max do |a, b|
    a.length <=> b.length
end.length

Benchmark.bm(max_width) do |x|
    example_files.each do |file|
        # next unless file == './examples/references.em' # nocheckin
        x.report(file) do
            begin
                tokens = Lexer.new(File.read(file).to_s).lex
                ast    = Parser.new(tokens).to_ast
                Runtime.new(ast).evaluate_expressions
            rescue Exception => e
                raise e
            end
            @tests_ran += 1
        end
    end
end

puts "\n◼︎ #{@tests_ran} tests passed"
