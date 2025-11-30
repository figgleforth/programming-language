require 'webrick'
require 'cgi'
require_relative '../ore'

module Ore
	class Server_Runner
		attr_accessor :server_instance, :interpreter, :port, :routes, :webrick_server, :server_thread

		def initialize server_instance, interpreter, routes = {}
			@server_instance = server_instance
			@interpreter     = interpreter
			@port            = extract_port
			@routes          = routes
		end

		def extract_port
			port_value = server_instance[:port] || server_instance.declarations['port']
			port_value.is_a?(Integer) ? port_value : 8080
		end

		def match_route http_method, path_parts, routes
			routes.values.find do |route|
				next unless route.http_method.value == http_method
				next unless route.parts.count == path_parts.count

				# All segments must match (considering :param placeholders)
				path_parts.zip(route.parts).all? do |req_part, route_part|
					(req_part == route_part) || (route_part.start_with?(':'))
				end
			end
		end

		def extract_url_params path_parts, route
			url_params = {}
			path_parts.zip(route.parts).each do |req_part, route_part|
				if route_part.start_with? ':'
					param_name                    = route_part[1..-1]
					url_params[param_name]        = req_part
					url_params[param_name.to_sym] = req_part
				end
			end
			url_params
		end

		def parse_query_string query_string
			query_params = {}
			if query_string
				query_string.split('&').each do |pair|
					key, value               = pair.split '=', 2
					query_params[key]        = CGI.unescape(value || '')
					query_params[key.to_sym] = CGI.unescape(value || '')
				end
			end
			query_params
		end

		def handle_request req, res, routes
			path_string  = req.path
			query_string = req.query_string
			http_method  = req.request_method.downcase
			path_parts   = req.path.split('/').reject { _1.empty? }

			target_route = match_route http_method, path_parts, routes

			if target_route
				url_params   = extract_url_params path_parts, target_route
				query_params = parse_query_string query_string

				# Create Request and Response objects
				air_res = Ore::Response.new
				air_req = Ore::Request.new

				air_req.path    = path_string
				air_req.method  = http_method
				air_req.query   = query_params
				air_req.params  = url_params
				air_req.headers = req.header.to_h
				air_req.body    = req.body

				# Update declarations
				air_req.declarations['path']    = air_req.path
				air_req.declarations['method']  = air_req.method
				air_req.declarations['query']   = air_req.query
				air_req.declarations['params']  = air_req.params
				air_req.declarations['headers'] = air_req.headers
				air_req.declarations['body']    = air_req.body

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
				# 404 Not Found
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
				res.header['Content-Type'] = 'text/html; charset=utf-8'
			end
		end

		def start
			@webrick_server = WEBrick::HTTPServer.new Port: port

			webrick_server.mount_proc '' do |req, res|
				handle_request req, res, @routes
			end

			@server_thread = Thread.new do
				webrick_server.start
			end

			puts "------------------------------"
			puts "Server started on port #{port}"
			puts "Available routes:"
			@routes.values.each do |route|
				puts "  #{route.http_method.value.upcase} /#{route.path}"
			end
			puts "------------------------------"

			server_thread
		end

		def stop
			webrick_server&.shutdown
			Thread.kill server_thread if server_thread
		end
	end
end
