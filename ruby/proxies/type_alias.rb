module Code
	# A type expression with a name, from `Strumber :: String | Number`, or without one, from a `: String | Number` annotation. It is not a Type: it cannot be constructed, it only answers whether a value satisfies it. Each operator keeps its set meaning: `|` either, `&` both, `~` the left but not the right, `^` exactly one.
	class Type_Alias < Scope
		# A tagged type in the tree (`Array\Bool`). A check reads only `name`, the same as a `x: Array\Bool` annotation does, and `text` is for display.
		Tagged = ::Data.define :name, :text

		# @return [::String, Tagged, ::Array] a type name, a Tagged, or [operator, left, right]
		attr_accessor :tree

		# @param tree [::String, Tagged, ::Array] see #tree
		# @param name [::String, nil] nil for an annotation that has no alias name
		def initialize tree, name = nil
			super name
			@tree = tree
		end

		# Builds the tree from a flat chain (`A | B & C` is [A, B, C] with ['|', '&']), so `&` binds tighter than `|` the same way it does in a value expression.
		# @param operands [[::String, Tagged]]
		# @param operators [[::String]]
		# @return [::String, ::Array]
		def self.tree_from_chain operands, operators
			precedence = ->(operator) { PRECEDENCES[operator] || DEFAULT_OPERATOR_PRECEDENCE }
			output     = [operands.first]
			pending    = []
			reduce     = -> { right = output.pop; output << [pending.pop, output.pop, right] }

			operators.each_with_index do |operator, i|
				reduce.call while pending.any? && precedence[pending.last] >= precedence[operator]
				pending << operator
				output << operands[i + 1]
			end
			reduce.call while pending.any?
			output.first
		end

		# @yieldparam name [::String] one type name in the tree
		# @yieldreturn [Boolean] whether the value satisfies that one type
		def satisfied? node = tree, &satisfies_name
			return satisfies_name.call(node.name) if node.is_a? Tagged
			return satisfies_name.call(node) unless node.is_a? ::Array

			operator, left, right = node
			left_result           = satisfied? left, &satisfies_name
			right_result          = satisfied? right, &satisfies_name
			case operator
			when '|' then left_result || right_result
			when '&' then left_result && right_result
			when '~' then left_result && !right_result
			when '^' then left_result ^ right_result
			end
		end

		# @return [::String] the expression as written, for example "String | Number"
		def expression_to_s node = tree, parent_precedence = 0
			return node.text if node.is_a? Tagged
			return node unless node.is_a? ::Array

			operator, left, right = node
			precedence            = PRECEDENCES[operator] || DEFAULT_OPERATOR_PRECEDENCE
			text                  = "#{expression_to_s left, precedence} #{operator} #{expression_to_s right, precedence + 1}"
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
