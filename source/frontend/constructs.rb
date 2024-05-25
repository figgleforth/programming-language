# class Construct
#    attr_accessor :value, :children
#
#
#    def initialize value, children = []
#       @value    = value
#       @children = children
#    end
#
#
#    def to_s
#       "#{self.class}(#{value})"
#    end
# end
#
# class Comment < Construct; end
#
# class TypeAssignment < Construct; end
#
# class ObjectDeclaration < Construct; end
#
# class FunctionDefinition < Construct; end
#
# class VariableDeclaration < Construct; end
#
# class VariableAssignment < Construct; end
#
# class IfStatement < Construct; end
#
# class ForStatement < Construct; end
#
# class WhileStatement < Construct; end
#
# class WhenStatement < Construct; end
#
# class ExpressionStatement < Construct; end
#
# class BinaryExpression < Construct; end
#
# class Identifier < Construct; end
#
# class NumberLiteral < Construct; end
#
# class StringLiteral < Construct; end
#
# class FunctionCall < Construct; end
#
# # class MemberAccess < Construct; end
#
# # Additional constructs based on the language specification
#
# class Api < Construct; end
#
# class Enum < Construct; end
#
# class Setter < Construct; end
#
# class Getter < Construct; end
#
# # Node to represent a block of statements
# class Block < Construct
#    def initialize(children = [])
#       super(nil, children)
#    end
#
#
#    def to_s
#       "BlockConstruct(#{children.map(&:to_s).join(', ')})"
#    end
# end
