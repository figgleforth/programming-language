require_relative '../helpers/colorize'


class Scope < Hash
	#             [Scope]            [Scope]
	attr_accessor :stack, :identity, :portals, :references
	#                     {}                   {}

	def initialize
		super

		@references = {}
		@identity   = {}
		@portals    = []
		@stack      = []
	end


	# @return Scope
	def curr_scope
		stack.last or self
	end


	# @param expr [Identifier_Expr, Prefix_Expr]
	def get expr
		unless expr.is_a? Identifier_Expr or expr.is_a? Prefix_Expr
			raise "Scope#get(expr) called with #{expr} but expected Ident_Expr or Prefix_Expr"
		end

		if expr.is_a? Prefix_Expr and expr.operator.string != '@'
			raise "Scope#get(expr) called with Prefix_Expr that is not @"
		elsif expr.is_a? Prefix_Expr and expr.operator.string == '@'
			return curr_scope.identity[expr.expression.string]
		end

		value = nil
		curr_scope.portals.each do
			value = _1.get expr
			return value if value
		end
		value = curr_scope.references[expr.string] unless value
		value = self[expr.string] unless value
		value
	end


	# When the passed block is called, it means that a scope exists which declares the given identifier. Not including self.
	# @param expr [Identifier_Expr]
	# @yieldparam scope [Scope] The scope where the identifier is found
	# @return [nil, Scope]
	def scope_containing expr, &block
		[stack + portals].flatten.find do|it|
			# _1: Scope
			if it.get expr
				block.call(it) if block_given?
				it
			end
		end
	end


	# @param expr [Identifier_Expr]
	# @return [Boolean] Whether
	def set expr, new_value = nil
		unless expr.is_a? Identifier_Expr
			raise "Scope#set(expr) called with #{expr} but expected Ident_Expr"
		end

		scope = scope_containing expr do
			# _1: Scope
			_1.set expr, new_value
		end

		unless scope # then set it on self
			self[expr.string] = new_value
			scope             = self
		end

		!!scope # true if scope was found
	end


	def interpret expressions = []
		@output = nil # value returned to the console
		expressions.each do
			@output = run _1
		end
		@output
	end


	# @param expr [Infix_Expr]
	def infix expr
		# builtin = Token::INFIX.include? expr.operator.string # otherwise it's a custom operator

		if expr.operator == '='
			set expr.left, run(expr.right)
		end
	end


	def run expr
		case expr
			when Number_Expr
				if expr.type == :int
					Integer(expr.string)
				elsif expr.type == :float
					if expr.decimal_position == :end
						Float(expr.string + '0')
					else
						Float(expr.string)
					end # no need to explicitly check :beginning decimal position (.1) because Float(string) can parse that
				end
			when String_Expr
				expr.to_string
			when Identifier_Expr
				get expr
			when Infix_Expr
				infix expr
			else
				puts
				puts colorize(7, 'ERROR ERROR ERROR ERROR', 'black')
				puts "last value: #{@output}"
				puts colorize(7, "Scope#run(#{expr.class}) not implemented")
				raise
		end
	end
end
