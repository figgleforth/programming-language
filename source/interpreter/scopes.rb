require 'pp'

=begin

8/19/24
mess This entire file is a mess. It needs to be cleaned up, which should be easy to do because now I know how I'm going to implement the entire construct of scopes.

!!!
Most objects will end up as a Scope. The entire runtime is mostly nested Scopes. The program has an array of Scopes, the stack, where the front is the global scope, and the back is the current scope. They're Hashes because it's a free data structure that I don't have to replicate. An examples:

x=1
stack of scopes: [{x: 1}]

func {->}
[{func: Ref}]

Class {}
[{Class: Ref}]

Class {
	name
	to_s {->}
}
scope of this class: {name:nil, to_s: Ref}

In general, if something can be instantiated, it becomes a scope.

=end

module Scopes
	class Scope < Hash # contains all declarations – vars, funcs, constants, classes, etc. funcs and classes are not evaluated unless explicitly by the user, so their original Expr is stored in a references table funcs are not executed because this is basically just a template of what an instance would look like
		attr_accessor :compositions, :name


		def initialize
			super
			@compositions = []
			hash
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
