```
This is a multiline comment.
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
1 + (2 * 3)

`Prefix
-test1
@test2
!test3
#test4

```
Declarations:
Variables and functions must start lowercase.
Class/Types must start uppercase.
Constants must be ALL_CAPS.
```
nothing =; `short for = nil
nothing; `short for = ni;

assigned = 5

CONSTANT = {
	FOO = 0
	BOO = {
		MOO = 1
	}
}

`function syntax
name_of_function { params_before_colon;
	"body after colon"
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

{} `empty hash or dict
{ b = 2 } `keys contains b
{ a = 2, b = 3 } `keys contains a and b

Empty_Type {
}

Transform {
	position `identifiers in type body is the only place it's is considered a nil declaration. Elsewhere it is an expression. Makes for really simple types like My_Type { this that etc }
	rotation;

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

Complex_Inline | Foo & Boo ^ Moo - Poo | Composed_Type {}

`testing prefixes with dot access
obj.?test `?ident is like &. in ruby
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
My_Type!;
My_Type?;

lots_of_params { aa a, bb b, cc c, d, e; }
a ? b : c `(a ? (b : c)) until another phase corrects it to conditional expression

if 1
	'one'
elif 2
	'two'
elsif 3
	'three'
else
	'idk'
end

while 1
	'one!'
elwhile 2
	'two!'
elswhile 3
	'three!'
else
	'idk!'
end

./local `./ is equivalent to self in Ruby
../global `../ is the global scope
.../third `.../ is the third party code

./a.b.c.d

`shorthand for multiplication
g = 9.8
2g
GRAVITY = 9.8
3GRAVITY
5kg
2gether
4x4


`arrays
array = [1, 2, 3]
3 * Transform.new `runtime should create array of 3 instances

`strings
fun = 'yes'
fun! = "single and double quotes equivalent `fun`"
is_programming_fun? = 'interpolate fun with backtick `fun!`'
!a.b

(1,2) `tuples
(4,5,) `trailing comma is fine
