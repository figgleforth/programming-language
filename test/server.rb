require 'webrick'
require './lib/air.rb'
require './lib/shared/helpers.rb'

expressions = _parse File.read('./air/server.air').to_s
interpreter = Interpreter.new expressions

# Run a single instance of Air::Server (for now)
port   = nil
routes = nil
result = interpreter.output do |result, runtime, stack|
	port   = runtime.servers.first[:port]
	routes = runtime.routes
end

# Configure WEBrick
server = WEBrick::HTTPServer.new :Port => port
server.mount_proc '' do |req, res|
	# note: The empty string when mounting is a wildcard to intercept every route.
	path_string  = req.path
	query_string = req.query_string
	http_method  = req.request_method.downcase
	path_parts   = req.path.split('/').reject { _1.empty? }

	# Find matching route by HTTP method and path structure
	target_route = routes.values.find do |route|
		# 1. HTTP method must match
		next unless route.http_method.value == http_method

		# 2. Path segment count must match
		next unless route.parts.count == path_parts.count

		# 3. All segments must match (considering :param placeholders)
		matching_parts = path_parts.zip(route.parts).all? do |req_part, route_part|
			(req_part == route_part) || (route_part.start_with?(':'))
		end

		matching_parts
	end

	if target_route
		# Extract URL parameters from path
		url_params = {}
		path_parts.zip(target_route.parts).each do |req_part, route_part|
			if route_part.start_with? ':'
				param_name             = route_part[1..-1] # Remove leading ':'
				url_params[param_name] = req_part
			end
		end

		# Parse query string into hash
		query_params = {}
		if query_string
			query_string.split('&').each do |pair|
				key, value        = pair.split '=', 2
				query_params[key] = CGI.unescape(value || '')
			end
		end

		# Create Request and Response objects
		air_res         = Air::Response.new
		air_req         = Air::Request.new
		air_req.path    = path_string
		air_req.method  = http_method
		air_req.query   = query_params
		air_req.params  = url_params
		air_req.headers = req.header.to_h
		air_req.body    = req.body

		# Update declarations to match instance variables
		air_req.declarations['path']    = air_req.path
		air_req.declarations['method']  = air_req.method
		air_req.declarations['query']   = air_req.query
		air_req.declarations['params']  = air_req.params
		air_req.declarations['headers'] = air_req.headers
		air_req.declarations['body']    = air_req.body

		# Execute route handler with intrinsic request/response
		begin
			result = interpreter.interp_route_handler target_route, air_req, air_res, url_params

			# Apply response object's configuration to WEBrick response
			res.status = air_res.status
			air_res.headers.each { |k, v| res.header[k] = v }
			res.body = air_res.body_content.to_s

		rescue => e
			res.status = 500
			res.body   = <<~HTML
			    <h1>500 Internal Server Error</h1>
			    <h2>#{e.class}: #{e.message}</h2>
			    <pre>#{e.backtrace.join("\n")}</pre>
			HTML
			res.header['Content-Type'] = 'text/html; charset=utf-8'
		end
	else
		# target_route is nil, so show 404
		res.status = 404
		res.body   = <<~HTML
		    <h1>404 Not Found</h1>
		    <p>No route matches #{http_method.upcase} #{path_string}</p>
		    <hr>
		    <h3>Available Routes:</h3>
		    <ul>
		    	#{routes.values.map { |r| "<li>#{r.http_method.value.upcase} /#{r.path}</li>" }.join("\n")}
		    </ul>
		HTML
		res.header['Content-Type'] = 'text/html; charset=utf-8' # See https://developer.mozilla.org/en-US/docs/Glossary/Request_header
	end
end

begin
	server_thread = Thread.new do
		server.start
	end

	server_thread.join
ensure
	server.shutdown
	Thread.kill server_thread
	puts "Killed server thread #{server_thread}"
end
