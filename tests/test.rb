# This code runs all .em files in ./examples through the lexer, parser, and runtime

require_relative '../source/lexer/lexer'
require_relative '../source/parser/parser'
require_relative '../source/interpreter/runtime'
require_relative '../source/colorize'
require 'benchmark'

output_lexed  = false
output_parsed = false
interpret_ast = false # this one is intentionally gating interpreting as well as output because this breaks a lot, and sometimes I need to see the tokens or ast without evaluating

tests     = Dir['./examples/*.em'].shuffle
tests     = ['./examples/_.em'] # temporary override
max_width = tests.max { _1.length <=> _2.length }.length # the Benchmark output needs to know how wide the column of report names is, so it'll be the longest filename

def output things, section_name, section_color = 'white', pretty = false
	title = "——— #{section_name} ———"
	puts colorize(73, title, 'black')
	things.each {
		if pretty
			pp _1
		else
			puts _1
		end
	}
end


Benchmark.bm(max_width) do |x|
	tests.each do |file|
		x.report(file) do
			begin
				code   = File.read(file).to_s
				tokens = Lexer.new(code).lex
				if output_lexed
					t = tokens.reject { _1 == Delimiter_Token }
					output t, 'LEXER', 73
				end

				ast = Parser.new(tokens, code).to_expr
				if output_parsed
					a = ast.reject { _1 == "\n" }
					output a, 'PARSER', 99
				end

				if interpret_ast
					o = Runtime.new(ast).evaluate_expressions
					output o, 'PARSER', 168
				end
			rescue Exception => e
				raise "Testing file #{file} failed with \n\t#{e}"
			end
		end
	end
end
