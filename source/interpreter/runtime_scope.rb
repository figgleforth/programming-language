class Runtime_Scope
    @@block_depth = 0
    attr_accessor :depth, :members, :methods, :objects


    def initialize
        @members      = {}
        @methods      = {}
        @objects      = {}
        @depth        = @@block_depth
        @@block_depth += 1
    end


    def global?
        depth == 0
    end


    def decrease_depth
        @@block_depth -= 1
    end
end
