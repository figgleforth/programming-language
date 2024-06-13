One {
}

Two {
}

Three {
	&One
	&Two
}

Five {
	&Two
	&Three
}

Four {
	&Five
	~One
}

# todo: add difference and intersect as well. this would make building classes so easy

Entity {
	&Inventory
	&Physics
	&Position
	&Renderer
	&Rotation

	move { to position -> }
}

Shop > Entity {
	~Physics
}

Audio_Player > Entity {
	~Inventory
	~Physics
	~Renderer
	~Rotation


}

