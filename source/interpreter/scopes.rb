require 'pp'

module Scopes
    class Scope < Hash
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


    # end

    class Transparent < Scope; end


    class Global < Scope; end


    # Block scopes can look up identifiers outside of itself, and in itself
    class Block < Scope; end


    class Block_Call < Scope; end


    # Maybe temporary name for scopes cd'd into
    class Peek < Scope; end


    # Instance scopes can look up identifiers only in global scope, and in itself. All programs start with an opaque scope as the global scope.
    class Instance < Scope; end


    # Class_Expr are evaluated one time into a Static for each class. When instances are created, this Static becomes a blueprint/template for what needs to be declared in the instance. Here is the Static for Atom:
    # {
    #    @  = {
    #           type = Static
    #   		new = Class_Expr
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


    class Base_Scope
        attr_accessor :name, :declarations # based on notes/scope.txt

        def initialize name = nil
            @name         = name
            @declarations = {}
        end
    end


    # Used to differentiate between types of scopes, even though they are basically identical

    class Global_Scope < Base_Scope
        def initialize
            super 'Global'
        end
    end


    class Instance_Scope < Base_Scope # represents the scope of an instance of a Class
    end


    class Class_Scope < Base_Scope # represents the scope of a Class declaration. Meaning all declarations on a class – vars, funcs, constants, nested classes, etc. These funcs are not executed because this is basically just a template of what an instance would look like
    end
end
