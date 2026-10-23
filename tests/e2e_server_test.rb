require 'minitest/autorun'
require_relative '../ruby/main'
require 'net/http'
require 'uri'
require 'timeout'
require 'tmpdir'

class E2E_Server_Test < Minitest::Test
	def setup
		@port = 9999 + Random.rand(100) # Random port to avoid conflicts
	end

	def teardown
		if @server_runner && @interpreter
			@interpreter.stop_server @server_runner
			sleep 0.1
		end
	end

	# `#start_server` used to spawn WEBrick in a Thread.new and return immediately, with nothing synchronizing the caller to when WEBrick actually starts listening. Thread.new returns before the new thread has run at all, so `webrick_server.status` was still :Stop right after start_server returned.
	# Interpreter#run's own "did a server start?" check (`servers.any? { status == :Running }`) raced that and prog almost every time, so `bin/prog run`/`@start` would just silently exit instead of staying up. start_server now blocks on a StartCallback until WEBrick is genuinely :Running (or raises if it failed to start), so this must be true with no sleep at all.
	def test_start_server_blocks_until_webrick_is_actually_running_regression
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := #{@port};
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get:// (; "ok" )
		    }

		    app := Web_App()
		CODE

		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		assert_equal :Running, @server_runner.webrick_server.status
	end

	# A route's tokens use the page's namespace. After the request, a token is static again.
	def test_onclick_token_namespace_goes_back_to_static_after_a_request
		code = <<~CODE
		    @load 'lang/server'

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get://three (;
		    		@onclick((; 1 ))
		    	)
		    }

		    app := Web_App()
		CODE

		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		response = Net::HTTP.get_response URI("http://localhost:#{@port}/three")
		assert_equal '200', response.code
		assert_equal 'page_three-0', response.body
		assert_equal({ element_namespace: 'static', next_slot: 0 }, @interpreter.render_token_counter)
	end

	# Runs `code` and starts the server it returns.
	def start_app code
		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner
	end

	# Sends a click the way dom.js does: POST DOM_EVENT_URL/<token>, with the input values as JSON.
	def click token, inputs
		uri          = URI("http://localhost:#{@port}#{Code::DOM_EVENT_URL}/#{token}")
		request      = Net::HTTP::Post.new uri, 'Content-Type' => 'application/json'
		request.body = JSON.generate({ inputs: inputs })
		Net::HTTP.start(uri.host, uri.port) { it.request request }
	end

	def test_on_server_read_closure_gets_the_value_before_the_click_closure_runs
		start_app <<~CODE
		    @load 'lang/server'

		    draft := ''
		    saved := ''

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		read_token  := @on_server_read((value; draft = value))
		    		click_token := @onclick((; saved = draft))
		    		"`read_token` `click_token`"
		    	)

		    	get://saved (;
		    		saved
		    	)
		    }

		    app := Web_App()
		CODE

		page = Net::HTTP.get_response URI("http://localhost:#{@port}/")
		assert_equal 'page_-0 page_-1', page.body

		click 'page_-1', { 'page_-0' => 'Buy milk' }

		saved = Net::HTTP.get_response URI("http://localhost:#{@port}/saved")
		assert_equal 'Buy milk', saved.body
	end

	# A <select multiple> sends an Array, and the closure gets it as a language Array.
	def test_on_server_read_closure_gets_a_list_as_an_array
		start_app <<~CODE
		    @load 'lang/server'

		    picked := ''

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		read_token  := @on_server_read((values; picked = values.join('+')))
		    		click_token := @onclick((; 1 ))
		    		"`read_token` `click_token`"
		    	)

		    	get://picked (;
		    		picked
		    	)
		    }

		    app := Web_App()
		CODE

		Net::HTTP.get_response URI("http://localhost:#{@port}/")
		click 'page_-1', { 'page_-0' => ['red', 'blue'] }

		picked = Net::HTTP.get_response URI("http://localhost:#{@port}/picked")
		assert_equal 'red+blue', picked.body
	end

	# A closure with no param runs without the value.
	def test_on_server_read_closure_with_no_param_still_runs
		start_app <<~CODE
		    @load 'lang/server'

		    ran := 'no'

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		read_token  := @on_server_read((; ran = 'yes'))
		    		click_token := @onclick((; 1 ))
		    		"`read_token` `click_token`"
		    	)

		    	get://ran (;
		    		ran
		    	)
		    }

		    app := Web_App()
		CODE

		Net::HTTP.get_response URI("http://localhost:#{@port}/")
		click 'page_-1', { 'page_-0' => 'Buy milk' }

		ran = Net::HTTP.get_response URI("http://localhost:#{@port}/ran")
		assert_equal 'yes', ran.body
	end

	# A Dom input from lang/html.code still gets its `value` member.
	def test_dom_input_still_gets_its_value_on_a_click
		start_app <<~CODE
		    @load 'lang/server'
		    @load 'lang/html'

		    saved := ''

		    Page + Div {
		    	html_id := 'p'

		    	render (;
		    		text := Textarea(key := 'text')
		    		[text, Button('Save', key := 'save', onclick := (; saved = text.value))]
		    	)
		    }

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		Page()
		    	)

		    	get://saved (;
		    		saved
		    	)
		    }

		    app := Web_App()
		CODE

		page = Net::HTTP.get_response URI("http://localhost:#{@port}/")
		assert_includes page.body, "#{Code::DOM_ATTRIBUTE_PREFIX}-on-server-read=\"p-text\""
		assert_includes page.body, "#{Code::DOM_ATTRIBUTE_PREFIX}-onclick=\"p-save\""

		reply = click 'p-save', { 'p-text' => 'Buy milk' }
		assert_equal 'p', reply[Code::DOM_TARGET_ID_HEADER] # the Dom path names the element to replace

		saved = Net::HTTP.get_response URI("http://localhost:#{@port}/saved")
		assert_equal 'Buy milk', saved.body
	end

	def test_server_starts_and_responds
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := #{@port};
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get:// (;
		    		"Hello from Backend!"
		    	)

		    	get://hello/:name ( name;
		    		"<h1>Hello, `name`!</h1>"
		    	)
		    }

		    app := Web_App()
		CODE

		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		# Test GET /
		response = Net::HTTP.get_response URI("http://localhost:#{@port}/")
		assert_equal '200', response.code
		assert_equal 'Hello from Backend!', response.body

		# Test parameterized route
		response = Net::HTTP.get_response URI("http://localhost:#{@port}/hello/World")
		assert_equal '200', response.code
		assert_includes response.body, 'Hello, World!'

		# Test 404
		response = Net::HTTP.get_response URI("http://localhost:#{@port}/nonexistent")
		assert_equal '404', response.code
		assert_includes response.body, 'Not Found'
	end

	# A route matching every segment literally wins over one that leaned on a `:param`, regardless of
	# declaration order. This is what makes `lang/server.code`'s `get://favicon.ico` route actually
	# shield an app's own `get://:id` from the browser's automatic icon probes.
	def test_literal_route_beats_a_param_route_regardless_of_order
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := #{@port};
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get://:id ( id; "dynamic `id`" )
		    	get://favicon.ico (; "the literal one" )
		    }

		    app := Web_App()
		CODE

		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		literal = Net::HTTP.get_response URI("http://localhost:#{@port}/favicon.ico")
		assert_equal '200', literal.code
		assert_equal 'the literal one', literal.body

		# A path with no literal route still reaches the dynamic one.
		dynamic = Net::HTTP.get_response URI("http://localhost:#{@port}/42")
		assert_equal '200', dynamic.code
		assert_equal 'dynamic 42', dynamic.body
	end

	# dom.js began as a Ruby string and still names its cookie `#{BROWSER_VIEW_SIZE}`. Before the server filled that in, the browser set a cookie with that literal name, and no route ever saw the window size.
	def test_window_size_cookie_reaches_a_route
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := #{@port};
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get:// (; "<html><head></head><body>hi</body></html>" )
		    	get://size (; "`browser_view_size.width`x`browser_view_size.height`" )
		    }

		    app := Web_App()
		CODE

		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		page = Net::HTTP.get_response URI("http://localhost:#{@port}/")
		assert_includes page.body, "'#{Code::DOM_BROWSER_VIEW_SIZE}=' + size"
		refute_includes page.body, '#{BROWSER_VIEW_SIZE}'

		size = Net::HTTP.new('localhost', @port).get '/size', 'Cookie' => "#{Code::DOM_BROWSER_VIEW_SIZE}=800x600"
		assert_equal '800x600', size.body
	end

	# The server read dom.js and the other browser assets relative to the working directory, so every HTML page failed with a 500 when `bin/program` started outside `source/`.
	def test_an_html_page_gets_its_scripts_from_any_working_directory
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := #{@port};
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get:// (; "<html><head></head><body>hi</body></html>" )
		    }

		    app := Web_App()
		CODE

		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		Code::Interpreter.cached_asset_source_by_path.clear # an earlier test may have read them from `source/` already
		page = Dir.mktmpdir { |elsewhere| Dir.chdir(elsewhere) { Net::HTTP.get_response URI("http://localhost:#{@port}/") } }

		assert_equal '200', page.code
		assert_includes page.body, "#{Code::DOM_ATTRIBUTE_PREFIX}-onclick" # a line from dom.js
		refute_includes page.body, '#{DOM_ATTRIBUTE_PREFIX}' # the placeholder was filled in
		refute_includes page.body, '#{DOM_TARGET_ID_HEADER}'
		refute_includes page.body, '#{DOM_EVENT_URL}'
	end

	def test_query_parameters
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := #{@port};
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get://search (;
		    		"Query: `request.query`"
		    	)
		    }

		    app := Web_App()
		CODE

		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		response = Net::HTTP.get_response URI("http://localhost:#{@port}/search?q=test&page=1")
		assert_equal '200', response.code
		# The response should contain the query params
		assert_includes response.body, 'q'
	end

	def test_post_route
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := #{@port};
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	post://submit (;
		    		"Form submitted"
		    	)
		    }

		    app := Web_App()
		CODE

		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		uri      = URI("http://localhost:#{@port}/submit")
		response = Net::HTTP.post_form uri, {}
		assert_equal '200', response.code
		assert_equal 'Form submitted', response.body
	end

	# `request.body[:key]` (and even `request.body['key']`) silently missed and returned `nil` --
	# `Code::Dictionary#normalize_dict_key` always converts a subscript key to a Symbol before
	# checking `@hash`, but `body_hash` (from CGI.parse/JSON.parse) is String-keyed, so neither form
	# ever actually matched the one key that was really stored. `query_params`/`url_params` already
	# worked around this same problem by hand (storing each entry under both its String and Symbol
	# form) -- `body_hash`/`headers_hash` didn't get the same treatment. Fixed with a shared
	# `#double_key_with_symbols` helper, applied to both in `#handle_request`.
	def test_request_body_subscript_access
		code = <<~CODE
		    @load 'lang/server'

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	post://submit (;
		    		"symbol: `request.body[:name]`, string: `request.body['name']`"
		    	)
		    }

		    app := Web_App()
		CODE

		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		uri      = URI("http://localhost:#{@port}/submit")
		response = Net::HTTP.post_form uri, { 'name' => 'World' }
		assert_equal '200', response.code
		assert_equal 'symbol: World, string: World', response.body
	end

	# `response.redirect` was completely unreachable: Response is a plain Scope, not a Code::Instance,
	# and #build_prog_response pokes `declarations` directly rather than running the Type's own body
	# on it, so `redirect` (declared in lang/server.code's `Response {}`) never got copied onto the
	# instance -- and the Instance-fallback lookup that would normally rescue that is gated on
	# `is_a?(Code::Instance)`, so it never fired either. Every call raised `Undeclared_Identifier:
	# redirect has not been declared`. Fixed with a real `Code::Response#proxy_redirect` (scopes.rb).
	def test_response_redirect
		code = <<~CODE
		    @load 'lang/server'

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	post://go (;
		    		response.redirect('/landed')
		    	)
		    }

		    app := Web_App()
		CODE

		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		uri            = URI("http://localhost:#{@port}/go")
		http           = Net::HTTP.new uri.host, uri.port
		response       = http.post uri.path, ''
		assert_equal '303', response.code
		assert_equal '/landed', response['Location']
	end

	def test_dialog_and_popover_render_through_a_real_route
		code = <<~CODE
		    @load 'lang/html'

		    Server {
		    	port,
		    	Self ( port := #{@port};
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get:// (;
		    		Div([
		    			Button('Open menu', html_popovertarget := 'menu'),
		    			Div([
		    				Button('Close', html_popovertarget := 'menu', html_popovertargetaction := 'hide')
		    			], html_id := 'menu', html_popover := 'auto'),
		    			Dialog([], html_open := true)
		    		])
		    	)
		    }

		    app := Web_App()
		CODE

		@interpreter    = Code::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner        = server_instance
		@server_runner.port   = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner.routes = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		response = Net::HTTP.get_response URI("http://localhost:#{@port}/")
		assert_equal '200', response.code
		assert_includes response.body, '<dialog open>', 'a real request must render the boolean-true fix as a bare attribute, not open="true"'
		assert_includes response.body, 'popover="auto"', 'popover keeps its real value, not collapsed to bare'
		assert_includes response.body, 'popovertarget="menu"', 'no hyphen -- this is one real HTML attribute, not popover-target'
		assert_includes response.body, 'popovertargetaction="hide"', 'same no-hyphen shape as popovertarget'
	end

	def test_multiple_servers_with_different_routes
		port_a = @port
		port_b = @port + 1

		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port;
		    		self.port = port
		    	)
		    }

		    Server_A + Server {
		    	get://a (;
		    		"Response from Server A"
		    	)
		    }

		    Server_B + Server {
		    	get://b (;
		    		"Response from Server B"
		    	)
		    }

		    a := Server_A(#{port_a})
		    b := Server_B(#{port_b})
		CODE

		interpreter = Code::Interpreter.new
		interpreter.run code

		a_instance = interpreter.stack.first['a']
		b_instance = interpreter.stack.first['b']

		routes_a = interpreter.collect_routes_from_instance a_instance
		routes_b = interpreter.collect_routes_from_instance b_instance

		@server_runner_a        = a_instance
		@server_runner_a.port   = Integer(a_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner_a.routes = routes_a

		@server_runner_b        = b_instance
		@server_runner_b.port   = Integer(b_instance.get(:port) || Code::Server::DEFAULT_PORT)
		@server_runner_b.routes = routes_b

		interpreter.start_server @server_runner_a
		interpreter.start_server @server_runner_b

		# Server A should respond to /a but not /b
		response_a = Net::HTTP.get_response URI("http://localhost:#{port_a}/a")
		assert_equal '200', response_a.code
		assert_equal 'Response from Server A', response_a.body

		response_a_404 = Net::HTTP.get_response URI("http://localhost:#{port_a}/b")
		assert_equal '404', response_a_404.code

		# Server B should respond to /b but not /a
		response_b = Net::HTTP.get_response URI("http://localhost:#{port_b}/b")
		assert_equal '200', response_b.code
		assert_equal 'Response from Server B', response_b.body

		response_b_404 = Net::HTTP.get_response URI("http://localhost:#{port_b}/a")
		assert_equal '404', response_b_404.code

		interpreter.stop_server @server_runner_a
		interpreter.stop_server @server_runner_b
		@server_runner = nil
	end
end
