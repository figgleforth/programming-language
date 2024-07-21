class Scope
    @@block_depth = 0
    attr_accessor :depth,
                  :name,
                  :variables, # hash of values or expressions by identifier
                  :functions, # hash of Block_Constructs
                  :classes # hash of Class_Constructs

    def initialize name = nil
        @depth        = @@block_depth
        @name         = if @depth == 0
            'Global'
        elsif name
            name
        end
        @@block_depth += 1
        @variables    = {}
        @functions    = {}
        @classes      = {}
    end


    def global?
        depth == 0
    end


    def decrease_depth
        @@block_depth -= 1
    end
end
