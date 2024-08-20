`numbers
123
1_000
1.0
1.
.2
3 + 5 * 2 - 4 / (1 + 1) ** 2

`parenthesized exprs
(1)
(1+2)



`strings
'sawyer'
"`who` is tied to a tree in a jungle of mystery"

`identifiers
Class {}    `class, always capitalized
func { -> } `func, always lowercased
var = 1     `var, always lowercased

`hashes
x = {a:123, 'b': 345345} `access keys via dot or subscript
x.a
x.b
x[a]
hash = {
	x: 1
}
{456:123}
what = {nil:nil} `bug parses as {"nil"=>nil}

`sets aka circumfix
()
(1, 2, 3)
variable = ((1,2), 2, [a,b], a, b)

`arrays
a = [1, 2, 3, x, var, func(), Class.new]


`operator are also identifiers
..=+-~*!@#$%^&.?/|<>_:; `always symbols in any sequence*
.=+-~*!@#$%..^&?/|<>_:; `also valid
`.=+-~*!@#$%^&.?/|<>_:;. is an invalid operator*
`because operators cannot end with a dot unless all other characters are dots. But you can start with or include e other dots anywhere else. The following are all valid:
................:::#$%^
..........
...*&^%()

`declare operators with [operator, in/pre/post/circumfix, operator]
operator infix by { left, right -> left * right }
4 by 8

```
operator infix : { left, right ->
	"`left`:`right`"
}

this one breaks hashes so I need to think about how to make this work, cause this is cool for things like time. Imagine being able to specify time like `11:11`. Imagine being able to write 3:14PM

operator postfix PM
operator postfix AM
```


`visibility
_Class {}       `private
__Class {}      `protected
_private = 12
__protected = 34
`!@#$%^&*

`passing anon func to call. I'm not sure if
abc.def.{ -> }
abc.def { -> }

xyz.{->}
xyz().{->}
xyz.each.{->}
xyz.each { -> } `this parses as Infix(hash . Func_Decl(each)) which is convenient for Runtime, we can treat Infix.right = Func_Decl as passing a block to .left. This looks better than .{->} but is not as recognizable. Maybe dot is the way to go.

`functions
funk { a, b -> inline }
funky -> no `inline without {}, but must be single-line expression
inline -> 'lost'

funky { #four = 4, eight = 8, forty two = 2 % 3, bc = def ->
	#four `also works in blocks
	inline
}

{ -> } `anonymous function
intro { for sho2 -> "Previously on `show`" } `param labels
into(for: 'Lost') `Previously on Lost

ref = funky `omitting parens on function doesn't call it, but lets you pass it around.
ref() `calls it
ref()() `calls the output of calling ref(), if possible


`classes
Island {
	coordinates

	Hatch {
		Computer {
			enter { numbers ->
				if numbers == 4815162342
					`do something
				else
					`uhoh
				}
			}
		}
	}
}

Hatch > Old_Hatch {} `OOP inheritance

island = Island.new `new is a reserved instantiation identifier, () may be omitted

find { #island -> `# prefix localizes the scope of that variable. Meaning
	>! coordinates `access island.coordinates as if it were defined locally
}

f(island)
#island `scope localization works anywhere, not just in params
-#island `remove from local scope

`I also like this syntax, tbd!
`# += island
`# -= island


`( x, :, 4, y, :, 8, 5 ) `hashes must always use : because it is easier to identify instead of allowing oth
( x + y : 420 )

`it would be nice to } treat Hash and Set as the same
{x:1, y:2}.x `should = 1
{x:1, y:3}.y `should raise
`so from the user's perspective, it doesn't matter if it's a hash or set. you can use it as either, or as oth
`It should be Set_Literal_Expr. And that is what hash nd sets will be known as

[]
[1]
[1, 2]
[x = 3, y = 4]

{
	1: 2
}

Dafunk {
`	funk `at class scope, identifiers without ssignment are treated as nil assignment
}
`
`Transform { `that allows for nice looking data structures. You could pretend this is a struct. It really doesn't matter here because everything's a hashon the inside.
	rotation, position
`}

(1 + 2) - 3

funk()
()
funky(4, 5, for: 6)

(7, 8, for,:, 9)


(1, 1, 2)

Class {
	"" route { ->
	} `Route_Decl
} ` any class can respond to a route as long as a erver is configured somehow. syntax tbd


1..2
3.<4

Class {}
funk {
	#bwah -> 123
}

raise !

!1

!()
1 @#%@#$%@#$ 23234

if true {
}

nil

#12

!1
2!

1+2




if c1 {
	11
elsif c2
22
elif c3
33
else
	44
}

while c5 {
	55
else
	no
}

WHAT = 1
WHAT
what
What

{
	x:1,
	'y':2
}

(1+2)

todo
ENUM = {
	ONE: 1
	TWO: 2
	THREE: {
		FOUR: 4
	}
}



5++
--1 + 2
3++ - 7
3++ + 7
++3 + 7
++3 - 7
--3 + 7
--3 - ++7--

unku -> 4815, 123

!What
What!
!what!
>!!! !What.new!

= { what -> }



!x
y!
!z!

?x
x?
?x?

%something

`preparse for all Operator_Decl where `operator #$%#$ {->}`. register their identifier and what kind re/in/post

`



100.00
100.
.11

.:
....$%
.?
...#$%#$..$%
.:.:
|||
.
=
=====
====.==


{ abc, def -> }


!What
What!
!what!()

>!! 2
>! 1
!What.new!

!position.x!
!!position.y!

!!a.b!!


Atom {
	position
	rotation
	a = 1
	b =;
	c
}


Class {
	member1
	member2
}


without { #this -> }


%works
5%5

!a.b!

x = 3 + 5 * 2 - 4 / (1 + 1) ** 2
((3 + (5 * 2))) - (4 / ((1 + 1) ** 2))
(((3 + 5) * (2 - 4)) / (((1 + 1)) ** 2))



y = 3 + 5 * 2 - 4 / (1 + 1)



a.b.c


1 > 2
1 + 2
1 - 2

> Atom
+ Atom
- Atom

> Atom.x
+ Atom.y
- Atom.z

1 - a.x

x = 3 + 5 * 2 - 4 / (1 + 1) ** 2

a ++ * b
a ++ + b
x+++y

operator prefix ++ { right -> }
operator postfix ++ { left -> }
operator circumfix ++ { value -> }

`Atom + Atom `currently broken. To make this work, lass_Decl would need to be moved to #augment_expr

#island
island!
island
funk { -> }
Class {
	computer = Computer.new
	on { -> }
	Computer {}
}

funk(for: 123)

boo = boo { -> }
boo { -> }

abc.def.hij.klm
@c
@a.b
a.@b



./current_scope
../global_scope
.../third_party_scope

`x = $100 `bug parses as [Binary(x = $), \n, 100]

11:11pm

online { -> 132 }
inline -> 456
