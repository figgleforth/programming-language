require_relative '../parser/ast'
require_relative 'block_scope'
require_relative 'runtimes'
require 'benchmark'

# Jon Blow has a Queued struct that contains an array of expressions in the order that they have to be executed. he says this is one way of traversing the tree when you're executing code. you could otherwise keep some pointer to where you are in the tree, but that sounds difficult?

# Evaluates AST and returns the result
class Interpreter
    attr_accessor :expressions, :scopes


    def initialize expressions
        @expressions = expressions
        @scopes      = []
    end


    def depth
        @scopes.count
    end


    def curr_scope
        @scopes.last
    end


    def benchmark
        started_at = Time.now
        yield
        Time.now - started_at
    end


    def evaluate expr
        return unless expr

        case expr
            when Assignment_Expr
                value = evaluate expr.expression
            else
                "Unrecognized ast #{expr.inspect}"

                # when Identifier_Expr
                # when Class_Expr
        end
    end
end


# def evaluate
#     if Lexer::KEYWORDS.include? token.string
#         return nil if token.string == 'nil'
#         return true if token.string == 'true'
#         return false if token.string == 'false'
#     else
#         token.string
#     end
# end
