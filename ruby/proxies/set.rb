require 'set'

module Code
	class Set < Instance
		extend Ruby_Proxies
		attr_accessor :set

		def initialize _items = nil
			super 'Set'
			@set = ::Set.new
		end

		# A struct or Array element compares by its current values, and it can change after it is added, which leaves it under its old hash. So, like Dictionary#find_key, the Set rehashes once per change (Dictionary.key_changed!) before anything that reads its hashes: a changed element is found by its new value, and two elements that became equal count as one.
		def fresh_set
			if @changeable_items && @reset_at != Code::Dictionary.key_epoch
				@set.reset
				@reset_at = Code::Dictionary.key_epoch
			end
			@set
		end

		def note_changeable items
			@changeable_items ||= items.any? { it.is_a?(Code::Struct) || it.is_a?(Code::Array) }
		end

		def to_ruby_set other
			return ::Set.new               if other.nil?
			return other.dup              if other.is_a? ::Set
			return other.fresh_set.dup   if other.is_a? Code::Set
			return ::Set.new(other.values) if other.respond_to? :values
			return ::Set.new(other.to_a)  if other.respond_to?(:to_a) || other.respond_to?(:each)
			Code.assert false, "Set expected an Array, Range, or Set, got #{other.class.name.split('::').last}"
		end

		# --- mutating primitives (return self, matching Ruby's Set#add/#delete/#merge/#clear) ---

		def proxy_add item
			note_changeable [item]
			fresh_set.add item
			self
		end

		def proxy_delete item
			fresh_set.delete item
			self
		end

		def proxy_merge other
			items = to_ruby_set other
			note_changeable items
			fresh_set.merge items
			self
		end

		def proxy_clear
			@set.clear
			self
		end

		# --- queries ---

		def proxy_length
			fresh_set.size
		end

		def proxy_empty?
			fresh_set.empty?
		end

		# A fresh Array snapshot -- mutating it can't corrupt the Set's own store.
		def proxy_values
			Code::Array.new fresh_set.to_a
		end

		def proxy_subset? other
			fresh_set.subset? to_ruby_set(other)
		end

		def proxy_superset? other
			fresh_set.superset? to_ruby_set(other)
		end

		def proxy_disjoint? other
			fresh_set.disjoint? to_ruby_set(other)
		end

		def proxy_intersect? other
			fresh_set.intersect? to_ruby_set(other)
		end

		# --- set algebra ---

		def | other
			combined Code::Set.new.tap { |s| s.set.replace(fresh_set | to_ruby_set(other)) }
		end

		def & other
			combined Code::Set.new.tap { |s| s.set.replace(fresh_set & to_ruby_set(other)) }
		end

		def - other
			combined Code::Set.new.tap { |s| s.set.replace(fresh_set - to_ruby_set(other)) }
		end

		def ^ other
			combined Code::Set.new.tap { |s| s.set.replace(fresh_set ^ to_ruby_set(other)) }
		end

		# A Set built by `|`/`&`/`-`/`^` keeps following its struct and Array elements.
		def combined result
			result.note_changeable result.set
			result
		end

		def == other
			other.is_a?(Code::Set) && fresh_set == other.fresh_set
		end

		def to_s
			"Set{#{fresh_set.to_a.map(&:to_s).join(', ')}}"
		end
	end
end
