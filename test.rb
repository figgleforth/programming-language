# This code runs all .em files in ./examples through the lexer, parser, and runtime. todo: better testing, this'll do for now

require_relative 'source/lexer/lexer'
require_relative 'source/parser/parser'
require_relative 'source/interpreter/interpreter'
require_relative 'source/helpers/colorize'
require 'benchmark'

@print_output = true

# lexer and parser always run because I wanna make sure they work. This only controls their output
output_lexed  = true
output_parsed = true
interpret     = false

# tests = Dir['./examples/*.em'].shuffle
tests     = ['./examples/lexer.em'] # temporary override
max_width = tests.max { _1.length <=> _2.length }.length # the Benchmark output needs to know how wide the column of report names is, so it'll be the longest filename

def output things, section_name, section_color = 'white', pretty = true
	return unless @print_output
	title = "——— #{section_name} ———"
	puts colorize(section_color, title, 'black')
	if things.is_a? Array
		things.each {
			if pretty
				pp _1
			else
				puts _1
			end
		}
	else
		pp things
	end
end


Benchmark.bm(max_width) do |x|
	tests.each do |file|
		x.report(file) do
			begin
				code   = File.read(file).to_s
				tokens = Lexer.new(code).lex
				exprs  = Parser.new(tokens, code).to_expr

				if output_lexed
					t = tokens.reject { _1 == Delimiter_Token }
					output t, 'LEXER', 73
				end

				if output_parsed
					a = exprs.reject { _1 == "\n" }
					output a, 'PARSER', 99
				end

				if interpret
					output [], 'INTERPRETER', 142
					i = Interpreter.new exprs
					puts i.interpret
				end
			rescue Exception => e
				raise "Testing file #{file} failed with \n\t#{e}"
			end
		end
	end
end
