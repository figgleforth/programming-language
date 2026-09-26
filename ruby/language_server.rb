require 'json'
require 'uri'

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

		# The legend sent in `initialize` -- each semantic token refers to these by index.
		SEMANTIC_TOKEN_TYPES     = %w(comment string number keyword operator type function variable decorator).freeze
		SEMANTIC_TOKEN_MODIFIERS = %w(readonly).freeze

		def initialize input: $stdin, output: $stdout
			@input     = input
			@output    = output
			@documents = {} # {uri => source text}
			@semantic_tokens_by_uri = {} # {uri => last good semanticTokens data}
			@file_sources_by_path = {} # {path => source} for files read from disk, not open in the editor
			@disk_mtimes          = {} # {path => mtime when first read}
			@declarations_by_uri  = {} # {uri => {source:, declarations:}}
			@asts_by_uri          = {} # {uri => {source:, ast:}} for open documents
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
			when 'textDocument/semanticTokens/full' then handle_semantic_tokens message
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
				'semanticTokensProvider'    => {
					'legend' => { 'tokenTypes' => SEMANTIC_TOKEN_TYPES, 'tokenModifiers' => SEMANTIC_TOKEN_MODIFIERS },
					'full'   => true,
				},
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

		# Answers with every match. More than one only happens for a member name found in several types
		# (`to_s`, `each`) -- both RubyMine and Zed then show a list to pick from.
		def handle_definition message
			params = message['params']
			found  = find_declarations params.dig('textDocument', 'uri'), params['position']

			respond message['id'], found.map { |f| location_for f[:uri], f[:expr] }
		end

		# ----- textDocument/hover -----

		HOVER_MATCH_LIMIT = 3
		HOVER_LINE_LIMIT  = 12

		def handle_hover message
			params = message['params']
			found  = find_declarations(params.dig('textDocument', 'uri'), params['position']).first HOVER_MATCH_LIMIT

			if found.empty?
				respond message['id'], nil
				return
			end

			snippets = found.map do |f|
				lines = source_snippet(f[:source], f[:expr]).lines
				lines = lines.first(HOVER_LINE_LIMIT) + ["\t…\n"] if lines.size > HOVER_LINE_LIMIT
				"```\n#{lines.join.rstrip}\n```"
			end
			respond message['id'], 'contents' => { 'kind' => 'markdown', 'value' => snippets.join("\n---\n") }
		end

		# ----- Finding a declaration -----

		SCOPE_EXPRESSIONS = [Code::Func_Expr, Code::Type_Expr, Code::For_Loop_Expr].freeze # Route_Expr < Func_Expr

		# The name under the cursor, resolved the way the language resolves it:
		# - `x.name` looks only at members -- of the enclosing type for `self.`/`Self.`, of that type for
		#   `Type.name`, and otherwise of every type that has a member called `name`.
		# - A bare name looks outward from the cursor: the params and locals of each enclosing function,
		#   loop, and type, then the file's top level, other open files, and the standard library -- and
		#   last, as a member of any type, for a method called from inside its own type's body.
		# @return [Array<Hash{uri:, expr:, source:}>]
		def find_declarations uri, position
			forget_changed_files
			source  = @documents[uri]
			lexemes = (Code.lex(source) rescue [])
			line, column = position['line'] + 1, position['character'] + 1
			index = lexemes.index { |lex| lex.line_start == line && column.between?(lex.column_start, lex.column_end) }
			return [] unless index && lexemes[index].type.to_s.casecmp?('identifier')

			name   = lexemes[index].value
			scopes = enclosing_scopes uri, source, line, column
			dot    = index > 0 && lexemes[index - 1].type == :operator && lexemes[index - 1].value == '.'

			found = if dot
				member_of_receiver uri, (index > 1 ? lexemes[index - 2] : nil), name, scopes
			else
				find_in_scopes(uri, source, scopes, name) || find_declaration(uri, name)
			end
			found ? [found] : members_named(uri, name)
		end

		# Every function, type, route, and loop whose span holds the cursor, innermost first.
		def enclosing_scopes uri, source, line, column
			scopes = []
			visit  = lambda do |expr|
				next unless expr.is_a?(Code::Expression) && (!span?(expr) || span_holds?(expr, line, column))

				scopes << expr if SCOPE_EXPRESSIONS.any? { |kind| expr.is_a? kind }
				child_expressions(expr).each(&visit)
			end
			ast_for(uri, source).each(&visit)
			scopes.reverse
		end

		# Walks every Expression-valued field, whatever its name -- each Expression subclass names its children differently.
		def child_expressions expr
			expr.instance_variables.flat_map do |ivar|
				value = expr.instance_variable_get ivar
				(value.is_a?(::Array) ? value.flatten : [value]).grep Code::Expression
			end
		end

		def find_in_scopes uri, source, scopes, name
			scopes.each do |scope|
				if scope.is_a?(Code::Func_Expr) && !scope.is_a?(Code::Route_Expr)
					param = scope.parameters&.find { |p| p.name&.value == name }
					return { uri: uri, expr: param, source: source } if param
				end

				declaration = declarations_in_body(scope)[name]
				return { uri: uri, expr: declaration.expr, source: source } if declaration && !load_target_path(declaration.expr)
			end
			nil
		end

		def declarations_in_body scope
			body = case scope
			when Code::Route_Expr    then [scope.expression]
			when Code::Func_Expr     then scope.expressions
			when Code::Type_Expr     then scope.expressions
			when Code::For_Loop_Expr then scope.body
			end
			Code::Declarator.new.declare_all [*body].compact
		rescue StandardError
			{}
		end

		def member_of_receiver uri, receiver, name, scopes
			return nil unless receiver&.type.to_s.casecmp?('identifier')

			type = if %w(self Self).include? receiver.value
				expr = scopes.find { |scope| scope.is_a? Code::Type_Expr }
				expr && { uri: uri, expr: expr, source: @documents[uri] }
			elsif receiver.type == :Identifier
				find_declaration uri, receiver.value
			end
			return nil unless type && type[:expr].is_a?(Code::Type_Expr)

			member = declarations_in_body(type[:expr])[name]
			member && { uri: type[:uri], expr: member.expr, source: type[:source] }
		end

		# A member called `name` in any type declared in the open files, the files they `@load`, and the standard library.
		def members_named uri, name
			found = []
			each_reachable_file uri do |doc_uri, source|
				declarations_for(doc_uri, source).each_value do |declaration|
					next unless declaration.expr.is_a?(Code::Type_Expr) && declaration.expr_or_decl.is_a?(::Hash)

					member = declaration.expr_or_decl[name]
					found << { uri: doc_uri, expr: member.expr, source: source } if member.is_a? Code::Declaration
				end
			end
			found.uniq { |f| [f[:uri], f[:expr].line_start, f[:expr].column_start] }
		end

		def each_reachable_file uri
			queue   = [uri, *(@documents.keys - [uri])].map { |doc_uri| [doc_uri, @documents[doc_uri]] }
			queue  << [file_uri(Code::STANDARD_LIBRARY_PATH), file_source(Code::STANDARD_LIBRARY_PATH)]
			visited = ::Set.new

			while (entry = queue.shift)
				doc_uri, source = entry
				next unless source && visited.add?(doc_uri)

				yield doc_uri, source
				declarations_for(doc_uri, source).each_value.map(&:expr).uniq(&:object_id).each do |expr|
					path = load_target_path expr
					queue << [file_uri(path), file_source(path)] if path
				end
			end
		end

		# Looks in the current document first, then every other open document, then the standard
		# library (which every program loads implicitly). A name a file brings in through `@load` is
		# followed into the loaded file, so the answer is where the name is really declared.
		# @return [Hash{uri:, expr:, source:}, nil]
		def find_declaration uri, name
			candidates = [uri, *(@documents.keys - [uri])].map { |doc_uri| [doc_uri, @documents[doc_uri]] }
			candidates << [file_uri(Code::STANDARD_LIBRARY_PATH), file_source(Code::STANDARD_LIBRARY_PATH)]

			candidates.each do |doc_uri, source|
				found = find_declaration_in doc_uri, source, name, ::Set.new
				return found if found
			end
			nil
		end

		def find_declaration_in uri, source, name, visited
			return nil unless source && visited.add?(uri)

			declaration = declarations_for(uri, source)[name]
			return nil unless declaration

			expr = declaration.expr
			if (path = load_target_path expr)
				found = find_declaration_in file_uri(path), file_source(path), name, visited
				return found if found
			end

			{ uri: uri, expr: expr, source: source }
		end

		# The resolved file path when `expr` is a bare `@load 'file'`, else nil.
		def load_target_path expr
			return nil unless expr.is_a?(Code::Call_Expr) && Code::Declarator.new.load_call?(expr) && expr.arguments&.first.is_a?(Code::String_Expr)

			Code::Declarator.resolve_load_filepath expr.arguments.first.value
		end

		# Code.parse output for an open document, reused until the text changes.
		def ast_for uri, source
			cached = @asts_by_uri[uri]
			return cached[:ast] if cached && cached[:source] == source

			ast = (Code.parse(source) rescue [])
			@asts_by_uri[uri] = { source: source, ast: ast }
			ast
		end

		def span? expr
			expr.respond_to?(:line_start) && expr.line_start && expr.line_end
		end

		def span_holds? expr, line, column
			([line, column] <=> [expr.line_start, expr.column_start]) >= 0 && ([line, column] <=> [expr.line_end, expr.column_end]) <= 0
		end

		# Code.declare output, reused until the text changes -- hover asks again every time the mouse rests on a word.
		def declarations_for uri, source
			cached = @declarations_by_uri[uri]
			return cached[:declarations] if cached && cached[:source] == source

			declarations = (Code.declare(source) rescue {})
			@declarations_by_uri[uri] = { source: source, declarations: declarations }
			declarations
		end

		def file_uri path
			URI::File.build(path: path).to_s
		end

		# The editor's unsaved text when the file is open, else the file on disk.
		def file_source path
			@documents[file_uri(path)] || (@file_sources_by_path[path] ||= ::File.read(path))
		rescue SystemCallError
			nil
		end

		# Declarator's own per-path cache never expires, and a changed file on disk can add or remove a name
		# that a cached `global.code` lookup would never see -- so any change drops every file-based cache.
		def forget_changed_files
			paths   = Code::Declarator.cached_declarations_by_filepath.keys | @file_sources_by_path.keys
			changed = paths.any? do |path|
				mtime = (::File.mtime(path) rescue nil)
				next @disk_mtimes[path] != mtime if @disk_mtimes.key? path

				@disk_mtimes[path] = mtime
				false
			end
			return unless changed

			Code::Declarator.reset_cached_by_path!
			@file_sources_by_path.clear
			@disk_mtimes.clear
			@declarations_by_uri.clear
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

		# ----- textDocument/semanticTokens/full -----

		# Syntax highlighting, driven by the real Lexer, so the colors always match the language. Like
		# documentHighlight, it needs only Code.lex, not a parse, so a file that does not parse still gets colors.
		def handle_semantic_tokens message
			uri    = message.dig 'params', 'textDocument', 'uri'
			source = @documents[uri]
			lexemes =
				begin
					Code.lex source
				rescue StandardError
					# Mid-edit input the Lexer rejects (an unclosed string) keeps the last good colors, instead of blanking the file.
					respond message['id'], 'data' => @semantic_tokens_by_uri.fetch(uri, [])
					return
				end
			tokens = [] # [first lexeme, last lexeme, type, modifier]
			skip    = false

			lexemes.each_with_index do |lex, i|
				if skip
					skip = false
					next
				end
				prev, nxt = (i > 0 ? lexemes[i - 1] : nil), lexemes[i + 1]

				# `:sym` and `@load` lex as two tokens each -- color the pair as one when nothing separates them.
				if lex.type == :operator && %w(: @).include?(lex.value) && nxt&.type.to_s.casecmp?('identifier') && adjacent?(lex, nxt) && !(prev && prev.type != :delimiter && adjacent?(prev, lex))
					type = lex.value == ':' ? 'string' : nxt.value == 'load' ? 'keyword' : 'decorator'
					tokens << [lex, nxt, type, nil]
					skip = true
					next
				end

				type, modifier = semantic_token_type lex, nxt
				tokens << [lex, lex, type, modifier] if type
			end

			data = []
			prev_line = prev_start = 0
			tokens.each do |first, last, type, modifier|
				token_lines(source, first, last).each do |line, start, length|
					next if length <= 0
					data.push line - prev_line, line == prev_line ? start - prev_start : start, length,
						SEMANTIC_TOKEN_TYPES.index(type), modifier ? 1 << SEMANTIC_TOKEN_MODIFIERS.index(modifier) : 0
					prev_line, prev_start = line, start
				end
			end

			@semantic_tokens_by_uri[uri] = data
			respond message['id'], 'data' => data
		end

		def semantic_token_type lex, nxt
			case lex.type
			when :comment                 then 'comment'
			when :string, :html, :fence, :route then 'string'
			when :number, :scientific_notation, :binary, :hexadecimal then 'number'
			when :operator                then lex.value =~ /\A[a-z]+\z/ ? 'keyword' : 'operator'
			when :IDENTIFIER              then ['variable', 'readonly']
			when :Identifier              then lex.reserved ? 'keyword' : 'type'
			when :identifier
				if lex.reserved then 'keyword'
				elsif nxt&.type == :delimiter && nxt.value == '(' then 'function'
				end
			end
		end

		def adjacent? left, right
			left.line_end == right.line_start && left.column_end + 1 == right.column_start
		end

		# LSP semantic tokens cannot cross a line break, so a multi-line comment, string, or fence
		# splits into one [line, start, length] piece per line (0-indexed, like every LSP position).
		def token_lines source, first, last
			lines = source.lines.map { |line| line.chomp.length }
			(first.line_start..last.line_end).map do |line|
				start  = line == first.line_start ? first.column_start - 1 : 0
				finish = line == last.line_end ? last.column_end : lines[line - 1].to_i
				[line - 1, start, [finish, lines[line - 1].to_i].min - start]
			end
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
