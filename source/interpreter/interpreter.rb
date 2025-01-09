=begin
#interpret(expr) exercise

x=1                 global = { x:1 }
y=2                 global = { x:1, y:2 }
x                   global[x]

func {->}           references = { func:{->} }          global[func] = ref(func)
func                global[func] => ref(func)
func()              global[func] => ref(func) => interpret(ref(func)) or call_function(ref(func)) to be more verbose

Class {id = 0}      references[Class] = { id:0 }        global[Class] = ref(Class)
Class               global[Class] => ref(Class)
Class.new           global[Class] => ref(Class) => init_class(ref(Class))

=end
require 'pp'


class Interpreter

	attr_accessor :global, :exprs


	def initialize exprs = []
		@global = {}
		@exprs  = exprs
	end


	def set key, value
		global[key] = value
	end


	def get key
		global[key]
	end


	def interpret
		last = nil
		exprs.each {
			last = run _1
		}
		last
	end


	# @param expr [Expr]
	def run expr
		case expr
			when Operator_Expr
				if expr.string == '@'
					puts "global\n#{PP.pp(global, '')}"
				else
					expr
				end
			when Infix_Expr
				if expr.operator.is '='
					set expr.left.string, run(expr.right)
				elsif %w(+ - * /).include? expr.operator.string
					run(expr.left).send expr.operator.string, run(expr.right)
				elsif expr.operator.is '.'
					left = get expr.left.string
					if left.is_a? Hash
						puts "left #{left}"
						left[expr.right.string]
					else
						raise ". not supported on #{expr.class}"
					end
				end
			when Func_Decl
				set expr.name.string, expr.expressions

			when Hash_Expr # zips keys and values, then maps Identifier keys to their string, and number values to their number. todo how should other types of keys/values be stored?
				Hash[expr.keys.map {
					case _1
						when Identifier_Expr
							_1.string
						else
							_1
					end
				}.zip(expr.values.map {
					run(_1)
				})]

			when Number_Literal_Expr # converts number string into Integer or Float
				if expr.type == :int
					Integer(expr.string)
				elsif expr.type == :float
					if expr.decimal_position == :end
						Float(expr.string + '0')
					else
						Float(expr.string)
					end # no need to explicitly check :beginning decimal position (.1) because Float(string) can parse that
				end
			when Identifier_Expr
				get expr.string
			else
				puts "\n\n#{expr.pp}"
				expr
		end
	end

end
