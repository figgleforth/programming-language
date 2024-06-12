nice = 69, naughty = 96, -100
69 + 12 / -123 * 4 % 6
(1 + -2)
-3

omg = :boo

nothing ::
	nice = 69 + 12 / 123 * 4
}

something :: string # could be return type or param
}

something :: claps # pre interpreter can determine which it is
}

accuracy :: claps, shots
}

operation :: with value
}

calculate :: using mode, with amount
}

Empty ::
}

Atom ::
	id
	type
	created_at = Date_Time.now
}

::} # object block
::} # method blocks
:=} # lambda block

# no such thing as a base class. Every object is either itself or self composed with other objects.
Base :> Atom
	iterate ::
		doubler = :: it * 2 }
		items.map doubler

		items.map :: it * 2 }

		items.map ::
			it * 2
		}
	}



	square :: input
		input * input
	}

	something ::
	}

	operation :: with value
	}

	calculate :: using mode, with amount
	}
}


Collection ::
	elements: array
}


Array :> Atom, Collection
	include? :: element
	}
}
