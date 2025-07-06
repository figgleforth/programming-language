class Interpreter
	require './lang/constants'
	require './lang/parser/expression'
	require './lang/interpreter/constructs'
	require './lang/interpreter/errors'

	attr_accessor :i, :input, :stack, :global

	def initialize input = [] # [Expression]
		@input  = input
		@global = Scope.new
		@stack  = [@global]

		# todo Global declarations like String, Int, etc. Maybe some #make_* functions, or a generic one. But not here, this is ugly.
		string      = Instance.new
		string.name = 'String'
		set_in_scope curr_scope, 'String', string
	end

	def output
		# todo I'd like to collect errors and keep interpreting the program if possible. Or should that only happen at the Parser?
		out = nil
		input.each do |it|
			out = interpret it
		end
		out
	end

	# todo Use this in orher places instead of manually adding to the stack
	def temporarily_push_scope scope, &block
		already_top_scope = curr_scope == scope
		stack << scope unless already_top_scope
		yield scope if block_given?
		stack.pop unless already_top_scope
	end

	def add_to_stack scope
		stack << scope unless curr_scope == scope
	end

	def get_scope_containing identifier
		stack.reverse.find do |it|
			it[identifier]
		end
	end

	def set_in_curr_scope identifier, value = nil
		scope = get_scope_containing(identifier) || curr_scope
		set_in_scope scope, identifier, value
	end

	def set_in_scope scope, identifier, value = nil
		scope[identifier] = value
	end

	def curr_scope
		stack.last
	end

	def interpret expr
		case expr
		when Number_Expr, String_Expr
			expr.value

		when Symbol_Expr
			expr.value.to_sym

		when Identifier_Expr
			return true if expr.value == 'true'
			return false if expr.value == 'false'

			receiver_scope = get_scope_containing(expr.value) || curr_scope
			if not receiver_scope
				raise Undeclared_Identifier.new expr.inspect
			end
			receiver_scope[expr.value]

		when Prefix_Expr
			case expr.operator
			when '-'
				-interpret(expr.expression)
			when '+'
				+interpret(expr.expression)
			when '!', 'not'
				!interpret(expr.expression)
			when './'
				interpret expr.expression
			else
				raise Unhandled_Prefix.new expr
			end

		when Infix_Expr
			if expr.operator == ':='
				# Regular declarations where the type will be inferred later.
				set_in_curr_scope expr.left.value, interpret(expr.right)
			elsif expr.operator == '=' && expr.left.type
				# These are `variable: Type` declaration so treat it as a := since I don't do anything with the type at the moment. Maybe this part won't be impacted by the implementation of types. We'll see.
				expr.operator = ':='
				interpret expr

			elsif expr.operator == '='
				if expr.left.value == expr.left.value.upcase
					raise Cannot_Reassign_Constant
				end

				receiver_scope = get_scope_containing(expr.left.value) || curr_scope
				if receiver_scope[expr.left.value]
					set_in_scope receiver_scope, expr.left.value, interpret(expr.right)
				else
					raise Cannot_Assign_Undeclared_Identifier
				end

			elsif expr.operator == '.' && expr.right.value == 'new'
				receiver_scope = get_scope_containing(expr.left.value)
				if not receiver_scope
					raise Cannot_Initialize_Undeclared_Identifier.new expr.left.value
				end

				receiver = receiver_scope[expr.left.value]

				if receiver.is_a? Type
					it             = Instance.new
					it.name        = receiver.name
					it.hash        = receiver.hash
					it.expressions = receiver.expressions
					# todo Don't separate compositions from expressions. It isn't necessary.
					it.compositions = receiver.compositions
					receiver        = it
				end

				add_to_stack receiver
				receiver.expressions.each do |it|
					interpret it
				end
				stack.pop
				receiver

			elsif expr.operator == '.'
				left = interpret expr.left

				case left
				when Scope, Instance, Type
				else
					raise Undeclared_Identifier.new expr.left
				end

				temporarily_push_scope left do
					result = interpret(expr.right)

					if not result
						raise Undeclared_Identifier.new expr.right
					end
					return result
				end

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
				left  = interpret expr.left
				right = interpret expr.right
				left.send expr.operator, right

			elsif COMPOUND_OPERATORS.include? expr.operator
				left_scope = get_scope_containing(expr.left.value)
				add_to_stack left_scope
				left   = interpret expr.left
				right  = interpret expr.right
				result = left.send expr.operator[..-2], right
				stack.pop
				result

			elsif %w(&& & || | and or).include? expr.operator
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
					left  = interpret expr.left
					right = interpret expr.right
					left.send expr.operator, right
				rescue Exception => e
					# A reminder not to naively rescue here, otherwise you won't be able to catch any raises from within interpreter.
					raise e
				end
			end

		when Postfix_Expr
			case expr.operator
			when '=;'
				receiver_scope = get_scope_containing(expr.expression.value) || curr_scope
				set_in_scope receiver_scope, expr.expression.value, nil
				# #todo or Nil_Construct. Ruby has NilClass.
				# when ';' #todo I want `identifier;` to behave just like `=;` but currently ';' does not resolve to a postfix expression.
			else
				raise Unhandled_Postfix.new expr
			end

		when Circumfix_Expr
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
						dict[it.value.to_sym] = nil
					elsif it.is_a? Infix_Expr
						case it.operator
						when ':', '='
							# The left operand can be any hashable object. It's too early in the project to consider hashing but I need to special case for it now.
							if it.left.is_a?(Identifier_Expr) || it.left.is_a?(Symbol_Expr)
								dict[it.left.value.to_sym] = interpret it.right
							else
								raise Invalid_Dictionary_Key
							end
						else
							raise Invalid_Dictionary_Infix_Operator
						end
					end
					dict # In case I forget, #reduce requires that the injected value be returned to be passed to the next iteration.
				end

			else
				raise Unhandled_Circumfix_Expr.new expr
			end

		when Call_Expr
			receiver = if expr.receiver.is(Infix_Expr)
				interpret expr.receiver # dot-chains etc.
			else
				interpret expr.receiver
			end

			case receiver
			when Type
				add_to_stack receiver
				receiver.expressions.each do |it|
					interpret it
				end
				stack.pop
				receiver

				it             = Instance.new
				it.name        = receiver.name
				it.hash        = receiver.hash
				it.expressions = receiver.expressions
				# todo Don't separate compositions from expressions. It isn't necessary.
				it.compositions = receiver.compositions
				it

			when Func
				add_to_stack receiver
				receiver.params.zip(expr.arguments).each do |param, arg|
					set_in_curr_scope param.name, interpret(arg)
				end
				result = nil
				receiver.expressions.each { |e| result = interpret e }
				stack.pop
				result

			else
				raise Unhandled_Call_Receiver, receiver.inspect
			end

		when Func_Expr
			it             = Func.new
			it.name        = expr.name
			it.params      = expr.param_decls
			it.expressions = expr.expressions

			if expr.name
				receiver_scope = get_scope_containing(expr.name) || curr_scope
				set_in_scope receiver_scope, expr.name, it
			end

			it

		when Type_Decl
			it              = Type.new
			it.name         = expr.name
			it.compositions = expr.composition_exprs
			it.expressions  = expr.expressions

			receiver_scope = get_scope_containing(expr.name) || curr_scope
			set_in_scope receiver_scope, expr.name, it

			it

		else
			raise Unhandled_Expr.new expr
		end
	end
end
