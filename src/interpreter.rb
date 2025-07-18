require './src/shared/constructs'
require './src/shared/expressions'
require './src/shared/constants'
require './src/shared/errors'
require './src/shared/helpers'

class Interpreter
	attr_accessor :i, :input, :stack

	def initialize input = []
		@input = input
		@stack = [Scope.new('Global')]
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
		# todo, when String and so on, because everything needs to be some type of scope to live inside the Emerald runtime. Every object in Scope.data{} is either a primitive like String, Integer, Float, or they're a instanced version like Number.
		case expr
		when Number_Expr
			# Number_Expr is already handled in #interpret but this is short-circuiting that for cases like 1.something where we have to make sure the 1 is no longer a numeric literal, but instead a runtime object version of the number 1.
			scope             = Number.new expr.value
			scope.type        = expr.type
			scope.numerator   = expr.value
			scope.denominator = 1
			scope

		when Array
		else
			expr
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

			if stack.last.is_a? Func
				target_scope = stack.reverse_each.find do |scope|
					scope.is_a? Instance
				end

				if target_scope&.has? expr.left.value
					declare expr.left.value, right, target_scope
				else
					declare expr.left.value, right
				end
			else
				declare expr.left.value, right
			end
		when '.'
			if expr.right == 'new' || expr.right.is('new')
				return interp_dot_new expr
			end

			left = maybe_instance interpret expr.left
			unless left.is_a? Scope
				raise Invalid_Dot_Infix_Left_Operand, expr.inspect
			end

			if left.is_a? Emerald::Array
				if expr.right.is Number_Expr
					return left.values[interpret expr.right] # I'm intentionally interpreting here, even though I could just use expr.right.value, because I want to test how Number_Expr is interpreted. I mean, I know how but it can take multiple paths to get to its value. In this case, I expect it to be the literal number, but sometimes I need it wrapped in a runtime Number.
				elsif expr.right.is Array_Index_Expr
					array = left # Just for clarity.

					expr.right.indices_in_order.each do |index|
						array = array[index]
					rescue NoMethodError => _
						# We dug our way to a nonexistent array, because #[] doesn't exist on it.
						raise "array[#{index}] is not an array, it's #{array.inspect}"
					end

					return array
				end
			else
				stack << left
				result = interpret expr.right
				stack.pop
				return result
			end
		else
			if INFIX_ARITHMETIC_OPERATORS.include? expr.operator
				left  = maybe_instance interpret expr.left
				right = maybe_instance interpret expr.right
				left.send expr.operator, right

			elsif COMPARISON_OPERATORS.include? expr.operator
				left  = interpret expr.left
				right = interpret expr.right
				left.send expr.operator, right

			elsif COMPOUND_OPERATORS.include? expr.operator
				# (a += b)  ==>  (a = (a + b))
				assignment_infix          = Infix_Expr.new
				assignment_infix.left     = expr.left
				assignment_infix.operator = '='

				right_side_infix          = Infix_Expr.new
				right_side_infix.left     = expr.left
				right_side_infix.operator = expr.operator[..-2] # This just trims the = from compound operators +=, -=, etc.
				right_side_infix.right    = expr.right

				assignment_infix.right = right_side_infix
				interpret assignment_infix

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
			array        = Emerald::Array.new
			array.values = []
			expr.expressions.reduce([]) do |values, expr|
				array.values << interpret(expr)
			end
			array
		when '()'
			if expr.expressions.empty?
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
			raise "Interpreter#interp_circumfix unhandled circumfix #{expr.inspect}"
		end
	end

	def interp_call expr
		receiver = interpret expr.receiver
		case receiver
		when Type
			interp_type_call receiver, expr

		when Func
			interp_func_call receiver, expr

		when Instance
			interp_instance_call receiver, expr

		else
			raise "Interpreter#interp_call unhandled #{receiver.inspect}"
		end
	end

	def interp_type_call type, expr
		instance = Instance.new type.name # :generalize_me

		stack << instance

		type.expressions.each do |expr|
			interpret expr
		end

		func_new = instance[:new]
		if func_new
			interp_func_call func_new, expr
		else
			if expr.arguments.count > 0
				raise "Given #{expr.arguments.count} arguments, but new{;} was not declared for #{type.inspect}"
			end
		end

		stack.pop # Just for clarity, the pop returs the instance from above..
	end

	def interp_func_call func, expr
		result = Nil.new

		stack << func

		params = func.expressions.select do |expr|
			expr.is_a? Param_Expr
		end

		params.zip(expr.arguments).each do |param, arg|
			value = if arg
				interpret arg
			elsif param.expression
				interpret param.expression
			else
				Nil.new # Do I need this? Check later.
			end

			declare param.name, value
		end

		body = func.expressions - params

		body.each do |e|
			result = interpret e
			# todo, Here's where returns should be respected. For now, the last expression's result will be the return value. And actually, I like that about Ruby so that's the default behavior I want.
			# result = interpret e # This just reads the value, which is currently nil. What it should do, is some form of #declare like above, otherwise we're not overwriting the value.
		end

		stack.pop # func
		result
	end

	def interp_instance_call instance, expr
		stack << instance

		func_new = instance[:new]
		if func_new
			interp_func_call func_new, expr
		else
			if expr.arguments.count > 0
				raise "Given #{expr.arguments.count} arguments, but new{;} was not declared for #{instance.inspect}"
			end
		end
		stack.pop # instance
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
		stack.pop # type
	end

	def interp_func expr
		result = Nil.new

		scope             = Func.new expr.name
		scope.expressions = expr.expressions

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

			# todo, Should this merge be more intelligent in some way? For example, what if two Types share keys? Consider this for both for - and |.

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
			raise "Interpreter#interpret `when #{expr.inspect}` not implemented."
		end
	end
end
