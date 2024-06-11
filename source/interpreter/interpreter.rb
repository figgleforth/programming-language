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


    def evaluate!
        time = benchmark do
            Block_Scope.new.tap do |scope|
                @scopes << scope

                @expressions.each do |expr|
                    if expr == AssignmentExpr
                        curr_scope.members[expr.name] ||= Runtime_Assignment.new(expr).tap do |runtime|
                            runtime.evaluated_value = expr.evaluate
                            # puts runtime.evaluated_value
                        end
                    elsif expr == IdentifierExpr
                        if curr_scope.members[expr.identifier]
                            runtime = curr_scope.members[expr.identifier] # Runtime_Assignment
                            puts runtime.evaluated_value
                            # elsif curr_scope.methods[expr.identifier]
                            # elsif curr_scope.objects[expr.identifier]
                        else
                            raise "Undefined identifier #{expr.identifier}"
                        end
                    elsif expr == ObjectExpr
                        Block_Scope.new.tap do |s|
                            @scopes << s
                            puts expr
                        end.decrease_depth
                    end
                end

            end.decrease_depth
        end
        puts "\nRan in #{'%.5f' % time} seconds"
    end

    def evaluate ast
        return unless ast

        case ast
            when AssignmentExpr
            when IdentifierExpr

            else
                "Unrecognized ast #{ast.inspect}"

        end
    end
end

# class Ast
# class Program < Ast
# class Ast_Expression < Ast
# class SymbolExpr < Ast_Expression
# class StringExpr < Ast_Expression
# class NumberExpr < Ast_Expression
# class ObjectExpr < Ast_Expression
# class FunctionExpr < Ast_Expression
# class CommaSeparatedExpr < Ast_Expression
# class FunctionParamExpr < Ast_Expression
# class FunctionArgExpr < Ast_Expression
# class FunctionCallExpr < Ast_Expression
# class AssignmentExpr < Ast_Expression
# class UnaryExpr < Ast_Expression
# class BinaryExpr < Ast_Expression


# todo: get rid of types tomorrow. lets make this as ruby as possible for now. then later we can think about adding types. leave the parsing code, just don't use types.


# function evaluate(node):
#     if node is null:
#         return
#
#     // Evaluate based on node type
#     switch (node.type):
#         case Program:
#             for each child in node.children:
#                 evaluate(child)
#             break
#
#         case AssignmentExpr:
#             // Evaluate the right-hand side expression
#             value = evaluate(node.expression)
#             // Assign value to variable
#             environment[node.name] = value
#             break
#
#         case BinaryExpr:
#             // Evaluate left and right expressions
#             left_value = evaluate(node.left)
#             right_value = evaluate(node.right)
#             // Perform binary operation and return result
#             return perform_binary_operation(node.operator, left_value, right_value)
#
#         case IdentifierExpr:
#             // Look up variable value in the environment
#             if node.name not in environment:
#                 throw RuntimeError("Undefined variable: " + node.name)
#             return environment[node.name]
#
#         // Handle other node types similarly
#
#         default:
#             // Handle unsupported or unknown node types
#             throw RuntimeError("Unsupported node type: " + node.type)
#
# // Start evaluation with the root node of the AST
# evaluate(root_node)
