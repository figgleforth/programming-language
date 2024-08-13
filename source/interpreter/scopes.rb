require 'pp'

# ??? Scopes are runtime versions of language constructs. At its core, a Scope is a hash because it's a free data structure that I don't have to replicate. The idea behind scopes, as it is in this language, is that every single object is a Scope that lives inside another Scope.
# The program has an array of Scopes, known as the stack, where the back of the array is the current scope. A few examples, maybe even all of them, of what a scope is in this runtime – it's the global scope; it's the inside of a class; inside of an instance; inside of a function being evaluated; etc. Here's a refresher on the runtime:
#
# 	Parsing a number:
# 		1. Lexer lexes an expression "1", and outputs [Number_Token]
# 		2. Parser parses Number_Token and outputs Number_Literal_Expr
# 	  	3. Runtime evaluates Number_Literal_Expr and outputs 1
#
# 	Parsing a parenthesized expression:
# 		1. Lexer lexes an expression (1), and outputs [Delimiter,Number,Delimiter]
# 	  	2. Parser parses [Delimiter,Number,Delimiter] and outputs Tuple_Expr with one expression `1`
# 	  	3. Runtime evaluates Tuple_Expr and sees it is a single statement so it outputs 1
#
# 	Parsing a hash:
# 		1. Lexer lexes an expression "(x=2)", and outputs tokens sequence [Delimiter,Identifier,Operator,Number,Delimiter]
# 	  	2. Parser parses distinct pattern [Delimiter,Identifier,Operator,Number,Delimiter] and outputs Tuple_Expr with one expression `x=2`
# 	  	3. Runtime sees that Tuple_Expr is a hash
#			a. It creates a Hash scope
#			b. It pushes scope on top of stack
#			c. It evaluates all of its expressions, only `x=2` in this instance
# 				i. But because the Hash was pushed on top of the stack, x=2 is declared on the Hash
#			d. It pops the scope from the stack and returns it
#			e. Whatever caused this evaluation is now returned the scope
#
module Scopes
	# mess all over the place. This needs to be slimmed down.

	class Scope < Hash # represents the scope of a Class declaration. Meaning all declarations on a class – vars, funcs, constants, nested classes, etc. These funcs are not executed because this is basically just a template of what an instance would look like
		attr_accessor :compositions, :name


		def initialize
			super
			@compositions = []
		end


		def get identifier
			result = get_scope_with identifier
			return nil unless result
			result[identifier]
		end


		# When the block is called, it means that the set is possible,
		def get_scope_with identifier, &block
			stack = compositions + [self]
			# puts "\n\n\n\nstack:::: #{compositions}"
			stack.each do |it|
				if it.key? identifier
					block.call(it) if block_given?
					return it
				end
			end
			nil
		end
	end


	class Transparent < Scope; end


	class Global < Scope; end


	# Block scopes can look up identifiers outside of itself, and in itself
	class Block < Scope; end


	class Block_Call < Scope; end


	# Maybe temporary name for scopes cd'd into
	class Peek < Scope; end


	# Instance scopes can look up identifiers only in global scope, and in itself. All programs start with an opaque scope as the global scope.
	class Instance < Scope; end


	# Class_Decl are evaluated one time into a Static for each class. When instances are created, this Static becomes a blueprint/template for what needs to be declared in the instance. Here is the Static for Atom:
	# {
	#    @  = {
	#           type = Static
	#   		new = Class_Decl
	# 	    	name = Atom
	#         }
	# }
	# I may change around the structure of how this info is stored, but the idea remains. Instances created are dupes of this scope, with the #new function removed since it doesn't need to be stored again.
	class Static < Scope
		def initialize
			super
			self['types'] = []
		end
	end


	# this should probably also < Instance

	class String < Static; end


	class Array < Static; end


	class Hash < Static; end

end
