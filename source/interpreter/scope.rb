class Scope
    attr_accessor :depth,
                  :name,
                  :variables, # hash of values or expressions by identifier
                  :functions, # hash of Block_Constructs
                  :classes # hash of Class_Constructs

    def initialize name = nil
        @name      = if @depth == 0
            'Global'
        elsif name
            name
        end
        @variables = {}
        @functions = {}
        @classes   = {}
    end


    def global?
        depth == 0
    end
end
