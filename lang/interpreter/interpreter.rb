require './lang/parser/expression'
require './lang/interpreter/constructs'
require './lang/interpreter/errors'
require './lang/constants'

class Interpreter
	attr_accessor :i, :input, :stack, :global

	def initialize input = [] # [Expression]
		@input  = input
		@stack  = []
		@global = Scope.new 'Global', 0

		# todo Global declarations like String, Int, etc. Maybe some #make_* functions, or a generic one.
		set_in_scope @global, 'String', Type.new.tap {
			it.name = 'String'
		}
	end

	def get_scope identifier
		stack.reverse.find do
			it.dig identifier
		end || global
	end

	def set_in_curr_scope identifier, value = nil
		scope = get_scope(identifier)
		set_in_scope scope, identifier, value
	end

	def set_in_scope scope, identifier, value = nil
		scope[identifier] = value
	end

	def curr_scope
		stack.last || global
	end

	def output
		out = nil
		input.each do
			out = interpret it
		end
		out
		# todo I'd like to collect errors and keep interpreting the program if possible. Or should that only happen at the Parser?
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

			scope = get_scope(expr.value)
			scope[expr.value]

		when Prefix_Expr
			case expr.operator
			when '-'
				-interpret(expr.expression)
			when '+'
				+interpret(expr.expression)
			when '!'
				!interpret(expr.expression)
			when './'
				# Declarations on self, similar to Ruby's self
				stack << curr_scope
				result = interpret expr.expression
				stack.pop
				result

			when '../'
				# todo Global declarations scope
			when '.../'
				# todo Third party declarations scope
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

				scope = get_scope(expr.left.value)
				if scope&.include? expr.left.value
					set_in_scope scope, expr.left.value, interpret(expr.right)
				else
					raise Cannot_Assign_Undeclared_Identifier
				end

			elsif expr.operator == '.' && expr.right.value == 'new'
				scope = get_scope(expr.left.value)
				type  = scope[expr.left.value]
				if not type
					raise Cannot_Initialize_Undeclared_Identifier
				end

				hash = Type.to_h type

				stack << hash
				type.expressions.each do |it|
					interpret it
				end
				stack.pop
				hash
			elsif expr.operator == '.'
				scope = get_scope(expr.left.value)
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
				left  = interpret expr.left
				right = interpret expr.right
				left.send expr.operator, right

			elsif COMPOUND_OPERATORS.include? expr.operator
				stack << get_scope(expr.left.value)
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
				rescue
					raise Invalid_Infix.new expr.inspect
				end
			end

		when Postfix_Expr
			case expr.operator
			when '=;'
				scope = get_scope(expr.expression.value)
				set_in_scope scope, expr.expression.value, nil
				# #todo or Nil_Construct. Ruby has NilClass.
				# when ';' #todo
			else
				raise Unhandled_Postfix.new expr
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
			scope = get_scope(expr.receiver.value)
			type  = scope[expr.receiver.value]
			if not type
				raise Cannot_Initialize_Undeclared_Identifier
			end

			if type.is_a? Type
				hash = Type.to_h type # :garbage

				stack << hash
				type.expressions.each do |it|
					interpret it
				end

				stack.pop
				hash
			elsif type.is_a? Func
				# todo This Func/Decl#to_h stuff is :garbage. Clean this up.
				hash = Func.to_h type

				stack << hash
				type.params.zip(expr.arguments).each do |it, arg|
					# These expressions also store a :type, so eventually I'll want to use that.
					set_in_curr_scope it.name, interpret(arg)
				end

				result = nil
				type.expressions.each do |it|
					result = interpret it
				end
				stack.pop
				result
			else
				raise Unhandled_Call_Expr.new(expr)
			end

		when Func_Expr
			it             = Func.new
			it.name        = expr.name
			it.params      = expr.param_decls
			it.expressions = expr.expressions

			if expr.name
				scope = get_scope(expr.name)
				set_in_scope scope, expr.name, it
			end

			it

		when Type_Decl
			it              = Type.new
			it.name         = expr.name
			it.compositions = expr.composition_exprs
			it.expressions  = expr.expressions

			scope = get_scope(expr.name)
			set_in_scope scope, expr.name, it

			it

		else
			raise Unhandled_Expr.new expr
		end
	end
end
