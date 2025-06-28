# require './lang/parser/expression'
# require_relative 'constructs'
#
# class Interpreter
# 	attr_accessor :input, :output
# 	attr_writer :scopes
#
# 	def initialize input = []
# 		@input  = input
# 		@output = []
# 		@scopes = []
# 		@scopes << create_scope(:global)
# 	end
#
# 	# @return [Array<Hash>] stack of scopes
# 	def scopes
# 		@scopes
# 	end
#
# 	def create_scope type
# 		{
# 			'@' => {
# 				id:       (@scopes.length + 1),
# 				identity: type
# 			},
# 		}
# 	end
#
# 	def set_identifier_in_scope identifier, value = nil
# 		scope = scopes.reverse.find do
# 			it.dig(identifier)
# 		end
#
# 		if scope
# 			scope[identifier] = value
# 		else
# 			scopes.last[identifier] = value
# 		end
# 	end
#
# 	# @param [String] identifier
# 	def find_identifier_in_scopes identifier
# 		return nil unless identifier
#
# 		value = nil
# 		scopes.reverse.each do
# 			value ||= it.dig(identifier)
# 		end
#
# 		value
# 	end
#
# 	def output
# 		output = nil
# 		input.each do
# 			output = interpret it
# 			puts output
# 		end
# 		output
# 	end
#
# 	# @param [Expression] expr
# 	def interpret expr
# 		# puts "expr: #{expr.inspect}"
# 		case expr
# 			when Number_Expr
# 				expr.value
# 			when String_Expr
# 				expr.value
# 			when Identifier_Expr
# 				find_identifier_in_scopes expr.value
#
# 			when Prefix_Expr
# 				case expr.operator
# 					when '-'
# 						-i(expr.expression)
# 					when '+'
# 						+i(expr.expression)
# 					when '!'
# 						!i(expr.expression)
# 					else
# 						raise "Unhandled prefix #{expr.inspect}"
# 				end
# 			when Infix_Expr
# 				if "todo no longer using ::ASSIGNMENT" == false # NewLexer::ASSIGNMENT.include? expr.operator
# 					# if %w(+= -= *= |= /= %= &= ^=).include?(expr.operator)
# 					operation = expr.dup
# 					operation.operator = operation.operator.gsub('=', '')
#
# 					# left += right
# 					# left = left + right
#
#
#
# 					# expr.left remains the same
# 					expr.operator = '='
# 					expr.right    = operation
# 					i(expr)
# 				elsif %w(.. >. .< ><).include? expr.operator
# 					# todo return a Range object
#
# 					# elsif expr.operator == '=='
# 					# i(expr.left) == i(expr.right)
#
# 				# elsif expr.operator == '='
# 				# 	# left = i(expr.left)
# 				#
# 				# 	scope = scopes.reverse.find do
# 				# 		it.has_key? expr.left.value
# 				# 	end
# 				#
# 				# 	if scope
# 				# 		scope[expr.left.value] = i(expr.right)
# 				# 	else
# 				# 		scopes.last[expr.left.value] = i(expr.right)
# 				# 	end
#
# 					# if left
# 					# 	set_identifier_in_scope expr.left.value, i(expr.right)
# 					# else
# 					# 	left = scopes.last[expr.left.value] = i(expr.right)
# 					# end
# 					# left
#
# 				elsif %w(+ - * / % ** == !=).include? expr.operator
# 					left = i(expr.left)
# 					left.send expr.operator, i(expr.right)
#
# 				else
# 					warn "unknown infix #{expr.inspect}"
# 					i(expr.left).send expr.operator, i(expr.right)
# 				end
#
# 			when Postfix_Expr
# 				if expr.operator == '=;'
# 					set_identifier_in_scope i(expr.expression)
#
# 				else
# 					raise "Unknown postfix #{expr.inspect}"
#
# 				end
# 			when Circumfix_Expr
# 				case expr.grouping
# 					when '()'
# 						i expr.expressions
# 					else
# 						raise "unknown grouping #{expr.inspect}"
# 				end
#
# 			when Array
# 				last = nil
# 				expr.each do
# 					last = i it
# 				end
# 				last
#
# 			else
# 				warn "todo #{expr.inspect}"
# 				raise expr.inspect
# 		end
# 	end
#
# 	alias_method :i, :interpret
# end
#
#
# # case operator[..-2]
# # 	when '+'
# # 	when '-'
# # 	when '*'
# # 	when '|'
# # 	when '/'
# # 	when '%'
# # 	when '&'
# # 	when '^'
# # 	when '!'
# # 	when '<'
# # 	when '>'
# # 	when '||'
# # 	when '&&'
# # 	when '**'
# # 	when '<<'
# # 	when '>>'
# # 	when ':'
# # 	else
# # 		raise "NotImplemented assignment operator #{operator.inspect}"
# # end
