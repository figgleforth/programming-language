require 'debug'

# !!! this is just a shortcut for testing how it feels to work with custom operators without writing an official construct for this.
# copied here for convenience
# [1000, %w(>!!! >!! >! ./ ../ .../)],
# [380, %w([ _ __ @ . .@ , ])],
# [360, %w(< <= > >= == != === !== ** )],
# [340, %w(** * / %)],
# [320, %w(- +)],
# [300, %w(!! ? ??)],
# [280, %w(<< >>)],
# [260, %w(&)],
# [240, %w(^)],
# [220, %w(|)],
# [200, %w(&& || and or)],
# [180, %w()],
# [160, %w(++ --)],
# [140, %w(:)],
# [120, %w(= += -= *= /= %= &= |= ^= <<= >>=)],
# [100, %w[ ( , ) ]],
# [80, %w(.? .. .< >. >< !)],
Custom_Operator_Test = {
                          'by' => 200, # like *
                          'into' => 340, # like /
                          # ':' => 380, # todo breaks hashes. I wanna figure this out, see thoughts/operators.md
                       }.freeze


class Parser
	require_relative '../lexer/tokens'
	require_relative 'exprs'

	attr_accessor :i, :buffer, :source, :expressions, :eaten_this_iteration

	STARTING_PRECEDENCE   = 0
	SCOPE_PORTAL_SYMBOL   = '#'.freeze # character tbd!
	SCOPE_IDENTITY_SYMBOL = '@'.freeze # character tbd!
	DEBUG_SYMBOL = '—'.freeze

	def initialize buffer = [], source_code = ''
		@i                    = 0 # index of current token
		@buffer               = buffer
		@source               = source_code
		@expressions          = []
		@eaten_this_iteration = []
	end

	def to_expr
		@expressions = parse_until(EOF_Token)
	end

	def source_substring_for_token token, range
		start_pos = [token.start_index - range.begin, 0].max
		end_pos   = [token.end_index + range.end, source.length].min
		source[start_pos..end_pos] || ''
	end

	def eaten_this_iteration
		@eaten_this_iteration || []
	end

	# region Parsing Helpers

	def debug
		%Q(#{DEBUG_SYMBOL * 8} DEBUG INFO #{DEBUG_SYMBOL * 23}
#{DEBUG_SYMBOL * 8} PREVIOUS TOKEN #{DEBUG_SYMBOL * 23}
#{prev.inspect}
#{DEBUG_SYMBOL * 8} CURRENT TOKEN #{DEBUG_SYMBOL * 23}
#{curr.inspect}
#{DEBUG_SYMBOL * 8} NEXT TOKEN #{DEBUG_SYMBOL * 23}
#{peek(1).inspect}
#{DEBUG_SYMBOL * 8} LAST 5 EXPRESSIONS #{DEBUG_SYMBOL * 23}
#{expressions[-5..]&.map(&:inspect)}
#{DEBUG_SYMBOL * 23})
	end

	# buffer[i - 1]
	def prev
		buffer[[i - 1, 0].max]
	end

	# buffer[i]
	def curr
		buffer[i]
	end

	# buffer[i..]
	def remainder
		buffer[i..]
	end

	# whether there are tokens remaining to be parsed
	def tokens?
		i < (buffer&.length || 0)
	end

	def eat_past_deadspace
		eat while curr? %W(\n \r \s \t)
	end

	# looks at token without eating, can look backwards as well but peek index is clamped to buffer. if accumulated, returns an array of tokens. otherwise returns a single token
	def peek ahead = 0
		raise 'Parser.buffer is nil' unless buffer

		index = ahead.clamp(0, buffer.count)
		buffer[i + index]
	end

	# slices buffer until specified token, so it isn't included in the result. doesn't actually consume the buffer, you still have to do that by calling eat. easier to iterate this than fuck with the actual pointer in the buffer
	def peek_until token = "\n"
		remainder.slice_before do |t|
			t == token
		end.to_a.first
	end

	# uses peek_until to get count of tokens until specified token, then adds that count to the buffer pointer @i
	def eat_until token = "\n"
		@i += peek_until(token).count
	end

	# checks whether the remainder buffer contains the exact sequence of tokens. if one of the arguments is an array then that token in the sequence can be any one in the array. eg:
	#   curr? Identifier_Token, [=, ≠, :=, =;] will trigger whenever any of the 4 in the array come after the identifier.
	#   curr? Identifier_Token, '{' will trigger on exactly this, not either or
	def curr? * sequence
		remainder.slice(0, sequence.count).each_with_index.all? do |token, index|
			if sequence[index].is_a? Array
				sequence[index].any? do |sequence_element|
					if sequence_element.is_a? Symbol
						token.isa sequence_element.to_s
					else
						token.isa sequence_element
					end
				end
			else
				if sequence[index].is_a? Symbol
					token.isa sequence[index].to_s
				else
					token.isa sequence[index]
				end
			end
		end
	end

	# eats a specific sequence of tokens, either Token class or exact string. eg: eat StringLiteralToken, eat '.'. etc
	# idea: support sequence of elements where an element can be one of many, like the sequence [IdentifierToken, [:=, =]]
	def eat * sequence
		if curr? EOF_Token
			raise "#eat expected #{sequence.inspect} but got EOF at #{curr.inspect}, prev: #{prev.inspect}\n\nexprs #{expressions}"
		end
		if sequence.nil? || sequence.empty? || sequence.one?
			eaten = curr
			if sequence&.one? && !(eaten.isa sequence[0]) # eaten != sequence[0]
				extra = 25..0
				code  = source_substring_for_token(eaten, extra)
				parts = code.split "\n"
				caret = parts.last_char.tap {
					_1 << "\n\t#{' ' * (curr.column - 1)}^"
				}

				raise "#eat(#{sequence[0].inspect}) got #{eaten.string.inspect})\n#{caret}, at #{curr.inspect}, prev #{prev.inspect}"
			end
			@i    += 1
			eaten_this_iteration << eaten
			return eaten
		end

		[].tap do |result|
			# Usage:
			#   sequence =
			#     eat '}'
			#     eat %w(} end)
			sequence.each do |expected|
				unless curr.isa expected
					current   = "\n\nExpected #{expected} but got #{curr}"
					remaining = "\n\nREMAINING:\n\t#{remainder.map(&:to_s)}"
					progress  = "\n\nPARSED SO FAR:\n\t#{expressions[3..]}"
					raise "#{current}#{remaining}#{progress}" unless curr.isa expected
				end

				eaten = curr
				result << eaten
				eaten_this_iteration << eaten
				@i += 1
			end
		end
	end

	# endregion

	# region Sequence Parsing

	def class_ident?
		curr?(Identifier_Token) && curr.class?
	end

	def member_ident?
		curr?(Identifier_Token) && curr.member?
	end

	def constant_ident?
		curr?(Identifier_Token) && curr.constant?
	end

	def parse_block until_token = '}', starting_precedence = STARTING_PRECEDENCE, skip_inline_funcs = false
		Func_Expr.new.tap do |it|
			it.expressions = parse_until until_token, starting_precedence, skip_inline_funcs
		end
	end

	def make_string_or_number_literal_expr
		if curr == String_Token
			String_Literal_Expr.new
		else
			Number_Literal_Expr.new
		end.tap do |it|
			it.string = eat.string
		end
	end

	def make_class_composition_expr
		Class_Composition_Expr.new.tap do
			_1.operator   = eat # > + - # * & ~
			_1.expression = make_expr

			if curr?('as') && curr?(Identifier_Token)
				eat # as
				_1.alias_identifier = eat # you can alias compositions as symbols too
			end
		end
	end

	def make_array_of_param_decls
		[].tap do |params|
			start = curr
			# (label) (@) ident (= expr)
			until curr? ';'
				params << Func_Param_Decl.new.tap do
					if curr? SCOPE_PORTAL_SYMBOL and eat SCOPE_PORTAL_SYMBOL
						_1.portal = true
					end

					if curr?(Identifier_Token, Identifier_Token)
						_1.label = eat Identifier_Token
					end

					_1.name = eat Identifier_Token # ate ; a Key_Operator_Token as if it's an Identifier_Token

					if curr? '=' and eat '='
						_1.default = make_expr(STARTING_PRECEDENCE, true)
					end

					if curr? ','
						eat ','
					end

					eat_past_deadspace

					# if not curr? ';'
					# 	raise "Malformed Param_Decl starting at #{start.location_in_source}\n\n\tcurr: #{curr.inspect}\n\n"
					# end
				end
			end
		end
	end

	def make_conditional_expr is_while_conditional = false
		klass = if is_while_conditional
			While_Expr
		else
			Conditional_Expr
		end
		klass.new.tap do |it|
			eat if curr? %w(if while)

			if curr? Identifier_Token, '{'
				identifier   = eat Identifier_Token
				it.condition = Identifier_Expr.new.tap do |id|
					id.string = identifier
				end
				eat '{'
			else
				potential = make_expr
				if potential.is_a? Func_Decl
					it.condition = Identifier_Expr.new.tap do |id|
						id.string = potential.name
					end
				elsif potential.is_a?(Infix_Expr) && potential.operator == '.' && potential.right.is_a?(Func_Decl)
					it.condition = Identifier_Expr.new.tap do |id|
						id.string = potential.right.name
					end
				else
					it.condition = potential
				end

				eat '{' if curr? '{'
			end

			eat_past_deadspace
			it.when_true = parse_block %w(} end else elsif elif ef elswhile)

			if curr? 'else'
				eat 'else'
				it.when_false = parse_block %w(} end)
				eat if curr? %w(} end)
			elsif curr? %w(} end)
				eat if curr? %w(} end)
			elsif curr? %w(elsif elif elswhile elwhile)
				while curr? %w(elsif elif elswhile elwhile)
					eat # elsif or elif
					raise 'Expected condition in the elsif' if curr? "\n" or curr? ';' or curr? '}'
					it.when_false = make_conditional_expr is_while_conditional
				end
			else
				raise "\n\nYou messed your if/elsif/else up\n" + debug
			end
		end
	end

	def make_while_expr
		While_Expr.new.tap do |it|
			eat 'while' if curr? 'while'
			it.condition = parse_block("\n").expressions[0]
			it.when_true = parse_block %w(elswhile else })

			if curr? 'else'
				eat 'else'
				it.when_false = parse_block '}'
				eat '}'
			elsif curr? '}'
				eat '}'
			elsif curr? 'elswhile'
				while curr? 'elswhile'
					eat # elswhile
					raise 'Expected condition in the elswhile' if curr? "\n" or curr? ";"
					it.when_false = make_while_expr
				end
			else
				raise "\n\nYou messed your while/elswhile/else up\n" + debug
			end
		end
	end

	def make_hash_expr
		# { expr : expr , }
		Hash_Expr.new.tap {
			eat '{'
			eat_past_deadspace

			while tokens? && !curr?('}')
				_1.keys << make_expr
				if curr? ':' and eat ':' # ??? consider allowing additional operators
					eat_past_deadspace
					_1.values << make_expr
				else
					raise "Hash expected : to complete the expression for key #{_1.keys.last.inspect}\n\nbut got #{curr.inspect}\n\nat #{curr.line}:#{curr.column}"
				end

				eat if curr? ','
				eat_past_deadspace
			end

			eat '}'
		}
	end

	def make_array_expr
		# [ expr , ]
		Array_Expr.new.tap {
			eat '['
			if curr? ']' and eat ']'
				return _1
			end

			while tokens? && !curr?(']')
				_1.elements << make_expr
				puts "ate array expr elements #{_1.elements.inspect}, curr #{curr.inspect}"
				break if curr? ']'
				eat ',' if curr? ','
				eat_past_deadspace
			end
			eat ']'
		}
	end

	def make_operator_overload_expr
		raise 'Operator overloading not implemented in Parser'
	end

	def make_circumfix_expr opening = '(' # the option for other types of groupings is there, but right now I'm only using ( because other cases are already handled.
		Circumfix_Expr.new.tap {
			_1.grouping = case opening
				when '('
					'()'
				when '{'
					'{}'
				when '['
					'[]'
				else
					raise "#make_circumfix_expr unknown opening #{opening}"
			end

			eat opening
			closing = _1.grouping[1]

			until curr? closing
				_1.expressions << make_expr(precedence_for(opening))
				break if curr? closing

				eat ','
				eat_past_deadspace
			end

			eat closing

		}
	end

	def peek_until_contains? until_token, contains
		peek_until(until_token).any? do
			_1 == contains or _1 === contains
		end
	end

