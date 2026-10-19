module Code
	class Tcp_Socket < Instance
		extend Ruby_Proxies
		include Declaration_Accessors

		# @return ::TCPSocket, nil until #proxy_connect runs or Tcp_Server#proxy_accept sets it
		attr_accessor :socket

		def initialize name = 'Tcp_Socket'
			super name
		end

		# @param host ::String
		# @param port ::Integer
		# @return Code::Tcp_Socket
		def proxy_connect host, port
			require 'socket' # loaded on first use, like webrick and sequel
			@socket = ::TCPSocket.new (host.respond_to?(:value) ? host.value : host), port
			self
		end

		# The line end stays, so an HTTP line comes back with its "\r\n". Ruby reads socket bytes as BINARY and cuts the line at the LF byte, so the result is labelled UTF-8 to join with the language's own strings.
		# A byte that is not valid UTF-8 becomes U+FFFD, or split/downcase/trim on the line would raise a Ruby error and stop the server.
		# @return ::String, nil when the other side closed
		def proxy_read_line
			@socket.gets&.force_encoding('UTF-8')&.scrub
		rescue Errno::ECONNRESET
			nil
		end

		# Waits for count bytes, or fewer when the other side closes first.
		# @param count ::Integer
		# @return ::String, nil when the other side closed before the first byte
		def proxy_read count
			@socket.read(count)&.force_encoding 'UTF-8'
		rescue Errno::ECONNRESET
			nil
		end

		# A socket sends each write at once (Ruby sets sync on sockets), so there is nothing to flush.
		# @param text ::String
		# @return ::Integer the number of bytes written, nil when the other side closed
		def proxy_write text
			@socket.write (text.respond_to?(:value) ? text.value : text)
		rescue Errno::EPIPE, Errno::ECONNRESET
			nil
		end

		# @return nil
		def proxy_close
			@socket&.close
			nil
		end

		# @return true, false
		def proxy_closed? = @socket.nil? || @socket.closed?

		# @return ::String, for example "::1", or "::ffff:127.0.0.1" for an IPv4 client on a server that listens on every address
		def proxy_peer_ip = @socket.remote_address.ip_address

		# @return ::Integer
		def proxy_peer_port = @socket.remote_address.ip_port

		# @return ::Integer
		def proxy_local_port = @socket.local_address.ip_port

		# @return ::String
		def proxy_to_s
			return 'Tcp_Socket(closed)' if proxy_closed?

			"Tcp_Socket(#{@socket.local_address.inspect_sockaddr} <-> #{@socket.remote_address.inspect_sockaddr})"
		end
	end
end
