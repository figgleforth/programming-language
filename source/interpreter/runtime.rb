require_relative 'scopes'
require 'ostruct'
require 'securerandom'

CONTEXT_SYMBOL = 'scope'
SCOPE_KEY_TYPE = 'types'


class Reference
	# include Scopes
	attr_accessor :id


	def initialize
		@id = SecureRandom.uuid
	end


	def to_s
		# last 6 characters of the uuid, with a period in the middle
		"%{#{id[-5..]}}"
	end
end


class Runtime
	# todo Runtime should be Runtime < Global < Hash itself. Then it can be the global scope but with a stack built in. In the future, this will be able to read code from files, and insert their declarations
	attr_accessor :stack, :expressions, :warnings, :errors, :references, :last_evaluated


	def initialize expressions = []
		@expressions = expressions
		@references  = {}
		@warnings    = []
		@errors      = []
		@stack       = []
		preload_runtime
	end


	def preload_runtime
		push_scope (Scopes::Global.new.tap do |it|
		end), 'Em App'

		# @cleanup I'm sure there's a better way to do this
		[Scopes::String, Scopes::Array, Scopes::Hash].each do |atom|
			type              = atom.name.split('::').last
			instance          = Object.const_get(atom.to_s).new
			instance['types'] = [type]
			set type, instance
		end
	end


	def pp data
		puts PP.pp(data, '').chomp
	end


	def evaluate_expressions exprs = nil
		@expressions    = exprs unless exprs.nil?
		@last_evaluated = nil
		expressions.each do |it|
			@last_evaluated = evaluate it
		end
		@last_evaluated
	end


	# region Scopes – push, pop, set, get

	def push_scope scope, name = nil
		scope.name = if name.is_a? Identifier_Token
			name.string
		else
			name
		end if scope.respond_to? :name
		@stack << scope
		scope
	end


	# @param [Scopes::Scope] scope
	def compose_scope scope
		raise "trying to compose nil scope" if scope.nil?
		# puts "composing with #{scope}"
		curr_scope.compositions << scope
	end


	def pop_scope
		stack.pop unless stack.one?
	end


	def curr_scope
		stack.compact.last
	end


	def get_farthest_scope scope_type = nil
		return stack.first if stack.one?
		raise '#get_farthest_scope expected a scope type so it can create a hash of that type' if scope_type and not scope_type.is_a? Scopes::Scope

		# this merges two hashes into one hash. @todo get the reference to this, it was something off stackoverflow
		base_type = if scope_type
			scope_type
		else
			{}
		end
		[].tap do |it|
			stack.reverse_each do |scope|
				break if scope.is_a? Scopes::Static # stop looking, can't go further
				it << scope
				# all other blocks can be looked through
			end
		end.reduce(base_type, :merge)
	end


	def get identifier
		identifier = identifier.string if identifier.is_a? Identifier_Token

		value = nil

		case identifier
			when 'true'
				return true
			when 'false'
				return false
			else
				nil
		end

		# if identifier == 'X'
		#     puts "curr scope"
		#     pp curr_scope
		#     puts "compositions"
		#     pp curr_scope.compositions
		# end

		curr_scope.compositions.each do |comp|
			if comp.respond_to? :get_scope_with
				comp.get_scope_with identifier do |scope|
					value = scope[identifier]
					break
				end
			elsif comp.respond_to? :key? and comp.key? identifier
				value = comp[identifier]
			end
		end if curr_scope.respond_to? :compositions

		stack.reverse_each do |it|
			next unless it.respond_to? :get_scope_with

			it.get_scope_with identifier do |scope|
				value = scope[identifier]
				break
			end

			next unless it.respond_to? :key?
			if it.key? identifier
				value = it[identifier]
				break
			end
		end unless value

		# puts "#get #{identifier.inspect} after compositions and stack #{value.inspect}"

		value = stack.first[identifier] if value.nil?
		raise "undeclared `#{identifier || identifier.inspect}` in #{scope_signature curr_scope} in file #{}" if value.nil?

		# value = nil if value.is_a? Nil_Expr
		value
	end


	# todo this should set on previous scope if it exists. meaning that you can't create local declarations if they have the same name as one accessible externally. it will and should overwrite those
	def set identifier, value = nil
		identifier = identifier.string if identifier.is_a? Identifier_Token
		# raise "#set expects a string identifier\ngot: #{identifier.inspect}" unless identifier.is_a? String

		value ||= Nil_Expr.new

		found_scope = nil
		stack.reverse_each do |it|
			# try to overwrite the identifier in a scope if it exists
			found_scope = it.get_scope_with identifier do |scope|
				# calls this block with the first scope that has this identifier. Since scopes can be composed, this will check find the first composition, or self, that responds to the identifier. If none of the scopes do, then this block never calls. It also returns true after calling this block, otherwise false when no scope is found.
				# puts "\n\n\nfound the scope! #{scope.inspect}"
				push_scope scope
				scope[identifier] = value
				pop_scope
			end
			break if found_scope != nil
		end

		if found_scope == nil # then we never found or set the identifier, so the law of the land is that it gets declared on the global scope then
			curr_scope[identifier] = value
		end

		value || 'nil' # if found
	end


	# endregion Scopes

	# This is the meat of the runtime

	# puts "\n\nevaluating #{expr.inspect}"

	def number expr # :type, :decimal_position
		if expr.type == :int
			Integer(expr.string)
		elsif expr.type == :float
			if expr.decimal_position == :end
				Float(expr.string + '0')
			else
				Float(expr.string)
			end # no need to explicitly check :beginning decimal position (.1) because Float(string) can parse that
		end
	end


	def assignment expr # :name, :type, :expression
		# note) this handles CONST as well
		set expr.name, evaluate(expr.expression)
	end


	# @param [Scopes::Scope] scope
	def scope_signature scope # = curr_scope
		# mess fix and also doesn't even ever append compositions
		"".tap do |it|
			# it << inst.to_s
			if scope.is_a? Scopes::Peek
				# puts "its a peek"
			end
			# puts "ut::::: #{scope.class} --- #{scope.inspect}"
			it << if scope[:name]
				scope.name
			elsif scope['types']
				scope['types'].join ', '
			else
				scope.class.to_s.split('::').last
			end

			it << " { #{scope.keys.join(', ')} }"
			comps = "".tap do |c|
				scope.compositions.each do |comp|
					c << ' + { '
					c << scope_signature(comp)
					c << ' }'
				end
			end unless scope.respond_to? :compositions and scope.compositions.count > 0

			it << comps if comps
		end
	end


	# mess #constant?, #class?, #member?
	def identifier expr
		# ??? is this the right place for this? Probably? It can be assumed that scopes are instantiated with at least @ and _ declared. If the scope happens to be a class, it'll also have `new` declared.
		# if expr.string == '@'
		# 	# public standard members live here, while the rest is entirely your namespace
		# end
		#
		# if expr.string == '_'
		# 	# private members live here
		# end
		#
		# if expr.string == 'new'
		# 	# it's an instantiation
		# end

		value = get expr.string
		if value.is_a? Reference # functions and their expressions are only stored on the declaring object (enclosing Class, function, or otherwise). Instances will have the value of these declarations swapped at init to a Reference with a unique ID. Avoids duplicating block declarations.
			value = references[value.id]
		end

		if value.is_a? Assignment_Expr # ??? I don't remember why this would ever come out of an identifier
			if value.interpreted_value != nil # value.interpreted_value can be boolean true or false, so check against nil instead
				value.interpreted_value
			elsif value.expression.is_a? Func_Expr
				value.expression
			else
				value
			end
		end

		if value.is_a? Expr and not value.is_a? Func_Expr and not value.is_a? Class_Decl
			value = evaluate value
		end

		value = nil if value.is_a? Nil_Expr

		value
	end


	def binary expr # :operator, :left, :right
		if expr.operator == '='
			if expr.right.is_a? Call_Expr
				if expr.right.receiver.is_a? Func_Expr and expr.right.function_declaration?
					block_expr expr.right.receiver # evaluating the function block will also cause it to be put into the references hash, which is what we want when calling a declaratin.
				end
			end

			right = if expr.right.is_a? Func_Expr
				expr.right
			else
				evaluate expr.right
			end
			# right = if expr.right.is_a? Blo
			# puts ":: #{expr.left.string} = #{expr.right.inspect}"
			return set expr.left.string, right
		elsif expr.operator == ':'
			return set expr.left.string, evaluate(expr.right)
		elsif expr.operator == '=;'
			return set expr.left.string, nil
		end

		# puts "expr.left====> #{expr.left.inspect}"
		receiver = evaluate expr.left
		# puts "ORIGINAL RECEIVER #{receiver.inspect}"

		if receiver.is_a? Reference
			receiver = references[receiver.id]
		end

		if receiver.is_a? Return_Expr
			receiver = evaluate receiver
		end

		# This handles dot operations on a static scope, which is the equivalent of a class blueprint. Calling new on the blueprint creates an opaque scope. Calling anything else on it just gets the static value from the Static_Scope. Keep in mind that you can technically change these static values. Which would also impact how future instances are created, the inside values could be different.
		if receiver.is_a? Scopes::Static and expr.operator == '.'
			# note) this is the right place to implement #tap #where etc
			if expr.right.string == 'new'
				# todo make copies of all members as well, we don't want any shared instances between the static class and the instance.
				return receiver.dup.tap do |it|
					it[SCOPE_KEY_TYPE] = receiver[SCOPE_KEY_TYPE] #.gsub('Static', 'Instance') # receiver[CONTEXT_SYMBOL] # Instance.name
					it.each do |key, val|
						if val.is_a? Func_Expr
							ref                = Reference.new
							references[ref.id] = val
							it[key]            = ref
						end

						if val.is_a? Class_Decl and not receiver.is_a? Scopes::Global
							ref                = Reference.new
							references[ref.id] = val
							it[key]            = ref
						end
					end
				end

			elsif expr.right.is_a? Assignment_Expr
				push_scope receiver
				evaluate expr.right
				return pop_scope

			elsif expr.right.is_a? Block_Call_Expr
				push_scope receiver
				value = evaluate expr.right
				pop_scope
				return value

				# else
				# 	push_scope receiver
				# 	puts "\n\n=========#{expr.inspect}"
				# 	puts "receiver #{receiver.inspect}"
				# 	value = get expr.right.string
				# 	if not value
				# 		raise ".#{expr.right.string} not found in #{scope_signature(receiver)}"
				# 	end
				# 	pop_scope
				# 	return value

			end
		end

		if receiver.is_a? Scopes::Instance and expr.operator == '.'
			if expr.right.is_a? Block_Call_Expr
				push_scope receiver
				value = evaluate expr.right
				pop_scope
				return value
			else
				push_scope receiver
				value = get expr.right.string
				if not value
					raise ".#{expr.right.string} not found in #{scope_signature(receiver)}"
				end
				pop_scope
				return value
			end
		end

		# check if receiver is Instance

		# other potential patterns
		# { static } . new          instantiation
		# { static } . boo          get boo from static
		# { static } . boo=         set boo on static
		# { scope } . tap           tap on any scope
		# literal . tap             tap on any literal
		# { scope } . <str>         dot call anything on scope is basically like scope[str]. the <str> could be evaluated to { scope } in which case you could get:
		# { scope } . { scope }     which is fine too, cause there could be two nested scopes.

		# if receiver.is_a?
		# Scopes::Instance and expr.operator == '.' and expr.right.is_a? Assignment_Expr
		#     push_scope receiver
		#     value = evaluate expr.right
		#     pop_scope
		#     return value
		# end

		# if receiver.is_a? Scopes::Instance and expr.operator == '.' and expr.right.is_a? Block_Call_Expr
		#     push_scope receiver
		#     value = evaluate expr.right
		#     pop_scope
		#     return value
		# end

		# if receiver.is_a? Scopes::Instance and expr.operator == '.'
		#     # the below is equivalent to `return receiver[expr.right.string]` but I want to leave it explicit like this, to show what's going on with pushing and popping scopes.
		#     @stack << receiver
		#     value = get expr.right.string
		#     pop_scope
		#     return value
		# end

		# if receiver.is_a? Func_Expr and expr.operator == '.' and expr.right.string == 'new'
		#     scope                        = push_scope Scopes::Block.new
		#     scope[CONTEXT_SYMBOL][:name] = receiver.name.string
		#     evaluate receiver
		#     return pop_scope
		# end
		#
		# if receiver.is_a? Func_Expr and expr.operator == '.'
		#     scope                        = push_scope Scopes::Block.new
		#     scope[CONTEXT_SYMBOL][:name] = receiver.name.string
		#     evaluate receiver
		#     return pop_scope
		# end
		#
		# if receiver.is_a? Scope and expr.operator == '.' and expr.right.string == 'new'
		#     # @stack << receiver
		#     # value = evaluate get(expr.right)
		#     # @stack.pop
		#     return receiver.dup
		# end
		#
		# if receiver.is_a? Scope and expr.operator == '.'
		#     @stack << receiver
		#     value = evaluate get(expr.right)
		#     @stack.pop
		#     return value
		# end

		if receiver.is_a? Hash and expr.operator == '.' # this adds support for dot notation for dictionaries
			push_scope receiver
			value = get expr.right.string if receiver.key? expr.right.string
			pop_scope
			return value
		end

		# special case for CONST.right
		# special case for Class.right, Class.new
		# special case for right == 'new'
		# metaprogram the rest
		# 7/28/24) when the operator ends in = but is 2-3 characters long, and maybe manually exclude the equality ones and only focus on the assignments. We can extract the operator before the =. += would extract +, and so on. Since these operators in Ruby are methods, they can be called like `left.send :+, right` so these can be totally automated!
		valid = %w(+= -= *= /= %= &= |= ^= ||= >>= <<=)
		if expr.operator.string.end_with? '=' and valid.include? expr.operator.string
			without_equals = expr.operator.string.gsub '=', ''
			value          = if receiver.respond_to? :send
				receiver.send without_equals, evaluate(expr.right)
			else
				raise "Can't metaprogram `#{expr.operator.inspect}` in #binary"
			end

			set expr.left.string, value

			return value
		end

		left  = evaluate expr.left
		right = evaluate expr.right

		case expr.operator.string
			when '+'
				if expr.left.is_a? String_Literal_Expr # because I'm relying on Ruby to concat strings, the right hand must be a string as well. So when we encounter a left that's a string, then let's just automatically convert the right to a string
					"\"#{expr.left.string}#{right}\""

				elsif expr.right.is_a? String_Literal_Expr
					"\"#{left}#{expr.right.string}\""

				else
					left + right
				end

			when '-'
				# puts "expr #{expr.inspect}"
				# puts "left #{left.inspect}"
				# puts "right #{right.inspect}"
				left - right
			when '*'
				left * right
			when '/'
				left / right
			when '%'
				left % right
			when '**'
				left ** right
			when '<<'
				left << right
			when '>>'
				left >> right
			when '<='
				left <= right
			when '>='
				left >= right
			when '<'
				left < right
			when '>'
				left > right
			when '=='
				left == right
			when '||'
				left || right
			when '&&'
				left && right
			when '.?'
				if left.respond_to? expr.right.string
					left.send expr.right.string
				else
					Nil_Construct.new
				end
			when '='
				puts "AASSSSSign baby"
			when '.<', '..'
				if expr.operator == '..'
					evaluate(expr.left)..evaluate(expr.right)
				elsif expr.operator == '.<'
					evaluate(expr.left)...evaluate(expr.right)
				end
			when '**'
				# left must be an identifier in this instance
				# result = evaluate(expr.left) ** evaluate(expr.right)
				set expr.left.string, left ** right
			when '&&', 'and'
				evaluate(expr.left) && evaluate(expr.right)
			when '||', 'or'
				if expr.left.is_a? Nil_Expr
					# puts "left is nil #{expr.inspect}"
					return evaluate expr.right
				elsif expr.right.is_a? Nil_Expr
					# puts "right is nil #{expr.inspect}"
					return evaluate expr.left
				elsif expr.left.is_a? Nil_Expr and expr.right.is_a? Nil_Expr
					# puts "both are nil"
					return nil
				else
					# left = evaluate(expr.left)
					# left  = nil if left.is_a? Nil_Expr
					# right = evaluate(expr.right)
					# right = nil if right.is_a? Nil_Expr

					left || right
				end
			else
				# if expr.right.is_a? Set_Literal_Expr and expr.operator == '.'
				# 	puts "yielding to block, aka .() call"
				# end
				# left = eval(expr.left)
				if receiver.respond_to? :send
					# right = evaluate(expr.right)
					right = right.to_s if receiver.is_a? String
					receiver.send expr.operator.string, right
				else
					raise "Can't metaprogram `#{expr.operator}` in #binary"
				end

		end
	end


	def class_expr expr # gets turned into a Static, which essentially becomes a blueprint for instances of this class. This evaluates the class body manually, rather than passing Class_Decl.block to #block in a generic fashion.
		# Class_Decl :name, :block, :base_class, :compositions

		class_scope = Scopes::Static.new
		set expr.name.string, class_scope

		push_scope class_scope # push a new scope and also set it as the class
		curr_scope[SCOPE_KEY_TYPE] = [expr.name.string]
		expr.block.compositions.each do |it|
			# Composition_Expr :operator, :expression, :alias_identifier
			case it.operator
				when '>'
				when '+'
				when '-'
				else
					raise "Unknown operator #{it.operator} for composition #{it.inspect}"
			end
			# puts "it! #{it.inspect}"
			comp = evaluate(it.expression)
			curr_scope.merge! comp
			# puts "need to comp with\n#{comp}"
			raise "Undefined composition `#{it.identifier.string}`" unless comp
			# puts "compose with #{comp.inspect}\n\n"
			# this involves actual copying of guts.
			# 1) lookup the thing to compose, assert it's Static_Scope
			# 2) dup it, cope all keys and values to this scope (ignore any keys that shouldn't be duplicated)
			# reminder
			#   > Ident (inherits type)
			#   + Ident (only copies scope)
			#   - Ident (deletes scope members)
		end
		# curr_scope[CONTEXT_SYMBOL]['compositions'] = expr.block.compositions.map(&:name)

		expr.block.expressions.each do |it|
			next if it.is_a? Class_Composition_Expr
			# next if it.is_a? Func_Expr
			# todo don't copy the Block_Exprs either. Or do, but change the
			evaluate it
		end
		scope              = pop_scope
		ref                = Reference.new
		references[ref.id] = scope
		# set expr.name.string, scope # moved to beginning of this function
	end


	# If a block is named then it's intended to be declared in a variable. If a block is not named, then it is intended to be evaluated right away.
	# @param [Func_Expr] x
	def block_expr x
		if x.named? # store the actual expression in a references table, and store declare this reference as the value to be given to the name
			ref = Reference.new.tap do |it|
				# reference id should be a hash of its name, parameter names, and expressions. That way, two identical functions can be caught by the runtime. Currently it is being randomized in Reference#initialize
				references[it.id] = x
			end

			set x.name, ref
		else
			block_call x
		end
	end


	# @param [Call_Expr] it
	def call_expr it # :receiver, :parenthesized_expr
		# ident(...)
		# any_expr(...)
		# So we have to know whether the receiver is callable. What should be callable?

		# init from a class declaration
		# 	Class()
		# declare class and call it once
		# 	x = Class{}()
		# call function
		# 	function()
		# declare function and call it once
		# 	function {}()

		# 123()
		# ""

		# puts "call_expr it #{it.inspect}\n\n"
		receiver = it.receiver

		# if not receiver.is_a? Func_Expr
		# end
		if receiver.is_a? Func_Expr
			receiver = evaluate receiver
		elsif receiver === Identifier_Expr
			receiver = get receiver.string
		else
			receiver = get it.string
		end

		if receiver.is_a? Reference
			receiver = references[receiver.id]
		end
		raise "#call_expr input is not a Block or a Reference. #{receiver.inspect}" unless receiver.is_a? Func_Expr

		# puts "\narguments: #{it.parenthesized_expr.inspect}"
		# puts "\nfor receiver: #{receiver.inspect}"

		scope = Scopes::Transparent.new
		push_scope scope, it.receiver.string
		zipped = receiver.parameters.zip(it.parenthesized_expr.expressions)
		zipped.each.with_index do |(par, arg), i|
			# pars =>   :name, :label, :type, :default_expression, :composition
			# args =>   :expression, :label

			# if arg present, then that should take the value of par.name
			# it not arg, then set par.name, eval(par.default_expression)

			if arg
				if arg.respond_to? :expression
					set par.name, evaluate(arg.expression)
				else
					set par.name, arg
				end

			else
				if not par.default_expression
					pop_scope

					# puts "zipped: ", zipped.inspect
					# raise "##{name}(#{"•, " * i}???) requires an argument in position #{i} for parameter named #{par.name}"
				end
				set par.name, evaluate(par.default_expression)
			end

			if par.composition
				instance = get par.name
				# puts "the composition #{par.inspect}\n\ninstance: #{instance.inspect}"
				# compose_scope instance
				curr_scope.compositions << instance
				# puts "\ncurr composition: #{curr_scope.compositions.inspect}"
				set par.name, instance
			end
		end

		last = nil
		receiver.expressions.each do |it|
			if it.is_a? Class_Composition_Expr # just like the params composition, except that we do it at eval time instead
				instance = evaluate it.expression
				curr_scope.compositions << instance
				next
			end
			# puts "receiver call expr #{it.inspect}"
			last = evaluate it

			if last.is_a? Return_Expr
				pop_scope
				return evaluate last
			elsif it.is_a? Return_Expr
				pop_scope
				return it
			end
		end
		pop_scope
		last
	end


	# @param [Block_Call_Expr] expr
	def block_call expr # :name, :arguments
		args  = []
		block = if expr.is_a? Block_Call_Expr
			args = expr.arguments
			get expr.name # which should yield a Func_Expr
		elsif expr.is_a? Func_Expr
			expr
		else
			raise "#block_call received unknown expr #{expr.inspect}"
		end

		while block.is_a? Reference
			block = references[block.id]
		end

		if not block
			raise "No such method #{expr.name}"
		end

		if not expr.name and args.count > 0
			raise "Anon block cannot be"
		end

		scope = Scopes::Transparent.new
		push_scope scope, expr.to_s
		zipped = block.parameters.zip(args)
		zipped.each.with_index do |(par, arg), i|
			# pars =>   :name, :label, :type, :default_expression, :composition
			# args =>   :expression, :label

			# if arg present, then that should take the value of par.name
			# it not arg, then set par.name, eval(par.default_expression)

			if arg
				set par.name, evaluate(arg.expression)
			else
				if not par.default_expression
					pop_scope

					# puts "zipped: ", zipped.inspect
					# raise "##{name}(#{"•, " * i}???) requires an argument in position #{i} for parameter named #{par.name}"
				end
				set par.name, evaluate(par.default_expression)
			end

			if par.composition
				instance = get par.name
				# puts "the composition #{par.inspect}\n\ninstance: #{instance.inspect}"
				# compose_scope instance
				curr_scope.compositions << instance
				# puts "\ncurr composition: #{curr_scope.compositions.inspect}"
				set par.name, instance
			end
		end

		# puts "composed! #{curr_scope.compositions}"
		# puts "curr scope.class #{curr_scope.class}"

		last = nil
		block.expressions.each do |it|
			if it.is_a? Class_Composition_Expr # just like the params composition, except that we do it at eval time instead
				instance = evaluate it.expression
				curr_scope.compositions << instance
				next
			end
			# puts "block call expr #{it.inspect}"
			last = evaluate it

			if last.is_a? Return_Expr
				pop_scope
				return evaluate last
			elsif it.is_a? Return_Expr
				pop_scope
				return it
			end
		end
		pop_scope
		last
	end


	def conditional expr
		if evaluate expr.condition
			evaluate expr.when_true
		else
			evaluate expr.when_false
		end
	end


	def while_expr expr # :condition, :when_true, :when_false
		# push_scope Scopes::Block.new
		output = nil
		while evaluate expr.condition
			output = evaluate expr.when_true
		end

		if expr.when_false.is_a? Conditional_Expr and output.nil?
			output = evaluate expr.when_false
		end

		# pop_scope
		output
	end


	def enum_expr expr
		raise "#enum_expr should not run right now. CONST are now handled as normal assignments"
	end


	# rename this, wtf is macro command lol.
	def command expr # :name, :expression
		case expr.name.string
			when '>~' # breakpoint snake
				# I think a REPL needs to be started here, in the current scope. the repl should be identical to the repl.rb from the em cli. any code you run in this repl, is running in the actual workspace (the instance of the app), so you can make permanent changes. Powerful but dangerous.
				return "PRETEND BREAKPOINT IN #{scope_signature curr_scope}"
			when '>!'
				# !!! generalize these colorizations
				value   = evaluate(expr.expression)
				ansi_fg = "\e[38;5;#{0}m"
				ansi_bg = "\e[48;5;#{1}m"
				puts "#{ansi_fg}#{ansi_bg}  \e[1m!\e[0m #{value}\e[0m"
				return value
			when '>!!'
				value   = evaluate(expr.expression)
				ansi_fg = "\e[38;5;#{0}m"
				ansi_bg = "\e[48;5;#{2}m"
				puts "#{ansi_fg}#{ansi_bg} \e[1m!!\e[0m #{value}\e[0m"
				return value
			when '>!!!'
				value   = evaluate(expr.expression)
				ansi_fg = "\e[38;5;#{0}m"
				ansi_bg = "\e[48;5;#{5}m"
				puts "#{ansi_fg}#{ansi_bg}\e[1m!!!\e[0m #{value}\e[0m"
				return value
			when 'ls'
				return scope_signature get_farthest_scope(curr_scope)
			when 'ls!'
				return "".tap do |it|
					# fix this visibility thing. It is broken. The idea is to get the stack and combine it into one

					# it << "——––--¦  DECLARATIONS VISIBLE TO ME\n"
					# it << scope_signature(get_farthest_scope(curr_scope))
					# it << "\n\n——––--¦  SCOPE AT TOP OF STACK\n"
					# it << scope_signature(curr_scope)
					# it << "\n\n——––--¦  STACK SCOPE SIGNATURES (#{stack.count})\n"
					# stack.reverse_each do |s|
					#     it << "#{scope_signature(s)}\n"
					# end
					# it << "\n——––--¦  STACK (#{stack.count})\n"
					it << "".tap do |str|
						stack.reverse_each.map do |s|
							formatted = PP.pp(s, '').chomp
							formatted.split("\n").each do |part|
								str << "#{part}\n".to_s.gsub('"', '')
							end
						end
					end
					# it << "\n\s"
					# it << "\n\n——––--¦"
				end
			when 'cd'
				destination = evaluate expr.expression
				if destination.is_a? Scopes::Scope
					# what if we push the destination, then compose it with a Peek. I believe #set updates on compositions first before checking self. If not, that should be a rule for it
					scratch      = Scopes::Transparent.new
					scratch.name = 'Transparent'
					push_scope destination
					curr_scope.compositions << scratch
					return scope_signature get_farthest_scope(curr_scope)

					# scope = Scopes::Peek.new.tap do |it|
					#     it['types'] = destination['types'] # + [it.class.to_s.split('::').last]
					# end
					# push_scope scope
					# compose_scope destination
					# return scope_signature get_farthest_scope(curr_scope)
				else
					raise 'Can only cd into a scope!'
				end

			when 'cd ..'
				# since we composed above in cd, we need to erase compositions
				curr_scope.compositions.pop
				pop_scope # Transparent scope added in cd
				return scope_signature get_farthest_scope(curr_scope)
			else
				raise "Runtime#eval #command unhandled expr: #{expr.inspect}"
		end
	end


	def unary expr # :operator, :expression
		value = evaluate expr.expression
		case expr.operator.string
			when '-'
				-value
			when '+'
				+value
			when '~'
				~value
			when '!'
				!value
			else
				raise "#evaluate Unary_Expr(#{expr.inspect}) is not implemented"
		end
	end


	def evaluate expr
		# puts "=== evaluating\n#{expr.inspect}" unless expr.is_a? Delimiter_Token
		case expr
			when Assignment_Expr
				assignment expr
			when Infix_Expr
				# puts "binary ==> #{expr.inspect}"
				binary expr
			when Unary_Expr
				unary expr
			when Tuple_Expr # ??? reminder: these are () [] {}
				# xxx instead of strings, return the actual data structure for hash, set, and array.

