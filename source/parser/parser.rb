require 'debug'

# Turns string of code into tokens
class Parser
	require_relative '../lexer/tokens'
	require_relative 'exprs'

	attr_accessor :i, :buffer, :source, :expressions, :eaten_this_iteration

	DEBUG_SYMBOL = '■'.freeze


	def initialize buffer = [], source_code = ''
		@i                    = 0 # index of current token
		@buffer               = buffer
		@source               = source_code
		@expressions          = []
		@eaten_this_iteration = []
	end


	def to_expr
		parse_until(EOF_Token)
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
		%Q(#{DEBUG_SYMBOL * 8} DEBUG INFO #{DEBUG_SYMBOL * 56}
#{DEBUG_SYMBOL * 8} PREVIOUS TOKEN #{DEBUG_SYMBOL * 23}
#{prev.inspect}
#{DEBUG_SYMBOL * 8} CURRENT TOKEN #{DEBUG_SYMBOL * 23}
#{curr.inspect}
#{DEBUG_SYMBOL * 8} NEXT TOKEN #{DEBUG_SYMBOL * 23}
#{peek(1).inspect}
#{DEBUG_SYMBOL * 8} LAST 5 EXPRESSIONS #{DEBUG_SYMBOL * 23}
#{expressions[-5..]&.map(&:inspect)}
#{DEBUG_SYMBOL * 76})
	end


	#{DEBUG_SYMBOL * 8} LAST 5 #make_expr'd #{DEBUG_SYMBOL * 23}
	#{eaten_this_iteration[-5..]&.map(&:inspect)}
	# {DEBUG_SYMBOL * 8} SOME CODE #{DEBUG_SYMBOL * 23}
	# {eaten_this_iteration&.map(&:string).join[-15..]}

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


	# checks whether the remainder buffer contains the exact sequence of tokens. if one of the arguments is an array then that token in the sequence can be either of the two. eg: ident, [:, =, :=]
	def curr? * sequence
		remainder.slice(0, sequence.count).each_with_index.all? do |token, index|
			if sequence[index].is_a? Array
				sequence[index].any? do |sequence_element|
					if sequence_element.is_a? Symbol
						token == sequence_element.to_s
					else
						token == sequence_element
					end
				end
			else
				if sequence[index].is_a? Symbol
					token == sequence[index].to_s
				else
					token == sequence[index]
				end
			end
		end
	end


	# eats a specific sequence of tokens, either Token class or exact string. eg: eat StringLiteralToken, eat '.'. etc
	# idea: support sequence of elements where an element can be one of many, like the sequence [IdentifierToken, [:=, =]]
	def eat * sequence
		if sequence.nil? or sequence.empty? or sequence.one?
			eaten = curr
			if sequence&.one? and eaten != sequence[0]
				# puts debug
				# puts "::::: SOURCE CODE CONTEXT :::::"
				extra = 25..0
				code  = source_substring_for_token(eaten, extra)
				parts = code.split "\n"
				caret = parts.last.tap {
					_1 << "\n\t#{' ' * (curr.column - 1)}^"
				}

				puts %Q(\n
———————————————————————————
#eat(#{sequence[0].inspect}) got #{eaten.string.inspect}
~~~~~~~~~~~~~~~~~~~~~~~~~~~\n
\t#{caret}
~~~~~~~~~~~~~~~~~~~~~~~~~~~
———————————————————————————)
				raise
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
				unless curr == expected
					current = "\n\nExpected #{expected} but got #{curr}"
					# remaining = "\n\nREMAINING:\n\t#{remainder.map(&:to_s)}"
					progress = "\n\nPARSED SO FAR:\n\t#{expressions[3..]}"
					raise "#{current}#{remaining}#{progress}" unless curr == expected
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
		curr? Identifier_Token and curr.class?
	end


	def member_ident?
		curr? Identifier_Token and curr.member?
	end


	def constant_ident?
		curr? Identifier_Token and curr.constant?
	end


	def parse_block until_token = '}'
		Func_Expr.new.tap do |it|
			it.expressions = parse_until until_token

			# make sure the block's compositions are derived from the expressions parsed in the block
			it.compositions = it.expressions.select do |expr|
				expr.is_a? Class_Composition_Expr
			end
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


	# def make_class_composition_expr
	# 	Class_Composition_Expr.new.tap do |it|
	# 		it.operator = eat.string # > + - # * & ~
	# 		# puts "what if we eat expression"
	# 		# expr = make_expr
	# 		# puts "expr #{expr.inspect}"
	# 		it.expression = make_expr
	#
	# 		if curr? 'as' and curr? Identifier_Token
	# 			eat # as
	# 			it.alias_identifier = eat # you can alias compositions as symbols too
	# 		end
	# 	end
	# end

	def make_array_of_param_decls
		[].tap do |params|
			start = curr
			# (label) (%) ident (= expr)
			until curr? '->'
				params << Func_Param_Decl.new.tap {
					if curr? '%' and eat
						_1.composition = true
					end

					if curr? Identifier_Token, Identifier_Token
						_1.label = eat Identifier_Token
					end

					_1.name = eat Identifier_Token

					if curr? '=' and eat '='
						_1.default_expression = make_expr
					end

					if curr? ','
						eat ','
						eat_past_deadspace
					elsif not curr? '->'
						raise "Malformed Param_Decl starting at #{start.inspect}, curr: #{curr.inspect}"
					end

				}
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
			eat if curr? 'if' or curr? 'while'

			if curr? Identifier_Token, '{'
				identifier   = eat Identifier_Token
				it.condition = Identifier_Expr.new.tap do |id|
					id.string = identifier #.string
					# id.tokens << identifier
				end
				eat '{'
			else
				potential = make_expr
				if potential.is_a? Func_Expr and potential.named?
					it.condition = Identifier_Expr.new.tap do |id|
						id.string = potential.name #.string
					end
				elsif potential.is_a? Infix_Expr and potential.operator == '.' and potential.right.is_a? Func_Expr and potential.right.named?
					it.condition = Identifier_Expr.new.tap do |id|
						id.string = potential.right.name #.string
					end
				else
					it.condition = potential
				end

				eat '{' if curr? '{'
			end

			eat_past_deadspace
			it.when_true = parse_block %w(} else elsif elif ef elswhile)

			if curr? 'else'
				eat 'else'
				it.when_false = parse_block '}'
				eat '}'
			elsif curr? '}'
				eat '}'
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

			while tokens? and not curr? '}'
				_1.keys << make_expr
				if curr? %w(:) and eat # note I originally wanted to allow = as well, but it's not simple because a binary expression
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


	def make_set_expr
		# can be any one of these, the grouping symbol doesn't matter
		# @[ expr , ]
		# @( expr , )
		# @{ expr , }
		Set_Expr.new.tap {
			opener      = eat # @[ @( @{
			closer      = case opener.string[-1]
				when '['
					']'
				when '('
					')'
				when '{'
					'}'
				else
					raise " unknown set opener #{opener}"
			end
			_1.grouping = "#{opener.string[-1]}#{closer}"

			if curr? closer and eat
				return _1
			end

			while tokens? and not curr? closer
				_1.elements << make_expr
				break if curr? closer
				eat ',' # if curr? ','
				eat_past_deadspace
			end

			eat closer
		}
	end


	def make_array_expr
		# [ expr , ]
		Array_Expr.new.tap {
			eat '['
			if curr? ']' and eat
				return _1
			end
			while tokens? and not curr? ']'
				_1.elements << make_expr
				break if curr? ']'
				eat ','
				eat_past_deadspace
			end
			eat ']'
		}
	end


	def make_operator_overload_expr
		raise 'Operator overloading not implemented in Parser'
	end


	def make_tuple_expr opening = '{'
		closing = case opening
			when '{'
				'}'
			when '('
				')'
			when '['
				']'
			else
				raise "#make_grouped_expr unknown opening #{opening}"
		end

		Tuple_Expr.new(opening + closing).tap {
			eat opening

			if curr? closing
			else
				until curr? closing
					_1.expressions << make_expr
					break if curr? closing
					eat ','
					eat_past_deadspace
				end
			end

			eat closing
		}
	end


	def peek_until_contains? until_token, contains
		peek_until(until_token).any? do
			_1 == contains
		end
	end


