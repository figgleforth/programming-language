require 'json'

module Code
	# A Language Server Protocol server for .code files. It only runs Lexer,
	# Parser, and Declarator, never Interpreter -- an editor opening a file must
	# never trigger a loop, a route, or a database connection.
	#
	# Spec: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
	# Base framing: a 'Content-Length: N' header, a blank line, then N bytes of
	# UTF-8 JSON-RPC 2.0. LSP positions are 0-indexed; this codebase's own
	# Lexeme/Expression positions are 1-indexed (RubyMine's own convention), so
	# every position crosses a +1/-1 boundary right at the edge of this file.
	#
	# Every request handler shares one shape: read params off the request,
	# answer a question against Code.lex/Code.declare output, respond. Also
	# every handler can hit a syntax error mid-keystroke (the file is very
	# often mid-edit and incomplete) -- #handle_message's rescue turns that
	# into "no answer" for the one request, instead of killing the server.
	class Language_Server
		# expr class -> the vocabulary both SymbolKind and CompletionItemKind share; Route_Expr
		# matches the :function case too, since Route_Expr < Func_Expr.
		DECLARATION_KIND = ->(expr) do
			case expr
			when Code::Type_Expr then :class
			when Code::Struct_Expr then :struct
			when Code::Operator_Expr, Code::Operator_Overload_Expr then :operator
			when Code::Func_Expr, Code::Func_Signature_Expr then :function
			end
		end

		SYMBOL_KIND     = { function: 12, class: 5, struct: 23, operator: 25, constant: 14, variable: 13 }.freeze
		COMPLETION_KIND = { function: 3, class: 7, struct: 22, operator: 24, constant: 21, variable: 6, keyword: 14 }.freeze

		KEYWORDS = Code::RESERVED.select { |word| word =~ /\A[a-zA-Z_]+\z/ }.freeze

		def initialize input: $stdin, output: $stdout
			@input     = input
			@output    = output
			@documents = {} # {uri => source text}
			@running   = true
		end

		def run
			@input.binmode
			@output.binmode
			handle_message read_message while @running && !@input.eof?
		end

		private

		# ----- Base protocol (framing) -----

		def read_message
			headers = {}
			while (line = @input.gets "\r\n")
				line = line.chomp "\r\n"
				break if line.empty?
				name, value  = line.split ': ', 2
				headers[name] = value
			end
			JSON.parse @input.read headers['Content-Length'].to_i
		end

		def send_message payload
			json = JSON.generate payload
			@output.write "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
			@output.flush
		end

		def respond id, result
			send_message 'jsonrpc' => '2.0', 'id' => id, 'result' => result
		end

		def notify method, params
			send_message 'jsonrpc' => '2.0', 'method' => method, 'params' => params
		end

		# ----- Dispatch -----

		def handle_message message
			case message['method']
			when 'initialize'              then handle_initialize message
			when 'textDocument/didOpen'    then handle_did_open message
			when 'textDocument/didChange'  then handle_did_change message
			when 'textDocument/definition' then handle_definition message
			when 'textDocument/hover'      then handle_hover message
			when 'textDocument/references' then handle_references message
			when 'textDocument/documentHighlight' then handle_document_highlight message
			when 'textDocument/documentSymbol' then handle_document_symbol message
			when 'textDocument/completion' then handle_completion message
			when 'shutdown'                then respond message['id'], nil
			when 'exit'                    then @running = false
			else
				# 'initialized' and unrecognized notifications need no reply; an
				# unrecognized request still needs one, or the client hangs waiting.
				respond message['id'], nil if message['id']
			end
		rescue StandardError
			# The file is very often mid-edit (a half-typed function, a dangling
			# comma) when a request lands -- answer "nothing found" for just this
			# one request rather than taking the whole server down over it.
			respond message['id'], nil if message['id']
		end

		def handle_initialize message
			respond message['id'], 'capabilities' => {
				'textDocumentSync'          => 1, # Full -- the client resends the whole document text on every change
				'definitionProvider'        => true,
				'hoverProvider'             => true,
				'referencesProvider'        => true,
				'documentHighlightProvider' => true,
				'documentSymbolProvider'    => true,
				'completionProvider'        => {},
			}
		end

		def handle_did_open message
			doc = message.dig 'params', 'textDocument'
			@documents[doc['uri']] = doc['text']
			publish_diagnostics doc['uri']
		end

		def handle_did_change message
			params = message['params']
			uri    = params.dig 'textDocument', 'uri'
			@documents[uri] = params['contentChanges'].last['text']
			publish_diagnostics uri
		end

		# ----- Diagnostics (server-pushed, not a response to a request) -----

		def publish_diagnostics uri
			diagnostics =
				begin
					Code.declare @documents[uri]
					[]
				rescue StandardError => e
					[diagnostic_for(e)]
				end
			notify 'textDocument/publishDiagnostics', 'uri' => uri, 'diagnostics' => diagnostics
		end

		def diagnostic_for error
			expr = error.respond_to?(:expression) ? error.expression : nil
			range = expr.respond_to?(:line_start) && expr.line_start ? range_for(expr) : {
				'start' => { 'line' => 0, 'character' => 0 },
				'end'   => { 'line' => 0, 'character' => 1 },
			}
			{ 'range' => range, 'severity' => 1, 'source' => 'code-lang', 'message' => error.message }
		end

		# ----- textDocument/definition -----

		def handle_definition message
			params = message['params']
			uri    = params.dig 'textDocument', 'uri'
			name   = identifier_at @documents[uri], params['position']
			declaration = name && Code.declare(@documents[uri])[name]

			respond message['id'], declaration ? location_for(uri, declaration.expr) : nil
		end

		# ----- textDocument/hover -----

		def handle_hover message
			params = message['params']
			uri    = params.dig 'textDocument', 'uri'
			source = @documents[uri]
			name   = identifier_at source, params['position']
			declaration = name && Code.declare(source)[name]

			unless declaration
				respond message['id'], nil
				return
			end

			snippet = source_snippet source, declaration.expr
			respond message['id'], 'contents' => { 'kind' => 'markdown', 'value' => "```\n#{snippet}\n```" }
		end

		# ----- textDocument/references -----

		# Not scope-aware -- like Declarator itself, this matches by name only, across
		# every currently open document. Good enough to find "where else does this
		# word show up", not a real "which of these is the same variable" check.
		def handle_references message
			params = message['params']
			uri    = params.dig 'textDocument', 'uri'
			name   = identifier_at @documents[uri], params['position']

			locations = []
			if name
				@documents.each do |doc_uri, source|
					Code.lex(source).each do |lex|
						locations << { 'uri' => doc_uri, 'range' => range_for(lex) } if lex.type == :identifier && lex.value == name
					end
				end
			end

			respond message['id'], locations
		end

		# ----- textDocument/documentHighlight -----

		# The "every occurrence of this name lights up while my cursor sits on it" feature --
		# distinct from references (which opens a panel): this one is scoped to the current
		# file only, and RubyMine calls it constantly in the background as the cursor moves, so
		# it has to answer even when the file doesn't parse (matched by name, same as references).
		def handle_document_highlight message
			params = message['params']
			uri    = params.dig 'textDocument', 'uri'
			name   = identifier_at @documents[uri], params['position']

			highlights = []
			if name
				Code.lex(@documents[uri]).each do |lex|
					highlights << { 'range' => range_for(lex), 'kind' => 1 } if lex.type == :identifier && lex.value == name
				end
			end

			respond message['id'], highlights
		end

		# ----- textDocument/documentSymbol -----

		def handle_document_symbol message
			params = message['params']
			uri    = params.dig 'textDocument', 'uri'
			source = @documents[uri]

			symbols = Code.declare(source).map do |name, declaration|
				kind = SYMBOL_KIND[DECLARATION_KIND[declaration.expr] || (Helpers.constant_identifier?(name) ? :constant : :variable)]
				{ 'name' => name, 'kind' => kind, 'location' => location_for(uri, declaration.expr) }
			end

			respond message['id'], symbols
		end

		# ----- textDocument/completion -----

		def handle_completion message
			params = message['params']
			uri    = params.dig 'textDocument', 'uri'
			source = @documents[uri]

			declared = Code.declare(source).map do |name, declaration|
				kind = COMPLETION_KIND[DECLARATION_KIND[declaration.expr] || (Helpers.constant_identifier?(name) ? :constant : :variable)]
				{ 'label' => name, 'kind' => kind }
			end
			keywords = KEYWORDS.map { |word| { 'label' => word, 'kind' => COMPLETION_KIND[:keyword] } }

			respond message['id'], declared + keywords
		end

		# ----- Shared position helpers -----

		# Scans the flat token stream Lexer already produces, rather than
		# walking the AST -- every Expression subclass nests its children
		# under a different field name, but these commands only need the
		# name under the cursor, not the surrounding expression shape.
		def identifier_at source, position
			line, column = position['line'] + 1, position['character'] + 1
			lexeme = Code.lex(source).find { |lex| lex.line_start == line && column.between?(lex.column_start, lex.column_end) }
			lexeme&.value
		end

		def location_for uri, expr
			{ 'uri' => uri, 'range' => range_for(expr) }
		end

		def range_for span
			{
				'start' => { 'line' => span.line_start - 1, 'character' => span.column_start - 1 },
				'end'   => { 'line' => span.line_end - 1, 'character' => span.column_end - 1 },
			}
		end

		def source_snippet source, expr
			lines = source.lines
			slice = lines[(expr.line_start - 1)..(expr.line_end - 1)].dup
			slice[-1] = slice[-1][0...expr.column_end]
			slice[0]  = slice[0][(expr.column_start - 1)..]
			slice.join.rstrip
		end
	end
end
