require_relative '../ore'

module Ore
	class Interpreter
		attr_accessor :i, :input, :runtime

		def initialize input = [], runtime = nil
			@input   = input
			@runtime = runtime || Ore::Runtime.new
		end

		def output & block
			result = input.each.inject nil do |result, expr|
				interpret expr
			end

			if block_given?
				yield result, runtime
			end

			return result
		end

		def scope_for_identifier expr
			if !expr.is_a?(Ore::Identifier_Expr)
				return runtime.stack.last
			end

			# ident
			# ./ident
			# ../ident
			# .../ident

			case expr.scope_operator
			when '.../'
				runtime.stack.first
			when '../'
				raise "../ not implemented in #scope_for_identifier"
			when './'
				# Should default to the global scope if no Ore::Instance is present.
				scope = runtime.stack.reverse_each.find do |scope|
					(scope.is_a?(Ore::Instance) || scope.is_a?(Ore::Global)) && scope.has?(expr.value)
				end
				scope || runtime.stack.first
			else
				scope = runtime.stack.reverse_each.find do |scope|
					scope.has? expr.value
				end

				scope || runtime.stack.last
			end
		end

		def check_dot_access_permissions scope, ident, expr
			binding, privacy = Ore.binding_and_privacy ident

			case scope
			when Ore::Instance
				if privacy == :private && runtime.stack.last != scope
					raise Ore::Cannot_Call_Private_Instance_Member.new(expr, runtime)
				end
			when Ore::Type
				if binding == :instance
					raise Ore::Cannot_Call_Instance_Member_On_Type.new(expr, runtime)
				elsif privacy == :private
					raise Ore::Cannot_Call_Private_Static_Type_Member.new(expr, runtime)
				end
			end
		end

		def interp_identifier expr
			# todo: Proper error
			raise "Expected Ore::Identifier_Expr, got #{expr.inspect}" unless expr.is_a? Ore::Identifier_Expr

			scope = case expr.value
			when 'nil'
				return nil
			when 'true'
				# todo, return Ore::Bool.truthy
				return true
			when 'false'
				# todo, return Ore::Bool.falsy
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
					raise Ore::Undeclared_Identifier.new(expr, runtime)
				end
			elsif scope
				unless scope.has? expr.value
					raise Ore::Undeclared_Identifier.new(expr, runtime)
				end
				scope[expr.value]
			else
				# todo, Test this because I don't think this'll ever execute because #scope_for_identifier should now always return some scope.
				scope = runtime.stack.last
				raise Ore::Undeclared_Identifier.new(expr, runtime) unless scope.has? expr.value
				scope[expr.value]
			end

			# todo: Currently there is no clear rule on multiple unpacks. :double_unpack
			if expr.unpack && value.is_a?(Ore::Instance)
				runtime.stack.last.sibling_scopes << value
			end

			value
		end

		def interp_string expr
			return expr.value unless expr.interpolated

			interpolation_char_count = expr.value.count INTERPOLATE_CHAR
			if interpolation_char_count == 1
				return expr.value # For now... I think this is still not the correct approach.
			elsif interpolation_char_count > 1
				# todo: Proprely learn regex. For now, here's a description of what the regex below does:
				#
				# String: "Hi, |name|!"
				# Matches: ["name"]
				# Result: Interpolates the `name` variable

				# String: "Hi, \|name\|!"
				# Matches: []
				# Result: No interpolation, backslashes protect the pipes

				# String: "Hi, |first| and \|second\|"
				# Matches: ["first"]
				# Result: Only interpolates `first`, not `second`
				#

				result    = expr.value
				sub_exprs = result.scan(/(?<!\\)\|(.*?)(?<!\\)\|/).flatten

				sub_exprs.each do |sub|
					expression = Ore.parse sub
					value      = interpret expression.first
					result     = result.gsub "|#{sub}|", "#{value}"
				end
				result.gsub('\\', '') # Remove any escapes from the resulting string? Is this okay? I don't know...
			end
		end

		def maybe_instance expr
			# todo, when String and so on, because everything needs to be some type of scope to live inside the runtime. Every object in Ore::Scope.declarations{} is either a primitive like String, Integer, Float, or they're an instanced version like Ore::Number.
			case expr
			when Integer, Float
				# Ore::Number_Expr is already handled in #interpret but this is short-circuiting that for cases like 1.something where we have to make sure the 1 is no longer a numeric literal, but instead a runtime object version of the number 1.
				scope             = Ore::Number.new expr
				scope.type        = Ore.type_of_number_expr expr
				scope.numerator   = expr
				scope.denominator = 1
				scope
			when nil
				Ore::Nil.shared
			when true
				Ore::Bool.truthy
			when false
				Ore::Bool.falsy
			else
				expr
			end
		end

		def interp_dot_new expr
			receiver = interpret expr.left
			unless receiver.is_a? Ore::Type
				raise Ore::Cannot_Initialize_Non_Type_Identifier.new(expr.left, runtime)
			end

			instance             = Ore::Instance.new receiver.name # :generalize_me
			instance.expressions = receiver.expressions

			runtime.push_scope instance
			instance.expressions.each do |it|
				interpret it
			end
			runtime.pop_scope

			instance
		end

		def interp_prefix expr
			# note: See constants.rb PREFIX for exhaustive list of language-defined prefixes
			case expr.operator
			when '-'
				-interpret(expr.expression)
			when '+'
				+interpret(expr.expression)
			when '~'
				~interpret(expr.expression)
			when '!', 'not'
				!interpret(expr.expression)
			when 'return'
				returned = interpret expr.expression
				Ore::Return.new returned
			else
				raise Ore::Unhandled_Prefix.new(expr, runtime)
			end
		end

		# @param expr [Ore::Infix_Expr]
		def interp_infix_equals expr
			assignment_scope = scope_for_identifier expr.left

			# Special handling for load directive assignment, subscript, and maybe more later.

			if expr.left.is_a? Ore::Subscript_Expr
				if expr.left.expression.expressions.count > 1
					raise Ore::Too_Many_Subscript_Expressions.new(expr.left, runtime)
				end
				# note: I'm interpreting only the first expression of left.expression.expressions as the key because the brackets are a Circumfix_Expr which uses an array to store the values.
				receiver      = interpret expr.left.receiver
				key           = interpret expr.left.expression.expressions.first
				receiver[key] = interpret expr.right
				return receiver[key] # note: Intentionally returning the value here because the code starting with the directive check runs to the end of the method. todo: Imrpove?
			end

			# Handle dot assignment
			if expr.left.is_a?(Ore::Infix_Expr) && expr.left.operator == '.'
				receiver = interpret expr.left.left
				property = expr.left.right

				check_dot_access_permissions receiver, property.value, expr

				right_value              = interpret expr.right
				receiver[property.value] = right_value
				return right_value
			end

			if expr.right.is_a?(Ore::Directive_Expr) && expr.right.name.value == 'load'
				filepath = interpret expr.right.expression

				# Create new scope to load into
				new_scope = Ore::Scope.new expr.left.value
				runtime.load_file filepath, new_scope
				right_value = new_scope
			else
				# Normal assignment path
				evaluation_scope = scope_for_identifier expr.right

				runtime.push_scope(evaluation_scope) if evaluation_scope
				right_value = interpret expr.right
				runtime.pop_scope if evaluation_scope
			end

			case Ore.type_of_identifier expr.left.value
			when :IDENTIFIER
				# It can only be assigned once, so if the declaration exists, fail.
				if assignment_scope.has? expr.left.value
					raise Ore::Cannot_Reassign_Constant.new(expr.left, runtime)
				end
			when :Identifier
				# It can only be assigned `value` of Ore::Scope, which includes Ore::Type
				if !right_value.is_a?(Ore::Scope)
					raise Ore::Cannot_Assign_Incompatible_Type.new(expr, runtime)
				end
			when :identifier
				# It can be assigned and reassigned, so do nothing.
			end

			assignment_scope.declare expr.left.value, right_value
			return right_value
		end

		# @param expr [Ore::Infix_Expr]
		def interp_dot_infix expr
			return interp_dot_new expr if expr.right.is 'new'

			left = maybe_instance interpret expr.left

			unless left.kind_of?(Ore::Scope) || left.kind_of?(Ore::Range)
				raise Ore::Invalid_Dot_Infix_Left_Operand.new(expr, runtime)
			end

			case left
			when Ore::Array, Ore::Tuple
				interp_dot_array_or_tuple expr
			when Ore::Range
				interp_dot_range expr
			when Ore::Dictionary
				interp_dot_dictionary expr
			else
				interp_dot_scope expr
			end
		end

		def interp_dot_array_or_tuple expr
			scope = interpret expr.left # maybe_instance interpret expr.left

			case
			when expr.right.is(Ore::Func_Expr) && expr.right.name.value == 'each'
				interp_each_loop scope, expr.right
				scope

			when expr.right.is(Ore::Number_Expr)
				scope.values[expr.right.value]

			when expr.right.is(Ore::Array_Index_Expr)
				expr.right.indices_in_order.reduce(scope) do |current, index|
					raise Ore::Invalid_Dot_Infix_Left_Operand.new(expr, runtime) unless current.is_a?(Ore::Array)
					current[index]
				end

			else
				interp_dot_scope expr
			end
		end

		def interp_dot_range expr
			range = interpret expr.left # maybe_instance interpret expr.left
			if expr.right.is(Ore::Func_Expr) && expr.right.name.value == 'each'
				interp_each_loop range, expr.right
			end
			range
		end

		def interp_dot_dictionary expr
			dict = interpret expr.left

			case expr.right.value
			when 'keys', 'values', 'count'
				# note: keys, values, and count are declared on Ore::Dictionary so just call through to it
				dict.dict.send expr.right.value

			else
				# Fall through to normal scope lookup
				runtime.push_scope dict
				result = interpret expr.right
				runtime.pop_scope

				result
			end
		end

		def interp_dot_scope expr
			scope = interpret expr.left
			raise Ore::Invalid_Dot_Infix_Left_Operand.new(expr, runtime) if scope.nil?

			check_dot_access_permissions scope, expr.right.value, expr

			runtime.push_scope scope
			result = interpret expr.right
			runtime.pop_scope
			result
		end

		def interp_each_loop collection, func_expr
			collection.each do |it|
				each_scope                 = Ore::Scope.new 'each{;}'
				each_scope.enclosing_scope = runtime.stack.last
				runtime.push_scope each_scope
				each_scope.declare 'it', it
				func_expr.expressions.each { |e| interpret e }
				runtime.pop_scope
			end
		end

		# def interp_infix_dot expr
		# 	# todo, This is getting messy. I need to factor out some of these cases. :factor_dot_calls
		# 	if expr.right == 'new' || expr.right.is('new')
		# 		return interp_dot_new expr
		# 	end
		#
		# 	# binding = Ore.binding_of_ident expr.left.value
		# 	# privacy = Ore.visibility_of_ident expr.left.value
		#
		# 	left = maybe_instance interpret expr.left
		#
		# 	if !left.kind_of?(Ore::Scope) && !left.kind_of?(Ore::Range)
		# 		raise Ore::Invalid_Dot_Infix_Left_Operand.new(expr, runtime)
		# 	end
		#
		# 	if left.is_a?(Ore::Array) || left.kind_of?(Ore::Tuple)
		# 		if expr.right.is(Ore::Func_Expr) && expr.right.name.value == 'each'
		# 			left.each do |it|
		# 				each_scope                 = Ore::Scope.new 'each{;}'
		# 				each_scope.enclosing_scope = runtime.stack.last
		# 				runtime.push_scope each_scope
		# 				each_scope.declare 'it', it
		# 				expr.right.expressions.each do |expr|
		# 					interpret expr
		# 				end
		# 				runtime.pop_scope
		# 			end
		#
		# 			return left
		# 		elsif expr.right.is Ore::Number_Expr
		# 			return left.values[expr.right.value]
		#
		# 		elsif expr.right.is Ore::Array_Index_Expr
		# 			array_or_tuple = left # Just for clarity.
		#
		# 			expr.right.indices_in_order.each do |index|
		# 				unless array_or_tuple.is_a? Ore::Array
		# 					# note: If left were a ::Number, subscript notation would succeed because that is integer bit indexing.
		# 					raise Ore::Invalid_Dot_Infix_Left_Operand.new(expr, runtime)
		# 				end
		# 				array_or_tuple = array_or_tuple[index]
		# 			end
		#
		# 			return array_or_tuple
		# 		end
		#
		# 	elsif left.kind_of? Ore::Range
		# 		if expr.right.is(Ore::Func_Expr) && expr.right.name.value == 'each'
		# 			# todo: Should be handled by #interp_func_call?
		#
		# 			left.each do |it|
		# 				each_scope = Ore::Scope.new 'each{;}'
		# 				runtime.push_scope each_scope
		# 				each_scope.declare 'it', it
		# 				expr.right.expressions.each do |expr|
		# 					interpret expr
		# 				end
		# 				runtime.pop_scope
		# 			end
		# 		end
		# 		return left
		#
		# 	elsif left.kind_of? Ore::Dictionary
		# 		case expr.right.value
		# 		when 'keys', 'values', 'count'
		# 			# note: keys, values, and count are declared on Ore::Dictionary so just call through to it
		# 			left.dict.send expr.right.value
		# 		else
		# 			# Fall through to normal scope lookup
		# 			runtime.push_scope left
		# 			result = interpret expr.right
		# 			runtime.pop_scope
		# 			return result
		# 		end
		#
		# 	else
		# 		raise Invalid_Dot_Infix_Left_Operand.new(expr, runtime) if left == nil
		#
		# 		runtime.push_scope left
		# 		result = interpret expr.right
		# 		runtime.pop_scope
		#
		# 		return result
		# 	end
		# end

		# @param expr [Ore::Infix_Expr]
		def interp_infix expr
			case expr.operator
			when '='
				interp_infix_equals expr
			when '.'
				interp_dot_infix expr
			when '<<'
				left  = maybe_instance interpret expr.left
				right = interpret expr.right

				if left.is_a?(Ore::Array)
					left.values << right
				else
					begin
						# todo: I don't like generic approach because the type of `left` is unknown at this moment.
						left.send expr.operator, right
					rescue
						# todo: Proper error
						raise "Unsupported << operator for #{expr.inspect}"
					end
				end
			else
				if expr.left.value == UNPACK_PREFIX
					case expr.operator
					when '+='
						right = interpret expr.right
						raise Ore::Invalid_Unpack_Infix_Right_Operand.new(expr, runtime) unless right.is_a? Ore::Scope
						runtime.stack.last.sibling_scopes << right
					when '-='
						right = interpret expr.right
						raise Ore::Invalid_Unpack_Infix_Right_Operand.new(expr, runtime) if right && !(right.is_a? Ore::Scope)
						runtime.stack.last.sibling_scopes.delete right # todo: Warn or error when trying to -= a scope that isn't a sibling?
					else
						raise Invalid_Unpack_Infix_Operator.new(expr, runtime)
					end
				elsif INFIX_ARITHMETIC_OPERATORS.include? expr.operator
					left  = maybe_instance interpret expr.left
					right = maybe_instance interpret expr.right

					if left.is_a?(Ore::Array) && expr.operator == '<<'
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
					assignment_infix          = Ore::Infix_Expr.new
					assignment_infix.left     = expr.left
					assignment_infix.operator = '='

					right_side_infix          = Ore::Infix_Expr.new
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
						Ore::Range.new start, finish
					when '.<'
						Ore::Range.new start, finish, exclude_end: true
					when '>.'
						Ore::Range.new start + 1, finish
					when '><'
						Ore::Range.new start + 1, finish, exclude_end: true
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
			# note: See constants.rb POSTFIX for exhaustive list of language-defined postfixes. Currently there are no built-in postfix operators.
			raise Ore::Unhandled_Postfix.new(expr, runtime)
		end

		def interp_circumfix expr
			case expr.grouping
			when '[]'
				array = Ore::Array.new

				expr.expressions.each do |e|
					array.values << interpret(e)
				end

				array
			when '()'
				if expr.expressions.empty?
					Ore::Tuple.new 'Tuple' # For now, I guess. What else should I do with empty parens?
				elsif expr.expressions.count == 1
					interpret expr.expressions.first
				else
					values       = expr.expressions.reduce([]) do |arr, expr|
						arr << interpret(expr)
					end
					tuple        = Ore::Tuple.new 'Tuple'
					tuple.values = values
					tuple
				end
			when '{}'
				expr.expressions.reduce(Ore::Dictionary.new) do |dict, it|
					if it.is_a? Ore::Identifier_Expr
						dict[it.value.to_sym] = nil
					elsif it.is_a? Ore::Infix_Expr
						case it.operator
						when ':', '='
							if it.left.is_a?(Ore::Identifier_Expr) || it.left.is_a?(Ore::Symbol_Expr) || it.left.is_a?(Ore::String_Expr)
								dict[it.left.value.to_sym] = interpret it.right
							else
								# The left operand should be allowed to be any hashable object. It's too early in the project to consider hashing but this'll be a good reminder.
								raise Ore::Invalid_Dictionary_Key.new(it, runtime)
							end
						else
							raise Ore::Invalid_Dictionary_Infix_Operator.new(it, runtime)
						end
					end
					# In case I forget, #reduce requires that the injected value be returned to be passed to the next iteration.
					dict
				end
			else
				# todo: Proper error
				raise "Interpreter#interp_circumfix unhandled circumfix #{expr.inspect}"
			end
		end

		def interp_call expr
			receiver = interpret expr.receiver

			case receiver
			when Ore::Instance, Ore::Type, Ore::Html_Element
				interp_type_call receiver, expr

			when Ore::Func # func()
				interp_func_call receiver, expr

			else
				raise Ore::Cannot_Initialize_Non_Type_Identifier.new expr.receiver, runtime
			end
		end

		def interp_type_call type, expr
			#
			# Ore::Type_Expr is converted to Ore::Type in #interp_type.
			# Ore::Instance inherits Ore::Type's @name and @types.
			#
			#     (See constructs.rb for Ore::Type and Ore::Instance declarations)
			#     (See expressions.rb for Ore::Type_Expr declaration)
			#
			# - Push instance onto runtime.stack
			# - Interpret type.expressions so the declarations are made on the instance
			# - Keep instance on the runtime.stack
			# - For each Ore::Func declared on instance, set `func.enclosing_scope = instance`
			# - Interpret instance[:new], the initializer
			# - Delete :new from instance, no longer needed
			#

			# :generalize_me
			instance = if type.name == 'Dictionary'
				Ore::Dictionary.new
			else
				Ore::Instance.new type.name
			end
			# instance       = Ore::Instance.new type.name
			instance.types = type.types

			# note: There was a bug here where I wasn't popping the instance after interpreting the type's expressions. That caused the #new function below (func_new) to not properly interpret arguments passed to it.
			runtime.push_then_pop instance do |scope|
				type.expressions.each do |expr|
					interpret expr
				end
			end

			instance.declarations.each do |key, decl|
				next unless decl.is_a? Ore::Func

				cloned                     = decl.dup
				cloned.enclosing_scope     = instance
				instance.declarations[key] = cloned
			end

			func_new = instance[:new]
			if func_new
				interp_func_call func_new, expr
			else
				if expr.arguments.count > 0
					# todo: Proper error
					raise "Given #{expr.arguments.count} arguments, but new{;} was not declared for #{type.inspect}"
				end
			end

			instance.delete :new
			instance
		end

		def interp_func_call func, expr
			call_scope = Ore::Scope.new func.name

			params = func.expressions.select do |expr|
				expr.is_a? Ore::Param_Expr
			end

			if expr.arguments.count > params.count
				# todo: Proper error
				raise "Arguments given, no params declared #{expr.inspect}"
			end

			# Evaluate arguments in caller's scope (before pushing function scopes)
			arg_values = expr.arguments.map { |arg| interpret arg }

			runtime.push_scope func.enclosing_scope
			runtime.push_scope call_scope
			params.each_with_index do |param, i|
				value = if i < arg_values.length
					arg_values[i]
				elsif param.default
					interpret param.default
				else
					raise Ore::Missing_Argument.new(expr, runtime)
				end

				runtime.stack.last.declare param.name, value

				if param.unpack && value.is_a?(Ore::Instance)
					call_scope.sibling_scopes << value
				end
			end

			body = func.expressions - params
			if func.name == 'assert'
				raise Ore::Assert_Triggered.new(expr, runtime) unless interpret(body.first) == true # Just to be explicit.
			end

			result = nil
			body.each do |e|
				next if e.is_a? Ore::Param_Expr

				result = interpret e
				break if result.is_a? Ore::Return
			end

			Ore.assert runtime.pop_scope == call_scope
			Ore.assert runtime.pop_scope == func.enclosing_scope

			result
		end

		# @param route [Ore::Route] The route to execute
		# @param req [Ore::Request] Request object to inject
		# @param res [Ore::Response] Response object to inject
		# @param url_params [Hash] Extracted URL parameters (e.g., {"id" => "123"})
		# @return The result of handler execution
		def interp_route_handler route, req, res, url_params = {}
			handler = route.handler
			params  = handler.expressions.select { |e| e.is_a? Ore::Param_Expr }

			call_scope = Ore::Scope.new "#{handler.name || 'anonymous'}_route"
			runtime.push_scope handler.enclosing_scope
			runtime.push_scope call_scope

			# Make request and response available without explicit declaration
			call_scope.declare 'request', req
			call_scope.declare 'response', res

			# Bind URL parameters as function arguments. For example, get://:abc/:def { abc, def; }
			params.each do |param|
				value = url_params[param.name] || url_params[param.name.to_sym]

				if value.nil?
					if route.param_names.include? param.name
						# todo: I haven't triggered this yet to ensure this works.
						# todo: Proper error
						raise "Route parameter '#{param.name}' expected but not found in URL"
					end

					# Use default value or raise
					if param.default
						value = interpret param.default
					else
						# todo: Is this reachable?
						raise Ore::Missing_Argument.new(expr, runtime)
					end
				end

				call_scope.declare param.name, value
			end

			body   = handler.expressions - params
			result = nil

			body.each do |expr|
				next if expr.is_a? Ore::Param_Expr # Reminder, param expressions are part of the function body by design. This is redundant because I'm subtracting the params from the handler expressions a few lines above, but just in case!

				result = interpret expr
				break if result.is_a? Ore::Return
			end

			if result.is_a? String
				res.body_content         = result
				res.declarations['body'] = result
			elsif result.is_a? Ore::Array
				html = ''
				result.values.each do |it|
					if it.is_a? String
						html += it
					elsif it.is_a?(Ore::Instance) && it.types.include?('Dom')
						html += render_dom_to_html it
					end
				end
				res.body_content         = html
				res.declarations['body'] = html
			elsif result.is_a? Ore::Instance
				# todo: Maybe find a better class name than Dom, and add a constant for it.
				if result.types.include? 'Dom'
					html                     = render_dom_to_html result
					res.body_content         = html
					res.declarations['body'] = html
				else
					res.body_content         = result.inspect
					res.declarations['body'] = result.inspect
				end
			end

			# Clean up scopes
			popped_call      = runtime.pop_scope
			popped_enclosing = runtime.pop_scope

			Ore.assert popped_call == call_scope
			Ore.assert popped_enclosing == handler.enclosing_scope

			result
		end

		def render_dom_to_html dom_instance
			# todo: Clean up this method
			html_attrs = dom_instance.declarations.select { |k, v| k.to_s.start_with? 'html_' }
			css_attrs  = dom_instance.declarations.select { |k, v| k.to_s.start_with? 'css_' }
			render     = dom_instance.declarations['render']
			element    = html_attrs['html_element']

			html_attrs = html_attrs.reject { |k, v| k == 'html_element' }

			html_attrs = html_attrs.map do |key, value|
				key = key.to_s.gsub 'html_', ''
				key = key.gsub '_', '-'
				[key, value]
			end.to_h

			css_attrs = css_attrs.map do |key, value|
				key = key.to_s.gsub 'css_', ''
				key = key.gsub '_', '-'
				[key, value]
			end.to_h

			html = "<#{element}"

			unless html_attrs.empty?
				html += " "
				html += html_attrs.map { |key, value| "#{key}=\"#{value}\"" }.join(' ')
			end

			unless css_attrs.empty?
				html += " style=\""
				html += css_attrs.map { |key, value| "#{key}:#{value}" }.join(';')
				html += "\""
			end

			html += ">"

			if render
				call_expr           = Ore::Call_Expr.new
				call_expr.receiver  = render
				call_expr.arguments = []

				render_result = interp_func_call render, call_expr

				if render_result.is_a?(String)
					html += render_result
				elsif render_result.is_a?(Ore::Array)
					render_result.values.each do |child|
						if child.is_a?(String)
							html += child
						elsif child.is_a?(Ore::Instance) && child.types.include?('Dom')
							html += render_dom_to_html(child)
						end
					end
				elsif render_result.is_a?(Ore::Instance) && render_result.types.include?('Dom')
					html += render_dom_to_html(render_result)
				end
			end

			html += "</#{element}>"
			html
		end

		def interp_type expr
			type = Ore::Type.new expr.name.value

			type.expressions = expr.expressions

			if type.types
				type.types << type.name
			else
				type.types = [type.name]
			end

			# todo: Make @types a set
			type.types = type.types.uniq
			runtime.stack.last.declare type.name, type

			runtime.push_then_pop type do |scope|
				expr.expressions.each do |expr|
					interpret expr
				end
			end

			type
		end

		def interp_element expr
			element             = Ore::Html_Element.new expr.element.value
			element.expressions = expr.expressions
			# element.attributes = filtered element.expressions

			runtime.stack.last.declare element.name, element

			runtime.push_then_pop element do |scope|
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

			route                 = Ore::Route.new
			route.enclosing_scope = runtime.stack.last
			route.handler         = expression
			route.http_method     = expr.http_method
			route.path            = expr.path
			route.path            = route.path[1..] if route.path.start_with? '/'
			route.param_names     = expr.param_names || []

			route.parts = route.path.split('/').reject do
				_1.empty?
			end

			unless expression.is_a? Ore::Func
				raise Ore::Invalid_Http_Directive_Handler.new(expr, runtime)
			end

			route_key = if expression.name && expression.name != 'Ore::Func'
				expression.name
			else
				# Anonymous route with auto-generated key: "method:path"
				"#{route.http_method.value}:#{route.path}"
			end

			# Store route in the enclosing Type's @routes if it has one (e.g., Server)
			enclosing_type = runtime.stack.reverse.find do |scope|
				scope.is_a?(Ore::Type) || scope.is_a?(Ore::Server)
			end
			if enclosing_type
				enclosing_type.routes            ||= {}
				enclosing_type.routes[route_key] = route
			end

			runtime.routes[route_key] = route
			runtime.stack.last.declare route_key, route if expression.name && expression.name != 'Ore::Func'

			route
		end

		def interp_func expr
			func                 = Ore::Func.new expr.name&.value
			func.enclosing_scope = runtime.stack.last
			func.expressions     = expr.expressions

			if func.name
				runtime.stack.last.declare func.name, func
			end

			func
		end

		def interp_composition expr
			# These are interpreted sequentially, so there are no precedence rules. I think that'll be better in the long term because there's no magic behind their evaluation. You can ensure the correct outcome by using these operators to form the types you need.

			operand_scope = interp_identifier expr.identifier
			unless operand_scope.is_a? Ore::Scope
				# todo: Proper error
				raise "Expected a scope to compose with, got #{operand_scope.inspect}"
			end
			curr_scope    = runtime.stack.last

			case expr.operator
			when '|'
				# Union with Ore::Type
				operand_scope.declarations.each do |key, value|
					curr_scope[key] ||= value
				end

				curr_scope.types ||= []
				curr_scope.types += operand_scope.types
				curr_scope.types = curr_scope.types.uniq
			when '~'
				# Removal of Ore::Type

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
				# todo: Proper error
				raise "Unknown composition operator #{expr.operator}"
			end
		end

		def interp_for_loop expr
			collection = interpret expr.collection
			stride     = interpret(expr.stride) if expr.stride

			Ore.assert collection.is_a?(Ore::Array) || collection.is_a?(Ore::Range)
			Ore.assert stride.nil? || stride.is_a?(Integer), "Stride must be an integer" if stride

			runtime.push_then_pop Scope.new('for_loop') do |scope|
				values = if collection.is_a? Ore::Range
					collection
				else
					collection.values
				end

				if stride
					catch :stop do
						values.each_slice(stride).with_index do |elements, index|
							scope.declare 'it', elements
							scope.declare 'at', index
							catch :skip do
								expr.body.each do |e|
									interpret e
								end
							end
						end
					end
				else
					catch :stop do
						values.each_with_index do |element, index|
							scope.declare 'it', element
							scope.declare 'at', index
							catch :skip do
								expr.body.each do |e|
									interpret e
								end
							end
						end
					end
				end
			end
		end

		def interp_conditional expr
			# I'm being very explicit with the "== true" checks of the condition. It's easy to misread this to mean that as long as it's not nil. While the distinction in this case may not matter (in Ruby), I still haven't decided how this language will handle truthiness.
			case expr.type
			when 'while', 'until', 'elwhile'
				result    = nil
				condition = interpret(expr.condition)

				if expr.type == 'until'
					catch :stop do
						until condition == true
							catch :skip do
								expr.when_true.each do |stmt|
									result = interpret(stmt)
								end
							end
							condition = interpret(expr.condition)
						end
					end
				else
					catch :stop do
						while condition == true
							catch :skip do
								expr.when_true.each do |stmt|
									result = interpret(stmt)
								end
							end
							condition = interpret(expr.condition)
						end
					end
				end

				if expr.when_false.is_a? Ore::Conditional_Expr
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

				if body.is_a? Ore::Conditional_Expr
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

				if body.is_a? Ore::Conditional_Expr
					interp_conditional body
				else
					result = body.each.inject(nil) do |result, expr|
						interpret expr
					end

					result || nil
				end
			end
		end

		# todo:_Maybe this should go on Ore::Server?
		def collect_routes_from_instance instance
			routes = {}

			instance.types.each do |type_name|
				type_def = runtime.stack.first[type_name]
				next unless type_def && type_def.respond_to?(:routes) && type_def.routes

				# Merge routes from this type
				type_def.routes.each do |key, route|
					routes[key] ||= route
				end
			end

			routes
		end

		def interp_directive expr
			case expr.name.value
			when 'start'
				server_instance = interpret expr.expression
				unless server_instance.is_a? Ore::Instance
					raise Ore::Invalid_Start_Diretive_Argument.new(expr, runtime)
				end

				routes = collect_routes_from_instance server_instance

				server_runner = Ore::Server_Runner.new server_instance, self, routes
				runtime.servers << server_runner

				server_runner.start
				server_runner
			when 'load'
				# Standalone load is interpreted into current scope by passing the scope into runtime#load_file
				filepath = interpret expr.expression
				runtime.load_file filepath, runtime.stack.last
				# note: #load_file returns the output but it's ignored. Assigning the value of a #load directive executres code in #interp_infix_expr
			else
				raise Ore::Directive_Not_Implemented.new(expr, runtime)
			end
		end

		def interp_subscript expr
			if expr.expression.expressions.count > 1
				raise Ore::Too_Many_Subscript_Expressions.new(expr.expression, runtime)
			end

			receiver = interpret expr.receiver
			key      = interpret expr.expression.expressions.first

			case receiver
			when Ore::Dictionary, Ore::Array
				receiver[key]
			else
				raise Ore::Invalid_Dot_Infix_Left_Operand.new(expr, runtime)
			end
		end

		def interpret expr
			case expr
			when Ore::Number_Expr, Ore::Symbol_Expr
				expr.value

			when Ore::Identifier_Expr
				interp_identifier expr

			when Ore::String_Expr
				interp_string expr

			when Ore::Type_Expr
				interp_type expr

			when Ore::Html_Element_Expr
				interp_element expr

			when Ore::Route_Expr
				interp_route expr

			when Ore::Func_Expr
				interp_func expr

			when Ore::Composition_Expr
				interp_composition expr

			when Ore::Prefix_Expr
				interp_prefix expr

			when Ore::Infix_Expr
				interp_infix expr

			when Ore::Postfix_Expr
				interp_postfix expr

			when Ore::Circumfix_Expr
				interp_circumfix expr

			when Ore::Call_Expr
				interp_call expr

			when For_Loop_Expr
				interp_for_loop expr

			when Ore::Conditional_Expr
				interp_conditional expr

			when Ore::Array_Index_Expr
				expr.indices_in_order

			when Ore::Subscript_Expr
				interp_subscript expr

			when Ore::Directive_Expr
				interp_directive expr

			when Ore::Comment_Expr
				# todo: Something?

			when Ore::Operator_Expr
				case expr.value
				when 'skip'
					throw :skip
				when 'stop'
					throw :stop
				end
			else
				raise Ore::Interpret_Expr_Not_Implemented.new(expr, runtime)
			end
		end
	end
end
