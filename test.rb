# This code runs all .em files in ./examples through the lexer, parser, and runtime. todo: better testing, this'll do for now

require_relative 'source/lexer/lexer'
require_relative 'source/parser/parser'
require_relative 'source/interpreter/interpreter'
require 'benchmark'

@print_output = true

# lexer and parser always run because I wanna make sure they work. This only controls their output
output_lexed  = true
output_parsed = true
interpret     = false

# tests = Dir['./examples/*.em'].shuffle
tests     = ['./examples/lexer.em'] # temporary override
max_width = tests.max { _1.length <=> _2.length }.length # the Benchmark output needs to know how wide the column of report names is, so it'll be the longest filename

def puts_with_title title, things
	return unless @print_output
	puts ":: #{title} ::"
	Array(things).each { pp(_1) }
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
					puts_with_title 'Lexer', t
				end

				if output_parsed
					a = exprs.reject { _1 == "\n" }
					puts_with_title 'Parser', a
				end

				# if interpret # todo
				# end
			rescue Exception => e
				raise "Testing file #{file} failed with \n\t#{e}"
			end
		end
	end
end
