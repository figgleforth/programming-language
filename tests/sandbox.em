# docs syntax, reference :Atom class identifier in documentation with a colon.
Atom {
	# compositions
	& Entity # merges all of Entity with Atom
	~ Transform # if Entity is composed with Transform, this removes Transform from Atom
	& CHARACTER # CHARACTER is some enum, so this composition removes the need to prefix the enum constants with CHARACTER.
}


Atom {
	& Pos
	~ Rot

	whatever =;
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

CHARACTER {
	GUY
	PLATFORM
}

Entity {
	character =;
	name =;
	position =;

	# class var
	self.references.count = 0

	# class func
	self.do_something {}

	self.inspect { "Entity(`self.refs`)" }
}


player./current_level = 1 # ./ is like  &. in Ruby. I want the dot to go first since that feels more like accessing a member or whatever. the / is just the next key on the keyboard so it flows. I want this language to feel as smooth as possible.

if player./current_level # also works like ruby's #respond_to?
}

nice { param, param_with_default = 1 -> "body" }

cool { param, param_with_default = 1 ->
	"body"
}

spicy = {
	input = 96 -> 'whatever'
}

yolo = { 96 + 12 / -123 * 4 % 6 }

func_without_params {
	"body!"
}

empty {}
Empty {}

lost = { in = 42 -> }

{
	whatever
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
#a ? b : c # todo


next_level { player
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

   info {
      "Emerald version `version`"
   }

   increase_version { to ->
      version = to
   }

   change_version { by delta ->
#      version += delta
   }
}

first./middle./last

_SOME_ENUM {}

# todo: abc ?? xyz # abc if abc, otherwise xyz

SOME_CONST = 1

_Emerald {
	& Atom
}

_function {
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
	inspect { "Lilly(at: `position`, speed: `speed` units" }
}

this? = :test # Ruby's symbol literals

Enum_Collection_Expr {
	& Ast_Expression

	name =;
	constants =;

	to_s {
	}
}


# multiple keywords for else-if
if 1 > 2
	aaa
	bbb
elsif 4 > 3
	ccc
elif 5 > 3
	ddd
	eee
	fff
ef 100_000
	hhh
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

method {}
method2 { 48 }
method3 { input -> "`input`" }
method4 { in1, in2, in3, in4, in5 -> "boo!" }
method5 { on input -> "`input`" }

method
method2()
method3('yay')
method4(4 + 8, Abc {}, WHAT {}, whatever {}, 32)
method5(on: 'bwah')
imaginary(object: Xyz {}, enum: BWAH {}, func: whatever {}, member: nice)


if 1 > 2
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
else
	dabra
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
}, Abc{}, DEF{}, def{}, {}, [], a[0], Player > Atom {
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

records = Record.where { it.something == true }
records = Readonly.where { it.something == true }

test { with &a = 1, whence b = 2, c, d = variable= 1 ->
	# params with & are going to have their variables and functions merged into this scope, meaning instead of a.some_variable, you can just use some_variable
}

[1, "asdf"]

1.0
1.
0.1
.1

1.2.3.4 # todo, this is still parsing as a number

test { abc &this = 1, def that, like = 2, &whatever  ->
}


&test
&Test

User.where {
	it.created_at > Date_Time.today
}

User.where {
	created_at > Date_Time.today and posts.count > 0
}

double { value -> value * 2 }

# todo: runtime hooks for function calls. Haven't decided on syntax yet
#before double { arguments -> # arguments would be something like [{ name: value, type: float/int/whatever }]
#}
