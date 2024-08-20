` You just have to know the absolute path of everything you are referencing

Island {
	Hatch {
		Computer {}
	}

	Cave {
		Water_Source {}
	}
}

` the pink I previously liked: #ffb198

Other_Island {
	Laboratories {}
}

America {
	Los_Angeles {
		Airport {
			depart { ->
`				>! "see ya"
				return see ya
			}
		}
	}
}


cool = true
Abc {
	cool = true ` if this were defined in here, the cool in the global scope would not get changed. If you comment this cool out, then the global cool does get changed.
	double_if_two { x = 1234 ->
		if x == 2 {
			cool = false
			return 4
		}

		69
	}
}

`raise "cool should have stayed true" unless cool == true

whatever { -> }

`>! Abc.new.double_if_two(123)
poop = { -> Abc.new.double_if_two(2) }
poop()
`raise "expected 4" unless ohboy == 4
