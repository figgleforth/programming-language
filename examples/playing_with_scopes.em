Lost {
	Island {
		Computer {
			model = 'c64'
		}

		Hatch {
			old_pc =;   ` assigned nil
`			pc =        ` also valid nil assignment. When there's no expression between = and \n then the assumed intent is that you want to assign a nil value

			open { ->
				pc = Lost.Island.Computer.new
			}

			` oneliners that do nothing
			nothing {->}
			another_nothing {->}

			open() ` you can call any functions in this scope
		}

		hatch = Hatch.new
	}
}

hatch = Lost.Island.Hatch.new
island = Lost.Island.new
hatch.close()

Mac {
	model
}

mac = Mac.new
mac2 = Mac.new

mac.model = 'M2'
Mac.model = 'M8'

`if Mac.model == mac.model { oops "Expected macs to have different models" }

TV {
	show = 'Lost'
}

WC = 123
VR = TV
television = TV.new
TV.show = 'KOTH' ` updating the static
def = TV.new

`raise "Expected def.show to be KOTH" unless def.show == 'KOTH'

`raise "shit" unless true
