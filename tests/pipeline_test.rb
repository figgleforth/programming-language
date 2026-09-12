require 'minitest/autorun'
require_relative '../source/main'
require_relative 'base_test'

class Pipeline_Test < Base_Test
	def test_interp
		assert_equal 42, Code::Interpreter.new.run("42")
	end

	def test_lex
		result = Code::Lexer.new("42").output
		assert_instance_of ::Array, result
		assert_instance_of Code::Lexeme, result.first
	end

	def test_parse
		lexemes = Code::Lexer.new("42").output
		result  = Code::Parser.new(lexemes).output
		assert_instance_of ::Array, result
		assert_instance_of Code::Number_Expr, result.first
	end

	def test_documenter
		code = <<~CODE
		    # a comment
		    1 + 1 # another comment
		CODE
		lexemes     = Code::Lexer.new(code).output
		expressions = Code::Parser.new(lexemes).output
		result      = Code::Documenter.new(expressions).output
		assert_equal ['a comment', 'another comment'], result.map(&:value)
	end

	def test_type_checker
		lexemes     = Code::Lexer.new("42").output
		expressions = Code::Parser.new(lexemes).output
		assert_nil Code::Type_Checker.new(expressions).output
	end
end
