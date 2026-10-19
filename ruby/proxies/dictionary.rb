module Code
	class Dictionary < Instance
		extend Ruby_Proxies
		attr_accessor :hash

		def initialize hash = nil
			super 'Dictionary'
			@hash                 = hash || {}
			@declarations['hash'] = @hash
		end

		proxy_delegate 'hash'
		proxy :count
		proxy :empty?
		proxy :clear

		def proxy_keys
			Code::Array.new hash.keys
		end

		def proxy_values
			Code::Array.new hash.values
		end

		def proxy_merge other_hash
			rehash_keys
			other_hash.rehash_keys
			Code::Dictionary.new hash.merge(other_hash.hash)
		end

		# A key keeps its own type, the same as in Ruby: `{:name = 1}` and `{'name' = 1}` hold two keys, and `{123 = 1}` a Number key. A wrapped primitive (a Code::String, Number, or Bool) unwraps to its Ruby value, so a variable that holds `'name'` finds the same entry as the literal `'name'`. Any other value is its own key: a struct compares by its name and member values (Struct#hash), so `d[Vec2(0, 0)]` finds an entry made with another `Vec2(0, 0)`, and an instance compares by identity.
		def normalize_dict_key key
			case key
			when Code::String, Code::Symbol, Code::Number then key.value
			when Code::Bool then key.truthiness
			when Code::Nil then nil
			else key
			end
		end

		# A struct or Array key compares by its values, and it can change after it is stored: the entry then sits under its old hash, where a lookup by the new value cannot find it. So a lookup that misses rehashes once, when such a value has changed since the last rehash, and looks again. A hit never needs it, since Ruby compares the stored key's current value.
		@key_epoch = 0

		class << self
			attr_reader :key_epoch

			# Called by Struct#[]= and the Array methods that change values in place.
			def key_changed!
				@key_epoch += 1
			end
		end

		# Does the hash hold `key` (already normalized), by the key's current value?
		def find_key key
			return true if hash.has_key? key
			return false unless @changeable_keys && @rehashed_at != Dictionary.key_epoch

			rehash_keys
			hash.has_key? key
		end

		def rehash_keys
			hash.rehash
			@rehashed_at = Dictionary.key_epoch
		end

		# note; To prevent Scope#[] or Scope#get from missing out on the actual location of the hash. Standard members still call through to [] and get. I'm manually calling these proxy methods in some places. @pasted from array.rb
		def proxy_get key
			key = normalize_dict_key key
			hash[key] if find_key key
		end

		def proxy_set key, value
			key = normalize_dict_key key
			find_key key # rehashes first when a key changed, or this would add a second entry for it
			@changeable_keys ||= key.is_a?(Code::Struct) || key.is_a?(Code::Array)
			hash[key] = value
		end

		# `[]`/`[]=` (#proxy_get/#proxy_set above) normalize the key before touching `hash` -- these three need the exact same normalization, or a key held in a variable (`d.has_key?(name)`, a Code::String) never matches the raw String that is stored.
		def proxy_has_key? key
			find_key normalize_dict_key(key)
		end

		def proxy_delete key
			key = normalize_dict_key key
			hash.delete key if find_key key
		end

		def proxy_fetch key, default = nil
			key = normalize_dict_key key
			find_key(key) ? hash[key] : default
		end

		def == other
			return false unless other.is_a? Dictionary

			rehash_keys
			other.rehash_keys
			hash == other.hash
		end

		# How `to_s` shows a String key: bare when it is a plain name, since `{name = 1}` makes the key "name", and quoted otherwise.
		# @param key [::String]
		def proxy__bare_name? key
			key = key.value if key.is_a? Code::String
			key.is_a?(::String) && key.match?(/\A[A-Za-z_][A-Za-z0-9_]*[?!]?\z/) && !%w(true false nil self Self Global).include?(key)
		end

		def to_s
			hash.inspect
		end
	end
end
