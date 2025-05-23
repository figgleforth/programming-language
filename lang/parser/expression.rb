require 'pp'

# todo clean up attrs

class Expression
	attr_accessor :value, :type, :start_location, :end_location

	def initialize value = nil
		@value = value if value
	end

	def is other
		if other.is_a?(Symbol) || other.is_a?(String)
			value == other
		else
			raise 'Cannot == except with String or Symbol'
		end
	end
end

class Func_Expr < Expression
	attr_accessor :name, :expressions, :composition_exprs, :param_decls, :signature

	def initialize
		@param_decls  = []
		@expressions  = []
		@compositions = []
	end

	def signature
		(name || '').tap do |n|
			n << '{'
			n << param_decls.map do |param|
				label   = param.label ? "#{param.label}:" : ''
				default = param.default ? "=#{param.default}" : ''
				"#{label}#{param.name}#{default}"
			end.join(',')
			n << ';'

			if expressions.any?
				n << '['
				n << expressions.join(',')
				n << ']'
			end
			n << '}'
		end
	end

	def to_s
		signature
	end
end

class Func_Decl < Func_Expr
	attr_accessor :name

	def to_s
		word = if expressions.count == 1
			'expression'
		else
			'expressions'
		end
		"#{self.class.name}(#{name.value}{#{param_decls.join(', ')}; #{expressions.map(&:to_s)}})"
	end
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

	def to_s
		"#{fix.value} #{name.value} {#{param_decls.map(&:name).map(&:value).join(',')};}"
	end
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

class Param_Expr < Expression
	attr_accessor :expression, :label

	def to_s
		if label
			"#{label.value}: #{expression}"
		else
			expression.to_s
		end
	end
end

class Type_Decl < Expression
	attr_accessor :identifier, :expressions, :composition_exprs

	def initialize
		super
		@composition_exprs = []
		@expressions       = []
	end

	def to_s
		"#{identifier}{c:#{composition_exprs.map(&:to_s)}, e:#{expressions.map(&:to_s)}}"
	end
end

class Number_Expr < Expression
	attr_accessor :type, :decimal_position

	def initialize number
		@value = number
	end

	def value= val
		@value = val.gsub('_', '')
		if val[0] == '.'
			@type             = :float
			@decimal_position = :start
		elsif val[-1] == '.'
			@type             = :float
			@decimal_position = :end
		elsif val&.include? '.'
			@type             = :float
			@decimal_position = :middle
		else
			@type = :int
		end
	end

	def to_s
		value
	end

	# def to_s
	# 	"#{self.class.name}(#{string})"
	# end

	# Useful reading
	# https://stackoverflow.com/a/18533211/1426880
	# https://stackoverflow.com/a/1235891/1426880
end

class Symbol_Expr < Expression
	def to_symbol
		":#{string}"
	end
end

class String_Expr < Expression
	attr_accessor :interpolated

	def initialize string
		super string
		@interpolated = string.include? Lexer::COMMENT_CHAR # if at least one ` is present then it should be interpolated, if formatted properly.
	end

	def to_s
		value.inspect
	end
end

class Dict_Expr < Expression
	attr_accessor :expressions # holds Infix_Exprs

	def initialize
		super
		@expressions = []
	end

	def to_s
		"Dict(#{expressions.count}){#{expressions.map(&:to_s)}}"
	end
end

class Array_Expr < Expression
	attr_accessor :elements

	def initialize
		super
		@elements = []
	end

	def to_s
		"[#{elements.map(&:to_s).join(',')}]"
	end
end

class Prefix_Expr < Expression
	attr_accessor :operator, :expression

	def to_s
		"Prefix(#{operator}#{expression.to_s})"
	end
end

class Postfix_Expr < Expression
	attr_accessor :operator, :expression

	def to_s
		"Postfix(#{expression}#{operator}))"
	end
end

class Infix_Expr < Expression
	attr_accessor :operator, :left, :right

	def initialize
		super
	end

	def to_s
		"Infix(#{left&.value || left.to_s} #{operator} #{right&.value || right.to_s})"
	end
end

class Circumfix_Expr < Expression # one or more comma, or maybe even space-separated, expressions
	# @return [Array] of comma separated expressions that make up this Expr
	attr_accessor :grouping, :expressions

	def initialize(grouping = '(')
		@expressions = []
		@grouping    = grouping
	end

	def empty?
		expressions.empty?
	end

	def to_s
		"Set#{grouping[0]}#{expressions.map(&:to_s).join(', ')}#{grouping[1]}"
	end
end

class Operator_Expr < Expression
	attr_accessor :custom, :precedence

	def to_s
		"#{value}"
	end
end

class Identifier_Expr < Expression
	def to_s
		value
	end
end

class Key_Identifier_Expr < Identifier_Expr
end

class Composition_Expr < Expression
	attr_accessor :operator, :expression

	def to_s
		"Comp(#{operator}#{expression})"
	end
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

class Raise_Expr < Expression # expressions that can halt the program. Right now that's oops and >~
	attr_accessor :name, :expression
end

class Nil_Expr < Expression
end

class Return_Expr < Expression
	attr_accessor :expression
end

class Call_Expr < Expression
	attr_accessor :receiver, :arguments

	#
	def to_s
		"#{receiver}(#{arguments.join(', ')})"
	end
end

class Enum_Decl < Expression
=begin

CONST = some_expression
WEIRD_ALPHABET {
	A
	B {
		C
	}
}

WEIRD_ALPHABET.A
WEIRD_ALPHABET.B
WEIRD_ALPHABET.B.C
WEIRD_ALPHABET.A.D

=end
	attr_accessor :identifier, :expression
end
