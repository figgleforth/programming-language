require 'json'
require 'openssl'
require 'uri'

module Code
	# Set-Cookie lines (RFC 6265 §4.1), and signed values: a user can read a signed cookie, but cannot change it without the server's secret.
	module Cookies
		NAME_REGEX      = /\A[!#$%&'*+\-.^_`|~0-9A-Za-z]+\z/ # a token (RFC 6265 §4.1.1): no space, `=`, `;` or `,`
		SAME_SITE       = %w(Strict Lax None)
		SIGNED_VALUES   = [::String, ::Integer, ::Float, true, false, nil].freeze
		SIGNATURE_SPLIT = '--'

		# @return ::String, one Set-Cookie value. The value is URL-encoded, so any text fits.
		def self.header name, value, max_age: nil, path: '/', http_only: true, secure: false, same_site: 'Lax'
			raise Code::Invalid_Cookie.new("the cookie name #{name.inspect} must be letters, digits, and !#$%&'*+-.^_`|~ only") unless name.is_a?(::String) && name.match?(NAME_REGEX)
			raise Code::Invalid_Cookie.new("same_site must be one of #{SAME_SITE.join(', ')}, not #{same_site.inspect}") unless SAME_SITE.include? same_site
			raise Code::Invalid_Cookie.new("same_site := 'None' needs secure := true, or the browser drops the cookie") if same_site == 'None' && !secure

			parts = ["#{name}=#{URI.encode_www_form_component value.to_s}", "Path=#{path}"]
			parts << "Max-Age=#{Integer max_age}" if max_age
			parts << 'HttpOnly' if http_only
			parts << 'Secure' if secure
			parts << "SameSite=#{same_site}"
			parts.join '; '
		end

		# The value as JSON, so 7 reads back as 7, not "7". The name is part of the signature, so a signed value cannot move to another cookie.
		def self.sign name, value, secret
			unless SIGNED_VALUES.any? { it.is_a?(::Class) ? value.is_a?(it) : value.equal?(it) }
				raise Code::Invalid_Cookie.new("a signed cookie holds a String, a Number, a Bool or nil, not #{value.class}")
			end

			payload = base64url_encode JSON.generate(value)
			"#{payload}#{SIGNATURE_SPLIT}#{signature name, payload, secret}"
		end

		# @return [true, value] when the signature is right, else [false, nil]
		def self.verify name, text, secret
			payload, _, mac = text.to_s.rpartition SIGNATURE_SPLIT
			return [false, nil] if payload.empty? || !OpenSSL.secure_compare(mac, signature(name, payload, secret))

			[true, JSON.parse(base64url_decode(payload))]
		rescue ArgumentError, JSON::ParserError
			[false, nil]
		end

		# Base64 with - and _ in place of + and /, and no = at the end, so it fits in a cookie (RFC 4648 §5). pack('m0') is Ruby's own strict Base64; the base64 gem is not in Ruby's default gems.
		def self.base64url_encode text
			[text].pack('m0').tr('+/', '-_').delete('=')
		end

		def self.base64url_decode text
			text = text.tr '-_', '+/'
			(text + '=' * (-text.length % 4)).unpack1 'm0'
		end

		def self.signature name, payload, secret
			OpenSSL::HMAC.hexdigest 'SHA256', secret, "#{name}=#{payload}"
		end

		# The cookies a browser would send next, after it reads these Set-Cookie values: a value replaces the old one, and Max-Age=0 removes it.
		# @param cookies Array of objects with `name` and `value`
		# @return Array of Http_Server::Webrick_Cookie
		def self.after_set_cookies cookies, set_cookie_values
			by_name = cookies.to_h { [it.name, it.value] }
			set_cookie_values.each do |line|
				pair, *attributes = line.split ';'
				name, value       = pair.split '=', 2
				if attributes.any? { it.strip == 'Max-Age=0' }
					by_name.delete name
				else
					by_name[name] = value.to_s
				end
			end
			by_name.map { |name, value| Code::Http_Server::Webrick_Cookie.new name, value }
		end

		# A cookie value as it came, URL-decoded. A value that does not decode stays as it came.
		def self.decode value
			URI.decode_www_form_component value.to_s
		rescue ArgumentError
			value.to_s
		end
	end
end
