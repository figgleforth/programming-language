# Here is how you might define a function
def print_name: str(name: str)
  -> "Hello, [name]!"
end

# This could be the syntax to spawn a new thread
spawn print_name("Alice")

# Spawning another thread
spawn print_name("Bob")

# Wait function could be used to wait for all spawned threads to complete their execution before proceeding
wait() # waits for all spawned threads to finish

# This might be how you define a Thread in Opal
obj Thread: class(func: str(str)) # takes a function reference as constructor argument
  def run: str(input: str)
    # somehow call the func passed in constructor with provided input
    # returns the output from the function
  end
end

# Then we could use it like this:

def greeting: str(name: str)
  "Hello, [name]!"
end

def main
  t1: Thread = Thread.new(greeting)
  -> t1.run("Alice")
  
  t2: Thread = Thread.new(greeting)
  -> t2.run("Bob")
end

obj Opal[1.0]: struct(color: float3)  # versions and float3
end

color: float4 = (1.0, 1.0, 1.0, 1.0)


## interfaces. Objects that implement these interfaces must:
1) declare any variables in the interface
2) declare any stubbed methods in the interface
3) may redeclare an implemented method (such as label below) but it is redundant because the interface provides this method to the object implementing it. The syntax for implementing an interface is not yet been developed.
##

## todo) operators ##

## todo) ideas I’m still thinking about ##

##
composition, for example: (operator for this is yet to be determined)

Sandwich.variables.private # inject all private variables found on the Sandwich object into this file

Sandwich.functions.public # inject all public functions found on the Sandwich object into this file

Sandwich.variables # injects both public and private variables

Sandwich.functions # injects both public and private functions

Sandwich # injects everything, effectively inheriting from it but not actually inheriting from it
##


# maybe object is both a class and struct, and you choose how you want to pass it around. * is reference, otherwise always by value
~~object self: Type~~

! 'your log message'
!! 'your warning message'
!!! 'your error message'


for some_collection_such_as_list
  it # keyword referring to the current item
  at # keyword referring to the current index
  stop # keyword to break out of the loop
  next # keyword to skip to the next iteration, maybe it should be called next?
end
