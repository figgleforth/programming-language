require 'minitest/autorun'
require_relative '../src/ore'
require_relative 'base_test'

class Pipeline_Test < Base_Test
	def test_default_pipeline
		pipe = Ore::Pipeline.default
		assert_equal 42, pipe.run("42")
	end

	def test_lexer_only
		pipe = Ore::Pipeline.new Ore::Lexer
		assert_instance_of ::Array, pipe.run("42")
		assert_instance_of Ore::Lexeme, pipe.run("42").first
	end

	def test_lexer_and_parser_only
		pipe = Ore::Pipeline.new Ore::Lexer, Ore::Parser
		assert_instance_of ::Array, pipe.run("42")
		assert_instance_of Ore::Number_Expr, pipe.run("42").first
	end
end
