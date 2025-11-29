require_relative '../air'

module Air
	class Interpreter
		attr_accessor :i, :input, :stack, :context

		def initialize input = [], global_scope = nil
			@input   = input
			@stack   = [global_scope || Air::Global.new]
			@context = Air::Execution_Context.new
		end

		def output & block
			result = input.each.inject nil do |result, expr|
				interpret expr
			end

			if block_given?
				yield result, context, stack
			end

			result
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
			if !expr.is_a?(Air::Identifier_Expr)
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
			raise "Expected Air::Identifier_Expr, got #{expr.inspect}" unless expr.is_a? Air::Identifier_Expr

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

			value = if scope.is_a? ::Array
				found = scope.reverse_each.find do |scope|
					scope.has? expr.value
				end

				if found && found.has?(expr.value)
					found[expr.value]
				else
					raise Air::Undeclared_Identifier, expr.inspect
				end
			elsif scope
				raise Air::Undeclared_Identifier, "#{expr.inspect}\n#{scope.inspect}" unless scope.has? expr.value
				scope[expr.value]
			else
				# todo, Test this because I don't think this'll ever execute because #scope_for_identifier should now always return some scope.
				scope = stack.last
				raise Air::Undeclared_Identifier, expr.inspect unless scope.has? expr.value
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
					expression = Air.parse sub
					value      = interpret expression.first
					result     = result.gsub "|#{sub}|", "#{value}"
				end
				result
			end
		end

		def maybe_instance expr
			# todo, when String and so on, because everything needs to be some type of scope to live inside the context. Every object in Air::Scope.declarations{} is either a primitive like String, Integer, Float, or they're an instanced version like Air::Number.
			case expr
			when Integer, Float
				# Air::Number_Expr is already handled in #interpret but this is short-circuiting that for cases like 1.something where we have to make sure the 1 is no longer a numeric literal, but instead a context object version of the number 1.
				scope             = Air::Number.new expr
				scope.type        = Air.type_of_number_expr expr
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
				raise Air::Cannot_Initialize_Non_Type_Identifier, expr.left.inspect
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

		# @param expr [Air::Infix_Expr]
		def interp_infix_equals expr
			assignment_scope = scope_for_identifier expr.left
			evaluation_scope = scope_for_identifier expr.right

			push_scope(evaluation_scope) if evaluation_scope
			right_value = interpret expr.right
			pop_scope if evaluation_scope

			case Air.type_of_identifier expr.left.value
			when :IDENTIFIER
				# It can only be assigned once, so if the declaration exists, fail.
				if assignment_scope.has? expr.left.value
					raise Air::Cannot_Reassign_Constant, expr.inspect
				end
			when :Identifier
				# It can only be assigned `value` of Air::Type.
				if !right_value.is_a?(Air::Type)
					raise Air::Cannot_Assign_Incompatible_Type, expr.inspect
				end
			when :identifier
				# It can be assigned and reassigned, so do nothing.
			end

			declare expr.left.value, right_value, assignment_scope
			return right_value
		end

		# @param expr [Air::Infix_Expr]
		def interp_infix_dot expr
			# todo, This is getting messy. I need to factor out some of these cases. :factor_dot_calls
			if expr.right == 'new' || expr.right.is('new')
				return interp_dot_new expr
			end

			left = maybe_instance interpret expr.left
			if !left.kind_of?(Air::Scope) && !left.kind_of?(Range)
				raise Invalid_Dot_Infix_Left_Operand, "#{expr.inspect}"
			end

			if left.is_a?(Air::List) || left.kind_of?(Air::Tuple)
				if expr.right.is(Air::Func_Expr) && expr.right.name.value == 'each'
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
				elsif expr.right.is Air::Number_Expr
					return left.values[interpret expr.right] # I'm intentionally interpreting here, even though I could just use expr.right.value, because I want to test how Air::Number_Expr is interpreted. I mean, I know how but it can take multiple paths to get to its value. In this case, I expect it to be the literal number, but sometimes I need it wrapped in a context Air::Number.
				elsif expr.right.is Air::Array_Index_Expr
					array_or_tuple = left # Just for clarity.

					expr.right.indices_in_order.each do |index|
						array_or_tuple = array_or_tuple[index]
					rescue NoMethodError => _
						# We dug our way to a nonexistent array, because #[] doesn't exist on it.
						raise "array[#{index}] is not an array, it's #{array_or_tuple.inspect}"
					end

					return array_or_tuple
				end

			elsif left.kind_of? Range
				if expr.right.is(Air::Func_Expr) && expr.right.name.value == 'each'
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

		# @param expr [Air::Infix_Expr]
		def interp_infix expr
			case expr.operator
			when '='
				interp_infix_equals expr
			when '.'
				interp_infix_dot expr
			when '<<'
				left  = maybe_instance interpret expr.left
				right = maybe_instance interpret expr.right

				if left.is_a?(Air::List)
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

					if left.is_a?(Air::List) && expr.operator == '<<'
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
					assignment_infix          = Air::Infix_Expr.new
					assignment_infix.left     = expr.left
					assignment_infix.operator = '='

					right_side_infix          = Air::Infix_Expr.new
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
				array        = Air::List.new
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
					if it.is_a? Air::Identifier_Expr
						dict[it.value.to_sym] = nil
					elsif it.is_a? Air::Infix_Expr
						case it.operator
						when ':', '='
							if it.left.is_a?(Air::Identifier_Expr) || it.left.is_a?(Air::Symbol_Expr) || it.left.is_a?(Air::String_Expr)
								dict[it.left.value.to_sym] = interpret it.right
							else
								# The left operand should be allowed to be any hashable object. It's too early in the project to consider hashing but this'll be a good reminder.
								raise Air::Invalid_Dictionary_Key, it.inspect
							end
						else
							raise Air::Invalid_Dictionary_Infix_Operator, it.inspect
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
			when Air::Type, Air::Html_Element # Air::Type()
				interp_type_call receiver, expr

			when Air::Func # func()
				interp_func_call receiver, expr

			else
				raise "Interpreter#interp_call unhandled #{receiver.inspect}"
			end
		end

		def interp_type_call type, expr
			#
			# Air::Type_Expr is converted to Air::Type in #interp_type.
			# Air::Instance inherits Air::Type's @name and @types.
			#
			#     (See constructs.rb for Air::Type and Air::Instance declarations)
			#     (See expressions.rb for Air::Type_Expr declaration)
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
				expr.is_a? Air::Param_Expr
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
						raise Air::Missing_Argument, param.inspect
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
				next if e.is_a? Air::Param_Expr

				result = interpret e
				break if result.is_a? Air::Return
			end

			Air.assert pop_scope == call_scope
			Air.assert pop_scope == func.enclosing_scope

			result
		end

		# @param route [Air::Route] The route to execute
		# @param req [Air::Request] Request object to inject
		# @param res [Air::Response] Response object to inject
		# @param url_params [Hash] Extracted URL parameters (e.g., {"id" => "123"})
		# @return The result of handler execution
		def interp_route_handler route, req, res, url_params = {}
			handler = route.handler
			params  = handler.expressions.select { |e| e.is_a? Air::Param_Expr }

			call_scope = Air::Scope.new "#{handler.name || 'anonymous'}_route"
			push_scope handler.enclosing_scope
			push_scope call_scope

			# Make request and response available without explicit declaration
			declare 'request', req, call_scope
			declare 'response', res, call_scope

			# Bind URL parameters as function arguments. For example, get://:abc/:def { abc, def; }
			params.each do |param|
				# param: Air::Param_Expr
				value = url_params[param.name] || url_params[param.name.to_sym]

				if value.nil?
					# Check if this is a route parameter
					if route.param_names.include? param.name
						# todo: I haven't triggered this yet to ensure this works.
						# todo: Write error in lib/runtime/errors.rb and raise that instead.
						raise "Route parameter '#{param.name}' expected but not found in URL"
					end

					# Use default value or raise
					if param.default
						value = interpret param.default
					else
						# todo: Is this reachable? I imagine
						raise Air::Missing_Argument, param.inspect
					end
				end

				declare param.name, value, call_scope
			end

			# Execute handler body expressions without the param expressions.
			body   = handler.expressions - params
			result = nil

			body.each do |expr|
				next if expr.is_a? Air::Param_Expr # Reminder, param expressions are part of the function body by design. This is redundant because I'm subtracting the params from the handler expressions a few lines above, but just in case!

				result = interpret expr
				break if result.is_a? Air::Return
			end

			# If result is a string and response.body not set, use result as body
			if result.is_a?(String) && res.body_content.empty?
				res.body_content         = result
				res.declarations['body'] = result
			end

			# Clean up scopes
			popped_call      = pop_scope
			popped_enclosing = pop_scope

			Air.assert popped_call == call_scope
			Air.assert popped_enclosing == handler.enclosing_scope

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

		def interp_element expr
			element             = Air::Html_Element.new expr.element.value
			element.expressions = expr.expressions
			# element.attributes = filtered element.expressions

			declare element.name, element

			push_then_pop element do |scope|
				expr.expressions.each do |expr|
					# TODO: When evaluating render{;}, it should expect one of the following:
					# - string
					# - another Html_Element
					# - array of Html_Elements
					interpret expr
				end
			end

			element
		end

		def interp_route expr
			expression = interpret expr.expression

			route                 = Air::Route.new
			route.enclosing_scope = stack.last
			route.handler         = expression
			route.http_method     = expr.http_method
			route.path            = expr.path
			route.path            = route.path[1..] if route.path.start_with? '/'
			route.param_names     = expr.param_names || []

			route.parts = route.path.split('/').reject do
				_1.empty?
			end

			unless expression.is_a?(Air::Func)
				raise Invalid_Http_Directive_Handler, expression.inspect
			end

			if expression.name
				@context.routes[expression.name] = route
				declare expression.name, route
			else
				# Anonymous route with auto-generated key: "method:path"
				route_key                  = "#{route.http_method.value}:#{route.path}"
				@context.routes[route_key] = route
			end
		end

		def interp_func expr
			func                 = Air::Func.new expr.name&.value
			func.enclosing_scope = stack.last
			func.expressions     = expr.expressions

			if func.name
				declare func.name, func
			else
				func
			end
		end

		def interp_composition expr
			# These are interpreted sequentially, so there are no precedence rules. I think that'll be better in the long term because there's no magic behind their evaluation. You can ensure the correct outcome by using these operators to form the types you need.

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

				if expr.when_false.is_a? Air::Conditional_Expr
					result = interp_conditional expr.when_false
				elsif expr.when_false.is_a? ::Array
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

				if body.is_a? Air::Conditional_Expr
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

				if body.is_a? Air::Conditional_Expr
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
			when 'serve_http'
				# TODO ensure Type contains Server
				# TODO Ensure Signal.trap(INT) somewhere
				# Spawn thread, run server in it.
				server = interpret expr.expression
				@context.servers << server
				server
			when 'load'
				filepath = interpret expr.expression
				stack.first.load_file filepath
			else
				raise Directive_Not_Implemented, expr.inspect
			end
		end

		def interpret expr
			case expr
			when Air::Number_Expr, Air::Symbol_Expr
				expr.value

			when Air::Identifier_Expr
				interp_identifier expr

			when Air::String_Expr
				interp_string expr

			when Air::Type_Expr
				interp_type expr

			when Air::Html_Element_Expr
				interp_element expr

			when Air::Route_Expr
				interp_route expr

			when Air::Func_Expr
				interp_func expr

			when Air::Composition_Expr
				interp_composition expr

			when Air::Prefix_Expr
				interp_prefix expr

			when Air::Infix_Expr
				interp_infix expr

			when Air::Postfix_Expr
				interp_postfix expr

			when Air::Circumfix_Expr
				interp_circumfix expr

			when Air::Call_Expr
				interp_call expr

			when Air::Conditional_Expr
				interp_conditional expr

			when Air::Array_Index_Expr
				expr.indices_in_order

			when Air::Directive_Expr
				interp_directive expr

			when Air::Comment_Expr
				# todo, Something?
			else
				raise Interpret_Expr_Not_Implemented, expr.inspect
			end
		end
	end
end
