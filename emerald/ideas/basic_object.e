self: Basic_Object

def !
	false
}

def ? # convenience for getting an object's type. Object.new.? yields string 'Object'
	self.@.type
}

# instance equality
def == other
	self.@.id == other.@.id
}

def != other
	not self == other
}

# type equality
def === other
	self.@.type == other.@.type
}

def !== other
	not self === other
}

# printing an instance of this yields string 'Basic_Object(`id`)' unless you override the `to_s` method
def to_s -> string
	'`?`(`self.@.id`)'
}
