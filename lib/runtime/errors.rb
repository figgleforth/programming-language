class Air_Error < RuntimeError
end

class Out_Of_Tokens < Air_Error
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

class Invalid_Dictionary_Key < Air_Error
end

class Invalid_Dictionary_Infix_Operator < Air_Error
end

class Invalid_Dot_Infix_Left_Operand < Air_Error
end

class Invalid_Scoped_Identifier < Air_Error
end

class Invalid_Http_Directive_Handler < Air_Error
end

class Interpret_Expr_Not_Implemented < Air_Error
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

class Missing_Argument < Air_Error
end

class Directive_Not_Implemented < Air_Error
end
