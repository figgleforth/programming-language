module Scopes
    class Scope
        attr_accessor :name, :declarations # based on notes/scope.txt

        def initialize name = nil
            @name         = name
            @declarations = {}
        end
    end


    # Used to differentiate between types of scopes, even though they are basically identical

    class Global_Scope < Scope
        def initialize
            super 'Global'
        end
    end


    class Instance_Scope < Scope # represents the scope of an instance of a Class
    end


    class Class_Scope < Scope # represents the scope of a Class declaration. Meaning all declarations on a class – vars, funcs, constants, nested classes, etc. These funcs are not executed because this is basically just a template of what an instance would look like
    end
end
