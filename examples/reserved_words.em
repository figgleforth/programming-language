Computer { `class
   TEST = [4, 8, 15, 16, 23, 42] `constant to save the world
	PERIOD_IN_SECONDS = 60 * 108  `108 minutes
	BUFFER_IN_SECONDS = 60 * 4    `4 minutes

	elapsed = 0.0

	update { delta -> `this function takes one argument
		elapsed += delta

		if elapsed >= PERIOD_IN_SECONDS
			destroy() `as in, destroy this instance
		}
	}

   execute { sequence ->
      if not within_sequence_window or !within_sequence_window `for you traditional programmers
         return
      }

      if sequence == TEST
         elapsed = 0.0
      }
   }

   `shorthand functions
   within_sequence_window -> elapsed >= (PERIOD_IN_SECONDS - BUFFER_IN_SECONDS)
   ping -> 4815162342
}

computer = Computer.new
sequence = [4, 8, 15, 16, 23, 42]

while computer.ping
	computer.update(1.0/60.0)
	if randf() <= 0.04815162342 { sequence[5] = 43 }
	computer.execute(sequence)
}
