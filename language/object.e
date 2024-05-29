self: Object

def !
	false
}

def ?
	@.type
}

def == other
	@.id == other.@.id
}

def != other
	not self == other
}

# checks types only
def === other
	@.type == other.@.type
}

def !== other
	not self === other
}
