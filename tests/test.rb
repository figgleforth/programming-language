require 'benchmark'
@tests_ran = 0

puts

Benchmark.bm(14) do |x|
    x.report('parser.rb') { require_relative 'parser' }
    x.report('interpreter.rb') { require_relative 'interpreter' }
    x.report('sandbox.em') do
        tokens = Lexer.new(File.read('tests/sandbox.em').to_s).lex
        ast    = Parser.new(tokens).to_ast
    end
end

puts "\nPassed #{@tests_ran} tests"
