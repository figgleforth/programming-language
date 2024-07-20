CHARACTER {
	GUY
	ENEMY
}

Thing {
	# compositions
	* Atom # merges all of Atom's declarations into Thing, does not inherit type Atom
	& Atom # merges all of Atom's declarations into Thing, inherits type Atom

	~ Transform # removes Transform's declarations, if present

	& CHARACTER # works with enums. No need to prefix GUY or ENEMY with CHARACTER dot

	# Objects can simultaneously be as many types as they want to compose with. I think I want that to work with enums as well.
}


# idea: docs syntax, reference :Atom class identifier in documentation with a colon.
Atom {
	& Pos
	~ Rot

	whatever =;
}

Player { & Atom as atom }

Thing {
	* Atom
}

Player > Atom {
	& Transform
	~ Transform

	number = -1
	player = 96 + 12 / -123 * 4 % 6
	whatever =;

	character = CHARACTER.GUY

	& CHARACTER
	character = GUY
}


Entity {
	character =;
	name =;
	position =;

	# class var
	self.references.count = 0

	# class func
	self.do_something { -> }

	self.inspect { -> "Entity(`self.refs`)" }

#	inspect: string { -> }
}


player.?current_level = 1 # .? is like  &. in Ruby. I want the dot to go first since that feels more like accessing a member or whatever. the / is just the next key on the keyboard so it flows. I want this language to feel as smooth as possible.

if player.?current_level { # also works like ruby's #respond_to?
}

nice { param, param_with_default = 1 -> "body" }

cool { param, param_with_default = 1 ->
	"body"
}

yolo = { -> 96 + 12 / -123 * 4 % 6 }

func_without_params { ->
	"body!"
}

empty { -> }
Empty {}

lost = { in = 42 -> }

{
	-> whatever
}

GAME_LOOP_STATE {
	UPDATE = 0
	RENDER = 96 + 12 / -123 * 4 % 6
	STRING = 'yes'
}

TESTING {}

(a + b) * c
!a
-a + +b
a ** b
a * b / c % d
a + b - c
a << b >> c
a < b <= c > d >= e
a == b != c === d !== e
a & b
a ^ b
a | b
a && b
a || b
a = b
a += b
a -= b
a *= b
a /= b
a %= b
a &= b
a |= b
a ^= b
a <<= b
a >>= b
a, b, c
player = 96 + 12 / -123 * 4 % 6
a.b.c = 0
1 ----------- 2
1 +++++++ 2
1 - --2
1 & 1


next_level { player ->
	player.level += 1
}

gain_level { player ->
}

STATUS {
   WORKING_ON_IT = 1
   NOT_WORKING_ON_IT
}

Emerald {
   version = 0.0
   bugs = 1_000_000
   status = STATUS.WORKING_ON_IT

   info { ->
      "Emerald version `version`"
   }

   increase_version { to ->
      version = to
   }

   change_version { by delta ->
#      version += delta
   }
}

first.?middle.?last

_SOME_ENUM {}

SOME_CONST = 1

_Emerald {
	& Atom
}

_function { ->
	& Atom
	 _ANOTHER_ENUM = 5
	_ANOTHER_ENUM {}
}

COLLECTION {
	ONE, TWO = 2
	THREE {
		FOUR = 4, FIVE {
			ZERO = 0
		}, SIX {}
	},
	SEVEN = Atom.new
}

COLLECTION.THREE.FIVE

Transform {
	position =;
}

Entity {
	~ Transform
}

Lilly_Pad {
	speed = 1.0
	inspect { -> "Lilly(at: `position`, speed: `speed` units" }
}

this? = :test # Ruby's symbol literals

Enum_Collection_Expr {
	& Ast_Expression

	name =;
	constants =;

	to_s { ->
	}
}


# multiple keywords for else-if
if 1 > 2 {
	aaa
	bbb
elsif 4 > 3
	ccc
elif 5 > 3
	ddd
	eee
	fff
else
	ggg
}

Shop > Entity {
	~ Physics
}

Audio_Player {
	& Entity
	~ Inventory
	~ Physics
	~ Renderer
	~ Rotation
}

Entity > Object {
	name =;
	move_speed =;

	go { to position -> # to is the label for position when calling this function
		inventory.position = position
	}
}

