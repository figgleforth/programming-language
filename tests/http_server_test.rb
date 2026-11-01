require_relative 'base_test'
require_relative '../ruby/main'
require 'net/http'
require 'socket'
require 'timeout'

# The server loop in lang/http_server.code, also when CODE_SERVER=webrick. The routes still run through Interpreter#handle_request, so e2e_server_test.rb covers them; these tests cover the loop itself.
class Http_Server_Test < Base_Test
	def setup
		@port = 10200 + Random.rand(300)
	end

	def teardown
		@interpreter&.stop_server @app if @app
	end

	def start_app
		@interpreter                = Code::Interpreter.new
		@interpreter.server_backend = :code
		@app                        = @interpreter.run <<~CODE
			@load 'lang/server'

			Web_App + Server {
				Self ( port := #{@port}; self.port = port )

				get://hello (;
					"hello"
				)

				post://echo (;
					"got `request.body[:x]`"
				)

				get://broken (;
					@raise "broken on purpose"
				)
			}

			Web_App()
		CODE
		@app.port   = @port
		@app.routes = @interpreter.collect_routes_from_instance @app
		@interpreter.start_server @app
	end

	def get path
		Net::HTTP.get_response URI("http://localhost:#{@port}#{path}")
	end

	# Sends raw bytes and reads the whole reply, which ends when the server closes the connection.
	def send_raw text
		Timeout.timeout 5 do
			socket = TCPSocket.new 'localhost', @port
			socket.write text
			socket.read
		ensure
			socket&.close
		end
	end

	def test_a_route_replies
		start_app
		reply = get '/hello'
		assert_equal '200', reply.code
		assert_equal 'hello', reply.body
		assert_equal '5', reply['content-length']
		assert_equal 'close', reply['connection']
	end

	def test_a_form_body_reaches_the_route
		start_app
		reply = Net::HTTP.post_form URI("http://localhost:#{@port}/echo"), 'x' => '1'
		assert_equal 'got 1', reply.body
	end

	def test_head_has_the_headers_of_get_and_no_body
		start_app
		reply = send_raw "HEAD /hello HTTP/1.1\r\nHost: x\r\n\r\n"
		assert_match "HTTP/1.1 200 OK\r\n", reply
		assert_match "Content-Length: 5\r\n", reply
		assert reply.end_with?("\r\n\r\n"), reply
	end

	def test_an_unknown_path_is_a_404
		start_app
		assert_equal '404', get('/nope').code
	end

	# The loop waits on every socket at once, so a client that sends half a request holds up no one
	def test_a_slow_client_does_not_hold_up_another
		start_app
		slow = TCPSocket.new 'localhost', @port
		slow.write "GET /hello HTTP/1.1\r\nHo"

		reply = Timeout.timeout(5) { get '/hello' }
		assert_equal 'hello', reply.body

		slow.write "st: x\r\n\r\n"
		assert_match "\r\n\r\nhello", Timeout.timeout(5) { slow.read }
	ensure
		slow&.close
	end

	def test_a_malformed_request_is_a_400_and_the_loop_goes_on
		start_app
		assert_match 'HTTP/1.1 400 Bad Request', send_raw("GARBAGE\r\n\r\n")
		assert_equal 'hello', get('/hello').body
	end

	def test_a_route_that_raises_is_a_500_and_the_loop_goes_on
		start_app
		assert_equal '500', get('/broken').code
		assert_equal 'hello', get('/hello').body
	end

	# The client sends the body only after the 100 Continue line (RFC 9110 §10.1.1)
	def test_expect_100_continue_gets_its_line_before_the_body
		start_app
		Timeout.timeout 5 do
			socket = TCPSocket.new 'localhost', @port
			socket.write "POST /echo HTTP/1.1\r\nHost: x\r\nExpect: 100-continue\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 3\r\n\r\n"
			assert_equal "HTTP/1.1 100 Continue\r\n", socket.gets
			assert_equal "\r\n", socket.gets

			socket.write 'x=1'
			assert_match "\r\n\r\ngot 1", socket.read
		ensure
			socket&.close
		end
	end

	def test_a_client_that_closes_early_does_not_stop_the_loop
		start_app
		socket = TCPSocket.new 'localhost', @port
		socket.write "GET /hel"
		socket.close
		assert_equal 'hello', Timeout.timeout(5) { get('/hello').body }
	end

	def test_stop_server_ends_the_loop_and_frees_the_port
		start_app
		@interpreter.stop_server @app
		refute @interpreter.server_running?(@app)

		start_app
		assert_equal 'hello', get('/hello').body
	end

	# Code after @start_server runs on the program's own thread while the loop runs on its own, and each keeps its own stack
	def test_the_program_runs_on_while_the_loop_waits
		@interpreter                = Code::Interpreter.new
		@interpreter.server_backend = :code
		@interpreter.serve_in_foreground = false
		out = @interpreter.run <<~CODE
			@load 'lang/server'

			Web_App + Server {
				Self ( port := #{@port}; self.port = port )

				get://hello (;
					"hello"
				)
			}

			app := @start_server Web_App()

			add ( a, b;
				a + b
			)

			add(2, 3)
		CODE
		@app = @interpreter.servers.first
		assert_equal 5, out
		assert_equal 'hello', get('/hello').body
	end

	# The key was written as :"code_stack_16" by mistake, so every interpreter shared one stack slot on a thread
	def test_each_interpreter_keeps_its_stack_under_its_own_key
		first  = Code::Interpreter.new
		second = Code::Interpreter.new
		refute_equal first.instance_variable_get(:@stack_key), second.instance_variable_get(:@stack_key)

		first.run 'x := 1'
		out = Thread.new do
			Thread.current[first.instance_variable_get(:@stack_key)] = [first.global]
			second.run "y := 2\ny"
		end.value
		assert_equal 2, out
	end
end
