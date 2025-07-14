class Emerald_Error < RuntimeError
	attr_accessor :expr

	def initialize expr
		super
		@expr = expr
	end
end

class Cannot_Reassign_Constant < Emerald_Error
end

class Undeclared_Identifier < Emerald_Error
end

class Cannot_Assign_Undeclared_Identifier < Emerald_Error
end

class Cannot_Initialize_Undeclared_Identifier < Emerald_Error
end

class Unhandled_Expr < Emerald_Error
end

class Invalid_Dictionary_Key < Emerald_Error
end

class Invalid_Dictionary_Infix_Operator < Emerald_Error
end

class Invalid_Dot_Infix_Left_Operand < Emerald_Error

end

class Unhandled_Circumfix_Expr < Emerald_Error
end

class Unhandled_Infix < Emerald_Error
end

class Unhandled_Prefix < Emerald_Error
end

class Unhandled_Postfix < Emerald_Error
end

class Unhandled_Call_Receiver < Emerald_Error
end

class Unhandled_Array_Index_Expr < Emerald_Error
end

class Assert_Triggered < Emerald_Error
end

class Multiple_Runtime_Errors < Emerald_Error
	attr_accessor :errors
end
