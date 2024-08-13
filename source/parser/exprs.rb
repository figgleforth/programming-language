require 'pp'


class Expr
	attr_accessor :string, :tokens


	def tokens
		@tokens ||= []
	end


	# @return self in pretty format [String]
	def pp
		PP.pp(self, '').chomp
	end


	def == other
		return false if other.nil?
		if other.is_a? Class
			other == self.class or self.is_a?(other)
		else
			other == string
		end
	end


	def === other
		return false if other.nil?
		other == self.class or self.is_a?(other)
	end
end


class Func_Expr < Expr
	attr_accessor :expressions, :compositions, :parameters, :signature


	def initialize
		@parameters  = []
		@expressions = []
	end


	# def before_hook_expressions # any expressions that are `@before some_function`
	# 	expressions.select do |s|
	# 		s.is_a? Block_Hook_Expr
	# 	end
	# end

	# def non_composition_expressions
	# 	expressions.select do |s|
	# 		s != Class_Composition_Expr
	# 	end
	# end

	# def composition_expressions
	# 	expressions.select do |s|
	# 		s == Class_Composition_Expr
	# 	end
	# end

	def named?
		not name.nil?
	end


	def function_declaration?
		not name.nil?
	end


	def signature # to support multiple methods with the same name, each method needs to be able to be represented as a signature. Naive idea: name+block.parameters.names.join(,)
		@signature ||= "#{name}".tap do |it|
			parameters.each do |param|
				# it: Function_Param_Expr
				# maybe also use compositions in the signature for better control over signature equality
				it << "#{param.label}:#{param.name}=#{param.default_expression}"
			end
		end
	end


	# def inspect
	# 	'{'.tap do |str|
	# 		str << "#{parameters.map(&:inspect).join(', ')} (#{parameters.count})" unless parameters.empty?
	# 		str << '->'
	# 		# str << "comps(#{composition_expressions.count}): #{composition_expressions.map(&:inspect)}, " unless composition_expressions.empty?
	# 		# str << "exprs(#{non_composition_expressions.count}): #{non_composition_expressions.map(&:inspect)}" unless non_composition_expressions.empty?
	# 		str << '}' unless false
	# 	end
	# end
end


class Func_Decl < Func_Expr
	attr_accessor :name

	# def inspect
	# 	"#{name.string}#{super}"
	# end
end


class Operator_Decl < Func_Decl

end


class Func_Param_Decl < Expr
	attr_accessor :name, :label, :type, :default_expression, :composition


	def initialize
		super
		@composition        = false
		@default_expression = nil
		@name               = nil
		@label              = nil
		@type               = nil
	end


	# def inspect
	# 	'Param('.tap {
	# 		_1 << '%' if composition
	# 		_1 << "#{label.string}: " if label
	# 		_1 << "#{name.string}"
	# 		_1 << " = #{default_expression.inspect}" if default_expression
	# 		_1 << '}'
	# 	}
	# end
end


# todo rename to Param_Expr
class Call_Arg_Expr < Expr
	attr_accessor :expression, :label

	# def inspect
	# 	"Arg(".tap do |str|
	# 		str << "label: #{label}, " if label
	# 		str << expression.inspect
	# 		str << ')'
	# 	end
	# end
end


class Block_Call_Expr < Expr
	attr_accessor :name, :arguments


	def initialize
		super
		@arguments = []
	end


	# def inspect
	# 	"#{false ? '' : 'fun_call'}(name: #{name}".tap do |str|
	# 		str << ", #{arguments.map(&:inspect)}" if arguments
	# 		str << ')'
	# 	end
	# end

end


class Class_Decl < Expr
	attr_accessor :name, :block, :base_class, :compositions
	# todo) remove base_class because a class can be a collection of types, so `Player > Input, Renderer, Inventory {}` means this class is simultaneously Player, Input, Renderer, and Inventory. That's because by composing, these classes are able to respond to methods that Input, Renderer, etc are normally able to.

	def initialize
		super
		@compositions = []
	end


	# def inspect_print(pp)
	#     pp.text "Class_Decl"
	# end

	# def inspect
	# 	"#{name.string}{#{block.expressions.inspect}}"
	# end
end


class Number_Literal_Expr < Expr
	attr_accessor :type, :decimal_position


	def initialize
		super
	end


	def string= val
		@string = val
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


	#
	# def inspect
	# 	string
	# end

	# Useful reading
	# https://stackoverflow.com/a/18533211/1426880
	# https://stackoverflow.com/a/1235891/1426880
end


class Symbol_Literal_Expr < Expr
	# def inspect
	# 	long  = "Sym(:#{string})"
	# 	short = ":#{string}"
	# 	false ? short : long
	# end

	def to_symbol
		":#{string}"
	end
end


class Boolean_Literal_Expr < Expr
	# def inspect
	# 	long  = "Bool(:#{string})"
	# 	short = ":#{string}"
	# 	false ? short : long
	# end

	def to_bool
		return true if string == "true"
		return false if string == "false"
		raise "Boolean_Literal_Expr should be either true or false, but is #{string.inspect}"
	end
end


class String_Literal_Expr < Expr
	attr_accessor :interpolated


	def string= val
		@string       = val
		@interpolated = val.include? '`' # todo: is there a better way?
	end


	def to_string
		"\"#{string}\""
	end


	# def inspect
	# 	# string.inspect
	# 	"Str(#{string.inspect})"
	# end
end


