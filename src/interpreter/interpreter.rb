class Interpreter
	require './src/constants'
	require './src/parser/expressions'
	require './src/interpreter/constructs'
	require './src/errors'
	require './src/helpers'

	@@skip_preload = false

	attr_accessor :i, :input, :stack, :global

	def initialize input = [] # of `Expression`s
		@input = input
		@stack = []
	end

	def wrap_in_runtime_hash value
		case value
		when Integer, Float
			number_type        = global['Number']
			inst               = number_type.dup
			inst[:numerator]   = value
			inst[:denominator] = if value.is_a? Float
				1.0
			else
				1
			end
			inst
		else
			value
		end
	end

	def output
		@global = Scope.new
		add_to_stack global

		prepend_builtin_types_for_interp unless @@skip_preload

		out = nil
		input.each do |it|
			out = interpret it
		end
		out
	end

	def prepend_builtin_types_for_interp
		all_type_expressions = parse_file './src/emerald/preload.e'
		all_type_expressions.each_with_index do |it, at|
			interpret it
		end
	end

	def push_then_pop scope, &block
		already_top = curr_scope == scope
		stack << scope unless already_top
		yield scope
	ensure
		stack.pop unless already_top || stack.count == 1
	end

	def add_to_stack scope
		stack << scope unless curr_scope == scope
	end

	def get_scope_containing identifier
		stack.reverse.find do |it|
			it[identifier]
		end
	end

	def set_in_curr_scope identifier, value = Nil.new
		scope = get_scope_containing(identifier) || curr_scope
		set_in_scope scope, identifier, value
	end

	def set_in_scope scope, identifier, value = Nil.new
		scope                          ||= @global
		scope.declarations[identifier] = value
	end

	def curr_scope
		stack.last
	end

	def interp_assert expr
		# Copypaste from #interp_call when Func.
		receiver = interpret expr.receiver
		result   = Nil.new

		push_then_pop receiver do
			receiver.params.zip(expr.arguments).each do |param, arg|
				if arg
					set_in_curr_scope param.name, interpret(arg)
				else
					# todo, :make_use_of_type
					set_in_curr_scope param.name, Nil.new
				end
			end
			receiver.expressions.each do |e|
				result = interpret e
			end
		end

		if result == false
			raise Assert_Triggered, expr.inspect
		end

		result
	end

	def interp_string expr
		if expr.interpolated
			result = ''
			parts  = expr.value.split('`')

			# Process split parts by alternating between string content and expressions to interpolate. Even-indexed parts are regular string content. Odd-indexed parts are expressions to interpolate.
			parts.each_with_index do |part, index|
				next if index.even?

				if part.empty? || part.chars.all? { |c| c == ' ' }
					next
				end

				lexemes     = Lexer.new(part).output
				expressions = Parser.new(lexemes).output

				value = nil
				expressions.each do |expr_part|
					value = interpret(expr_part)
				end

				result += value.to_s unless value.nil?
				result
			end

			result
		else
			expr.value
		end
	end

	def interp_identifier expr
		return true if expr.value == 'true'
		return false if expr.value == 'false'
		return Nil.new if expr.value == 'nil'

		# We should always have a scope, there's no need to check whether we have receiver_scope. If that's nil then there's something very wrong.
		receiver_scope = get_scope_containing(expr.value) || curr_scope
		if not receiver_scope
			raise Undeclared_Identifier, expr.value.inspect
		end
		value          = receiver_scope[expr.value]

		if expr.type
			receiver_scope[expr.value] = Nil.new
		else
			if value == nil
				raise Undeclared_Identifier, expr.value.inspect
			end
		end

		value
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
		if expr.operator == ':='
			# Regular declarations where the type will be inferred later.
			set_in_curr_scope expr.left.value, interpret(expr.right)

		elsif expr.operator == '=' && expr.left.type
			# These are `variable: Type` declaration so treat it as a := since I don't do anything with the type at the moment. Maybe this part won't be impacted by the implementation of types. We'll see.
			expr.operator = ':='
			interpret expr

		elsif expr.operator == '='
			if expr.left.value == expr.left.value.upcase
				raise Cannot_Reassign_Constant, expr.inspect
			end

			receiver_scope = get_scope_containing(expr.left.value) || curr_scope
			if receiver_scope[expr.left.value]
				set_in_scope receiver_scope, expr.left.value, interpret(expr.right)
			else
				raise Cannot_Assign_Undeclared_Identifier, expr.inspect
			end

		elsif expr.operator == '.' && expr.right.is('new')
			interp_dot_new expr

		elsif expr.operator == '.'
			interp_dot_infix expr

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

		elsif COMPARISON_OPERATORS.include? expr.operator
			receiver = interpret expr.left
			right    = interpret expr.right
			receiver.send expr.operator, right

		elsif COMPOUND_OPERATORS.include? expr.operator
			left_scope = get_scope_containing(expr.left.value)
			result     = nil
			push_then_pop left_scope do
				add_to_stack left_scope
				receiver = interpret expr.left
				right    = interpret expr.right
				result   = receiver.send expr.operator[..-2], right
				set_in_curr_scope expr.left.value, result
			end
			result

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

		else
			begin
				receiver = interpret expr.left
				right    = interpret expr.right
				receiver.send expr.operator, right
			rescue Exception => e
				# A reminder not to naively rescue here, otherwise you won't be able to catch any raises from within interpreter.
				raise e
			end
		end
	end

	def interp_dot_new expr
		receiver = interpret expr.left
		unless receiver.is_a? Type
			raise Cannot_Initialize_Undeclared_Identifier, expr.left.inspect
		end

		instance              = Instance.new
		instance.name         = receiver.name
		instance.declarations = receiver.declarations
		instance.expressions  = receiver.expressions
		instance.compositions = receiver.compositions

		push_then_pop instance do
			instance.expressions.each do |it|
				interpret it
			end
		end

		instance
	end

	def interp_dot_infix expr
		if expr.right.is_a? Array_Index_Expr
			raise Unhandled_Array_Index_Expr, expr.inspect
		end

		receiver = if expr.left.is Number_Expr
			# :extract_instance_creation
			wrap_in_runtime_hash interpret(expr.left)
		else
			interpret expr.left
		end

		case receiver
		when Scope
			result = nil
			push_then_pop wrap_in_runtime_hash(receiver) do
				result = interpret expr.right
			end
			result
		else
			raise Invalid_Dot_Infix_Left_Operand, expr.inspect
		end
	end

	def interp_postfix expr
		case expr.operator
		when '=;'
			receiver_scope = get_scope_containing(expr.expression.value) || curr_scope
			set_in_scope receiver_scope, expr.expression.value, Nil.new
		else
			raise Unhandled_Postfix, expr.inspect
		end
	end

	def interp_circumfix expr
		case expr.grouping
		when '[]'
			expr.expressions.reduce([]) do |arr, expr|
				arr << interpret(expr)
			end

		when '()'
			values = expr.expressions.reduce([]) do |arr, expr|
				arr << interpret(expr)
			end

			if values.count > 1
				tuple        = Tuple.new
				tuple.values = values
				tuple
			else
				values.first
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
			raise Unhandled_Circumfix_Expr, expr.inspect
		end
	end

	def interp_call expr
		if expr.receiver.value == 'assert'
			return interp_assert expr
		end

		receiver_scope = nil
		if expr.receiver.is(Infix_Expr) && expr.receiver.operator == '.'
			receiver_scope = interpret expr.receiver.left
			add_to_stack wrap_in_runtime_hash receiver_scope
		end

		receiver = interpret expr.receiver
		case receiver
		when Type
			push_then_pop receiver do
				receiver.expressions.each do |it|
					interpret it
				end
			end
			receiver

			it              = Instance.new
			it.name         = receiver.name
			it.declarations = receiver.declarations
			it.expressions  = receiver.expressions
			it.compositions = receiver.compositions
			it

		when Func
			result = Nil.new

			push_then_pop receiver do
				receiver.params.zip(expr.arguments).each do |param, arg|
					if arg
						set_in_curr_scope param.name, interpret(arg)
					elsif param.default
						set_in_curr_scope param.name, interpret(param.default)
					else
						# todo, :make_use_of_type
						set_in_curr_scope param.name, Nil.new
					end
				end
				result = Nil.new
				receiver.expressions.each do |e|
					result = interpret e
				end
			end

			result

		else
			raise Undeclared_Identifier, expr.inspect
		end
	end

	def interp_func expr
		it             = Func.new
		it.name        = expr.name
		it.params      = expr.param_decls
		it.expressions = expr.expressions

		if expr.name
			receiver_scope = get_scope_containing(expr.name) || curr_scope
			set_in_scope receiver_scope, expr.name, it
		end

		it
	end

	def interp_type expr
		it              = Type.new
		it.name         = expr.name
		it.compositions = expr.composition_exprs
		it.expressions  = expr.expressions

		push_then_pop it do
			it.expressions.each do |e|
				interpret e
			end
		end

		set_in_curr_scope expr.name, it

		it
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
			# 7/8/25, These should always return their "primitive" versions, then be wrapped in runtime versions as needed. Right? If anything, this makes testing easier because I don't have to unwrap back to the primitive.

		when String_Expr
			interp_string expr

		when Array_Index_Expr
			expr.indices_in_order
			# 7/9/25, I'm still unsure of how the .e <-> .rb files are going to interface. I kind of have an idea but not enough to move forward on things like this Array_Index_Expr.

		when Identifier_Expr
			interp_identifier expr

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

		when Func_Expr
			interp_func expr

		when Type_Decl
			interp_type expr

		when Conditional_Expr
			interp_conditional expr

		else
			raise Unhandled_Expr, expr.inspect
		end
	end
end
