{ -> }


abc
123
1_000
1.0
1.
.2
"tied to a tree in a jungle of mystery"
'freckles'
{ -> }
{ abc -> }
funk { -> }


Class {
}

inline ~> 'lost'
inline()

funkocomp { %four = 4, eight = 8, forty two = 2 % 3, abc = def ->
}

f { %x ->
	'do something'
}

x = 1
island.hatch

`x = $100 `todo this comes up as [Binary(x = $), \n, 100]
y = (1, 2)
z(x: 3, y = 4)

()


{->}

@{ 1, 2, 3 }
@{ x, :, 4, y, :, 8, 5 } `hashes must always use : because it is easier to identify instead of allowing both
@{ x + y : 420 }

`it would be nice to } treat Hash and Set as the same
`{x:1, y}.x should = 1
`{x:1, y}.y should raise
`so from the user's perspective, it doesn't matter if it's a hash or set. you can use it as either, or as both
`It should be Set_Literal_Expr. And that is what hash and sets will be known as

[]
[1]
[1, 2]
[x = 3, y = 4]

@{}
@[1, 2]
@(x=123, 'yolo')
@{a, b, c, d}

{
	1: 2
}

abc.def.{}

Dafunk {
	funk `at class scope, identifiers without assignment are treated as nil assignment
}

```
Transform { `that allows for nice looking data structures. You could pretend this is a struct. It really doesn't matter here because everything's a hash on the inside.
	rotation, position
}
```

(1 + 2) - 3

funk()
()
funky(4, 5, for: 6)

(7, 8, for,:, 9)


(1, 1, 2)
@(1, 1, 2)

`Class {
`	"" route { ->
`	} `Route_Decl
`} ` any class can respond to a route as long as a server is configured somehow. syntax tbd


1..2
3.<4

Class {}
funk {
	%bwah -> 123
}

raise !

!1

!()
@#$23234

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

`todo
`ENUM = {
`	ONE
`	TWO = 2
`	THREE = {
`		FOUR: 4
`	}
`}



5++
--1 + 2
3++ - 7
3++ + 7
++3 + 7
++3 - 7
--3 + 7
--3 - ++7--

unku ~> 4815, 123

!What
What!
!what!
>!!! !What.new!

`todo
`= { what -> }
`operator + { -> }


!x
y!
!z!

'asdfasdfasdfasdfa'

?x
x?
?x?

%something
`%.something `runtime error because dot operators

```
preparse for all Operator_Decl where `operator #$%#$ {->}`. register their identifier and what kind pre/in/post


```



100.00
100.
.11

`.:
`....$%
.?
`...#$%#$..$%
`.:.:
|||
.
=
=====
====.==

xyz.{->}
xyz().{->}

{ abc, def -> }


!What
What!
!what!()

>!! 2
>! 1
>!!! !What.new!

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


without { % this -> }


%works
5%5

!a.b!

x = 3 + 5 * 2 - 4 / (1 + 1) ** 2
`((3 + (5 * 2))) - (4 / ((1 + 1) ** 2))
`(((3 + 5) * (2 - 4)) / (((1 + 1)) ** 2))



y = 3 + 5 * 2 - 4 / (1 + 1)



a.b.c

abc.def.hij.klm
a.@b.c
@a.b
a.@.b
a.@b
@c
