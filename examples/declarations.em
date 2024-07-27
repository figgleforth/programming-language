abc = 123

Lost {
	Island {
		Hatch {
			Computer {}
		}
	}

	Plane {
	}
}

lost = Lost.new

computer = Lost.Island.Hatch.Computer.new
hatch = Lost.Island.Hatch.new

hhh = Lost.Island.Hatch # todo) this copies Hatch into hhh, but it should store a Reference instead

hhh_instance = hhh.new
@
