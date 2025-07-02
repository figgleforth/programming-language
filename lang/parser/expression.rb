require './lang/constants'

class Expression
	attr_accessor :value, :type, :start_location, :end_location

	def initialize value = nil
		@value = value if value
	end

	def is compare
		if compare.is_a? Symbol
			compare == type
		elsif compare.is_a? String
			compare == value
		elsif compare.is_a? Class
			compare.is_a? self.class
		else
			compare == self
		end
	end

	def isnt compare
		is(compare) == false
	end
end

class Func_Expr < Expression
	attr_accessor :name, :expressions, :param_decls, :signature

	def initialize
		@param_decls = []
		@expressions = []
	end

	def signature
		sig = name || ''
		sig += '{'
		sig += param_decls.map do |param|
			label   = param.label ? "#{param.label}:" : ''
			default = param.default ? "=#{param.default}" : ''
			"#{label}#{param.name}#{default}"
		end.join(',')
		sig += ';'
		sig += '}'

		# #todo Maybe bring back extra signature details
		# if expressions.any?
		# 	n << '['
		# 	n << expressions.join(',')
		# 	n << ']'
		# end
	end
end

class Func_Decl < Func_Expr
	attr_accessor :name
end

# get '/' home {;}
# put 'whatever/:id' do_something {;}
# post 'book/:id/publish' do_something {;}
class Route_Decl < Func_Expr
	attr_accessor :name, :method, :path

	def initialize name, method, path
		@name   = name
		@path   = path
		@method = method
	end
end

class Operator_Decl < Func_Decl
	attr_accessor :fix # pre, in, post, circumfix
end

class Param_Decl < Expression
	attr_accessor :name, :label, :type, :default, :portal

	def initialize
		super
		@portal  = false
		@default = nil
		@name    = nil
		@label   = nil
		@type    = nil
	end
end

# #delete_param_expr
class Param_Expr < Expression
	attr_accessor :expression, :label
end

class Type_Decl < Expression
	attr_accessor :identifier, :expressions, :composition_exprs

	def initialize
		super
		@composition_exprs = []
		@expressions       = []
	end
end

# Useful reading
# https://stackoverflow.com/a/18533211/1426880
# https://stackoverflow.com/a/1235891/1426880
class Number_Expr < Expression
	attr_accessor :type, :decimal_position

	def initialize number
		self.value = number
	end

	def value= val
		@value = val.gsub('_', '')

		if @value.include?('.')
			@value = @value.to_f
			@type  = :float
		else
			@value = @value.to_i
			@type  = :integer
		end
	end
end

class Symbol_Expr < Expression
end

class String_Expr < Expression
	attr_accessor :interpolated

	def initialize string
		super string
		@interpolated = string.include? COMMENT_CHAR # if at least one ` is present then it should be interpolated, if formatted properly.
	end
end

class Array_Expr < Expression
	attr_accessor :elements

	def initialize
		super nil
		@elements = []
	end
end

class Prefix_Expr < Expression
	attr_accessor :operator, :expression
end

class Postfix_Expr < Expression
	attr_accessor :operator, :expression
end

class Infix_Expr < Expression
	attr_accessor :operator, :left, :right

	def initialize
		super
	end
end

class Circumfix_Expr < Expression
	attr_accessor :grouping, :expressions

	def initialize(grouping = '(')
		@expressions = []
		@grouping    = grouping
	end
end

class Operator_Expr < Expression
	attr_accessor :custom, :precedence
end

class Identifier_Expr < Expression
end

class Key_Identifier_Expr < Identifier_Expr
end

class Composition_Expr < Expression
	attr_accessor :operator, :identifier
end

class Class_Composition_Expr < Composition_Expr
	attr_accessor :alias_identifier
end

class Conditional_Expr < Expression
	attr_accessor :condition, :when_true, :when_false

	def initialize
		super
		@when_true  = []
		@when_false = []
	end
end

class Raise_Expr < Expression
	attr_accessor :name, :expression
end

class Nil_Expr < Expression
end

class Return_Expr < Expression
	attr_accessor :expression
end

class Call_Expr < Expression
	attr_accessor :receiver, :arguments

	def initialize
		super
		@arguments = []
	end
end

class Subscript_Expr < Expression
	attr_accessor :receiver, :expression
end

class Enum_Decl < Expression
	attr_accessor :identifier, :expression
end
