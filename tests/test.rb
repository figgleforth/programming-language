require 'benchmark'
@tests_ran = 0

puts

Benchmark.bm(12) do |x|
    x.report('parser:') { require_relative 'parser' }
    x.report('interpreter:') { require_relative 'interpreter' }
end

puts "\nPassed #{@tests_ran} tests"
