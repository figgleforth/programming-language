Player > Atom {
	number = -1
	player = 69 + 12 / -123 * 4 % 6
	whatever;
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

}

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

like_this = {
	input = 69 -> 'whatever'
}


{
	whatever
}

GAME_LOOP_STATE {
	UPDATE = 0
	RENDER = 69 + 12 / -123 * 4 % 6
	WHENCE = 'yes'
}

TESTING {}
