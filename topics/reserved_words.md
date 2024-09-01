In this language I'm using capitalization to differentiate between types of identifiers, instead of making you type annoying words like `class` and `def` — although I'll admit that `func` is a cool word.

[Here's a sample program](../examples/reserved_words.em) that lexes and parses successfully but I have not tried interpreting it because the interpreter is broken 😎

```
`examples/reserved_words.em

Computer { `class
   TEST = [4, 8, 15, 16, 23, 42] `constant
	PERIOD_IN_SECONDS = 60 * 108  `108 minutes
	BUFFER_IN_SECONDS = 60 * 4    `4 minutes
	
	elapsed = 0.0 `variable
	
	update { delta -> `function which takes one argument
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
```
