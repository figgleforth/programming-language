class Construct
end


class Assignment_Construct < Construct
	attr_accessor :name, :expression, :interpreted_value, :is_constant
	# @expression could be a Func_Expr or any other Ast
end


class Block_Construct < Construct
	attr_accessor :name, :block, :signature

end


class Class_Construct < Construct
	attr_accessor :name, :block, :base_class, :compositions
	# block is a Func_Expr representing the AST of the class's body
	# base_class is a string identifier representing the base class
end


class Instance_Construct < Construct
	@@ids = 0
	attr_accessor :scope, :class_construct
	attr_reader :id
	# todo: don't store the class_construct here. It's already stored in the scope under :classes, so just look it up when needed
	def initialize
		super
		@id   = @@ids
		@@ids += 1
	end


	def name
		class_construct&.name
	end

end


class Enum_Construct < Construct
	attr_accessor :name, :lookup_table, :scope


	def initialize
		super
		@lookup_table = []
	end
end


class Range_Construct < Construct
	attr_accessor :left, :operator, :right
end


class Nil_Construct < Construct
	attr_accessor :expression
end
