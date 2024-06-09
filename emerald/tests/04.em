nice = 69, naughty := 96, -100
69 + 12 / -123 * 4 % 6
(1 + -2)
-3

nothing ::
	nice = 69 + 12 / 123 * 4
end

something :: string # could be return type or param
end

something :: claps # pre interpreter can determine which it is
end

accuracy :: claps, shots: int
end

operation :: with value: int
end

calculate :: using mode: Mode, with amount: float :: string
end

Empty :>
end

Atom :>
	id: int
	type: any
	created_at := Date_Time.now
end

# no such thing as a base class. Every object is either itself or self composed with other objects.
Base :> Atom
	nothing ::
		nice = 69
	end

	something :: string
	end

	operation :: with value: int
	end

	calculate :: using mode: Mode, with amount: float :: float
	end
end


Collection :>
	elements: array
end


Array :> Atom, Collection
	include? :: element: any :: bool
	end
end
