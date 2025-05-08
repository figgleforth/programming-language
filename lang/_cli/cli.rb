#!/usr/bin/env ruby

if ARGV.empty?
	puts "ERROR: Expected command line argument for source lang file.\nHOWTO: ruby /cli.rb your_source.em\n"
	exit 1
end


class CLI_Interpreter
	require_relative '../lexer/lexer'
	require_relative '../parser/parser'
	require_relative '../_runtime/_runtime'
	require 'pp'


	def initialize input_file
		@input = File.read input_file
	end


	def output
		# puts "input #{@input}"
		lexer = Lexer.new#(@input).lex
		tokens = lexer.lex @input
		# puts "■■■■ TOKENS\n"
		# tokens = tokens.chunk_while { |prev, curr| prev == curr }.flat_map { |chunk| chunk.first(1) } # ??? thanks to ChatGPT. squish duplicate tokens into one. Aimed at compacting multiple newlines
		# tokens.each {
		# 	if _1 == "\n"
		# 		puts
		# 	else
		# 		puts "#{_1.inspect}"
		# 	end
		# }

		expr = Parser.new(tokens).output
		puts "■■■■ EXPRESSIONS\n"
		expr.each {
			puts "#{_1.inspect}\n\n" unless _1.is_a? Delimiter_Token
		}

		# puts "■■■■ OUTPUT\n"
		# puts Runtime.new(expr).evaluate_expressions
		# puts "■■■■"
	end
end


interpreter = CLI_Interpreter.new ARGV[0]
interpreter.output
