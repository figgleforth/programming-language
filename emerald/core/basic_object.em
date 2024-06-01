obj Basic_Object

context: Context as @

# logical not. should figure out why this is useful. this is what Ruby does so I included it
def ! -> bool
	false
}

# convenience for getting an object's type. Object.new.? yields string 'Object'
def ? -> string
	self.@.type
}

# instance equality
def == other -> bool
	self.@.id == other.@.id
}

def != other -> bool
	not self == other
}

# type equality
def === other -> bool
	self.@.type == other.@.type
}

def !== other -> bool
	not self === other
}

def inspect -> string
	'`@.type`(`@.id`)'
}
