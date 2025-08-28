require 'webrick'
require './lib/air.rb'
require './lib/shared/helpers.rb'

expressions = _parse File.read('./air/preload.air').to_s
interpreter = Interpreter.new expressions

air_server = nil
routes     = nil
result     = interpreter.output do |result, runtime, stack|
	Air.assert runtime.servers.count == 1
	air_server = runtime.servers.first
	routes     = runtime.routes
end
Air.assert air_server

puts routes.inspect

class Simple < WEBrick::HTTPServlet::AbstractServlet
	def do_GET request, response
		response.status          = 200
		response['Content-Type'] = 'text/plain'
		response.body            = 'Hello, World!'
	end
end

server = WEBrick::HTTPServer.new :Port => air_server[:port]
server.mount '/simple', Simple

# routes.each do |name, route|
# 	server.mount_proc route.path do |req, res|
# 		puts "request: #{req.inspect}"
# 		interpreter.input = route.handler.expressions
# 		res.body          = interpreter.output
# 	end
# 	puts "Mounted:\t#{name} => #{route.path}"
# end

begin
	server.start
ensure
	server.shutdown
end
