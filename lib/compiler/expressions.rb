module Ore
	class Expression
		attr_accessor :value, :type, :l0, :c0, :l1, :c1, :source_file

		def initialize value = nil
			@value = value if value
		end

		def is compare
			if compare.is_a? Symbol
				compare == type
			elsif compare.is_a? ::String
				compare == value
			elsif compare.is_a? Class
				compare.new.is_a? self.class
			else
				compare == self
			end
		end

		def isnt compare
			is(compare) == false
		end

		def location
			return nil unless l0 && c0
			"#{source_file}:#{l0}:#{c0}" if source_file
			"#{l0}:#{c0}"
		end

		def line_col
			"#{l0}:#{c0}..#{l1}:#{c1}" if l0
		end
	end

	class Param_Expr < Expression
		attr_accessor :name, :label, :type, :default, :unpack

		def initialize
			super
			@unpack  = false
			@default = nil
			@name    = nil
			@label   = nil
			@type    = nil
		end

		alias_method :expression, :default # todo, Replace @default with this
	end

	class Func_Expr < Expression
		attr_accessor :name, :expressions, :signature

		def initialize
			@expressions = []
		end

		def signature
			sig         = name&.value || ''
			sig         += '{'
			param_decls = expressions.select do |expr|
				expr.is_a? Param_Expr
			end
			sig         += param_decls.map do |param|
				label   = param.label ? "#{param.label}:" : ''
				default = param.default ? "=#{param.default}" : ''
				"#{label}#{param.name}#{default}"
			end.join(',')
			sig         += ';'
			sig         += '}'
			sig
			# todo, Maybe bring back extra signature details.
			# if expressions.any?
			# 	n << '['
			# 	n << expressions.join(',')
			# 	n << ']'
			# end
		end
	end

	# get:// {;}
	# put://whatever/:id {id;}
	# post://book/:id/publish {id;}
	class Route_Expr < Expression
		attr_accessor :http_method, :path, :expression, :param_names # The expression can be a function or an identifier
	end

	class Directive_Expr < Expression
		attr_accessor :name, :expression
	end

	class Type_Expr < Expression
		attr_accessor :name, :expressions

		def initialize
			super
			@expressions = []
		end
	end

	# Useful reading.
	# https://stackoverflow.com/a/18533211/1426880
	# https://stackoverflow.com/a/1235891/1426880
	class Number_Expr < Expression
		attr_accessor :type
	end

	class Symbol_Expr < Expression
	end

	class String_Expr < Expression
		attr_accessor :interpolated

		def initialize string
			super string
			@interpolated = string.include? INTERPOLATE_CHAR
			# todo, This is a naive check. What if there is only one | char? Then it can't be a valid interpolation.
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
	end

	class Circumfix_Expr < Expression
		attr_accessor :grouping, :expressions

		def initialize grouping = '()'
			@expressions = []
			@grouping    = grouping
		end
	end

	class Operator_Expr < Expression
		attr_accessor :custom, :precedence
	end

	class Identifier_Expr < Expression
		attr_accessor :kind, :unpack, :scope_operator, :directive, :privacy, :binding
	end

	class Composition_Expr < Expression
		attr_accessor :operator, :identifier
	end

	class Conditional_Expr < Expression
		attr_accessor :condition, :when_true, :when_false

		def initialize
			super
			@when_true  = []
			@when_false = []
		end
	end

	class Return_Expr < Prefix_Expr
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

	class Array_Index_Expr < Expression
		attr_accessor :indices_in_order
	end

	class For_Loop_Expr < Expression
		attr_accessor :collection, :stride, :body
	end

	class Comment_Expr < Expression
	end

	class Html_Element_Expr < Expression
		# <element> {
		#     ...attributes
		#     render {;}
		# }
		# 11/2/25, TODO: Maybe this class should inherit from Type_Expr since this is just a type/class anyway? :html_vs_type_expr
		attr_accessor :expressions, :element

		def initialize element
			super element
			@element = element
		end
	end
end
