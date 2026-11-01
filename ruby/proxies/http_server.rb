module Code
	# The Ruby half of lang/http_server.code: the bridge from a parsed request to the routes, and the stop flag.
	class Http_Server < Instance
		extend Ruby_Proxies

		# A request and a reply shaped like WEBrick's, so Interpreter#handle_request serves this server with no change (Interpreter#respond_to_http_request builds them). They go when routing moves into .code.
		Webrick_Request = ::Data.define :path, :query_string, :request_method, :content_type, :body, :header, :cookies
		Webrick_Cookie  = ::Data.define :name, :value
		Webrick_Reply   = ::Struct.new :status, :header, :body do
			def []= name, value
				header[name] = value
			end
		end

		# @return Code::Interpreter, Code::Instance (the app's Server) -- set by Interpreter#start_code_server
		attr_accessor :interpreter, :app

		def initialize name = 'Http_Server'
			super name
			@stopping = false
		end

		# @param request Code::Struct, a Request from lang/http.code
		# @return Code::Array of the status, the headers (Code::Dictionary) and the body
		def proxy_respond request
			interpreter.respond_to_http_request app, request
		end

		def proxy_stopping? = @stopping

		# Interpreter#stop_server calls this from another thread. The loop sees it after its current wait.
		def stop!
			@stopping = true
		end
	end
end