=begin
todo switch to a hash instead of the nested arrays
precs = { 1000 => %w(>!!! >!! '>!' @),
  400  => %w[( )],
  380  => %w([ ]),
  360  => %w(< <= > >= == != === !== **),
  340  => %w(** * / %),
  320  => %w(- +),
  300  => %w(!! ? ??),
  280  => %w(<< >>),
  260  => %w(&),
  240  => %w(^),
  220  => %w(|),
  200  => %w(&& || and or),
  180  => %w(),
  160  => %w(++ --),
  140  => %w(: .),
  120  => %w(= += -= *= /= %= &= |= ^= <<= >>=),
  100  => %w(,),
  80   => %w(.? .. .< >. >< !) }
=end

	# Array of precedences and symbols for that precedence. if the token provided matches one of the operator symbols then its precedence is returned. Nice reference: https://rosettacode.org/wiki/Operator_precedence
	def precedence_for token
		# mess
		# todo I actually am not sure about these precedences. I mean, I understand the recursion and the concept, but I haven't thought about the precs of these operators. I should probably do that.
		# todo what does tight/loose binding even mean? I want better documentation for how this works.
		[

		   # binds tightly
		   [1000, %w(>!!! >!! >! ./ ../ .../)],
		   # [400, %w(( ))],
		   [380, %w([ _ __ @ . .@ , ])],
		   [360, %w(< <= > >= == != === !== ** )],
		   [340, %w(* / %)],
		   [320, %w(- +)],
		   [300, %w(!! ? ??)],
		   [280, %w(<< >>)],
		   [260, %w(&)],
		   [240, %w(^)],
		   [220, %w(|)],
		   [200, %w(&& || and or)],
		   [180, %w()],
		   [160, %w(++ --)],
		   [140, %w(:)],
		   [120, %w(= += -= *= /= %= &= |= ^= <<= >>=)],
		   # [100, %w(,)],
		   [100, %w[ ( , ) ]],
		   [80, %w(.? .. .< >. >< !)],
		   # binds loosely
		].find do |_, chars|
			str = if token.is_a? Token
				token.string
			else
				token
			end

			chars.sort_by! { -_1.length }.include?(str)
		end&.first || STARTING_PRECEDENCE
	end

	def make_expr starting_precedence = STARTING_PRECEDENCE, skip_inline_funcs = false
		# todo Operator_Decl    operator *fix == { left/right/both ; }
		# todo Route_Decl       "/users/:id" users_route { id ; }

		expr = \
		   if curr?('{') && peek_until_contains?('}', ';') # { ; }
			   Func_Expr.new.tap {
				   eat '{'

				   arrowed = peek_until_contains? '}', ';'
				   eat_past_deadspace

				   if arrowed
					   _1.parameters = make_array_of_param_decls
					   eat_past_deadspace
					   eat ';'
					   eat_past_deadspace
				   end

				   _1.expressions = parse_block.expressions
				   eat '}'
			   }

		   elsif curr? '{' # hash or
			   make_hash_expr

		   elsif curr? '['
			   make_array_expr

		   elsif (class_ident? or constant_ident?) && (curr?(Identifier_Token, '{') or curr?(Identifier_Token, '>') or curr?(Identifier_Token, '+'))
			   Class_Decl.new.tap do
				   _1.name = eat(Identifier_Token)

				   # comp_types     = %i(> & ~ + -)
				   # curr_comp_type = nil
				   # until curr? '{'
				   # todo implement composition
				   # end

				   if curr? '>' and eat '>'
					   raise 'Parent must be a Class' unless curr.class?
					   _1.base_class = eat(Identifier_Token)
				   end

				   if curr? '&' and eat '&'
					   until curr? '{'
						   eat_past_deadspace
						   _1.compositions << eat(Identifier_Token)
						   eat ',' if curr? ','
					   end
				   end

				   eat '{'
				   eat_past_deadspace

				   _1.expressions = parse_until '}', starting_precedence, skip_inline_funcs
				   eat '}'
			   end
		   elsif member_ident? && curr?(Identifier_Token, '{')
			   Func_Decl.new.tap { # :name < Func_Expr :expressions, :compositions, :parameters, :signature
				   _1.name = eat(Identifier_Token)
				   eat '{'
				   eat_past_deadspace

				   unless curr? ';'
					   _1.parameters = make_array_of_param_decls
					   eat_past_deadspace
				   end

				   eat ';'
				   eat_past_deadspace

				   _1.expressions = parse_block.expressions
				   eat '}'
			   }

		   elsif curr? 'operator'
			   types = %w(prefix infix postfix circumfix) # ??? this was declared a while ago, but it doesn't appear to be used.
			   Operator_Decl.new.tap do
				   eat 'operator'

				   unless curr? types
					   raise "Operator declaration #{curr.string} must be one of #{types}"
				   end

				   _1.fix  = eat Identifier_Token
				   _1.name = eat

				   eat '{'
				   eat_past_deadspace

				   if not curr? ';'
					   _1.parameters = make_array_of_param_decls
					   eat_past_deadspace
				   end

				   eat ';'
				   eat_past_deadspace

				   _1.expressions = parse_block.expressions
				   eat '}'

				   # eat '{'
				   #
				   # arrowed = peek_until_contains? '}', ';'
				   # eat_past_deadspace
				   #
				   # if arrowed
				   #   _1.parameters = make_array_of_param_decls
				   #   eat_past_deadspace
				   #   eat ';'
				   #   eat_past_deadspace
				   # end
				   #
				   # _1.expressions = parse_block.expressions
				   # eat '}'
			   end

		   elsif curr? '('
			   make_circumfix_expr '('

		   elsif curr? 'return'
			   Return_Expr.new.tap do |it|
				   eat # >> or return
				   it.expression = make_expr
			   end

		   elsif curr? 'while'
			   make_conditional_expr true

		   elsif curr? 'if'
			   make_conditional_expr

			   # elsif curr? Key_Identifier_Token && curr == 'operator'
			   # 	make_operator_overload_expr

		   elsif curr?(Key_Identifier_Token) && curr == 'raise'
			   Raise_Expr.new.tap {
				   # mess
				   # :name, :condition, :message_expression
				   _1.name       = eat(Key_Identifier_Token).string
				   _1.expression = if not curr? Delimiter_Token # curr? %w(, ; \n })
					   make_expr
				   end
			   }

			   # elsif %w(> + -).include? curr && peek(1) == Identifier_Token && peek(1).member?
			   #   raise 'Cannot compose a class with members, only other classes and enums'

			   # todo you should be able to assign different types to each other.
			   # YAY: member = member/Class/CONSTANT, CONSTANT = CONSTANT, Class = Class.
			   # NAY: Class = member, Class = CONSTANT

			   # elsif curr? Word_Token, ';'
			   #   Func_Decl.new.tap {
			   # 	  _1.name = eat Word_Token
			   # 	  eat ';'
			   # 	  _1.expressions = [make_expr]
			   #   }

		   elsif curr? String_Token or curr? Number_Token
			   make_string_or_number_literal_expr

		   elsif curr? Comment_Token
			   # xxx backticked comments
			   eat and nil

		   elsif curr? Delimiter_Token
			   eat and nil

		   elsif curr? Key_Identifier_Token
			   Key_Identifier_Expr.new.tap {
				   _1.token  = eat Key_Identifier_Token
				   _1.string = _1.token.string
			   }

		   elsif curr? Identifier_Token
			   Identifier_Expr.new.tap {
				   _1.token  = eat Identifier_Token
				   _1.string = _1.token.string
			   }
		   elsif curr?(Identifier_Token) && Custom_Operator_Test.key?(curr.string)
			   Operator_Expr.new.tap {
				   _1.token  = eat Identifier_Token
				   _1.string = _1.token.string
			   }

		   elsif curr? Operator_Token
			   Operator_Expr.new.tap {
				   _1.token  = eat Operator_Token
				   _1.string = _1.token.string
			   }

		   elsif curr? EOF_Token
			   raise "got an EOF. Probably means a previous #make_expr call did not complete correctly. Normally, the #parse_until calls #make_expr in a loop, and it would catch the EOF instead of calling #make_expr with it."
		   else
			   raise "Parsing not implemented for #{curr.inspect}"
		   end

		augment_expr expr, starting_precedence, skip_inline_funcs
	end

	# eg. calling subject if () is next instead of a delimiter
	# eg. transforming subject into a binary expression
	# !!! if the next token is a conditional then you can turn the last expression into that.
	# !!! we can infer a grouped expression here without the groupings. If a comma is next, then group the expressions until the next newline. Later when this expression is evaluated, it gets evaluated as a group together.
	# !!! this also allows passing block to any expression. Originally that was going to be the .{ operator, but this is much simpler. If there's no delimiter between the last expression and { then it's a block being passed to the expression. Remember, that any class or function bodies with {} would already have been parsed into `ast` at this point. I guess the original .{ will also work since it would be parsed into a "dot {}" binary expression in #make_binary_expr_or_dont
	# ??? In what other ways can the expression be augmented here?
	# Given a freshly parsed expression, transform it into another expression if needed
	# eg. [expr, ()] becomes Call_Expr
	# eg. [expr, if/unless/while/until] becomes Conditional_Expr
	def augment_expr expr, starting_prec, skip_inline_funcs = false
		return expr if curr? "\n" or not expr

		# !!! custom operators. should check: expr == custom prefix op; curr == custom infix or postfix op
		if curr?(Identifier_Token) && Custom_Operator_Test.key?(curr.string)
			expr = Infix_Expr.new.tap {
				_1.left     = expr
				_1.operator = eat

				# !!! precedence lookup hack
				next_prec = Custom_Operator_Test[_1.operator.string]
				_1.right  = make_expr(next_prec)
				unless _1.right
					raise "Infix_Expr expected an expression after `#{_1.operator.string}`"
				end
			}
			return augment_expr expr, starting_prec, skip_inline_funcs
		end

		# !!! ignoring inline functions is a way of preventing [Identifier, ;] from being parsed as an inline function. This is needed in places like param declarations [{, Identifier, Identifier, ;]
		if !skip_inline_funcs && expr === Identifier_Expr && curr?(';')
			decl = Func_Decl.new.tap {
				_1.name = expr
				eat ';'
				_1.expressions = [make_expr]
			}

			return augment_expr decl, starting_prec, skip_inline_funcs
		end

		return expr if curr? %w(; :)

		postfix = curr?(Operator_Token) && (curr.respond_to?(:postfix?) && curr.postfix?) # xxx also check for user-declared postfix operators

		prefix = expr.is_a?(Operator_Expr) && (expr.token.respond_to?(:prefix?) && expr.token.prefix?) # xxx also check for user-declared prefix operators

		if prefix
			if expr.string == SCOPE_IDENTITY_SYMBOL && curr == '.' # manual handling of @. to just eat over the dot to make @.member behave like @member
				eat
			end

			expr = Prefix_Expr.new.tap {
				_1.operator   = expr
				_1.expression = make_expr precedence_for(expr.string)
			}

			unless expr.expression
				raise "Prefixed_Expr expected an expression after `#{expr.operator}`"
			end

			return augment_expr expr, starting_prec, skip_inline_funcs
		elsif postfix
			# !!! if this causes problems with order of operations, it would likely be for the same reason Prefixed_Expr did, and that was because I needed to prevent the next expression from grouping itself into the prefixed expression by adding a starting precedence to the make_expr call
			expr = Postfix_Expr.new.tap {
				_1.expression = expr
				_1.operator   = make_expr
			}
			return augment_expr expr, starting_prec, skip_inline_funcs
		end

		if curr? '(' and eat '('
			expr = Call_Expr.new.tap do
				# :receiver, :arguments
				_1.receiver  = expr
				_1.arguments = []

				until curr? ')'
					_1.arguments << Call_Arg_Expr.new.tap do |arg|
						if curr? Identifier_Token, ':' #, Token
							arg.label = eat Identifier_Token
							eat ':'
						end

						arg.expression = make_expr
					end

					eat if curr? ','
				end

				eat ')'
			end

			return augment_expr expr, starting_prec, skip_inline_funcs
		end

		# xxx any custom operator can be binary if it's declared to be. I don't have syntax for that yet, but this is where that check might go.
		# puts "are we here? #{curr.inspect}, infix? #{curr.infix?}, precedence: #{precedence_for(curr)}"
		# puts "curr?(Key_Identifier_Token, Operator_Token, Key_Operator_Token) #{curr?(Key_Identifier_Token, Operator_Token, Key_Operator_Token)}"
		# puts "curr?(Operator_Token) #{curr?(Operator_Token)}"
		# puts "curr?([Key_Identifier_Token, Operator_Token, Key_Operator_Token]) #{curr?([Key_Identifier_Token, Operator_Token, Key_Operator_Token])}"
		# relief: I figured out that I broke #curr?. Not sure what I did, but when using `and` it works but with `&&` it doesn't. so my understanding of *sequence or whatever I called it in #curr? is wrong. That's the bug! And it'll be easy to fix I think

		# this will just magically work when I fix #curr?
		while curr?([Key_Identifier_Token, Operator_Token, Key_Operator_Token]) && curr.infix?
			curr_operator_prec = precedence_for(curr)

			unless curr_operator_prec
				raise "Unknown precedence for infix operator #{curr.inspect}"
			end

			if curr_operator_prec <= starting_prec
				return expr
			end

			operator = eat

			expr = Infix_Expr.new.tap {
				_1.left     = expr
				_1.operator = operator
				_1.right    = make_expr(curr_operator_prec)
				unless _1.right
					raise "Infix_Expr expected an expression after `#{_1.operator.string}` (#{_1.operator.line}:#{_1.operator.line})"
				end
			}

			if operator == '.@'
				# todo update start/end_index and line/column to reflect these operator changes
				expr.operator.string = '.'
				expr.right           = Prefix_Expr.new.tap {
					_1.expression      = expr.right
					_1.operator        = operator.dup
					_1.operator.string = '@'
				}
			end
		end

		expr
	end

=begin
skip_inline_funcs – prevents [ident, ;] from parsing as Func_Expr.
In a function declaration, the last param followed by the ; could parse as an inline Func_Expr [ident, ;] so I want to be able to bypass it

todo turn #parse_until's params into a single options param maybe? this looks ugly
=end

	def parse_until until_token = EOF_Token, starting_precedence = STARTING_PRECEDENCE, skip_inline_funcs = false
		exprs = []
		while tokens? && curr != EOF_Token
			if until_token.is_a? Array
				break if until_token.any? do |t|
					curr == t
				end
			else
				break if curr == until_token
			end
			expr = make_expr(starting_precedence, skip_inline_funcs)
			if expr
				exprs << expr
			end
		end
		exprs
	end
end
