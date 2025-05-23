123
2.3
-4.2
-123
+123
1 + 2 * 3 / 4
(1 + 2) * 3
1 + (2 * 3)
-test1
@test2
!test3
#test4
an_ident
a.b.c
assigned = 5


nothing =;
nope;
Atom;
NONE;

{;}
named_func {;}
{ some_param; "`some_param`" }

funk = { label param;
	param
}

{} `empty hash or dict
{ b= 2 } `keys[b] var_decl[b]
{ a = 2, b = 3 }

dict = { funk_ref = #funk }
{ object_a = object_b } `as long as each object can be hashed

Empty {}

Transform {
	position
	rotation;

	move { delta;
		position += delta
	}
}

Composition_Example {
	& Ghi
	^ Jkl
	- Mno
	| Pqr
	1 & 2 `making sure this still parses as infix after adding & and ^ to Lexer::PREFIX

	variable
	variable;
	variable=;
}

Inline_Composition | Empty {}

Complex | Inline_Composition & Composition_Example ^ Another - Last | Just_Kidding {
	1 - 2
	-2
`	& This - That `doesn't work
}

obj.@test
obj.#test
obj.?test `?ident is like &. in ruby

2>.6 `excludes 2, includes 6
3><7
1..5
4.<8
1.0..2.0

CONSTANT = {
	THIS = 0
}

_Type {
	nothing
	no_thing;
}

_variable;
variable! = 2 `! and ? allowed
var? = 3

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

./self
../global
.../third

./self.a.b.c
../global.c
.../third.d

x = 5
2x
3x

[1, 2, 3]
