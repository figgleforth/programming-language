module Air
	class Out_Of_Tokens < RuntimeError
	end

	class Undeclared_Identifier < RuntimeError
	end

	class Cannot_Reassign_Constant < RuntimeError
	end

	class Cannot_Assign_Incompatible_Type < RuntimeError
	end

	class Cannot_Assign_Undeclared_Identifier < RuntimeError
	end

	class Cannot_Initialize_Non_Type_Identifier < RuntimeError
	end

	class Invalid_Dictionary_Key < RuntimeError
	end

	class Invalid_Dictionary_Infix_Operator < RuntimeError
	end

	class Invalid_Dot_Infix_Left_Operand < RuntimeError
	end

	class Invalid_Scoped_Identifier < RuntimeError
	end

	class Invalid_Http_Directive_Handler < RuntimeError
	end

	class Interpret_Expr_Not_Implemented < RuntimeError
	end

	class Unhandled_Circumfix_Expr < RuntimeError
	end

	class Unhandled_Infix < RuntimeError
	end

	class Unhandled_Prefix < RuntimeError
	end

	class Unhandled_Postfix < RuntimeError
	end

	class Unhandled_Call_Receiver < RuntimeError
	end

	class Unhandled_Array_Index_Expr < RuntimeError
	end

	class Assert_Triggered < RuntimeError
	end

	class Missing_Argument < RuntimeError
	end

	class Directive_Not_Implemented < RuntimeError
	end
end
