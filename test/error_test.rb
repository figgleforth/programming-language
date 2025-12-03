require 'minitest/autorun'
require_relative '../lib/ore'
require_relative 'base_test'

class Error_Test < Base_Test
	def test_undeclared_identifier
		error = assert_raises Ore::Undeclared_Identifier do
			Ore.interp 'does_not_exist'
		end

		assert_equal "Identifier 'does_not_exist' is not declared in current scope",
		             error.error_message

		# Test that formatted message has key components
		assert_includes error.message, "Undeclared_Identifier"
		assert_includes error.message, "does_not_exist"

		error = assert_raises Ore::Undeclared_Identifier do
			Ore.interp_file 'test/fixtures/undeclared_identifier.ore'
		end

		assert_includes error.message, "undeclared_identifier.ore:3:5"
		assert_match /\d+ \|/, error.message # Line numbers
		assert_match /\^+/, error.message # Arrow indicators
		assert_includes error.message, ".ore:" # Filename with location
	end
end
