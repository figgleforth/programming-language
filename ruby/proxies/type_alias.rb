module Code
	# A type expression with a name, from `Strumber :: String | Number`, or without one, from a `: String | Number` annotation. It is not a Type: it cannot be constructed, it only answers whether a value satisfies it. Each operator keeps its set meaning: `|` either, `&` both, `~` the left but not the right, `^` exactly one.
	class Type_Alias < Scope
		# A tagged type in the tree (`Array\Bool`). A check reads only `name`, the same as a `x: Array\Bool` annotation does, and `text` is for display.
		Tagged = ::Data.define :name, :text

		# A literal in the tree (`"fill"`, `5`, `:fill`, `true`, `nil`). It allows only a value equal to `value`. `type_name` is the literal's own type, for a check that has only type names.
		Literal = ::Data.define :value, :type_name, :text

		# A struct shape in the tree (`<data: String>`). It allows a value that has each member, by name or by position. `struct` is the Code::Struct the shape was read into.
		Shape = ::Data.define :struct, :text do
			def type_name = 'Struct'
		end

		# Two parts of the tree joined by an operator (`A | B`). `left` and `right` are each a type name, a Tagged, a Literal, or another Node.
		Node = ::Data.define :operator, :left, :right

		# @return [::String, Tagged, Literal, Node] a type name, a Tagged, a Literal, or a Node
		attr_accessor :tree

		# @param tree [::String, Tagged, Literal, Node] see #tree
		# @param name [::String, nil] nil for an annotation that has no alias name
		def initialize tree, name = nil
			super name
			@tree = tree
		end

		# Builds the tree from a flat chain (`A | B & C` is [A, B, C] with ['|', '&']), so `&` binds tighter than `|` the same way it does in a value expression.
		# @param operands [[::String, Tagged, Literal]]
		# @param operators [[::String]]
		# @return [::String, Tagged, Literal, Node]
		def self.tree_from_chain operands, operators
			precedence = ->(operator) { PRECEDENCES[operator] || DEFAULT_OPERATOR_PRECEDENCE }
			output     = [operands.first]
			pending    = []
			reduce     = -> { right = output.pop; output << Node.new(pending.pop, output.pop, right) }

			operators.each_with_index do |operator, i|
				reduce.call while pending.any? && precedence[pending.last] >= precedence[operator]
				pending << operator
				output << operands[i + 1]
			end
			reduce.call while pending.any?
			output.first
		end

		# @yieldparam leaf [::String, Literal, Shape] one type name, literal, or struct shape in the tree
		# @yieldreturn [Boolean] whether the value satisfies that one leaf
		def satisfied? node = tree, &satisfies_leaf
			return satisfies_leaf.call(node.name) if node.is_a? Tagged
			return satisfies_leaf.call(node) unless node.is_a? Node

			left_result  = satisfied? node.left, &satisfies_leaf
			right_result = satisfied? node.right, &satisfies_leaf
			case node.operator
			when '|' then left_result || right_result
			when '&' then left_result && right_result
			when '~' then left_result && !right_result
			when '^' then left_result ^ right_result
			end
		end

		# @return [::String] the expression as written, for example "String | Number"
		def expression_to_s node = tree, parent_precedence = 0
			return node.text if node.is_a?(Tagged) || node.is_a?(Literal) || node.is_a?(Shape)
			return node unless node.is_a? Node

			precedence = PRECEDENCES[node.operator] || DEFAULT_OPERATOR_PRECEDENCE
			text       = "#{expression_to_s node.left, precedence} #{node.operator} #{expression_to_s node.right, precedence + 1}"
			precedence < parent_precedence ? "(#{text})" : text
		end

		def display_name
			name || expression_to_s
		end

		def to_s
			name ? "#{name} :: #{expression_to_s}" : expression_to_s
		end

		# Two annotations written the same way are the same contract, so a signature `(-> String | Nil;)` matches another one.
		def == other
			other.is_a?(Type_Alias) && other.tree == tree
		end
		alias eql? ==

		def hash
			tree.hash
		end
	end
end
