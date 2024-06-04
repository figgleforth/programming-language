obj Base_Object

@: Context

# convenience for getting an object's type. eg: 'Base_Object'
def ? -> string
	@.type
}

# instance equality
def == other: Base_Object -> bool
	@.id == other.@.id
}

def != other: Base_Object -> bool
	not self == other
}

# type equality
def === other: Base_Object -> bool
	@.type == other.@.type
}

def !== other: Base_Object -> bool
	not self === other
}

def >== other: Base_Object -> bool
	@.ancestors.include? other
}

# eg: 'Base_Object(0x00000001049eec38)
def inspect -> string
	'`@.type`(`@.id`)'
}
