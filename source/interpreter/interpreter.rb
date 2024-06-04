# Evaluates AST and returns the result
class Interpreter
    require_relative '../parser/nodes'

    attr_accessor :ast


    def initialize ast
        @ast = ast
    end

    def interpret
        @ast.map &:evaluate
    end
end
