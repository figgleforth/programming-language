require 'webrick'
require './lib/air.rb'
require './lib/shared/helpers.rb'

expressions = _parse File.read('./air/preload.air').to_s
interpreter = Interpreter.new expressions

# Run a single instance of Air::Server
air_server = nil
routes     = nil
result     = interpreter.output do |result, runtime, stack|
	Air.assert runtime.servers.count == 1
	air_server = runtime.servers.first
	routes     = runtime.routes
end
Air.assert air_server

# Use air_server to build WEBrick config
server = WEBrick::HTTPServer.new :Port => air_server[:port]
server.mount_proc '' do |req, res|
	# The empty string is a wildcard to intercept every route.
	path_string = req.path # /abc/123/def ...
	query       = req.query_string # id=123&what=456
	type        = req.request_method # GET, PUT, ...
	parts       = req.path.split('/').reject do
		_1.empty?
	end

	# TODO This current structure is weird, it's hard to know how to evaluate the air_route value? It points to a function, so we need to execute it, and give it the proper arguments based on the request

	# routes = { :string_path => Air::Route }
	target_route = routes.values.find do |air_route|

		# Air::Route < Air::Func -> :http_method, :path, :handler, :parts
		identical_path = air_route.path == path_string
		next unless air_route.parts.count == parts.count

		matching_parts = parts.zip(air_route.parts).all? do |req_path_part, air_path_part|
			(req_path_part == air_path_part) || (air_path_part[0] == ':')
		end

		identical_path || matching_parts
	end

	res.body = "<div>"

	if target_route
		interpreter.input = target_route.handler.expressions #.expressions
		res.body          += "#{interpreter.output}"
	else
		res.body += "404"
	end

	res.body                   += "<hr /><h3>URL Parts</h3><p>#{parts}</p><h3>Currently Declared Routes</h3><p>#{routes.values.map(&:path)}</p>"
	res.body                   += "</div>"
	res.header['Content-Type'] = 'text/html; charset=utf-8' # See https://developer.mozilla.org/en-US/docs/Glossary/Request_header
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

# /abc/123/def
# ['abc', dynamic, 'def']
# A match is when:
#   1) path == route.path
#   2) parts == route.parts where fixed parts match with dynamic parts
#                           parts       = [abc, 123, def, whatever]
#                           route.parts = [abc, :id, def, :word]
#
