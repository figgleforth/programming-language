# This could be the syntax to spawn a new thread
spawn print_name("Alice")

# Spawning another thread
spawn print_name("Bob")

# Wait function could be used to wait for all spawned threads to complete their execution before proceeding
wait() # waits for all spawned threads to finish

# This might be how you define a Thread in Emerald

# Then we could use it like this:

def greeting(name: str) -> string
  "Hello, [name]!"
}

def main
  t1: Thread = Thread.new(greeting)
  -> t1.run("Alice")

  t2: Thread = Thread.new(greeting)
  -> t2.run("Bob")
}

obj Emerald[1.0]: struct(color: float3)  # versions and float3
}

color: float4 = (1.0, 1.0, 1.0, 1.0)

! 'your log message'
!! 'your warning message'
!!! 'your error message'
