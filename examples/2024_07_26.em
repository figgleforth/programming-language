Lost {
	Island {
		Computer {
			model = 'c64'
		}

		Hatch {
#			old_pc =;   # assigned nil
			pc =        # also valid nil assignment. When there's no expression between = and \n then the assumed intent is that you want to assign a nil value

			# both -> and :: can be used in block declaration to separate params (left) and the body (right)

			open { ->
				pc = Lost.Island.Computer.new
			}

			# I find :: easier to type than -> so both are valid symbols that indicate the bode of the block is next
			close :: pc = nil # this is short form – here you can't declare params and only one expression is allowed

			# oneliners that do nothing
			nothing {->}
			another_nothing {::}

			open() # you can call any functions in this scope
		}

		hatch = Hatch.new
	}
}

hatch = Lost.Island.Hatch.new
island = Lost.Island.new
hatch.close()

Mac {
	model=
}

mac = Mac.new
mac2 = Mac.new

mac.model = 'M2'
Mac.model = 'M8'

#if Mac.model == mac.model { oops "Expected macs to have different models" }

TV {
	show = 'Lost'
}

WC = 123
VR = TV
television = TV.new
TV.show = 'KOTH' # updating the static
def = TV.new

raise "Expected def.show to be KOTH" unless def.show == 'KOTH'

raise "shit" unless true
