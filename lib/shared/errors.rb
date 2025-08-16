class Air_Error < RuntimeError
	attr_accessor :expr

	def initialize expr
		super
		@expr = expr
	end
end

class Undeclared_Identifier < Air_Error
end

class Cannot_Reassign_Constant < Air_Error
end

class Cannot_Assign_Incompatible_Type < Air_Error
end

class Cannot_Assign_Undeclared_Identifier < Air_Error
end

class Cannot_Initialize_Non_Type_Identifier < Air_Error
end

class Unhandled_Expr < Air_Error
end

class Invalid_Dictionary_Key < Air_Error
end

class Invalid_Dictionary_Infix_Operator < Air_Error
end

class Invalid_Dot_Infix_Left_Operand < Air_Error

end

class Unhandled_Circumfix_Expr < Air_Error
end

class Unhandled_Infix < Air_Error
end

class Unhandled_Prefix < Air_Error
end

class Unhandled_Postfix < Air_Error
end

class Unhandled_Call_Receiver < Air_Error
end

class Unhandled_Array_Index_Expr < Air_Error
end

class Assert_Triggered < Air_Error
end

class Malformed_Scoped_Identifier < Air_Error
end

class Missing_Argument < Air_Error
end
