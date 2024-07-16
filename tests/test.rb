require 'benchmark'
@tests_ran = 0

puts

Benchmark.bm(12) do |x|
    x.report('parser') { require_relative 'parser' }
    x.report('interpreter') { require_relative 'interpreter' }
    x.report('sandbox em') do
        tokens = Lexer.new(File.read('tests/sandbox.em').to_s).lex
        ast    = Parser.new(tokens).to_ast
    end
end

puts "\nPassed #{@tests_ran} tests"
