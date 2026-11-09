module Code
	# Every `@operator` declaration of one symbol in one scope, kept under the symbol in the scope's declarations. Each declaration is keyed by its fixity and param types, so a second one with the same key replaces the first, whatever its return type. See Interpreter#find_operator_overload for how one is picked.
	class Operator_Overloads
		# `key` is the fixity and the param types as text (`infix(Vec2,Number)`). `cacheable` is false when a param's contract can depend on more than an operand's type (a literal, a shape, a signature, `Self`).
		Entry = ::Data.define :key, :func, :fixity, :cacheable

		attr_reader :symbol, :owner, :entries

		# @param owner [Code::Scope] the scope that declared them. A scope that gets this list from another one (composition, an instance of a type) copies it before it adds to it.
		def initialize symbol, owner, entries = {}
			@symbol  = symbol
			@owner   = owner
			@entries = entries # {key => Entry}, in the order they were declared
			@choices = {}
		end

		def add entry
			@entries[entry.key] = entry
			@choices.clear
			self
		end

		# A copy that `owner` can add to, without a change to this one.
		def copy_for owner
			Operator_Overloads.new symbol, owner, @entries.dup
		end

		# For composition: this list, plus each declaration of `other` with a key this list does not have. This list is the left one, so it wins.
		def joined_with other, owner
			joined = copy_for owner
			other.entries.each { |key, entry| joined.entries[key] ||= entry }
			joined
		end

		def cacheable?
			@entries.each_value.all?(&:cacheable)
		end

		# The declaration picked for operands of these types, or :none. Reset when a declaration is added.
		def cached_choice key
			@choices[key]
		end

		def cache_choice key, entry
			@choices[key] = entry || :none
		end

		def to_s
			"@operator #{symbol} (#{@entries.length} declaration#{'s' unless @entries.length == 1})"
		end

		alias_method :inspect, :to_s
	end
end
