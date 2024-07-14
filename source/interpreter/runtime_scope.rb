class Runtime_Scope
    @@block_depth = 0
    attr_accessor :depth, :variables, :methods, :instances


    def initialize
        @variables    = {}
        @methods      = {}
        @instances    = {}
        @depth        = @@block_depth
        @@block_depth += 1
    end


    def global?
        depth == 0
    end


    def decrease_depth
        @@block_depth -= 1
    end


    def to_s
        "Scope<methods #{methods}>"
    end
end
