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

server = WEBrick::HTTPServer.new :Port => air_server[:port]

routes.each do |name, route|
	server.mount_proc route.path do |req, res|
		puts "Request: #{req.inspect}"
		interpreter.input = route.handler.expressions
		res.body          = interpreter.output
	end
	puts "Mounted:\t#{name} => #{route.path}"
end

begin
	server.start
ensure
	server.shutdown
end
