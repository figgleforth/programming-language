# This code runs all .e files in ./examples through the lexer, parser, and runtime. todo: better testing, this'll do for now

require_relative 'source/lexer/lexer'
require_relative 'source/parser/parser'
require_relative 'source/interpreter/interpreter'
require 'benchmark'

@print_output = true

# lexer and parser always run because I wanna make sure they work. This only controls their output
lex_and_output   = true
parse_and_output = false
interpret        = false

tests = Dir['./examples/*.f'].shuffle
# tests     = ['./examples/1.e'] # temporary override
max_width = tests.max { _1.length <=> _2.length }.length # the Benchmark output needs to know how wide the column of report names is, so it'll be the longest filename

def puts_with_title title, things
	return unless @print_output
	puts "#{title}:\n"
	Array(things).each { pp(_1) }
end

Benchmark.bm(max_width) do |x|
	tests.each do |file|
		x.report(file) do
			code = File.read(file).to_s

			if lex_and_output
				tokens = Lexer.new(code).lex
				t      = tokens.reject { _1 == Delimiter_Token }
				puts_with_title 'Lexer', t
			end

			if parse_and_output
				exprs = Parser.new(tokens, code).to_expr
				a     = exprs.reject { _1 == "\n" }
				puts_with_title 'Parser', a
			end

			# if interpret
			# todo
			# end
		end
	end
end
