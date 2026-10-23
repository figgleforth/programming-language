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

	# Sends a click the way live_reload.js does: POST DOM_EVENT_URL/<token>, with the input values as JSON. `path` and `query` name the page the click came from; leave them out to send a click without them.
	def click token, inputs, path: nil, query: nil
		body         = { inputs: inputs }
		body[:path]  = path if path
		body[:query] = query if query
		uri          = URI("http://localhost:#{@port}#{Code::DOM_EVENT_URL}/#{token}")
		request      = Net::HTTP::Post.new uri, 'Content-Type' => 'application/json'
		request.body = JSON.generate body
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

	# The reply is only that HTML, and the header names its root id, so live_reload.js replaces that one element.
	def test_handler_that_returns_html_with_a_root_id_replaces_that_element
		start_app <<~CODE
		    @load 'lang/server'
		    @load 'lang/html2'

		    items := ['a']

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		@onclick((;
		    			items.push('b')
		    			Html_Renderer.render(ul(items.map((it; li(it))), [Attribute('id', 'list')]))
		    		))
		    	)
		    }

		    app := Web_App()
		CODE

		Net::HTTP.get_response URI("http://localhost:#{@port}/")
		reply = click 'page_-0', {}

		assert_equal '200', reply.code
		assert_equal 'list', reply[Code::DOM_TARGET_ID_HEADER]
		assert_equal '<ul id="list"><li>a</li><li>b</li></ul>', reply.body
		assert_equal({ element_namespace: 'static', next_slot: 0 }, @interpreter.render_token_counter)
	end

	# A Dom element from lang/html.code is HTML too. It is rendered once, by #interp_route_body.
	def test_handler_that_returns_a_dom_element_with_an_id_replaces_that_element
		start_app <<~CODE
		    @load 'lang/server'
		    @load 'lang/html'

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		@onclick((; Ul(html_id := 'list') ))
		    	)
		    }

		    app := Web_App()
		CODE

		Net::HTTP.get_response URI("http://localhost:#{@port}/")
		reply = click 'page_-0', {}

		assert_equal 'list', reply[Code::DOM_TARGET_ID_HEADER]
		assert_equal '<ul id="list"></ul>', reply.body
	end

	# A record, a number, or HTML with no id on its root element replaces nothing.
	def test_handler_that_returns_no_html_with_a_root_id_replaces_nothing
		start_app <<~CODE
		    @load 'lang/server'

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		number_token  := @onclick((; 5 ))
		    		no_id_token   := @onclick((; '<li>a</li><li id="b">b</li>' ))
		    		deeper_token  := @onclick((; '<ul><li id="b">b</li></ul>' ))
		    		"`number_token` `no_id_token` `deeper_token`"
		    	)
		    }

		    app := Web_App()
		CODE

		page = Net::HTTP.get_response URI("http://localhost:#{@port}/")
		assert_equal 'page_-0 page_-1 page_-2', page.body

		%w(page_-0 page_-1 page_-2).each do |token|
			assert_nil click(token, {})[Code::DOM_TARGET_ID_HEADER], "#{token} must not replace an element"
		end
	end

	# A handler that returns no HTML with a root id gets the full page back, run again with the new state.
	def test_click_with_no_html_reply_sends_the_full_page_again
		start_app <<~CODE
		    @load 'lang/server'

		    items := []
		    draft := ''

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		read_token  := @on_server_read((value; draft = value))
		    		click_token := @onclick((; items.push(draft)))
		    		"<html><body>`read_token` `click_token` items: `items.join(',')`</body></html>"
		    	)
		    }

		    app := Web_App()
		CODE

		page = Net::HTTP.get_response URI("http://localhost:#{@port}/")
		assert_includes page.body, 'page_-0 page_-1 items: </body>'

		reply = click 'page_-1', { 'page_-0' => 'Buy milk' }, path: '/', query: ''

		assert_equal '200', reply.code
		assert reply.body.start_with?('<!DOCTYPE html>'), 'the reply is a full page'
		assert_includes reply.body, 'page_-0 page_-1 items: Buy milk</body>' # the same tokens, and the new state
		assert_nil reply[Code::DOM_TARGET_ID_HEADER]
	end

	# The page path and query in the click body choose the route that runs again, as a GET.
	def test_click_fallback_runs_the_route_of_the_page_it_came_from
		start_app <<~CODE
		    @load 'lang/server'

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		'the home page'
		    	)

		    	get://tasks/:id (id;
		    		click_token := @onclick((; 1 ))
		    		"<html><body>`click_token` task `id` sort `request.query[:sort]` `request.method`</body></html>"
		    	)
		    }

		    app := Web_App()
		CODE

		page = Net::HTTP.get_response URI("http://localhost:#{@port}/tasks/3?sort=new")
		assert_includes page.body, 'page_tasks_3-0 task 3 sort new'

		reply = click 'page_tasks_3-0', {}, path: '/tasks/3', query: 'sort=new'

		assert_includes reply.body, 'page_tasks_3-0 task 3 sort new get</body>'
	end

	# Without a page path (an old live_reload.js, or a request made by hand), the click still ends in a 404.
	def test_click_without_a_page_path_still_gives_a_404
		start_app <<~CODE
		    @load 'lang/server'

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		@onclick((; 1 ))
		    	)
		    }

		    app := Web_App()
		CODE

		Net::HTTP.get_response URI("http://localhost:#{@port}/")
		assert_equal '404', click('page_-0', {}).code

		# An empty body, or one that is not a JSON object, counts as {}: the handler runs, and the reply is a 404, not a 500.
		['', '[1, 2]', 'not json'].each do |body|
			uri          = URI("http://localhost:#{@port}#{Code::DOM_EVENT_URL}/page_-0")
			request      = Net::HTTP::Post.new uri, 'Content-Type' => 'application/json'
			request.body = body
			reply        = Net::HTTP.start(uri.host, uri.port) { it.request request }
			assert_equal '404', reply.code, "body #{body.inspect}"
		end
	end

	# After a restart the server does not know an open page's tokens. It sends the page again, so the page gets new tokens.
	def test_click_with_an_unknown_token_sends_the_full_page_again
		start_app <<~CODE
		    @load 'lang/server'

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		click_token := @onclick((; 1 ))
		    		"<html><body>`click_token`</body></html>"
		    	)
		    }

		    app := Web_App()
		CODE

		reply = nil
		_, err = capture_subprocess_io do
			reply = click 'page_-999', {}, path: '/'
		end

		assert_equal '200', reply.code
		assert reply.body.start_with?('<!DOCTYPE html>'), 'the reply is a full page'
		assert_includes reply.body, '</style>page_-0</body>' # the page ran again, with a new token
		assert_includes err, 'unknown click token page_-999'

		assert_equal '404', click('page_-999', {}).code, 'without a page path, an unknown token is still a 404'
	end

	# A list page made only of html2 Elements: a textarea that the server reads, a button that adds the text, and a button that adds it and returns only the new list.
	def start_html2_list_app
		start_app <<~CODE
		    @load 'lang/server'
		    @load 'lang/html2'

		    items := []

		    # `draft` is a local of the page function, so the closures must keep it after the function returns.
		    render_list_page (;
		    	draft := ''

		    	Html_Renderer.render(html([
		    		body([
		    			textarea('', on_server_read := (value; draft = value)),
		    			button('Add', onclick := (; items.push(draft))),
		    			button('Add here', onclick := (;
		    				items.push(draft)
		    				Html_Renderer.render(ul(items.map((it; li(it, onclick := (; it)))), [Attribute('id', 'list')]))
		    			)),
		    			ul(items.map((it; li(it))), [Attribute('id', 'list')])
		    		])
		    	]))
		    )

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get:// (;
		    		render_list_page()
		    	)
		    }

		    app := Web_App()
		CODE
	end

	# The tokens that the page's html2 Elements wrote: [the textarea's, the Add button's, the Add here button's].
	def html2_list_page_tokens
		page    = Net::HTTP.get_response URI("http://localhost:#{@port}/")
		prefix  = Code::DOM_ATTRIBUTE_PREFIX
		read    = page.body[/#{prefix}-on-server-read="([^"]+)"/, 1]
		clicks  = page.body.scan(/#{prefix}-onclick="([^"]+)"/).flatten
		[read, *clicks]
	end

	# The Add button's handler returns no HTML, so the reply is the page run again, with the new item.
	def test_html2_page_click_sends_the_full_page_again
		start_html2_list_app
		read_token, add_token, _ = html2_list_page_tokens
		assert_equal %w(page_-0 page_-1), [read_token, add_token]

		reply = click add_token, { read_token => 'Buy milk' }, path: '/', query: ''

		assert_equal '200', reply.code
		assert reply.body.start_with?('<!DOCTYPE html>'), 'the reply is a full page'
		assert_includes reply.body, '<ul id="list"><li>Buy milk</li></ul>'
		assert_nil reply[Code::DOM_TARGET_ID_HEADER]
	end

	# The Add here button's handler returns the list, so the reply is only the list. Its items get tokens inside the clicked token, and the page's own tokens stay.
	def test_html2_page_click_sends_only_the_html_its_handler_returns
		start_html2_list_app
		read_token, _, add_here_token = html2_list_page_tokens

		reply = click add_here_token, { read_token => 'Buy milk' }, path: '/', query: ''

		prefix = Code::DOM_ATTRIBUTE_PREFIX
		assert_equal 'list', reply[Code::DOM_TARGET_ID_HEADER]
		assert_equal "<ul id=\"list\"><li #{prefix}-onclick=\"#{add_here_token}-0\">Buy milk</li></ul>", reply.body
		refute_includes reply.body, '<!DOCTYPE'
		assert @interpreter.dom_onclick_function_handlers.key?(add_here_token), 'the page tokens stay'
		assert @interpreter.dom_onclick_function_handlers.key?("#{add_here_token}-0")
	end

	# A token that no render made, as after a restart: the page runs again and gets new tokens.
	def test_html2_page_click_with_an_unknown_token_sends_the_full_page_again
		start_html2_list_app
		html2_list_page_tokens

		reply = nil
		_, err = capture_subprocess_io do
			reply = click 'page_-999', {}, path: '/', query: ''
		end

		assert_equal '200', reply.code
		assert reply.body.start_with?('<!DOCTYPE html>'), 'the reply is a full page, not a 404'
		assert_includes reply.body, "#{Code::DOM_ATTRIBUTE_PREFIX}-onclick=\"page_-1\""
		assert_includes err, 'unknown click token page_-999'
	end

	# A URL param is text. A typed one gets the text as its type, and text that is not that type gives a 404, not a 500.
	def test_typed_route_params_get_their_type_from_the_url
		start_app <<~CODE
		    @load 'lang/server'

		    Web_App + Server {
		    	Self ( port := #{@port}; self.port = port )

		    	get://int/:id (id: Int;
		    		"`id + 1`"
		    	)

		    	get://float/:x (x: Float;
		    		"`x * 2`"
		    	)

		    	get://number/:n (n: Number;
		    		"`n + 1`"
		    	)

		    	get://bool/:on (on: Bool;
		    		if on 'yes' else 'no' end
		    	)

		    	get://text/:name (name;
		    		"`name`!"
		    	)
		    }

		    app := Web_App()
		CODE

		get = ->(path) { Net::HTTP.get_response URI("http://localhost:#{@port}#{path}") }

		assert_equal '42', get['/int/41'].body
		assert_equal '-1', get['/int/-2'].body
		assert_equal '3.0', get['/float/1.5'].body
		assert_equal '2', get['/number/1'].body
		assert_equal '2.5', get['/number/1.5'].body
		assert_equal 'yes', get['/bool/true'].body
		assert_equal 'no', get['/bool/false'].body
		assert_equal 'abc!', get['/text/abc'].body

		%w(/int/abc /int/1.5 /float/x /number/ten /bool/maybe).each do |path|
			reply = get[path]
			assert_equal '404', reply.code, path
			assert_includes reply.body, 'cannot be converted to', path
		end

		# The text comes from the URL, so it is escaped in the reply.
		reply = get['/int/%3Cscript%3E']
		assert_equal '404', reply.code
		assert_includes reply.body, '&lt;script&gt;'
		refute_includes reply.body, '<script>'
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

	# live_reload.js began as a Ruby string and still names its cookie `#{BROWSER_VIEW_SIZE}`. Before the server filled that in, the browser set a cookie with that literal name, and no route ever saw the window size.
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

	# The server read live_reload.js and the other browser assets relative to the working directory, so every HTML page failed with a 500 when `bin/program` started outside `source/`.
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
		assert_includes page.body, "#{Code::DOM_ATTRIBUTE_PREFIX}-onclick" # a line from live_reload.js
		assert_includes page.body, "var Idiomorph" # loaded before live_reload.js, which calls it
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
