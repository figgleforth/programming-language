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

# Notes about object declaration:
# - Use `self:` declaration at the beginning of a file to make the file itself an object.
# - Note that only one `self: ` declaration can be present in a file, the above example is for demonstration purposes only.
# - It is very important that `self: obj Name` does not have a block otherwise it will fail with a syntax error.
# - Regardless of presence of `self:`, top-level expressions directly in the file are valid.
# - Inner objects use blocks for their bodies, regardless of the presence of the `self:` declaration.
# - Inner objects can be declared inside of other objects, even inside a file that is declared an object using `self: `
# - Regular objects start with `obj`, while file objects start with `self:`, very important.

# Notes about composition:
# - Inheritance does not exist in Hatch
# - To compose objects, use `+` followed by the object's name, either inline or on a new line.
# - Examples:
#     obj Stone + SomeComposition, AnotherComposition
#     end
#
#     self: obj Hatch + SpaceStone (notice there is no `end` keyword here because it is a file object declaration)

# Notes about initializers, and params as they relate to methods in general:
# - Objects can have initializers, specified by the `new` keyword followed by method body.
# - To initialize a parameter automatically, use the `@@` symbol before the parameter name and mention the parameter by its name
# - Example of automatic initialization:
#     obj Stone(weight: float)
#       weight: float = @@weight # weight is mentioned by name, if the param were called mass, you would say `weight: float = @@mass`
#     end
#
# - Initializer method, works for both inner objects and top-level for the file object. Example:
#     new(weight: float)
#     end
