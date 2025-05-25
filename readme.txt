```
This entire file lexes and parses. Soon it'll be interpreting too!
Read lang/test.rb to see how this readme is used as example source code for the lexer and parser, and soon runtime.
```

`Numbers
48
1.5
-1.6
-2.3
+4.2

`Arithmetic
1 + 2 * 3 / 4
(1 + 2) * 3
4 + (2 * 3) == 4 + 2 * 3

`Prefix
-test1
@test2
!test3
#test4
!test5.test6


```
Declarations:
Variables and functions must start lowercase.
Class/Types must start uppercase.
Constants must be ALL_CAPS.
```
nothing =;`short for = nil

assigned = 5

left = right =;

CONSTANT = {
	FOO = 0
	BOO = {
		MOO = 1
	}
}

`function syntax
name_of_function { params_come_before_colon;
	`body of the function = all expressions between ; and }
}

`anonymous functions
{;}
{ some_param; "`some_param`" }

`assignable and called the same way though, so it's identical to a normal function declaration
funk = { param;
	param
}

function_with_label { it internal_name;
	do_something(internal_name)
}

lots_of_params_with_labels { aa a, bb b, cg=9c c, d, e; }

{} `empty hash or dict
{ b = 2 } `keys contains b
{ a = 2, b = 3 } `keys contains a and b

Empty_Type {}

Transform {
	position `identifiers in type body is the only place it's is considered a nil declaration. Elsewhere it is an expression. Makes for really simple types like My_Type { this that etc }
	rotation =;

	move { delta;
		position += delta
	}
}

Composed_Type { `composition over inheritance
	| Transform
	& Foo
	^ Boo
	- Moo
}

Complex_Inline | Foo & Boo ^ Moo - Poo | Composed_Type {} `worry about precedence later lol

`Functions and Types use {} for body grouping
`Control flow only uses `end` to terminate body
if one
	1
elif two
	2
elsif three
	3
else
	4
	4
	4
end

while one
	'one!'
elwhile two
	'why not?'
elswhile three
	'three!'
else
	'idk!'
end

`a ? b : c `not supported currently (a ? (b : c)) until another phase corrects it to conditional expression

./local `./ is equivalent to self in Ruby
../global `../ is the global scope
.../third `.../ is the third party code

./a.b.c.d

`Testing prefixes with dot access
obj.?test_question_mark.?again `?ident is like &. in ruby
obj.@test
obj.#test

`ranges
2>.6 `excludes 2, includes 6
3><7
1..5
4.<8
1.0..2.0

`underscored declarations are private
_Type {
	_nothing
	_something = 2
}

`! and ? allowed in vars, funcs, and types
variable! = 2
var? = 3
My_Type! =;
My_Type? =;



`shorthand for multiplication
`not supported anymore, I'll figure out how to add it back!
`g = 9.8
`2g
`GRAVITY = 9.8
`3GRAVITY
`5kg
`2gether
`4x4

`arrays
array1 = [1, 2, 3]
array2 = (1, 2, 3)
{1, 2, 3}
Transform.new * 2 `runtime should create array of 2 instances?

`strings
fun = 'yes'
fun! = "! and ? allowed in identifier"
fun? = '`fun`'
is_programming_fun? = 'single and double quotes equivalent, interpolate fun with backtick `fun!`'

(1,2) `tuples
(4,5,) `trailing comma is fine

puts = .../Logger.log

`@ = current scope, provided by runtime
@ += Time `localize Time's declarations
puts now `prints Time.now
@ -= time `remove when done

{;
	@ += .../Logger
	log('Logger will be removed by runtime at end of function')
}()


Token_Remake {
	type, value, reserved, line, column
}


Lexer {
	i = 0
	col = 1
	row = 1
	input =;

	new { input = '"hello world"';
		./input = input
	}

	whitespace? { char = curr;
		char == "\t" or char == " "
	}
}

Expression { value: Any, type: Symbol, start_location: Int, end_location: Int }

Type_Decl | Expression {
	& Expression
	identifier
	expressions = []
	composition_expressions = []
}

abc.call(1,2,3)

x = 4
y = 8
{x y z} `{x:4, y:8, z:nil} dictionary
{a b c} `{a:nil, b:nil, c:nil}
`variable name is used as key unless


test: This
function: That {;}
{}

Island {
	| Buildings

	Hatch | Props {
		computer: Computer
		door: Door
		code: Number = 4815162342
	}

	hatch = Hatch.new `we'll worry about inferring types later
}

dictionary: Dictionary = {x:15, y=16} `circumfix {} that doesn't include ; is a
./a.b.c

1 & 2
1 | 2
1 || 2
|123| `parses as circumfix ||

builtin_tap.{;
}
''.{;} `works with anything that can receive a . operator
Anything.{;}

`fix this
`test.named {;} `parses
`test.whatever(123) {;} `doesn't