=begin
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
		# ??? mess I need to space out the precedences so that users can declare their own precedences that can work within these.
		[

		  # binds tightly
		  #      @this.that  ((@this) . that)
		  #      >! 123      (>! 123)
		  [1000, %w(>!!! >!! >! @)],
		  [400, %w(( ))],
		  [380, %w([ ])],
		  [360, %w(< <= > >= == != === !== ** )],
		  [340, %w(** * / %)],
		  [320, %w(- +)],
		  [300, %w(!! ? ??)],
		  [280, %w(<< >>)],
		  [260, %w(&)],
		  [240, %w(^)],
		  [220, %w(|)],
		  [200, %w(&& || and or)],
		  [180, %w()],
		  [160, %w(++ --)],
		  [140, %w(: .)],
		  [120, %w(= += -= *= /= %= &= |= ^= <<= >>=)],
		  [100, %w(,)],
		  [80, %w(.? .. .< >. >< !)],

		  # binds loosely
		  #      abc.def.hij.klm     (((abc.def).hij).klm)

		].find do |_, chars|
			chars.sort_by! { -_1.length }.include?(token.string)
		end&.first
	end


	def make_expr starting_precedence = 0
		# todo Operator_Decl when curr?(operator, Operator_Token, {)
		# todo Route_Decl when curr? String_Literal, Identifier_Token, {

		# puts "curr: #{curr.inspect} arrowed? #{peek_until_contains? "\n", '->'}"
		# if curr == "\n"
		# 	puts "curr #{curr.inspect}"
		# 	puts "curr? Delimiter_Token #{curr? Delimiter_Token}"
		# end
		#
		# return eat

		expr = \
		  if curr? '{' and peek_until_contains? '}', '->' # { -> }
			  Func_Expr.new.tap {
				  eat '{'

				  arrowed = peek_until_contains? '}', '->'
				  eat_past_deadspace

				  if arrowed
					  _1.parameters = make_array_of_param_decls
					  eat_past_deadspace
					  eat '->'
					  eat_past_deadspace
				  end

				  _1.expressions = parse_block.expressions
				  eat '}'
			  }
		  elsif curr? '{' # hash or
			  make_hash_expr

		  elsif curr? '['
			  make_array_expr

		  elsif curr? %w[ @{ @\[ @( ]
			  make_set_expr

		  elsif class_ident? && (curr?(Identifier_Token, '{') or curr?(Identifier_Token, '>') or curr?(Identifier_Token, '+'))
			  # todo compositions
			  # ??? useful checks that I don't want to write inline, in the big if-else block
			  # class_merge_comp   = (curr? '>', Identifier_Token and (peek(1).constant? or peek(1).class?))
			  # class_add_comp     = (curr? '+', Identifier_Token and (peek(1).constant? or peek(1).class?))
			  # class_remove_comp  = (curr? '-', Identifier_Token and (peek(1).constant? or peek(1).class?))
			  # wormhole_comp      = (curr? '%', Identifier_Token or curr? '*', Identifier_Token) # note the binary * operator will be handled below this massive if-else. There's no danger in using it as a prefix here, I guess I could also

			  Class_Decl.new.tap do |it|
				  # puts "curr #{curr.inspect}"
				  it.name = eat(Identifier_Token)

				  if curr? '>' and eat '>'
					  raise 'Parent must be a Class' unless curr.class?
					  it.base_class = eat(Identifier_Token)
				  end

				  if curr? '&' and eat
					  # keep eating comma separated compositions until {
					  until curr? '{'
						  eat_past_deadspace
						  it.compositions << eat(Identifier_Token)
						  eat ',' if curr? ','
					  end
				  end

				  eat '{'
				  eat_past_deadspace
				  it.block = parse_block '}'
				  eat '}'
			  end
		  elsif member_ident? and curr?(Identifier_Token, '{')
			  Func_Decl.new.tap { # :name < Func_Expr :expressions, :compositions, :parameters, :signature
				  _1.name = eat(Identifier_Token)
				  eat '{'

				  arrowed = peek_until_contains? '}', '->'
				  eat_past_deadspace

				  if arrowed
					  _1.parameters = make_array_of_param_decls
					  eat_past_deadspace
					  eat '->'
					  eat_past_deadspace
				  end

				  _1.expressions = parse_block.expressions
				  eat '}'
			  }
		  elsif constant_ident? and curr? Identifier_Token, '{'
			  Enum_Decl.new.tap {
				  # :identifier, :expression
				  _1.identifier = eat Identifier_Token
				  if curr? '{' and eat
					  until curr? '}'

					  end
				  end

			  }

		  elsif curr? '('
			  make_tuple_expr '('

		  elsif curr? 'return'
			  Return_Expr.new.tap do |it|
				  eat # >> or return
				  it.expression = make_expr
			  end

		  elsif curr? 'while'
			  make_conditional_expr true

		  elsif curr? 'if'
			  make_conditional_expr

			  # elsif curr? Key_Identifier_Token and curr == 'operator'
			  # 	make_operator_overload_expr

		  elsif curr? Key_Identifier_Token and curr == 'raise'
			  Raise_Expr.new.tap {
				  # mess
				  # :name, :condition, :message_expression
				  _1.name       = eat(Key_Identifier_Token).string
				  _1.expression = if not curr? Delimiter_Token # curr? %w(, ; \n })
					  make_expr
				  end
			  }

			  # elsif %w(> + -).include? curr and peek(1) == Identifier_Token and peek(1).member?
			  #   raise 'Cannot compose a class with members, only other classes and enums'

			  # todo you should be able to assign different types to each other.
			  # YAY: member = member/Class/CONSTANT, CONSTANT = CONSTANT, Class = Class.
			  # NAY: Class = member, Class = CONSTANT

		  elsif curr? Identifier_Token, '~>'
			  Func_Decl.new.tap {
				  _1.name = eat Identifier_Token
				  eat '~>'
				  _1.expressions = [make_expr]
			  }

		  elsif curr? String_Token or curr? Number_Token
			  make_string_or_number_literal_expr

		  elsif curr? Comment_Token
			  # xxx backticked comments

			  eat and nil

		  elsif curr? Delimiter_Token
			  eat and nil

		  elsif curr? Key_Identifier_Token
			  Key_Identifier_Expr.new.tap {
				  _1.string = eat Key_Identifier_Token
			  }

		  elsif curr? Identifier_Token
			  Identifier_Expr.new.tap {
				  _1.string = eat Identifier_Token
			  }

		  elsif curr? Operator_Token
			  Operator_Expr.new.tap {
				  _1.string = eat Operator_Token
			  }

		  elsif curr? EOF_Token
			  puts debug
			  raise "Parser expected an expression but reached EOF"
		  else
			  raise "Parsing not implemented for #{curr.inspect}"
		  end

		augment_or_dont expr, starting_precedence
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
	def augment_or_dont expr, starting_prec
		# puts "aug? #{expr.inspect}"
		return expr if curr? "\n" or not expr
		return expr if curr? %w(-> :)

		postfix = curr?(Operator_Token) && (curr.respond_to?(:postfix?) and curr.postfix?) # xxx also check for user-declared postfix operators
		prefix  = expr.is_a?(Operator_Expr) && (expr.string.respond_to?(:prefix?) and expr.string.prefix?) # xxx also check for user-declared prefix operators
		if prefix
			if expr.string == '@' and curr == '.' # manual handling of @. to just eat over the dot to make @.member behave like @member
				eat
			end

			expr = Prefixed_Expr.new.tap {
				_1.operator   = expr
				_1.expression = make_expr precedence_for(expr.string)
			}

			if not expr.expression
				raise "Prefixed_Expr expected an expression after `#{expr.operator}`"
			end

			return augment_or_dont expr, starting_prec
		elsif postfix # ??? should this be an elsif?
			# !!! if this causes problems with order of operations, it would likely be for the same reason Prefixed_Expr did, and that was because I needed to prevent the next expression from grouping itself into the prefixed expression by adding a starting precedence to the make_expr call
			expr = Postfixed_Expr.new.tap {
				_1.expression = expr
				_1.operator   = make_expr
			}
			return augment_or_dont expr, starting_prec
		end

		# puts "and? #{expr.inspect}"

		if curr? '(' and eat '(' # and subject and not subject == "\n"
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

						# puts "before making arg expr #{curr.inspect}"
						arg.expression = make_expr # if curr? Token, ','
						#     parse_block ','
						# elsif curr? Token, ')'
						#     parse_block ')'
						# else
						#     parse_block %w[, )]
						# end.expressions[0]
					end

					eat if curr? ','
				end

				eat ')'
			end
		end

		# xxx an operator can be binary if it's declared to be. I don't have syntax for that yet, but this is where that check would go.

		# valids = curr? [Key_Identifier_Token, Operator_Token, Key_Operator_Token] #, Identifier_Token]# and not curr? %w(for)
		# return expr unless valids

		while curr? [Key_Identifier_Token, Operator_Token, Key_Operator_Token] and curr.infix?
			curr_operator_prec = precedence_for(curr)

			if not curr_operator_prec
				raise "Unknown precedence for infix operator #{curr.inspect}"
			end

			# puts "curr_prec #{curr_operator_prec}"
			# puts "starting_prec #{starting_prec}"
			# if starting_prec >= curr_operator_prec
			if curr_operator_prec <= starting_prec
				return expr
			end

			operator = eat

			expr = Infix_Expr.new.tap {
				_1.left     = expr
				_1.operator = operator
				_1.right    = make_expr(curr_operator_prec)
				if not _1.right
					raise "Infixed_Expr expected an expression after `#{_1.operator.string}`"
				end
			}
		end

		expr
	end


	def parse_until until_token = EOF_Token
		exprs = []
		while tokens? and curr != EOF_Token
			if until_token.is_a? Array
				break if until_token.any? do |t|
					curr == t
				end
			else
				break if curr == until_token
			end

			if (expr = make_expr)
				exprs << expr
			end
		end
		exprs
	end
end
