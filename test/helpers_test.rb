require 'minitest/autorun'
require_relative '../lib/ore'
require_relative '../lib/shared/helpers'
require_relative 'base_test'

class Helpers_Test < Base_Test
	include Helpers

	def test_access_level_public
		assert_equal :public, access_level('identifier')
		assert_equal :public, access_level('someMethod')
		assert_equal :public, access_level('CONSTANT')
		assert_equal :public, access_level('ClassName')
	end

	def test_access_level_private
		assert_equal :private, access_level('_identifier')
		assert_equal :private, access_level('_someMethod')
		assert_equal :private, access_level('_CONSTANT')
		assert_equal :private, access_level('_ClassName')
	end

	def test_access_level_with_trailing_underscore
		assert_equal :public, access_level('identifier_')
		assert_equal :public, access_level('CONSTANT_')
		assert_equal :private, access_level('_identifier_')
		assert_equal :private, access_level('_CONSTANT_')
	end

	def test_binding_level_instance
		assert_equal :instance, binding_level('identifier')
		assert_equal :instance, binding_level('someMethod')
		assert_equal :instance, binding_level('CONSTANT')
		assert_equal :instance, binding_level('_privateMethod')
	end

	def test_binding_level_static
		assert_equal :static, binding_level('identifier_')
		assert_equal :static, binding_level('someMethod_')
		assert_equal :static, binding_level('CONSTANT_')
		assert_equal :static, binding_level('ClassName_')
	end

	def test_binding_level_private_static
		assert_equal :static, binding_level('_privateMethod_')
		assert_equal :static, binding_level('_PRIVATE_CONSTANT_')
	end

	def test_combined_access_and_binding
		# public instance
		ident = 'count'
		assert_equal :public, access_level(ident)
		assert_equal :instance, binding_level(ident)

		# public static
		ident = 'count_'
		assert_equal :public, access_level(ident)
		assert_equal :static, binding_level(ident)

		# private instance
		ident = '_count'
		assert_equal :private, access_level(ident)
		assert_equal :instance, binding_level(ident)

		# private static
		ident = '_count_'
		assert_equal :private, access_level(ident)
		assert_equal :static, binding_level(ident)
	end

	def test_constant_identifier
		assert constant_identifier?('CONSTANT')
		assert constant_identifier?('ALL_CAPS')
		assert constant_identifier?('MAX_RETRIES')
		refute constant_identifier?('notConstant')
		refute constant_identifier?('Capitalized')
		refute constant_identifier?('mixedCase')
	end

	def test_type_identifier
		assert type_identifier?('ClassName')
		assert type_identifier?('Type_Name')
		assert type_identifier?('Person')
		assert type_identifier?('_PrivateClass')
		refute type_identifier?('lowercase')
		refute type_identifier?('CONSTANT')
	end

	def test_member_identifier
		assert member_identifier?('variable')
		assert member_identifier?('method_name')
		assert member_identifier?('camelCase')
		refute member_identifier?('ClassName')
		refute member_identifier?('CONSTANT')
	end

	def test_type_of_identifier
		assert_equal :IDENTIFIER, type_of_identifier('CONSTANT')
		assert_equal :IDENTIFIER, type_of_identifier('MAX_VALUE')
		assert_equal :Identifier, type_of_identifier('ClassName')
		assert_equal :Identifier, type_of_identifier('Person')
		assert_equal :identifier, type_of_identifier('variable')
		assert_equal :identifier, type_of_identifier('methodName')
	end

	def test_type_of_identifier_with_leading_underscores
		assert_equal :IDENTIFIER, type_of_identifier('_CONSTANT')
		assert_equal :Identifier, type_of_identifier('_ClassName')
		assert_equal :identifier, type_of_identifier('_variable')
	end

	def test_type_of_identifier_operators
		assert_equal :operator, type_of_identifier('and')
		assert_equal :operator, type_of_identifier('or')
		assert_equal :operator, type_of_identifier('not')
		assert_equal :operator, type_of_identifier('unless')
		assert_equal :operator, type_of_identifier('return')
	end

	def test_type_of_number_expr
		assert_equal :integer, type_of_number_expr('42')
		assert_equal :integer, type_of_number_expr('0')
		assert_equal :float, type_of_number_expr('3.14')
		assert_equal :float, type_of_number_expr('0.5')
		assert_equal :array_index, type_of_number_expr('1.2.3')
		assert_equal :array_index, type_of_number_expr('0.0.0')
	end
end
