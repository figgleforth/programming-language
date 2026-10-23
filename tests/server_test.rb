require 'minitest/autorun'
require_relative '../ruby/main'
require_relative 'base_test'
require 'net/http'
require 'uri'

class Server_Test < Base_Test
	def test_server_instance_creation
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := 3000;
		    		self.port = port
		    	)
		    }

		    server := Server()
		CODE

		result = Code.interp code
		assert_instance_of Code::Server, result
		assert_equal 3000, result[:port]
	end

	def test_web_app_with_server_composition
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := 3001;
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get:// (;
		    		"Hello World"
		    	)
		    }

		    app := Web_App()
		CODE

		result = Code.interp code
		assert_instance_of Code::Server, result
		assert_equal 3001, result[:port]
	end

	def test_route_defined_in_server_type
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := 3002;
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get://hello (;
		    		"Hi there!"
		    	)

		    	get://users/:id ( id;
		    		"User: `id`"
		    	)
		    }

		    app := Web_App()
		CODE

		interpreter = Code::Interpreter.new
		interpreter.run code

		assert_equal 2, interpreter.route_functions_by_route_name.count
	end

	def test_server_runner_initialization
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := 8888;
		    		self.port = port
		    	)
		    }
		    app := Server()
		CODE

		interpreter     = Code::Interpreter.new
		server_instance = interpreter.run code

		server_instance.port = Integer(server_instance.get(:port) || Code::Server::DEFAULT_PORT)

		assert_equal 8888, server_instance.port
	end

	def test_route_collection
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := 3003;
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get:// (;
		    		"Home"
		    	)

		    	post://submit (;
		    		"Submitted"
		    	)
		    }

		    app := Web_App()
		CODE

		interpreter = Code::Interpreter.new
		interpreter.run code

		assert_equal 2, interpreter.route_functions_by_route_name.count
	end

	def test_route_matching
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := 3004;
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get://users/:id ( id;
		    		"User `id`"
		    	)

		    	get://posts/:post_id/comments/:comment_id ( post_id, comment_id;
		    		"Post `post_id` Comment `comment_id`"
		    	)
		    }

		    app := Web_App()
		CODE

		interpreter     = Code::Interpreter.new
		server_instance = interpreter.run code
		routes          = interpreter.route_functions_by_route_name

		matched = interpreter.match_route 'get', ['users', '123'], routes
		assert matched
		assert_equal 'get', matched.http_method.value

		matched = interpreter.match_route 'get', ['posts', '456', 'comments', '789'], routes
		assert matched
		assert_equal 'get', matched.http_method.value

		matched = interpreter.match_route 'post', ['users', '123'], routes
		assert_nil matched
	end

	def test_url_param_extraction
		code = <<~CODE
		    Server {
		    	port,
		    	Self ( port := 3005;
		    		self.port = port
		    	)
		    }

		    Web_App + Server {
		    	get://users/:user_id/posts/:post_id ( user_id, post_id;
		    		"User `user_id` Post `post_id`"
		    	)
		    }

		    app := Web_App()
		CODE

		interpreter = Code::Interpreter.new
		interpreter.run code
		route      = interpreter.route_functions_by_route_name.values.first
		path_parts = ['users', '42', 'posts', '99']
		url_params = interpreter.extract_url_params path_parts, route

		assert_equal '42', url_params['user_id']
		assert_equal '99', url_params['post_id']
	end

	def test_query_string_parsing
		interpreter  = Code::Interpreter.new
		query_params = interpreter.parse_query_string 'name=John&age=30&city=NYC'

		assert_equal 'John', query_params['name']
		assert_equal '30', query_params['age']
		assert_equal 'NYC', query_params['city']
	end

	def test_query_string_with_url_encoding
		interpreter  = Code::Interpreter.new
		query_params = interpreter.parse_query_string 'message=Hello%20World&special=%21%40%23'

		assert_equal 'Hello World', query_params['message']
		assert_equal '!@#', query_params['special']
	end

	# The browser sends the click body, so Click_Body.parse keeps only what has the right shape.
	def test_click_body_keeps_only_what_has_the_right_shape
		parse = ->(text) { Code::Interpreter::Click_Body.parse text }

		good = parse.('{"inputs": {"a-0": "Buy milk"}, "path": "/tasks/3", "query": "sort=new"}')
		assert_equal({ 'a-0' => 'Buy milk' }, good.inputs)
		assert_equal '/tasks/3', good.path
		assert_equal 'sort=new', good.query

		[nil, '', 'not json', '[1, 2]', '"text"'].each do |text|
			body = parse.(text)
			assert_equal({}, body.inputs, text.inspect)
			assert_nil body.path, text.inspect
			assert_nil body.query, text.inspect
		end

		odd = parse.('{"inputs": [1, 2], "path": "tasks/3", "query": 5}')
		assert_equal({}, odd.inputs)
		assert_nil odd.path, 'a path must start with /'
		assert_nil odd.query
	end
end
