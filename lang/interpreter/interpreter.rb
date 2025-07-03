require './lang/parser/expression'
require './lang/interpreter/constructs'
require './lang/interpreter/errors'
require './lang/constants'

class Runtime < Hash
end

class Interpreter
	attr_accessor :i, :input, :stack, :runtime

	def initialize input = [] # [Expression]
		@input   = input
		@stack   = []
		@runtime = make_scope GSCOPE, 0

		# Global declarations like String, Int, etc
		set_in_scope @runtime, 'String', Type_Blueprint.new.tap {
			it.name = 'String'
		}
	end

	# A scope is for anything that can carry declarations. That would be global and instances.
	def make_scope type, id
		{
			__type: type,
			__id:   id
		}
	end

	def get_scope identifier
		stack.reverse.find do
			it.dig identifier
		end
	end

	def set_in_curr_scope identifier, value = nil
		scope = get_scope(identifier) || runtime
		set_in_scope scope, identifier, value
	end

	def set_in_scope scope, identifier, value = nil
		scope[identifier] = value
	end

	def output
		out = nil
		input.each do
			out = interpret it
		end
		out
		# I'd like to collect errors and keep interpreting the program if possible. Or should that only happen at the Parser?
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

			scope = get_scope(expr.value) || runtime
			scope[expr.value]

		when Prefix_Expr
			case expr.operator
			when '-'
				-interpret(expr.expression)
			when '+'
				+interpret(expr.expression)
			when '!'
				!interpret(expr.expression)
			else
				raise "Unhandled prefix #{expr.inspect}"
			end

		when Infix_Expr
			if expr.operator == ':='
				# [Global, Array] or [Global]
				scope = get_scope(expr.left.value) || runtime
				set_in_scope scope, expr.left.value, interpret(expr.right)
			elsif expr.operator == '=' && expr.left.type
				expr.operator = ':='
				interpret expr
				# scope = get_scope(expr.left.value) || runtime
				# set_in_scope scope, expr.left.value, interpret(expr.right)

			elsif expr.operator == '='
				if expr.left.value == expr.left.value.upcase
					raise Cannot_Reassign_Constant
				end

				scope = get_scope(expr.left.value) || runtime
				if scope&.include? expr.left.value
					set_in_scope scope, expr.left.value, interpret(expr.right)
				else
					raise Cannot_Assign_Undeclared_Identifier
				end

			elsif expr.operator == '.' && expr.right.value == 'new'
				scope = get_scope(expr.left.value) || runtime
				type  = scope[expr.left.value]
				if not type
					raise Cannot_Initialize_Undeclared_Identifier
				end

				if not type.is_a? Type_Blueprint
					raise "this should never happen"
				end

				hash = Type_Blueprint.to_h type

				stack << hash
				type.exprs.each do |it|
					interpret it
				end
				stack.pop
				hash
			elsif expr.operator == '.'
				scope = get_scope(expr.left.value) || runtime
				if not scope
					raise Undeclared_Identifier
				end

				left = interpret expr.left
				stack << left
				result = interpret expr.right
				stack.pop
				result
			elsif RANGE_OPERATORS.include? expr.operator
				start  = interpret expr.left
				finish = interpret expr.right
				case expr.operator # This is officially a templated language, haha
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
				if expr.operator == 'in'
					left  = interpret expr.left
					right = interpret expr.right
					right.include? left # #todo improve
				else
					left  = interpret expr.left
					right = interpret expr.right
					left.send expr.operator, right
				end

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
				rescue
					raise Invalid_Infix.new
				end
			end

		when Postfix_Expr
			case expr.operator
			when '=;'
				scope = get_scope(expr.expression.value) || runtime
				set_in_scope scope, expr.expression.value, nil # #todo or Nil_Construct. Ruby has NilClass.
				# when ';' #todo
			else
				raise "Runtime#interpret(when Postfix) not yet handling #{expr.inspect}"
			end

		when Circumfix_Expr
			case expr.grouping
			when '()'
				values       = expr.expressions.reduce([]) do |arr, expr|
					arr << interpret(expr)
				end
				tuple        = Tuple.new
				tuple.values = values
				tuple

			when '[]'
				expr.expressions.reduce([]) do |arr, expr|
					arr << interpret(expr)
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
				raise Invalid_Dictionary_Expr
			end

		when Call_Expr
			# :receiver, :arguments
			scope = get_scope(expr.receiver.value) || runtime
			type  = scope[expr.receiver.value]
			if not type
				raise Cannot_Initialize_Undeclared_Identifier
			end

			# #todo implementation for Type_Blueprint and Func_Blueprint are not the same. This currently assumes a Type_Blueprint

			hash = Type_Blueprint.to_h type

			stack << hash
			type.exprs.each do |it|
				interpret it
			end

			# if new{;} is declared, call it with
			stack.pop
			hash
			# #todo this is a copy paste from Infix.new above

		when Func_Expr
			it        = Func_Blueprint.new
			it.name   = expr.name
			it.params = expr.param_decls
			it.exprs  = expr.expressions
			# #todo These need to be converted to a hash to be :homoiconic_expressions

			if expr.name
				scope = get_scope(expr.name) || runtime
				set_in_scope scope, expr.name, it
			end

			it

		when Type_Decl
			# :homoiconic_expressions
			it              = Type_Blueprint.new
			it.name         = expr.name
			it.compositions = expr.composition_exprs
			it.exprs        = expr.expressions

			scope = get_scope(expr.name) || runtime
			set_in_scope scope, expr.name, it

			it
		else
			raise Unhandled_Expr.new expr
		end
	end
end
