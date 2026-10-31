module Code
	class Tcp_Server < Instance
		extend Ruby_Proxies
		include Declaration_Accessors

		# @return ::TCPServer, nil until #proxy_listen runs
		attr_accessor :server

		def initialize name = 'Tcp_Server'
			super name
		end

		# A second call does nothing, so `Self` can call it and a user call cannot open a second socket.
		# @return Code::Tcp_Server
		def proxy_open_socket backlog = nil
			require 'socket' # loaded on first use, like webrick and sequel
			@server ||= ::TCPServer.new (host.respond_to?(:value) ? host.value : host), port
			@server.listen(backlog) if backlog
			self.port = @server.local_address.ip_port # port 0 asks the OS for a free port, so store the real one
			self
		end

		# Waits until a client connects.
		# @return Code::Tcp_Socket
		def proxy_wait_for_connection
			socket        = Code::Tcp_Socket.new
			socket.socket = @server.accept
			socket
		end

		# Waits until one of the sockets has bytes to read, or a client waits to connect. The server itself is in the result when a client waits.
		# @param sockets Code::Array of Code::Tcp_Socket
		# @param timeout ::Numeric, seconds; nil waits as long as it takes
		# @return Code::Array of the ready ones, empty after the timeout
		def proxy_wait_for_ready sockets, timeout = nil
			by_io = { @server => self }
			(sockets.respond_to?(:values) ? sockets.values : sockets).each { by_io[it.socket] = it unless it.proxy_closed? }
			ready, = ::IO.select by_io.keys, nil, nil, timeout
			Code::Array.new (ready || []).map { by_io[it] }
		end

		# @return nil
		def proxy_close
			@server&.close
			nil
		end

		# @return true, false
		def proxy_closed? = @server.nil? || @server.closed?

		# @return ::String
		def proxy_to_s
			return 'Tcp_Server(closed)' if proxy_closed?

			"Tcp_Server(#{@server.local_address.inspect_sockaddr})"
		end
	end
end
