a.b.c = 0

Atom {
	&Pos
	&Rot

	whatever =;
}

Player > Atom {
	&Transform # & will merge Transform into this object, it merges all its members and functions, including the ones that were merged into it beforehand
	transform = &Transform # this is currently parsing as a variable assignment
	number = -1
	player = 69 + 12 / -123 * 4 % 6
	whatever =;

	character = CHARACTER.GUY
}

Sokoban {
	CHARACTER {
		GUY
		PLATFORM
	}
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
	input = 69 -> 'whatever'
}

sixty_nine = { 69 + 12 / -123 * 4 % 6 }

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
	RENDER = 69 + 12 / -123 * 4 % 6
	WHENCE = 'yes' # todo: need to .expressions[0]
}

TESTING {}


next_level { player
# todo: unhandled +=
#	player.level += 1
}


# adds members of this object to the local scope but they reference the arg player. allows you to do:
gain_level { player ->
	&player
	&works.on.nested.too # todo: this parsed as `exprs(1): ["BE(BE(BE(&works . ident(on)) . ident(nested)) . ident(too))`
#	level += 1 # equivalent to player.level when not using &. it's the programmer's responsibility to make sure they don't & args with clashing members. #raise when that happens
}

more { &one, &two = 2, three = 3 -> # todo: the & in params isn't treated as a comp technically, but the interpreter can figure it out
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
	atom = &Atom # this should merge the two scopes but also allow prefixing the scope with atom.
}

_function {
	&Atom
	 _ANOTHER_ENUM = 5
	_ANOTHER_ENUM {}
}

#_ANOTHER_ENUM = 'yet'

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
	&Transform
}

Lilly_Pad {
	&Entity

	speed = 1.0

	inspect { "Lilly(at: `position`, speed: `speed` units" } # position directly accessible because it was merged into this object with the &Entity statement
}

this? = :test


Enum_Collection_Expr {
	&Ast_Expression

	name =;
	constants =;

	to_s {
#		if short_form
#			"enum{`name`, constants(`constants.count`)}"
#		else
#			"enum{`name`, constants(`constants.count`): `constants.map(:to_s)`}"
#		}
	}
}


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
	~Physics
}

Audio_Player {
	&Entity
	~Inventory
	~Physics
	~Renderer
	~Rotation
}

Entity > Object {
	inventory = &Inventory
	&Physics

	name =;
	move_speed =;

	go { to position ->
		inventory.position = position
	}
}

go(to: 123)

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
imaginary(object: Xyz {}, enum: BWAH {}, func: whatever {}, member: shit)


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

while a > 0
	# ...
elswhile a < 0
	# ...
else
	# ...
}

while true
}, while false
}, while
	shit
}

go(wtf =;) # this shouldn't be possible
