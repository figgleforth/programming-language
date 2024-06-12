Player > Atom {
	number = -1
	player = 69 + 12 / -123 * 4 % 6
	whatever;
	level;
	character = CHARACTER.GUY
}

Sokoban {
	CHARACTER {
		GUY
		PLATFORM
	}

}

Entity {
	character;
	name;
	position;

# todo: unhandled `self`
#	self.refs = 0 # class variable

#	self.add_ref { # class function
#		refs++
#	}

#	self.inspect { "Entity(`self.refs`)" }

}



player./current_level = 1 # ./ is like  &. in Ruby. I want the dot to go first since that feels more like accessing a member or whatever. the / is just the next key on the keyboard so it flows. I want this language to feel as smooth as possible. .? is also supported since that's the first symbol I decided on, but it's annoying to type.
player.?level

#if player./current_level # also works like ruby's #respond_to?
#}



Leaf > Entity {
	name = 'Lilly'
	character = CHARACTER.PLATFORM
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

lost = { in = 42 -> }

{
	whatever
}

GAME_LOOP_STATE {
	UPDATE = 0
	RENDER = 69 + 12 / -123 * 4 % 6
	WHENCE = 'yes'
}

TESTING {}


next_level { player
# todo: unhandled +=
#	player.level += 1
}


# adds members of this object to the local scope but they reference the arg player. allows you to do:
gain_level { player ->
	&player
	&works.on.nested.too
#	level += 1 # equivalent to player.level when not using &. it's the programmer's responsibility to make sure they don't & args with clashing members. #raise when that happens
}

more { &one, &two = 2, three = 3 ->
}

first./middle./last