go(to: 123) # the label being used. Should it be required when the function is defined with it?

method { -> }
method2 {  -> 48 }
method3 { input -> "`input`" }
method4 { in1, in2, in3, in4, in5 -> "boo!" }
method5 { on input -> "`input`" }

method
method2()
method3('yay')
method4(4 + 8, Abc {}, WHAT {}, whatever {}, 32)
method5(on: 'bwah')
imaginary(object: Xyz {}, enum: BWAH {}, func: whatever {}, member: nice)


if 1 > 2 {
	aaa
	bbb
elif 4 > 3
	ccc
elif 5 > 3
	ddd
	eee
	fff
elif 100_000
	hhh
else
	ggg
}

while 4 > 3
	skip
	stop, skip, whatever
	1 + 2
	go!(48), yay
}

# if-else style while loops
while a > 0
	abra
elswhile a < 0
	ca
}

# separate statements because they are comma-separated
while true
}, while false
}, while
	nice
}

# making sure that this parses properly
a[b[c]][1][abc[2 + 3]] + 4
a[b[c]][1][abc[2+3]+4]
a[1+2][b[c[3]]][d+e][f-g]
a[1+2][b[c[3]]][d+e][f-g]

[1, 2, 3+4,while true
}, while false
}, while
	nice
}, Abc{}, DEF{}, def{ -> }, {}, [], a[0], Player > Atom {
	& Transform # & will merge Transform into this object
	number = -1
	player = 96 + 12 / -123 * 4 % 6
	whatever =;

	character = CHARACTER.GUY
}]



a[1+2][b[c[3]]][d+e][f-g]

some_var[]

[]

wtf =;
go(wtf =;)

Atom {
	& Entity
	& Transform
}

[[]]

Record {
	& Columns
	& Querying
	& Persistence
	& Validations
}

Readonly_Record {
	& Record
	~ Persistence
	~ Validations
}

Readonly > Record {
	& Querying
	& Columns
	~ Persistence
	~ Validations
}

records = Record.where { -> it.something == true }
records = Readonly.where { -> it.something == true }

test { with &a = 1, where b = 2, c, d = variable= 1 ->
	# params with & are going to have their variables and functions merged into this scope, meaning instead of a.some_variable, you can just use some_variable
}

[1, "asdf"]

1.0
1.
0.1
.1

test { abc &this = 1, def that, like = 2, &whatever  ->
}

&test
&Test

User.where { ->
	it.created_at > Date_Time.today
}

User.where { ->
	created_at > Date_Time.today and posts.count > 0
}

double { value -> value * 2 }

spicy = { input = 96 ->
	@before check_spicy_function
	'whatever'
}

check_spicy_function { arguments -> }

{ in = 42 ->
	'anon block'
	yay
}

test = true
test = false

Atom > What {}

[].each { ->
}

"boo".tap { ->
	it += 'oo'
}

"".map { ->
	it += 'nice'
}

[1, 2].where { ->
	it == 2
}

tap { -> } # valid, but pointless

%s(boo hoo moo) # [:boo,  :hoo,  :moo]
%S(boo hoo moo) # [:BOO,  :HOO,  :MOO]

%v(boo hoo moo) # ['boo', 'hoo', 'moo']
%V(boo hoo moo) # ['BOO', 'HOO', 'MOO']

%w(boo hoo moo) # ["boo", "hoo", "moo"]
%W(boo hoo moo) # ["BOO", "HOO", "MOO"]

%d(boo hoo moo) # {boo: nil, hoo: nil, moo: nil}

{ x: 1 }
{ x = 1 }


span = 1..23 # inclusive end, starts at left expression
less = 5.<67 # exclusive end, starts at left expression


#Nice {
#	new { # executes before the .tap call below
#	}
#}

Atom.new()
Atom.new

Atom.tap {}
Atom.tap {}

f { x = 3*4 -> x*3 }
f(4)

x { in -> in }
x()

x { in = nil -> in }
x()

x { in = 1 -> in }
x()


Atom.new

Atom {
	&Atom
	& Atoms as atoms
	func { &this, & that = true -> } # composition valid with or without whitespace after &
}
