require_relative 'error_formatter'

module Ore
	class Error < StandardError
		attr_accessor :expression, :lexeme, :custom_message, :context
		attr_accessor :manual_location, :source_file

		def initialize expression_or_message = nil, context = nil, expression: nil, lexeme: nil, location: nil, source_file: nil
			if expression_or_message.is_a? String
				@custom_message = expression_or_message
				@expression     = expression
				@context        = context
			else
				@expression     = expression_or_message
				@context        = context
				@custom_message = error_message
			end

			@lexeme          = lexeme
			@manual_location = location
			@source_file     = source_file

			super format_error
		end

		def error_message
			"An error occurred"
		end

		def format_error
			Error_Formatter.new(self).format
		end
	end

	class Undeclared_Identifier < Error
		def error_message
			"Identifier '#{expression.value}' is not declared in current scope"
		end
	end

	class Cannot_Reassign_Constant < Error
		def error_message
			"Cannot reassign constant '#{expression.value}'"
		end
	end

	class Cannot_Assign_Incompatible_Type < Error
		def error_message
			"Cannot assign non-Scope value to Capitalized identifier '#{expression.left.value}'"
		end
	end

	class Cannot_Initialize_Non_Type_Identifier < Error
		def error_message
			"Cannot call () on '#{expression.value}' because it is not a type"
		end
	end

	class Invalid_Dictionary_Key < Error
		def error_message
			"Invalid dictionary key - must be an identifier, symbol, or string"
		end
	end

	class Invalid_Dictionary_Infix_Operator < Error
		def error_message
			"Invalid operator '#{expression.operator}' in dictionary literal - expected ':' or '='"
		end
	end

	class Invalid_Dot_Infix_Left_Operand < Error
		def error_message
			"Cannot use dot operator on non-scope value"
		end
	end

	class Unhandled_Prefix < Error
		def error_message
			"Unhandled prefix operator '#{expression.operator}'"
		end
	end

	class Unhandled_Postfix < Error
		def error_message
			"Unhandled postfix operator '#{expression.operator}'"
		end
	end

	class Missing_Argument < Error
		def error_message
			"Required parameter '#{expression}' is missing"
		end
	end

	class Assert_Triggered < Error
		def error_message
			"Assertion failed"
		end
	end

	class Invalid_Http_Directive_Handler < Error
		def error_message
			"HTTP route handler must be a function"
		end
	end

	class Invalid_Start_Diretive_Argument < Error
		def error_message
			"#start directive expects a Server instance"
		end
	end

	class Directive_Not_Implemented < Error
		def error_message
			"Directive '##{expression.name.value}' is not implemented"
		end
	end

	class Interpret_Expr_Not_Implemented < Error
		def error_message
			"Expression type #{expression.class.name} is not implemented in interpreter"
		end
	end

	class Out_Of_Tokens < Error
		def error_message
			"Unexpected end of input"
		end
	end

	class Unterminated_String_Literal < Error
		def error_message
			"String literal was not terminated"
		end
	end

	class Invalid_Scoped_Identifier < Error
		def error_message
			"Invalid scope operator usage"
		end
	end
end