=begin  rules:

[]          blank array
()          blank set or hash
(1)         parenthesized expr
(x=1)       assignment therefore

what if you could use any you like ( [ { with a literal prefix.

#{} #() #[]       hash
%{} %() %[]       set
@{} @() @[] []    array

there should be a simple default for each that doesn't require the prefix, right?

[] is the obvious one to be default
////

actually, what if set was done with array syntax? It's more like an array than a hash anyway.

hear me out. if a class body or block body is just an array of things enclosed in {}, maybe the language should use {} for arrays. that leaves () for hash and [] for set

{} hash     I really like this syntax. it's what I'm used to. I need to figure out how to make it work. I think blocks will require -> now. it's currently optional. requiring it makes things very clear. with this:

	{}              hash
	{ -> }          block
	Ident {}        class declaration
	ident { -> }    func declaration

Copy this into parser

() set
[] array




=end

				expr_count = expr.expressions.count

				empty_group   = expr_count == 0 # ()
				just_one_expr = expr_count == 1 # (a) or (a = 1)
				all_binaries  = expr.expressions.all? { _1 == Infix_Expr } # (a = 1, b.c)

				# (a = 1, b)
				at_least_one_binary = expr.expressions.any? { _1 == Infix_Expr }

				# (a, b, c, d, e, f)
				no_binaries = !at_least_one_binary

				# (a = 1, b = 2) xxx handle += -= etc
				all_assignment_binaries = expr.expressions.all? { _1 == Infix_Expr and _1.operator.string == '=' } and not empty_group
				any_assignment_binaries = expr.expressions.any? { _1 == Infix_Expr and _1.operator.string == '=' } and not empty_group

				# :grouping, :expressions
				intended_array = expr.grouping == '[]'
				intended_block = expr.grouping == '{}'
				intended_group = expr.grouping == '()'

				is_set = intended_group and no_binaries # and not empty_group
				is_hash = intended_group and all_assignment_binaries
				is_array = intended_array

				value = if just_one_expr
					# evaluate expr.expressions[0]
					"parenthesized"
				elsif is_set
					"set #{expr}"
				elsif is_hash
					"hash #{expr}"
				elsif is_array
					"array #{expr}"
				end

				puts "\n\n~~~ #{expr} ~~~\n\n"
				puts "                  count  :  #{expr_count}"
				puts "            empty_group  :  #{empty_group}\n\n"
				puts "          just_one_expr  :  #{just_one_expr}"
				puts "           all_binaries  :  #{all_binaries}"
				puts "            no_binaries  :  #{no_binaries}\n\n"
				puts "all_assignment_binaries  :  #{all_assignment_binaries}"
				puts "any_assignment_binaries  :  #{any_assignment_binaries}"
				puts "    at_least_one_binary  :  #{at_least_one_binary}\n\n"
				puts "         intended_array  :  #{intended_array}"
				puts "         intended_block  :  #{intended_block}"
				puts "         intended_group  :  #{intended_group}"
				puts "                 is_set  :  #{is_set}"
				puts "                is_hash  :  #{is_hash}"
				puts "               is_array  :  #{is_array}"
				puts "\n  => \n\n"

				return value

				# hash
				# set
				# array
				# regular grouping

				# all_assignment_binaries = expr.expressions.select { _1 == Infixed_Expr and _1.operator.string == '=' }.count ==

				if just_one_expr
					evaluate expr.expressions[0] # if it isn't obvious, this case is just a regular grouped expression with parens that gets evaluated

				elsif all_binaries
					"hash #{expr.inspect}"
					# 1. push a Hash scope
					# 2. evaluate all expressions on that scope
					# 3. pop the Hash scope
					# 4. return the Hash scope

				elsif at_least_one_binary and not all_binaries
					"mix of both #{expr.inspect}"

				elsif not at_least_one_binary
					if expr.grouping == '()'
						'Set('.tap { |it|
							# xxx push a temp block then evaluate
							it << expr.expressions.map {
								"#{evaluate(_1)}"
							}.join(', ')
							it << ')'
						}
					elsif expr.grouping == '[]'
						'Array['.tap { |it|
							# xxx push a temp block then evaluate
							it << expr.expressions.map do |e|
								"#{evaluate(e)}"
							end.join(', ')
							it << ']'
						}
					else
						raise "Unknown grouping for #{expr.inspect}"
					end
				else
					"nothing? #{expr.inspect}"
				end

				# ??? this here has to be a standalone grouped expression. The parser would by now have captured an expression call
				# If all expressions are Binop(=) aka assignment, then it's a hash
				# If all expressions are non-Binop(=), then it's an array or set
				# If it's a mix of both,

				# reference: https://rosettacode.org/wiki/Hash_from_two_arrays
				# value_results = expr.values.map { |val| evaluate val }
				# Hash[expr.keys.zip(value_results)]
				# if expr.keys.one? and expr.values.none? # then it is a parenthesized expression
				# 	evaluate expr.keys.first
				# end

			when Conditional_Expr
				conditional expr
			when While_Expr
				while_expr expr
			when Class_Decl
				class_expr expr
			when Func_Expr
				block_expr expr
			when Call_Expr
				call_expr expr
			when Block_Call_Expr
				block_call expr
			when Class_Composition_Expr
				instance = get expr.name
				curr_scope.compositions << instance
			when Block_Composition_Expr
				instance = get expr.name
				compose_scope instance
			when Identifier_Expr
				identifier expr
			when Number_Literal_Expr
				number expr
			when String_Literal_Expr
				expr.string
			when Symbol_Literal_Expr
				expr.to_symbol
			when Boolean_Literal_Expr
				expr.to_bool
			when Enum_Expr
				enum_expr expr
			when Return_Expr
				evaluate expr.expression
			when Nil_Expr
				nil # todo if things break, it's because I added the nil here. But this makes more sense
				Nil_Expr
			when Raise_Expr
				# cleanup
				if expr.condition != nil
					result = evaluate expr.condition
					if not result
						# puts "with condition but it didn't return anything: #{result.inspect}"
						raise("".tap do |it|
							it << "\n\n~~~~ OOPS ~~~~\n"
							message = evaluate expr.message_expression
							if message
								it << "#{message}"
							else
								it << "Evaluate any expression when oopsing: `oops expression`"
							end
							it << "\n~~~~ OOPS ~~~~\n"
						end)
					end
				else
					raise("".tap do |it|
						it << "\n\n~~~~ OOPS ~~~~\n"
						message = evaluate expr.message_expression
						if message
							it << "#{message}"
						else
							it << "Evaluate any expression when oopsing: `oops expression`"
						end
						it << "\n~~~~ OOPS ~~~~\n"
					end)
				end
			when nil
			when Delimiter_Token # ??? I decided to send newlines to the runtime so that I can make anything callable when a Set comes after it. If we see any delimiter, ignore it for now. But when we see a Set, we can check if there was a Delimiter before us. If there was, it's just a set, if there wasn't it's likely a call to the previous expression
				nil
			else
				raise "Runtime#eval #{expr.inspect} not implemented"
		end
	end

end
