require 'benchmark'
@tests_ran = 0

puts

Benchmark.bm(19) do |x|
    x.report('parser.rb') { require_relative 'parser' }
    x.report('interpreter.rb') { require_relative 'interpreter' }
    x.report('examples/sandbox.em') do
        tokens     = Lexer.new(File.read('examples/sandbox.em').to_s).lex
        ast        = Parser.new(tokens).to_ast
        @tests_ran += 1
    end
    x.report('examples/cli.em') do
        tokens     = Lexer.new(File.read('examples/cli.em').to_s).lex
        ast        = Parser.new(tokens).to_ast
        @tests_ran += 1
    end
end

puts "\n◼︎ #{@tests_ran} tests passed"
