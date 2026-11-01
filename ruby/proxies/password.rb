require 'openssl'

module Code
	# The Ruby half of lang/password.code: scrypt from Ruby's OpenSSL. A hash holds its settings and its salt, so a later change to the settings still reads an old hash.
	class Password < Instance
		extend Ruby_Proxies

		SCRYPT_N    = 2**14 # the cost; each doubling doubles the time and the memory
		SCRYPT_R    = 8
		SCRYPT_P    = 1
		SALT_BYTES  = 16
		HASH_BYTES  = 32
		HASH_PREFIX = 'scrypt'

		# @return ::String, "scrypt$N$r$p$salt$hash", with the salt and the hash in Base64
		def proxy_hash text
			salt = OpenSSL::Random.random_bytes SALT_BYTES
			hash = OpenSSL::KDF.scrypt text.to_s, salt: salt, N: SCRYPT_N, r: SCRYPT_R, p: SCRYPT_P, length: HASH_BYTES
			[HASH_PREFIX, SCRYPT_N, SCRYPT_R, SCRYPT_P, [salt].pack('m0'), [hash].pack('m0')].join '$' # pack('m0') is strict Base64
		end

		# @return true when `text` gives `hash` again. A hash that is not in the format above gives false.
		def proxy_matches? text, hash
			prefix, n, r, p, salt, expected = hash.to_s.split '$'
			return false unless prefix == HASH_PREFIX && expected

			expected = expected.unpack1 'm0'
			actual   = OpenSSL::KDF.scrypt text.to_s, salt: salt.to_s.unpack1('m0'), N: Integer(n), r: Integer(r), p: Integer(p), length: expected.bytesize
			OpenSSL.secure_compare actual, expected
		rescue ArgumentError
			false
		end
	end
end
