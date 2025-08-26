require_relative 'air'

class Interpreter
	attr_accessor :i, :input, :stack, :runtime

	def initialize input = []
		@input             = input
		@stack             = [Air::Global.new]
		@runtime           = Air::Runtime.new
		@runtime.functions = {}
		@runtime.routes    = {}
		@runtime.servers   = []
	end

	def preload_intrinsics
		original_input = @input

		@input = _parse_file './air/preload.air'
		output # So the preloads are declared on this instance of Interpreter

		@input = original_input
	end

	def output
		input.each.inject nil do |result, expr|
			result = interpret expr
		end
	end

	def push_scope scope
		scope ||= stack.last

		stack << scope
	end

	def pop_scope
		if stack.length == 1
			stack.last
		else
			stack.pop
		end
	end

	def push_then_pop scope
		raise "Attempting to push `nil` value as scope" if scope == nil

		push_scope scope
		if block_given?
			yield scope
		end
		pop_scope
	end

	def declare identifier, value, scope = stack.last
		scope             ||= stack.last
		scope[identifier] = value
	end

	def scope_for_identifier expr
		if !expr.is_a?(Identifier_Expr)
			return stack.last
		end

		# ident
		# ./ident
		# ../ident
		# .../ident

		case expr.scope_operator
		when '.../'
			stack.first
		when '../'
			raise "../ not implemented in #scope_for_identifier"
		when './'
			# Should default to the global scope if no Air::Instance is present.
			scope = stack.reverse_each.find do |scope|
				(scope.is_a?(Air::Instance) || scope.is_a?(Air::Global)) && scope.has?(expr.value)
			end
			scope || stack.first
		else
			scope = stack.reverse_each.find do |scope|
				scope.has? expr.value
			end

			scope || stack.last
		end
	end

	def interp_identifier expr
		raise "Expected Identifier_Expr, got #{expr.inspect}" unless expr.is_a? Identifier_Expr

		scope = case expr.value
		when 'nil'
			return nil
		when 'true'
			# todo, return Air::Bool.truthy
			return true
		when 'false'
			# todo, return Air::Bool.falsy
			return false
		else
			scope_for_identifier expr
		end

		value = if scope.is_a? Array # Intentionally not Air::Array
			found = scope.reverse_each.find do |scope|
				scope.has? expr.value
			end

			if found && found.has?(expr.value)
				found[expr.value]
			else
				raise Undeclared_Identifier, expr.inspect
			end
		elsif scope
			raise Undeclared_Identifier, expr.inspect unless scope.has? expr.value
			scope[expr.value]
		else
			# todo, Test this because I don't think this'll ever execute because #scope_for_identifier should now always return some scope.
			scope = stack.last
			raise Undeclared_Identifier, expr.inspect unless scope.has? expr.value
			scope[expr.value]
		end

		value
	end

	def interp_string expr
		return expr.value unless expr.interpolated

		interpolation_char_count = expr.value.count INTERPOLATE_CHAR
		if interpolation_char_count == 1
			return expr.value # For now... I think this is still not the correct approach.
		elsif interpolation_char_count > 1
			result    = expr.value
			sub_exprs = result.scan(/\|(.*?)\|/).flatten
			sub_exprs.each do |sub|
				expression = _parse sub
				value      = interpret expression.first
				result     = result.gsub "|#{sub}|", "#{value}"
			end
			result
		end
	end

	def maybe_instance expr
		# todo, when String and so on, because everything needs to be some type of scope to live inside the runtime. Every object in Air::Scope.declarations{} is either a primitive like String, Integer, Float, or they're an instanced version like Air::Number.
		case expr
		when Integer, Float
			# Number_Expr is already handled in #interpret but this is short-circuiting that for cases like 1.something where we have to make sure the 1 is no longer a numeric literal, but instead a runtime object version of the number 1.
			scope             = Air::Number.new expr
			scope.type        = type_of_number_expr expr
			scope.numerator   = expr
			scope.denominator = 1
			scope
		when nil
			Air::Nil.shared
		when true
			Air::Bool.truthy
		when false
			Air::Bool.falsy
		else
			expr
		end
	end

	def interp_dot_new expr
		receiver = interpret expr.left
		unless receiver.is_a? Air::Type
			raise Cannot_Initialize_Non_Type_Identifier, expr.left.inspect
		end

		instance             = Air::Instance.new receiver.name # :generalize_me
		instance.expressions = receiver.expressions

		push_scope instance
		instance.expressions.each do |it|
			interpret it
		end
		pop_scope

		instance
	end

	def interp_prefix expr
		case expr.operator
		when '#'
			interp_intrinsic expr
		when '-'
			-interpret(expr.expression)
		when '+'
			+interpret(expr.expression)
		when '!', 'not'
			!interpret(expr.expression)
		when 'return'
			returned = interpret expr.expression
			Air::Return.new returned
		else
			raise Unhandled_Prefix, expr.inspect
		end
	end

	# @param expr [Infix_Expr]
	def interp_infix_equals expr
		assignment_scope = scope_for_identifier expr.left
		evaluation_scope = scope_for_identifier expr.right

		push_scope(evaluation_scope) if evaluation_scope
		right_value = interpret expr.right
		pop_scope if evaluation_scope

		case type_of_identifier expr.left.value
		when :IDENTIFIER
			# It can only be assigned once, so if the declaration exists, fail.
			if assignment_scope.has? expr.left.value
				raise Cannot_Reassign_Constant, expr.inspect
			end
		when :Identifier
			# It can only be assigned `value` of Air::Type.
			if !right_value.is_a?(Air::Type)
				raise Cannot_Assign_Incompatible_Type, expr.inspect
			end
		when :identifier
			# It can be assigned and reassigned, so do nothing.
		end

		declare expr.left.value, right_value, assignment_scope
		return right_value
	end

	# @param expr [Infix_Expr]
	def interp_infix_dot expr
		# todo, This is getting messy. I need to factor out some of these cases. :factor_dot_calls
		if expr.right == 'new' || expr.right.is('new')
			return interp_dot_new expr
		end

		left = maybe_instance interpret expr.left
		if !left.kind_of?(Air::Scope) && !left.kind_of?(Range)
			raise Invalid_Dot_Infix_Left_Operand, "#{expr.inspect}"
		end

		if left.is_a? Air::Array
			if expr.right.is(Func_Expr) && expr.right.name.value == 'each'
				left.values.each do |it|
					each_scope                 = Air::Scope.new 'each{;}'
					each_scope.enclosing_scope = stack.last
					push_scope each_scope
					declare 'it', it, each_scope
					expr.right.expressions.each do |expr|
						interpret expr
					end
					pop_scope
				end

				return left
			elsif expr.right.is Number_Expr
				return left.values[interpret expr.right] # I'm intentionally interpreting here, even though I could just use expr.right.value, because I want to test how Number_Expr is interpreted. I mean, I know how but it can take multiple paths to get to its value. In this case, I expect it to be the literal number, but sometimes I need it wrapped in a runtime Air::Number.
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
		elsif left.kind_of? Range
			if expr.right.is(Func_Expr) && expr.right.name.value == 'each'
				# todo, Should be handled by #interp_func_call?

				left.each do |it|
					each_scope = Air::Scope.new 'each{;}'
					push_scope each_scope
					declare 'it', it, each_scope
					expr.right.expressions.each do |expr|
						interpret expr
					end
					pop_scope
				end
			end
			return left

		else
			raise "Expected left to be non-nil for a dot infix." if left == nil

			push_scope left
			result = interpret expr.right
			pop_scope

			return result
		end
	end

	# @param expr [Infix_Expr]
	def interp_infix expr
		case expr.operator
		when '='
			interp_infix_equals expr
		when '.'
			interp_infix_dot expr
		when '<<'
			left  = maybe_instance interpret expr.left
			right = maybe_instance interpret expr.right

			if left.is_a?(Air::Array)
				left.values << right
			else
				begin
					left.send expr.operator, right
				rescue
					raise "Unsupported << operator for #{expr.inspect}"
				end
			end
		else
			if INFIX_ARITHMETIC_OPERATORS.include? expr.operator
				left  = maybe_instance interpret expr.left
				right = maybe_instance interpret expr.right

				if left.is_a?(Air::Array) && expr.operator == '<<'
					left.values << right
				else
					left.send expr.operator, right
				end

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
					Range.new start, finish, exclude_end: true
				when '>.'
					Air::Left_Exclusive_Range.new start, finish
				when '><'
					Air::Left_Exclusive_Range.new start, finish, exclude_end: true
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
			declare expr.expression.value, nil
		else
			raise Unhandled_Postfix, expr.inspect
		end
	end

	def interp_circumfix expr
		case expr.grouping
		when '[]'
			array        = Air::Array.new
			array.values = []
			expr.expressions.reduce([]) do |values, expr|
				array.values << interpret(expr)
			end
			array
		when '()'
			if expr.expressions.empty?
				Air::Tuple.new 'Tuple' # For now, I guess. What else should I do with empty parens?
			elsif expr.expressions.count == 1
				interpret expr.expressions.first
			else
				values       = expr.expressions.reduce([]) do |arr, expr|
					arr << interpret(expr)
				end
				tuple        = Air::Tuple.new 'Tuple'
				tuple.values = values
				tuple
			end
		when '{}'
			expr.expressions.reduce({}) do |dict, it|
				if it.is_a? Identifier_Expr
					dict[it.value.to_sym] = nil
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
		when Air::Type # Air::Type()
			interp_type_call receiver, expr

		when Air::Func # func()
			interp_func_call receiver, expr

		else
			raise "Interpreter#interp_call unhandled #{receiver.inspect}"
		end
	end

	def interp_type_call type, expr
		#
		# Type_Expr is converted to Air::Type in #interp_type.
		# Air::Instance inherits Air::Type's @name and @types.
		#
		#     (See constructs.rb for Air::Type and Air::Instance declarations)
		#     (See expressions.rb for Type_Expr declaration)
		#
		# - Push instance onto stack
		# - Interpret type.expressions so the declarations are made on the instance
		# - Keep instance on the stack
		# - For each Air::Func declared on instance, set `func.enclosing_scope = instance`
		# - Interpret instance[:new], the initializer
		# - Delete :new from instance, no longer needed
		#

		# :generalize_me
		instance       = Air::Instance.new type.name
		instance.types = type.types

		push_scope instance
		type.expressions.each do |expr|
			interpret expr
		end

		instance.declarations.values.each do |decl|
			next unless decl.is_a? Air::Func
			decl.enclosing_scope = instance
		end

		func_new = instance[:new]
		if func_new
			interp_func_call func_new, expr
		else
			if expr.arguments.count > 0
				raise "Given #{expr.arguments.count} arguments, but new{;} was not declared for #{type.inspect}"
			end
		end

		instance.delete :new
		pop_scope # Just for clarity, the pop returns the instance from above..
		instance
	end

	def interp_func_call func, expr
		call_scope = Air::Scope.new func.name #"#{func.name}() Air::Func Call"

		params = func.expressions.select do |expr|
			expr.is_a? Param_Expr
		end

		if expr.arguments.count > params.count
			raise "Arguments given, no params declared #{expr.inspect}"
		end

		push_scope func.enclosing_scope
		push_scope call_scope
		params.zip(expr.arguments).each do |param, arg|
			value = if arg && param
				interpret arg
			elsif arg && !param
				raise "Arg #{arg.inspect} given where none was expected."
			elsif !arg && param
				if param.default
					interpret param.default
				else
					raise Missing_Argument, param.inspect
				end
			else
				raise "This should never happen."
			end

			declare param.name, value
		end

		body = func.expressions - params
		if func.name == 'assert'
			raise Assert_Triggered, expr.inspect unless interpret(body.first) == true # Just to be explicit.
		end

		result = nil
		body.each do |e|
			next if e.is_a? Param_Expr

			result = interpret e
			break if result.is_a? Air::Return
		end

		Air.assert pop_scope == call_scope
		Air.assert pop_scope == func.enclosing_scope

		result
	end

	def interp_type expr
		type = Air::Type.new expr.name.value

		type.expressions = expr.expressions

		if type.types
			type.types << type.name
		else
			type.types = [type.name]
		end

		declare type.name, type

		push_then_pop type do |scope|
			expr.expressions.each do |expr|
				interpret expr
			end
		end

		type
	end

	def interp_route expr
		handler = interpret expr.expression

		route                 = Air::Route.new # expr.name&.value
		route.enclosing_scope = stack.last
		route.handler         = handler
		route.http_method     = expr.http_method
		route.path            = expr.path

		if handler.name
			@runtime.routes[handler.name] = route
			declare handler.name, route
		else
			route
		end
	end

	def interp_func expr
		func                 = Air::Func.new expr.name&.value
		func.enclosing_scope = stack.last
		func.expressions     = expr.expressions

		if func.name
			@runtime.functions[func.name] = func
			declare func.name, func
		else
			func
		end
	end

	def interp_composition expr
		# These are interpreted sequentially so there are no precedence rules. I think that'll be better in the long term because there's no magic behind their evaluation. You can ensure the correct outcome by using these operators to form the types you need.

		operand_scope = interp_identifier expr.identifier
		unless operand_scope.is_a? Air::Scope
			raise "Expected a scope to compose with, got #{operand_scope.inspect}"
		end
		curr_scope    = stack.last

		case expr.operator
		when '|'
			# Union with Air::Type
			operand_scope.declarations.each do |key, value|
				curr_scope[key] ||= value
			end

			curr_scope.types ||= []
			curr_scope.types += operand_scope.types
			curr_scope.types = curr_scope.types.uniq
		when '~'
			# Removal of Air::Type

			operand_keys_to_remove = operand_scope.declarations.keys

			# Maybe I'll have other keys to protect in the future.
			operand_keys_to_remove.reject! do |key|
				key.to_s == 'new'
			end

			operand_keys_to_remove.each do |key|
				curr_scope.delete key
			end

			curr_scope.types = curr_scope.types.reject do |type|
				type == expr.identifier.value
			end
		when '&'
			# Intersection of Types, aka what they share.

			shared_keys    = operand_scope.declarations.keys.select do |key|
				curr_scope.has? key
			end
			keys_to_delete = curr_scope.declarations.keys - shared_keys

			keys_to_delete.each do |key|
				curr_scope.declarations.delete key
			end

		when '^'
			# Symmetric difference of Types, aka what they don't share.

			shared_keys = curr_scope.declarations.keys.select do |key|
				operand_scope.has? key
			end

			current_unique_keys = curr_scope.declarations.keys - shared_keys
			operand_unique_keys = operand_scope.declarations.keys - shared_keys
			keys_to_keep        = current_unique_keys + operand_unique_keys

			curr_scope.declarations.delete_if do |key, _|
				!keys_to_keep.include? key
			end

			operand_unique_keys.each do |key|
				curr_scope[key] ||= operand_scope[key]
			end
		else
			raise "Unknown composition operator #{expr.operator}"
		end
	end

	def interp_conditional expr
		# I'm being very explicit with the "== true" checks of the condition. It's easy to misread this to mean that as long as it's not nil. While the distinction in this case may not matter (in Ruby), I still haven't decided how this language will handle truthiness.
		case expr.type
		when 'while', 'until', 'elwhile'
			result    = nil
			condition = interpret(expr.condition)

			if expr.type == 'until'
				until condition == true
					expr.when_true.each do |stmt|
						result = interpret(stmt)
					end
					condition = interpret(expr.condition)
				end
			else
				while condition == true
					expr.when_true.each do |stmt|
						result = interpret(stmt)
					end
					condition = interpret(expr.condition)
				end
			end

			if expr.when_false.is_a? Conditional_Expr
				result = interp_conditional expr.when_false
			elsif expr.when_false.is_a? Array # Also intentionally not Air::Array
				expr.when_false.each do |expr|
					result = interpret expr
				end
			end

			return result
		when 'unless'
			# @Copypaste from the else clause below. This is simple to factor out.
			# The behavior of truthiness is not yet finalized.
			condition = interpret expr.condition
			body      = if condition == false || condition.nil?
				expr.when_true
			else
				expr.when_false
			end

			if body.is_a? Conditional_Expr
				interp_conditional body
			else
				body.each.inject(nil) do |result, expr|
					interpret expr
				end
			end

		else
			condition = interpret expr.condition
			body      = if condition == true
				expr.when_true
			else
				expr.when_false
			end

			if body.is_a? Conditional_Expr
				interp_conditional body
			else
				result = body.each.inject(nil) do |result, expr|
					interpret expr
				end

				result || nil
			end
		end
	end

	def interp_directive expr
		case expr.name.value
		when 'start_server'
			# TODO Signal.trap 'INT'
			server = interpret expr.expression
			@runtime.servers << server
			puts "Server added to runtime: #{@runtime.servers.inspect}"
			server
		else
			raise Directive_Not_Implemented, expr.inspect
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

		when Route_Expr
			interp_route expr

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

		when Directive_Expr
			interp_directive expr

		when Comment_Expr
			# todo, Something?
		else
			raise Interpret_Expr_Not_Implemented, expr
		end
	end
end
