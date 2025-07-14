require './src/shared/constructs'
require './src/shared/expressions'
require './src/shared/constants'
require './src/shared/errors'
require './src/shared/helpers'

class Interpreter
	attr_accessor :i, :input, :stack

	def initialize input = []
		@input = input
		@stack = [Scope.new(:global)]
	end

	def output
		input.each.inject nil do |out, expr|
			out = interpret expr
		end
	end

	def declare identifier, value = Nil.new, scope = stack.last
		scope[identifier] = value
	end

	def interp_identifier expr
		return Nil.new if expr.value == 'nil'
		return true if expr.value == 'true'
		return false if expr.value == 'false'

		stack.reverse_each do |scope|
			# todo, Currently this is iterating all scopes, but depending on the type of identifier (:identifier, :Identifier, :IDENTIFIER) we might want to limit that. :CONSTANTS and :Types can search the whole stack, :vars_and_funcs shouldn't search past the first Instance type they encounter.
			return scope[expr.value] if scope.has? expr.value
		end

		raise Undeclared_Identifier, expr.value
	end

	def interp_string expr
		return expr.value unless expr.interpolated
		expr.value # todo, Interpolation
	end

	def maybe_instance expr
		# todo, when String and so on, beacuse everything needs to be some type of scope to live inside the Emerald runtime. Every object in Scope.data{} is either a primitive like String, Integer, Float, or they're a instanced version like Number.
		case expr
		when Number_Expr
			# Number_Expr is already handled in #interpret but this is short-circuiting that for cases like 1.something where we have to make sure the 1 is no longer a numeric literal, but instead a runtime object version of the number 1.
			scope             = Number.new expr.value
			scope.type        = expr.type
			scope.numerator   = expr.value
			scope.denominator = 1
			scope
		else
			interpret expr
		end
	end

	def interp_infix expr
		# todo, '.?' operator. Maybe it returns true if left responds to right. Or, behaves like &. in Ruby? Tbd...

		case expr.operator
		when '='
			# todo, Maybe warn when overwriting an existing identifier.
			declare expr.left.value, interpret(expr.right)

		when '.'
			left = expr.left
			base = interpret(left)

			unless base.is_a?(Scope)
				raise "Cannot access property of non-scope: #{base.inspect}"
			end

			stack << base
			result = interpret expr.right
			stack.pop
			result
		else
			if INFIX_ARITHMETIC_OPERATORS.include? expr.operator
				left  = maybe_instance expr.left
				right = maybe_instance interpret expr.right
				left.send expr.operator, right
			else
				raise "unhandled infix #{expr.inspect}"
			end
		end
	end

	def interp_postfix expr
		case expr.operator
		when ';'
			declare expr.value, Nil.new
		else
			raise Unhandled_Postfix, expr.inspect
		end
	end

	def interp_circumfix expr
		case expr.grouping
		when '()'
			if expr.expressions.count == 0
				# Empty tuple?
			elsif expr.expressions.count == 1
				interpret expr.expressions.first
			else
				# I can't remember what (1,2,3,4,5) was anymore lol. Probably a tuple
				raise "tuplle #{expr.inspect}"
			end
		else
			raise "circumfix #{expr.inspect}"
		end
	end

	def interp_type expr
		scope             = Type.new expr.name
		scope.expressions = expr.expressions

		if scope.types
			scope.types << expr.name
		else
			scope.types = [expr.name]
		end

		declare expr.name, scope
		stack.push scope
		expr.expressions.each do |e|
			interpret e
		end
		stack.pop

	end

	def interp_func expr
		scope             = Func.new expr.name
		scope.expressions = expr.expressions
		scope.expressions.insert 0, *expr.param_decls

		stack.push scope
		expr.expressions.each do |e|
			next unless e.is_a? Param_Expr
			interpret e
		end
		stack.pop

		declare expr.name, scope
	end

	def interp_composition expr
		case expr.operator
		when '|'
			scope_to_merge = interp_identifier expr.name

			unless scope_to_merge.is_a? Scope
				raise "Expected a scope to compose with, got #{scope_to_merge.inspect}"
			end

			curr_scope = stack.last

			# Should this merge be more intelligent in some way?
			scope_to_merge.data.each do |k, v|
				curr_scope[k] ||= v
			end

			# Currently I assume the current scope is an Type and therefore am calling .types directly. But, Funcs will also be able to compose themselves with their arguments. So, this is :temporary.
			curr_scope.types ||= []
			curr_scope.types += scope_to_merge.types
			curr_scope.types = curr_scope.types.uniq
		else
			raise "Unknown composition operator #{expr.operator}"
		end
	end

	def interpret expr
		case expr
		when Number_Expr, Symbol_Expr
			expr.value

		when Identifier_Expr
			interp_identifier expr

		when String_Expr
			interp_string expr

		when Infix_Expr
			interp_infix expr

		when Type_Expr
			interp_type expr

		when Func_Expr
			interp_func expr

		when Composition_Expr
			interp_composition expr

		when Postfix_Expr
			interp_postfix expr

		when Infix_Expr
			interp_infix expr

		when Circumfix_Expr
			interp_circumfix expr

		else
			expr
		end
	end
end
