require_relative 'scopes'
require 'ostruct'
require 'securerandom'

CONTEXT_SYMBOL = 'scope'
SCOPE_KEY_TYPE = 'types'

module Scope
	class V2 < Hash
		attr_accessor :identity, :stack, :portals, :references


		def initialize
			super
			@identity   = {} # {@: {}}
			@portals    = [] # {#: []}
			@stack      = [] # [{@#}]
			@references = {} # { }
		end


		def to_sig
			'{@, $'.tap {
				if not portals.empty?
					_1 << ':['
					_1 << portals.join(', ')
					_1 << ']'
				end

				if not keys.empty?
					_1 << ', '
					_1 << keys.join(', ')
				end

				_1 << '}'
			}
		end
	end
end

=begin

{
	@: {}       hidden decls like id and type accessed like @id, @type, etc
	$: []       merged scopes from $param
	_: {}       private declarations
}

{@$_} for short, or maybe drop the _, it looks nicer. {@$}, and that represents a scope

Here's how the scope changes as examples expressions are added
_

Scope<{ @$ }>         I'll omit Scope<> going forward unless it's necessary to convey something
-------------
Island {}

{ @$  Island:{@$  $:[Decl.Island]} }
-------------
it = Island.new

{ @$  Island:{@$  $:[Decl.Island]}  it:{@$  $:[Instance.Island]} }
-------------
Island {
	Hatch {}
}

{ @$  Island:{@$  $:[Decl.Island]  Hatch:{@$  $:[Decl.Hatch]}  it:{@$  $:[Instance.Island]} }
-------------
Island {
	Hatch {}
	open_hatch {->}
}

Scope<{ @$  Island:{@$  $:[Decl.Island]  Hatch:{@$  $:[Decl.Hatch]  open_hatch:Ref(open_hatch)}  it:{@$  $:[Instance.Island]} }, @references = {open_hatch:Func_Decl}>
-------------
it.open_hatch

it = get(it) => {@$  $:[Instance.Island]} }
	push it onto the stack
	$ << it
	$ [
		{@$  $:[Instance.Island]} }
	]

func = get(open_hatch) => Ref(open_hatch)

it.open_hatch() # called
func = get(open_hatch) => Ref(open_hatch)
call_expr(func) or something like that


The question is, should Class_Decl and Func_Decls both live in references?

	Ref(Island)
	Ref(Island.Hatch)
	Ref(open_hatch)

That would reduce the scope to

	{ @$  Island:Ref(Island)  it:{@$  $:[Instance.Island]} }
	self.references = {Island:Class_Decl  Island.Hatch:Class_Decl  open_hatch:Func_Decl}

While evaluating Island, it's going to make a reference for Island.Hatch, so there's no need to keep this Decl.Island scope around


	def class_decl decl => @references[decl.name] = decl
	def func_decl decl  => @references[decl.name] = decl
	def func_expr expr  => just gets called

	def infix expr      => left = Func_Expr

		id = @references[uuid] = expr.right
		set(left.name.string, Reference(id))

This expr can now be called later like `left()`

An examples of merge scopes

	funk { $island -> open_hatch }      # calling open_hatch via the merged scope
	ref = @refs[funk] = Func_Decl
	set funk, ref

Call_Expr are not guaranteed to have left be a Ref

	funk(it)
	left = get(funk)
	func_expr = if left is ref
		@refs[left]
	else
		left
	end

Left is Func_Decl with a merged param/arg $island.

Create a temp scope dedicated to running this func

	Scope<
		self     { @$  funk:Ref(funk)  it:{@$  $:[Instance.Island]} }
		@stack   [ Temp_Func_Scope<{@$} stack=[]> ]
	>

Now, evaluating funk()'s only expression, `open_hatch`

	last = nil
	left.expressions.map {
		last = run(_1)
	}
	last

This would return Reference(open_hatch)


When would it be a ref?         eg. left is Identifier_Expr     funk()  Class()
When would it NOT be a ref?     eg. left is *_Expr like         {->}()  1()  ""()  {}()

This is just an illustration, I'm not saying all these things respond to ()

