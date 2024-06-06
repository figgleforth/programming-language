# Evaluates AST and returns the result
class Interpreter
    require_relative '../parser/ast'

    attr_accessor :ast


    def initialize ast
        @ast = ast
    end

    def interpret
        @ast.map &:evaluate
    end
end

# Jon Blow has a Queued struct that contains an array of expressions in the order that they have to be executed. he says this is one way of traversing the tree when you're executing code. you could otherwise keep some pointer to where you are in the tree, but that sounds like hell.
