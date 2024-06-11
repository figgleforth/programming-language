class Block_Scope
    @@block_depth = 0
    attr_accessor :depth, :members, :methods, :objects

    BLOCK_INDENT = '——'


    def initialize
        @members = {}
        @methods = {}
        @objects = {}
        @@block_depth += 1
        @depth = @@block_depth

        indent = BLOCK_INDENT.length + 11 + @@block_depth
        puts " BLOCK ENTER".rjust(indent, BLOCK_INDENT) # for length of block enter phrase
    end

    def global?
        depth == 0
    end

    def decrease_depth
        @@block_depth -= 1
        indent = BLOCK_INDENT.length + 11 + @@block_depth
        puts " BLOCK EXIT".rjust(indent, BLOCK_INDENT) # for length of block enter phrase
    end
end