===

Set arithmetic on scopes

Class | This, That, & This, That ... {
	I think you should be able to keep alternating between > and &

Operators > & ~ + -

	A { a }
	B { b }
	C { c }

	A > B {}        { @ $:[A, B]  a  b }        inherit type and combine members in A, B
	A > B - B {}    { @ $:[A, B]  a    }        inherit type, not implementation

	A & B {}        { @ $:[A]          }        only mutual members of A, B
	A ~ B {}        { @ $:[A]     b    }        members not in A

	A + B {}        { @ $:[A]     a  b }        combined members A, B
	C + A - B {}    { @ $:[C]     a    }


1.	Union >:
	- Combines all elements from both sets, removing duplicates.
	- Example: {1, 2} ∪ {2, 3} = {1, 2, 3}.
2.	Intersection (∩ or &):
	- Returns the elements that are common to both sets.
	- Example: {1, 2} ∩ {2, 3} = {2}.
3.	Difference (− or \):
	- Returns the elements that are in one set but not in the other.
	- Example: {1, 2} − {2, 3} = {1}.
4.	Symmetric Difference (Δ or ^):
	- Returns the elements that are in either set, but not in their intersection.
	- Example: {1, 2} Δ {2, 3} = {1, 3}.
5.	Complement (~ or -):
	- Returns the elements not in the set, typically relative to a universal set.
	- Example: If the universal set is {1, 2, 3, 4} and the set is {2, 3}, the complement is {1, 4}.


=end

class Reference
	# include Scopes
	attr_accessor :id, :expr


	def initialize expr
		@id   = SecureRandom.uuid
		@expr = expr
	end


	def to_s
		join     = '-'
		id_label = "#{id[...3]}#{join}#{id[3...5]}#{join}#{id[5..7]}"
		if expr.is_a? Func_Decl
			# "#{expr.name.string}{#{expr.parameters.map(&:name).map(&:string).join(',')}}#{id_label}"
			# "#{expr.name.string}:#{id_label}"
			"#{id_label}(#{expr.name.string})"
		elsif expr.is_a? Class_Decl
			"#{id_label}(#{expr.name.string})"
		else
			expr
		end

		super
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

		# ??? there's probably a better way to do this
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
			@last_evaluated = run it
		end
		@last_evaluated
	end


	# region Scopes – push, pop, set, get

	def push_scope scope, name = nil
		scope.name = if name.is_a? Word_Token
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


	def get ident_expr
		# private   Prefix_Expr(Op(_) Identifier_Expr)
		# identity  Prefix_Expr(Op(#) Identifier_Expr)

		ident = ident_expr
		ident = ident_expr.token.string if ident_expr.is_a? Identifier_Expr

		value = nil

		# case ident
		# 	when 'true'
		# 		return true
		# 	when 'false'
		# 		return false
		# 	else
		# 		nil
		# end

		# if ident == 'X'
		#     puts "curr scope"
		#     pp curr_scope
		#     puts "compositions"
		#     pp curr_scope.compositions
		# end

		curr_scope.compositions.each do |comp|
			if comp.respond_to? :get_scope_with
				comp.get_scope_with ident do |scope|
					value = scope[ident]
					break
				end
			elsif comp.respond_to? :key? and comp.key? ident
				value = comp[ident]
			end
		end if curr_scope.respond_to? :compositions

		stack.reverse_each do |it|
			next unless it.respond_to? :get_scope_with

			it.get_scope_with ident do |scope|
				value = scope[ident]
				break
			end

			next unless it.respond_to? :key?
			if it.key? ident
				value = it[ident]
				break
			end
		end unless value

		value = stack.first[ident] if value.nil?

		# puts "\n\n#get #{ident.inspect} = #{value.inspect}\n\t"
		# puts "\n\tstack(#{stack.count}): #{stack.to_s}"
		# puts PP.pp(curr_scope, '').chomp

		if value.nil?
			puts "\n\n#get\n"
			puts PP.pp(ident_expr, '')

			raise "undeclared `#{ident || ident.inspect}` in #{curr_scope}"
		end

		# value = nil if value.is_a? Nil_Expr
		value
	end


	# todo this should set on previous scope if it exists. meaning that you can't create local declarations if they have the same name as one accessible externally. it will and should overwrite those
	def set identifier, value = nil
		identifier = identifier.token.string if identifier.is_a? Identifier_Expr
		# identifier = identifier.string if identifier.is_a? Word_Token
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
		set expr.name, run(expr.expression)
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


	# @param expr [Key_Identifier_Expr]
	def special_identifier expr
		case expr.string
			when 'nil'
				nil
			when 'true'
				true
			when 'false'
				false
			else
				raise "Unknown special right now #{expr.inspect}"
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

		value = get expr
		# if value.is_a? Reference # functions and their expressions are only stored on the declaring object (enclosing Class, function, or otherwise). Instances will have the value of these declarations swapped at init to a Reference with a unique ID. Avoids duplicating block declarations.
		# 	value = references[value.id]
		# end

		# if value.is_a? Assignment_Expr # ??? I don't remember why this would ever come out of an identifier
		# 	if value.interpreted_value != nil # value.interpreted_value can be boolean true or false, so check against nil instead
		# 		value.interpreted_value
		# 	elsif value.expression.is_a? Func_Expr
		# 		value.expression
		# 	else
		# 		value
		# 	end
		# end

		if value.is_a? Expr and not value.is_a? Func_Expr and not value.is_a? Class_Decl
			value = run value
		end

		value = nil if value.is_a? Nil_Expr

		# puts "the value #{value.inspect}"

		value
	end


	def infix expr # :operator, :left, :right
		# puts "infix #{expr.inspect}"
		case expr.operator.string
			when '='
				return "#{expr.left.inspect}\n\t=\n#{expr.right.inspect}"
			when '.'
				return "#{expr.left.inspect}\n\t.\n#{expr.right.inspect}"
			else
		end

		return
		# puts "\n\n#infix\n\n"
		# puts PP.pp(expr, '').chomp
		# puts "\n\n"
		if expr.operator == '.' and expr.right.string == 'new'
			# puts ".new!!!"
			receiver = run expr.left
			receiver = run receiver if receiver.is_a? Reference
			# puts "receiver #{run(receiver).inspect}"
			# return receiver
		end

		# if expr.left.string == '$'
		# 	if expr.operator == '+='
		# 		# xxx add scope to merge
		# 		right = run expr.right
		#
		# 		curr = Scope::V2.new
		# 		curr.portals << right
		# 		# puts "want to merge #{right.inspect}"
		# 		# puts "\nfake curr"
		# 		return curr.to_sig
		#
		# 	elsif expr.operator == '-='
		# 		# xxx remove scope to merge
		# 		# s = Scope::V2.new
		# 		# s.portals.reject! {
		# 		# 	_1 == expr.right
		# 		# }
		# 	end
		#
		# 	return
		# end

		if expr.operator == '='
			# puts "561 assign"
			# if expr.right.is_a? Call_Expr
			# 	if expr.right.receiver.is_a? Func_Expr and expr.right.function_declaration?
			# 		func_expr expr.right.receiver # evaluating the function block will also cause it to be put into the references hash, which is what we want when calling a declaration.
			# 	end
			# end

			right = if expr.right.is_a? Func_Expr
				expr.right
			else
				run expr.right
			end
			# right = if expr.right.is_a? Blo
			# puts ":: #{expr.left.string} = #{expr.right.inspect}"
			return set expr.left.string, right
		elsif expr.operator == ':'
			return set expr.left.string, run(expr.right)
		elsif expr.operator == '=;'
			return set expr.left.string, nil
		elsif expr.operator == '+='

		end

		# puts "expr.left====> #{expr.left.inspect}"
		receiver = run expr.left
		# puts "ORIGINAL RECEIVER #{receiver.inspect}"

		if receiver.is_a? Reference
			receiver = references[receiver.id]
		end

		if receiver.is_a? Return_Expr
			receiver = run receiver
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
							ref                = Reference.new(expr)
							references[ref.id] = val
							it[key]            = ref
						end

						if val.is_a? Class_Decl and not receiver.is_a? Scopes::Global
							ref                = Reference.new(expr)
							references[ref.id] = val
							it[key]            = ref
						end
					end
				end

			elsif expr.right.is_a? Assignment_Expr
				push_scope receiver
				run expr.right
				return pop_scope

			elsif expr.right.is_a? Block_Call_Expr_OLD
				push_scope receiver
				value = run expr.right
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
			if expr.right.is_a? Block_Call_Expr_OLD
				push_scope receiver
				value = run expr.right
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
			put s "736 assign"
			without_equals = expr.operator.string.gsub '=', ''
			value          = if receiver.respond_to? :send
				receiver.send without_equals, run(expr.right)
			else
				raise "Can't metaprogram `#{expr.operator.inspect}` in #binary"
			end

			set expr.left.string, value

			return value
		end

		left  = run expr.left
		right = run expr.right

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
					run(expr.left)..run(expr.right)
				elsif expr.operator == '.<'
					run(expr.left)...run(expr.right)
				end
			when '**'
				# left must be an identifier in this instance
				# result = evaluate(expr.left) ** evaluate(expr.right)
				set expr.left.string, left ** right
			when '&&', 'and'
				run(expr.left) && run(expr.right)
			when '||', 'or'
				if expr.left.is_a? Nil_Expr
					# puts "left is nil #{expr.inspect}"
					return run expr.right
				elsif expr.right.is_a? Nil_Expr
					# puts "right is nil #{expr.inspect}"
					return run expr.left
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


	def class_decl decl
		set(decl.name.string, Reference.new(decl).tap do
			references[_1.id] = decl
		end)
	end


	def class_expr expr # gets turned into a Static, which essentially becomes a blueprint for instances of this class. This evaluates the class body manually, rather than passing Class_Decl.block to #block in a generic fashion.
		# Class_Decl :name, :block, :base_class, :compositions

		class_scope = Scopes::Static.new
		set expr.name.string, class_scope

		push_scope class_scope # push a new scope and also set it as the class
		curr_scope[SCOPE_KEY_TYPE] = [expr.name.string]
		# expr.block.compositions.each do |it|
		# 	# Composition_Expr :operator, :expression, :alias_identifier
		# 	case it.operator
		# 		when '>'
		# 		when '+'
		# 		when '-'
		# 		else
		# 			raise "Unknown operator #{it.operator} for composition #{it.inspect}"
		# 	end
		# 	# puts "it! #{it.inspect}"
		# 	comp = evaluate(it.expression)
		# 	curr_scope.merge! comp
		# 	# puts "need to comp with\n#{comp}"
		# 	raise "Undefined composition `#{it.identifier.string}`" unless comp
		# 	# puts "compose with #{comp.inspect}\n\n"
		# 	# this involves actual copying of guts.
		# 	# 1) lookup the thing to compose, assert it's Static_Scope
		# 	# 2) dup it, cope all keys and values to this scope (ignore any keys that shouldn't be duplicated)
		# 	# reminder
		# 	#   > Ident (inherits type)
		# 	#   + Ident (only copies scope)
		# 	#   - Ident (deletes scope members)
		# end
		# curr_scope[CONTEXT_SYMBOL]['compositions'] = expr.block.compositions.map(&:name)

		expr.block.expressions.each do |it|
			next if it.is_a? Class_Composition_Expr
			# next if it.is_a? Func_Expr
			# todo don't copy the Block_Exprs either. Or do, but change the
			run it
		end
		scope              = pop_scope
		ref                = Reference.new(expr)
		references[ref.id] = scope
		# set expr.name.string, scope # moved to beginning of this function

		set expr.name, ref
	end


	# If a block is named then it's intended to be declared in a variable. If a block is not named, then it is intended to be evaluated right away.
	# @param [Func_Expr, Func_Decl] expr
	def func_expr expr
		ref = Reference.new(expr).tap do
			# reference id should be a hash of its name, parameter names, and expressions. That way, two identical functions can be caught by the runtime. Currently it is being randomized in Reference#initialize
			references[_1.id] = expr
			_1.expr           = expr
		end

		if expr.respond_to? :name
			set expr.name.string, ref
			puts "func_expr returning ref #{ref.inspect} for\n\t#{expr.inspect}"
			return ref
		end

		# puts "func_expr returning expr #{expr.inspect}"
		expr
		# if x.is_a? Func_Decl # store the actual expression in a references table, and store declare this reference as the value to be given to the name
		# 	ref = Reference.new(x).tap do
		# 		# reference id should be a hash of its name, parameter names, and expressions. That way, two identical functions can be caught by the runtime. Currently it is being randomized in Reference#initialize
		# 		references[_1.id] = x
		# 		_1.expr           = x
		# 	end
		#
		# 	set x.name, ref
		# else
		# 	block_call x
		# end
	end


	# @param [Call_Expr] expr
	def call_expr expr
		receiver = if expr.receiver === Func_Expr
			run expr.receiver
		elsif expr.receiver === Call_Expr
			call_expr expr.receiver
		elsif expr.receiver === Identifier_Expr
			get expr.receiver
		else
			raise "Unknown type of call #{expr.inspect}"
		end

		if receiver.is_a? Reference
			receiver = references[receiver.id]
		end

		raise "#call_expr input is not a Block or a Reference. #{receiver.inspect}" unless receiver.is_a? Func_Expr

		scope = Scopes::Transparent.new
		push_scope scope, expr.receiver.string
		zipped = receiver.parameters.zip(expr.arguments)
		zipped.each.with_index do |(par, arg), i|
			# pars =>   :name, :label, :type, :default_expression, :composition
			# args =>   :expression, :label

			# if arg present, then that should take the value of par.name
			# it not arg, then set par.name, eval(par.default)

			if arg
				if arg.respond_to? :expression
					set par.name, run(arg.expression)
				else
					set par.name, arg
				end

			else
				if not par.default
					pop_scope

					# puts "zipped: ", zipped.inspect
					# raise "##{name}(#{"•, " * i}???) requires an argument in position #{i} for parameter named #{par.name}"
				end
				set par.name, run(par.default)
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
				instance = run it.expression
				curr_scope.compositions << instance
				next
			end
			# puts "receiver call expr #{it.inspect}"
			last = run it

			if last.is_a? Return_Expr
				pop_scope
				return run last
			elsif it.is_a? Return_Expr
				pop_scope
				return it
			end
		end
		pop_scope
		last
	end


	# @param [Block_Call_Expr_OLD] expr

	def block_call expr # :name, :arguments
		args  = []
		block = if expr.is_a? Block_Call_Expr_OLD
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

		if not expr.is_a? Func_Decl and args.count > 0
			raise "Anon block cannot be"
		end

		scope = Scopes::Transparent.new
		push_scope scope, expr.to_s
		zipped = block.parameters.zip(args)
		zipped.each.with_index do |(par, arg), i|
			# pars =>   :name, :label, :type, :default_expression, :composition
			# args =>   :expression, :label

			# if arg present, then that should take the value of par.name
			# it not arg, then set par.name, eval(par.default)

			if arg
				set par.name, run(arg.expression)
			else
				if not par.default
					pop_scope

					# puts "zipped: ", zipped.inspect
					# raise "##{name}(#{"•, " * i}???) requires an argument in position #{i} for parameter named #{par.name}"
				end
				set par.name, run(par.default)
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
				instance = run it.expression
				curr_scope.compositions << instance
				next
			end
			# puts "block call expr #{it.inspect}"
			last = run it

			if last.is_a? Return_Expr
				pop_scope
				return run last
			elsif it.is_a? Return_Expr
				pop_scope
				return it
			end
		end
		pop_scope
		last
	end


	def conditional expr
		if run expr.condition
			run expr.when_true
		else
			run expr.when_false
		end
	end


	def while_expr expr # :condition, :when_true, :when_false
		# push_scope Scopes::Block.new
		output = nil
		while run expr.condition
			output = run expr.when_true
		end

		if expr.when_false.is_a? Conditional_Expr and output.nil?
			output = run expr.when_false
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
				value   = run(expr.expression)
				ansi_fg = "\e[38;5;#{0}m"
				ansi_bg = "\e[48;5;#{1}m"
				puts "#{ansi_fg}#{ansi_bg}  \e[1m!\e[0m #{value}\e[0m"
				return value
			when '>!!'
				value   = run(expr.expression)
				ansi_fg = "\e[38;5;#{0}m"
				ansi_bg = "\e[48;5;#{2}m"
				puts "#{ansi_fg}#{ansi_bg} \e[1m!!\e[0m #{value}\e[0m"
				return value
			when '>!!!'
				value   = run(expr.expression)
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
				destination = run expr.expression
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


	def prefix expr # :operator, :expression
		if %w(# _ ./ ../ .../).include? expr.operator.string
			return identifier expr
		end

		value = run expr.expression

		value = run value if value.is_a? Reference

		case expr.operator.string
			when '-'
				-value
			when '+'
				+value
			when '~'
				~value
			when '!'
				!value
			when '#'
				value # xxx add expr.expression to portals
			when '-#'
				value # xxx remove expr.expression from portals
			else
				raise "#evaluate prefix #{expr.inspect} is not implemented"
		end
	end


	def run expr
		# puts "=== evaluating\n#{expr.inspect}" unless expr.is_a? Delimiter_Token
		case expr
			when Number_Literal_Expr
				number expr
			when String_Literal_Expr
				expr.to_string
				# when Symbol_Literal_Expr
				# 	expr.to_symbol
			when Infix_Expr
				infix expr
			when Prefix_Expr
				prefix expr

			when Hash_Expr
				# :keys, :values
				res = expr.keys.zip(expr.values).map {
					if _1 === Identifier_Expr
						[_1.string, run(_2)]
					else
						[run(_1), run(_2)]
					end
				}.to_h

				Scopes::Scope.new.merge(res) # todo data structure

			when Array_Expr # todo data structure
				result = expr.elements.map {
					run _1
				}.join(', ')
				"[#{result}]"

			when Circumfix_Expr # unhandled () {} [], like tuples, sets, or parenthesized expressions
				# todo I think there should be some custom data structure where @elements contains the evaluated expr.expressions
				expr_count    = expr.expressions.count
				just_one_expr = expr_count == 1

				if just_one_expr
					return run expr.expressions.first
				else
					return expr # xxx return a tuple/set
				end

			when Conditional_Expr
				conditional expr
			when While_Expr
				while_expr expr
			when Class_Decl
				# class_expr expr
				class_decl expr
			when Func_Expr, Func_Decl
				func_expr expr
			when Call_Expr
				call_expr expr
				# when Block_Call_Expr_OLD
				# block_call expr
				# when Class_Composition_Expr
				# instance = get expr.name
				# curr_scope.compositions << instance
				# when Block_Composition_Expr
				# 	instance = get expr.name
				# 	compose_scope instance

			when Key_Identifier_Expr
				special_identifier expr
			when Identifier_Expr
				identifier expr
				# when Boolean_Literal_Expr_OLD
				# 	expr.to_bool
				# when Enum_Expr_OLD
				# 	enum_expr expr
			when Return_Expr
				run expr.expression
			when Nil_Expr
				nil # todo if things break, it's because I added the nil here. But this makes more sense
				Nil_Expr
			when Raise_Expr
				# cleanup
				if expr.condition != nil
					result = run expr.condition
					if not result
						# puts "with condition but it didn't return anything: #{result.inspect}"
						raise("".tap do |it|
							it << "\n\n~~~~ OOPS ~~~~\n"
							message = run expr.message_expression
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
						message = run expr.message_expression
						if message
							it << "#{message}"
						else
							it << "Evaluate any expression when oopsing: `oops expression`"
						end
						it << "\n~~~~ OOPS ~~~~\n"
					end)
				end
			when nil
			when Reference
				references[expr.id]
			else
				raise "Runtime#run not implemented for:\n#{expr.inspect}"
		end
	end

end