class Tuple_Expr < Expr # one or more comma, or maybe even space-separated, expressions
	# @return [Array] of comma separated expressions that make up this Expr
	attr_accessor :grouping, :expressions


	def initialize(grouping = '{')
		@expressions = []
		@grouping    = grouping
	end


	def empty?
		expressions.empty?
	end


	# def inspect
	# 	"(#{expressions.map(&:inspect).join(', ')})"
	# end
end


class Hash_Expr < Expr
	attr_accessor :keys, :values # ??? these two zipped together will for the key/val pairs

	def initialize
		super
		@keys   = []
		@values = []
	end


	# def inspect
	# 	zipped = keys.zip(values).map {
	# 		key, val = _1
	# 		"#{key.inspect} ~> #{val.inspect}"
	# 	}.join(', ')
	# 	"Hash{#{zipped}}(#{keys.count})#"
	# end
end


class Set_Expr < Expr
	attr_accessor :elements, :grouping


	def initialize
		super
		@elements = [] # ??? this will be operated on as if it were a set, later on at Runtime
	end


	# def inspect
	# 	"Set##{elements.count}#{grouping[0]}#{elements.map(&:inspect).join(', ')}#{grouping[-1]}"
	# end
end


class Array_Expr < Expr
	attr_accessor :elements


	def initialize
		super
		@elements = []
	end


	# def inspect
	# 	"[#{elements.map(&:to_s).join(',')}]"
	# end
end


class Prefixed_Expr < Expr
	attr_accessor :operator, :expression


	def to_s
		"#{operator}#{expression}"
	end
end


class Postfixed_Expr < Expr
	attr_accessor :operator, :expression

	#
	# def inspect
	# 	"Postfix(#{expression.inspect} #{operator.inspect})"
	# end
end


class Infix_Expr < Expr # ??? aka Infixed_Expr. I'm not sure if I want to keep the old name or not. It isn't named like the other *fix operators even though it relates to them. We'll see if I get confused or not
	attr_accessor :operator, :left, :right


	def initialize
		super
	end


	def to_s
		"(#{left.to_s} #{operator.string} #{right.to_s})"
		inspect
	end
end


class Operator_Expr < Expr

	def == other
		other.is_a?(Operator_Expr) and other.string == string
	end


	def to_s
		"#{string.string}"
		inspect
	end
end


class Identifier_Expr < Expr
	def identifier
		string
	end


	def to_s
		# 	# if string.class?
		# 	# 	"Class(#{string.inspect})"
		# 	# elsif string.constant?
		# 	# 	"CONSTANT(#{string.inspect})"
		# 	# elsif string.member?
		# 	# 	"member(#{string.inspect})"
		# 	# end
		"#{string.string}"
	end


	def == other
		other.is_a?(Identifier_Expr) and other.string == string
	end

end


class Key_Identifier_Expr < Identifier_Expr
	# def inspect
	# 	"Key_Ident(#{string})"
	# end
end


class Enum_Expr < Expr
	attr_accessor :name, :constants


	def initialize
		super
		@constants = []
	end
end


class Enum_Constant_Expr < Expr
	attr_accessor :name, :value
end


class At_Operator_Expr < Expr
	attr_accessor :identifier, :expression
end


# class Block_Hook_Expr < At_Operator_Expr
# 	attr_accessor :target_function_identifier
# end

class Composition_Expr < Expr
	attr_accessor :operator, :expression
end


class Block_Composition_Expr < Composition_Expr
	attr_accessor :name
end


class Class_Composition_Expr < Composition_Expr
	attr_accessor :alias_identifier

	#
	# def inspect
	# 	if false
	# 		"#{operator}#{expression}#{alias_identifier ? " = #{alias_identifier}" : ''}"
	# 	else
	# 		"comp(#{operator}#{expression}#{alias_identifier ? " = #{alias_identifier}" : ''})"
	# 	end
	# end
end


class Conditional_Expr < Expr
	attr_accessor :condition, :when_true, :when_false

	# def inspect
	# 	"if #{condition.inspect}".tap do |str|
	# 		if when_true
	# 			str << " then #{when_true.expressions.map(&:inspect)}"
	# 		end
	# 		if when_false
	# 			if when_false.is_a? Conditional_Expr
	# 				str << " else #{when_false.inspect}"
	# 			else
	# 				str << " else #{when_false.expressions.map(&:inspect)}"
	# 			end
	# 		end
	# 	end
	# end
end


class While_Expr < Expr
	attr_accessor :condition, :when_true, :when_false

	#
	# def inspect
	# 	"while #{condition}".tap do |str|
	# 		if when_true
	# 			str << " then #{when_true.expressions.map(&:inspect)}"
	# 		end
	# 		if when_false
	# 			if when_false.is_a? While_Expr
	# 				str << " else #{when_false.to_s}"
	# 			else
	# 				str << " else #{when_false.expressions.map(&:inspect)}"
	# 			end
	# 		end
	# 	end
	# end
end


class Raise_Expr < Expr # expressions that can halt the program. Right now that's oops and >~
	attr_accessor :name, :expression
end


class Nil_Expr < Expr
end


class Return_Expr < Expr
	attr_accessor :expression
end


class Call_Expr < Expr
	attr_accessor :receiver, :arguments

	#
	# def inspect
	# 	"#{receiver.inspect}(#{arguments.map(&:inspect).join(', ')})"
	# end
end


class Route_Decl < Func_Expr
	# request_method, String_Literal, Identifier_Token, {
	# eg. get '/' home { -> }
	attr_accessor :route, :name
end


class Enum_Decl < Expr
=begin
	CONST = expr
	CONST { (recurse)
=end
	attr_accessor :identifier, :expression
end
