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

	def interp_dot_new expr
		receiver = interpret expr.left
		unless receiver.is_a? Type
			raise Cannot_Initialize_Non_Type_Identifier, expr.left.inspect
		end

		instance             = Instance.new receiver.name # :generalize_me
		instance.expressions = receiver.expressions

		stack << instance
		instance.expressions.each do |it|
			interpret it
		end
		stack.pop

		instance
	end

	def interp_prefix expr
		case expr.operator
		when '-'
			-interpret(expr.expression)
		when '+'
			+interpret(expr.expression)
		when '!', 'not'
			!interpret(expr.expression)
		when './'
			interpret expr.expression
		when 'return'
			interpret expr.expression
		else
			raise Unhandled_Prefix, expr.inspect
		end
	end

	def interp_infix expr
		case expr.operator
		when '='
			# todo, Maybe warn when overwriting an existing identifier.
			right = interpret expr.right

			case identifier_kind expr.left.value
			when :identifier
				# Can assign anything
			when :Identifier
				# Only Types
				raise Cannot_Assign_Incompatible_Type, expr.inspect unless right.is_a? Type
			when :IDENTIFIER
				# Anything but it cannot be reassigned
				begin
					left = interpret expr.left
					if left
						raise Cannot_Reassign_Constant, expr.inspect
					end
				rescue Undeclared_Identifier
					# I'm ignoring it in this case since we are assigning the constant if it doesn't exist. I'm not sure that I like having to rescue from #interpret. Oh well, for now.
				end
			end
			declare expr.left.value, right

		when '.'
			if expr.right.is('new')
				return interp_dot_new expr
			end

			left = interpret expr.left
			unless left.is_a? Scope
				raise Invalid_Dot_Infix_Left_Operand, expr.inspect
			end

			stack << left
			result = interpret expr.right
			stack.pop
			result

		else
			if INFIX_ARITHMETIC_OPERATORS.include? expr.operator
				left  = maybe_instance expr.left
				right = maybe_instance interpret expr.right
				left.send expr.operator, right

			elsif COMPARISON_OPERATORS.include? expr.operator
				left  = interpret expr.left
				right = interpret expr.right
				left.send expr.operator, right

			elsif RANGE_OPERATORS.include? expr.operator
				start  = interpret expr.left
				finish = interpret expr.right
				case expr.operator
				when '..'
					Range.new start, finish
				when '.<'
					Range.new start, finish, true
				when '>.'
					Left_Exclusive_Range.new start, finish
				when '><'
					Left_Exclusive_Range.new start, finish, exclude_end: true
				end

			elsif LOGICAL_OPERATORS.include? expr.operator
				case expr.operator
				when '&&', 'and'
					interpret(expr.left) && interpret(expr.right)
				when '||', 'or'
					interpret(expr.left) || interpret(expr.right)
				when '&'
					interpret(expr.left) & interpret(expr.right)
				when '|'
					interpret(expr.left) | interpret(expr.right)
				end
			end
		end
	end

	def interp_postfix expr
		case expr.operator
		when ';'
			declare expr.expression.value, Nil.new
		else
			raise Unhandled_Postfix, expr.inspect
		end
	end

	def interp_circumfix expr
		case expr.grouping
		when '[]'
			expr.expressions.reduce([]) do |values, expr|
				values << interpret(expr)
			end
		when '()'
			if expr.expressions.count == 0
				Tuple.new 'Tuple' # For now, I guess. What else should I do with empty parens?
			elsif expr.expressions.count == 1
				interpret expr.expressions.first
			else
				values       = expr.expressions.reduce([]) do |arr, expr|
					arr << interpret(expr)
				end
				tuple        = Tuple.new 'Tuple'
				tuple.values = values
				tuple
			end
		when '{}'
			expr.expressions.reduce({}) do |dict, it|
				if it.is_a? Identifier_Expr
					dict[it.value.to_sym] = Nil.new
				elsif it.is_a? Infix_Expr
					case it.operator
					when ':', '='
						if it.left.is_a?(Identifier_Expr) || it.left.is_a?(Symbol_Expr) || it.left.is_a?(String_Expr)
							dict[it.left.value.to_sym] = interpret it.right
						else
							# The left operand should be allowed to be any hashable object. It's too early in the project to consider hashing but this'll be a good reminder.
							raise Invalid_Dictionary_Key, it.inspect
						end
					else
						raise Invalid_Dictionary_Infix_Operator, it.inspect
					end
				end
				# In case I forget, #reduce requires that the injected value be returned to be passed to the next iteration.
				dict
			end
		else
			raise "circumfix #{expr.inspect}"
		end
	end

	def interp_call expr
		receiver = interpret expr.receiver

		case receiver
		when Type
			stack << receiver
			receiver.expressions.each do |it|
				interpret it
			end
			stack.pop
			receiver

			instance             = Instance.new receiver.name # :generalize_me
			instance.expressions = receiver.expressions
			instance

			stack << instance
			instance.expressions.each do |it|
				interpret it
			end
			stack.pop

		when Func
			# 7/14/25, This parameters filter might look silly, but I intentionally decided that both Type and Func will only have @expressions for simplicity. I'll treat them as such unless special cases expect a special set of expressions like several Param_Exprs. This seems like an okay way to handle this so it'll do.
			parameters = receiver.expressions.select do |it|
				it.is_a? Param_Expr
			end

			result = Nil.new

			stack << receiver
			parameters.zip(expr.arguments).each do |param, arg|
				if arg
					declare param.name, interpret(arg)
				elsif param.default
					declare param.name, interpret(param.default)
				else
					# todo, :make_use_of_type
					declare param.name, Nil.new
				end
			end
			receiver.expressions.each do |e|
				result = interpret e
			end
			stack.pop

			result

		else
			raise Undeclared_Identifier, expr.inspect
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

			# todo, Should this merge be more intelligent in some way? For example, what if two Types share keys> Both for - and |.

			scope_to_merge.data.each do |k, v|
				curr_scope[k] ||= v
			end

			# Currently I assume the current scope is an Type and therefore am calling .types directly. But, Funcs will also be able to compose themselves with their arguments. So maybe this is :temporary, or more likely, I'll have a separate function for func_composition? Idk yet.
			curr_scope.types ||= []
			curr_scope.types += scope_to_merge.types
			curr_scope.types = curr_scope.types.uniq
		when '-'
			# Copypaste from when '|'
			scope_to_unmerge = interp_identifier expr.name

			unless scope_to_unmerge.is_a? Scope
				raise "Expected a scope to compose with, got #{scope_to_unmerge.inspect}"
			end

			curr_scope = stack.last

			keys_to_unmerge = scope_to_unmerge.data.keys

			# Currently I assume the current scope is an Type and therefore am calling .types directly. But, Funcs will also be able to compose themselves with their arguments. So, this is :temporary.
			curr_scope.types ||= []
			curr_scope.types = curr_scope.types.reject do |type|
				keys_to_unmerge.include? type
			end
			curr_scope.types = curr_scope.types.uniq
		else
			raise "Unknown composition operator #{expr.operator}"
		end
	end

	def interp_conditional expr
		condition    = interpret expr.condition
		to_interpret = if condition == true
			expr.when_true
		else
			expr.when_false
		end

		# todo, :while_loops

		to_interpret.each.inject(nil) do |result, it|
			interpret it
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

		when Type_Expr
			interp_type expr

		when Func_Expr
			interp_func expr

		when Composition_Expr
			interp_composition expr

		when Prefix_Expr
			interp_prefix expr

		when Infix_Expr
			interp_infix expr

		when Postfix_Expr
			interp_postfix expr

		when Circumfix_Expr
			interp_circumfix expr

		when Call_Expr
			interp_call expr

		when Conditional_Expr
			interp_conditional expr

		when Array_Index_Expr
			expr.indices_in_order

		else
			# raise expr.inspect
			expr
		end
	end
end
