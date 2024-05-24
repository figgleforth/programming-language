```
file is named spec.sp so code here is scoped to an object named _Spec, inferred from the file name. leading underscore for preventing name collisions. I don't like having to indent for classes, so I want the file itself to be considered a class. Object in this language, actually
```

# set type of self for explicit naming of the file object
self: Island
self: Island + Others
self: Island + Hatch + Others

year: float

# file object constructor
new(year: float)
end

# all code outside of objects and code blocks is scoped to the file object

# the Sapphire object is declared inside the Island object because of the self type assignment
obj Hatch
  new(numbers: int)
  end
end

obj Person
  hint: string
end

obj Others
end

obj Hatch
  # adding `new` to the front of a var declaration is equivalent to declaring a new(numbers: int) constructor
  new numbers: string

  # setter syntax
  new person: Person do
    it # keyword representing `person`
    it.right_handed = true # mutable within this block

    # no return expected
  end

  # getter syntax
  people: [Person] => []
end

def square(value: int) -> int
  _.args # [value: int]
  _.type # (int) -> int
end

new
  _.args # also works in the constructor since it's also a method
  _.type # method signature, in this case _Spec because constructor returns this obj, aka _Spec
end

def square_and_some(a: int) -> float
  a * a / 4.815 # return keyword is optional
end

def save -> bool # method signature is () -> bool
end

def no_args_and_no_return # () -> nil
end

def no_return(name: string) # method signature is (str) -> nil
end

### argument labels
# required when calling method, if present
###

def email(name: string, on day: string) -> string # `on` is the argument label
  "`name`, you must enter the numbers on `day`!" # use `day` to refer to the argument in the method body
end

# use `on` label to refer to the argument in the method call
email('Locke', on: 'Tuesday') # `on:` is required here

email 'Jack', on: 'Tuesday' # omit parens like Ruby

# enums, must begin with `enum` and end with ‘end’. They can also have methods, but because they are stateless methods are perfectly fine. Since the method has signature, as long as it matches the signature of the enum, it is fine.

enum TokenType: int
  identifier
  literal = 2
end

enum Another: string
  def smooth(value: int) -> string
    # must return string to satisfy enum type
    "smoothing `value`"
  end
  brain = 'brain'
end

### variables ###

# type is not required. when present, variable can only be that type. when not present, variable can be any type.

untyped = 1
untyped = "hello"
untyped = (1, 2, 3)

typed := 1
# `typed = "hello"` would fail

static some_static_var: int = 1

first: TokenType = TokenType.literal
second: TokenType = .identifier
third: Another = .smooth(4)
third.value # "smoothing 4"

some_number: int = 1 # public
_one_number: int = 2 # private because _ prefix is used, equivalent to writing `private one_number`

year: int! # ! cannot be nil

def _private_method # because of _ prefix, this method is private
end


# built in types

color: (float, float, float, float) = (1.0, 1.0, 1.0, 1.0)
whatever: (int, int, int) = (1, 2, 3) # etc

# named tuple values
color3: (r: float, g: float, b: float, a: float) = (1.0, 1.0, 1.0, 1.0)
color4 := (w: 1.0, x: 1.0, y: 1.0, z: 1.0)

# access tuple values by index
color.0
color.1
color.2 # and so on
color3.r # .g, .b, etc
color4.w # .x, .y, etc

result: int = multiply(4, 8) # calling some multiply function
year: int = 2023
buoyancy: float = 0.78
question: string = "how cool is that?"
single_quote_string: string = 'single quotes are valid too, and interpolate! `question`'
description: string # uninitialized value is nil
about_me: string = "I was created in `year`" # interpolation
k: range = 0..10
what: (int) -> float # func references look like (input_types, ...) -> return_type
what2: () -> (float, float) # tuple return type

value: float => factor * weight # getter

some_float: float = 16.23
some_inferred_num := 1987 #  := infers the type. placement of the whitespace for the inference colon doesn't matter but this one is preferred as this more closely follows the syntax

# dictionary literal specifying the type of the key as str, and type of value as int. any type can be used in either, except I guess nested dictionary as a key? but maybe that should be allowed to as long as the object can be hashed to a string
dict: {string: int} = {
  some_key: some_integer # keys auto converted to string if they can be
}

dict_ref: dictionary = dict # generic type alias for any dictionary, regardless of key/val types

tuples: (int, int) = (4.8, 1.5) # this can never be confused with a method returning nil because that must explicitly be defined as (nil)(args, ...)

day: string = day_of_week() # method parens may not be omitted, it's one thing I find confusing sometimes in Ruby

enabled?: bool = true # the ? is a valid character for variable and method names, but not object names (eg, Sapphire?) because the ? means the object can be optional whereas the ? in a variable or method name is just part of its name

# ways of calling constructor
assorted1: Sandwich = new(1) # omit object literal when "new"-ing if the type is declared
assorted2: Sandwich = Sandwich(2) # this is fine too
assorted3 := Sandwich(3) # include object literal when inferring type, but omit new keyword

# idea) shorthand for sand: Sandwich = new(4)
sand: Sandwich(4)

sandwiches: [Sandwich] = [...] # initialize your array of Sandwiches here

# type hints)

monday: string = 'Monday'
weekday: string = 'Friday'
dates: Date = .today
times: Time
datetime: DateTime

# variable type here is the signature of a method
takes_string_returns_nothing: (string) -> nil # writing `nil` is not optional as it needs to be explicit to avoid confusion with tuples

# hint) blocks except `self: ` all must begin with their respective keyword and finish with `end` #
# obj ...
# end

for some_collection_such_as_array
  it # keyword referring to the current item
  at # keyword referring to the current index
  stop # keyword to break out of the loop
  next # keyword to skip to the next iteration, maybe it should be called next?
  # if `it` is a tuple, then `it.0` is the first item, `it.1` is the second, etc. or you may access them using their names
end

for some_dictionary
  it.key
  it.val
  stop
  next
end

for 10 # when a number is provided, it will loop that many times.
  it # eg) when looping 10, the it will be 1-10
  at # eg) when looping 10 the i will be 0-9
  next
  stop
end

while locked?
  next # works here too
  stop # works here too
  it # refers to locked?
  at # refers to the current iteration of this loop
end

if condition
end

if locked? || enabled?
end

if locked? or enabled?
end

if locked? && !enabled?
end

if locked? and !enabled?
end

# switch statement using special when keyword
when some_enum
  is .brain
    calculate()
  # when another `is` encountered, signifies end of implied block
  is .identifier
  is .literal: whatever(it) # inline
  is .smooth(4)
    # blocks may be explicit
  end
else
  # this is optional, and acts as the default case
end

def some_method
  do_something if enabled? # if statement may be placed on the same line as the method definition
  some_var := if enabled? # if statement may be used as an expression
    1.0
  else
    0.0
  end
end

# other blocks
some_collection_such_as_array.each # no need to add `do |variable|` like in Ruby
  it
  at
  stop
  next
end

collection.where # like Ruby's select and filter, but combined into one
  it
  at
  stop
  next
end

squared := [1, 2, 3].map
  it * it
  # at, stop, next are also available. stop would bail on the map and could cause the mapped object to have less elements due to early bail.
end

only := collection.where
  it == 1
end

# and so on for filter, etc. though the names of these methods may change

_.log result # arrow is shorthand for debug printing to console
_.log 'nice' if enabled? # print 'nice' if enabled?
_.log result + 4, "the result is `result`" # takes an array of expressions, prints each on a new line
_.warn 'some warning' # debug print warning
_.error 'some error' # debug print error

# hint) reading from console. when the line with _.input is executed, the program waits for input from the console. when the user presses enter, the input is stored in the variable on the left side of the _.input operator
favorite_thing := _.input

# interfaces
# objects that use api interfaces must implement any stubbed methods in the interface
# usage is with +, because you are composing the object with the interface
# ```
# obj ObjectReceivingComposition + SomeComposingAPI
# ```
# ```
# obj ObjectReceivingComposition + SomeComposingAPI, AnotherComp, AnotherAndSoOn
# ```
# interfaces are called APIs, and start with the api keyword. the block is its body

api SpaceStone
  mass: float
  ancestor: SpaceStone
  private value: float # private!

  def weight: float # stubbed because It has no block body
  def calculate_something(float) -> int
  def label: string
    "it weighs `mass`!"
  end
  private def do_something # this method is private. privacy is controller per method unlike Ruby
    # stubbed method to be implemented
  end
end

obj SomeStone
  + SpaceStone # means this object is composed of a SpaceStone, this here is composition, not inheritance
  # must implement stubbed methods, otherwise receives variables and completed methods for free

  def weight: float
    # stubbed method to be implemented
  end

  private def do_something
    # stubbed method to be implemented
    ancestor.calculate_something(4.8) # ancestor is defined in the SpaceStone api
  end
end

# hint) built-in error api
  Errors are not automatically raised, instead they are passed by value and you are able to choose whether you want to raise or print the error

api Error # compose with this to make custom errors
  def message: string
end

obj NotImplemented + Error # you may add anything to the body so long as the stubbed method is implemented, even if it is calculated like message here with the => keyword
  def message: string => 'You did not implement this or whatever'
end

# hint) composition, no inheritance, period. only composition
# the reason for this + key symbol is because the object and its composition declarations are very pleasing to read. the + symbol also implies adding stuff together
# ```
# obj Something
#   + ComposeThis
#   + ComposeThat
#   # etc
# end
# ```
# look at how beautiful that is. even the short form is neat
# ```
# obj Something + ComposeThis, ComposeThat
# end
# ```
# works at file level too, notice no object block and no indent, even though the comment indent makes it look indented lol
# ```
# + SpaceStone
# + ComposeThis, ComposeThat
# ```

# this file object's api implementations:
def weight: float
  # must implement according to api
end

private def do_something
  ancestor.calculate_something(4.8)
end # must also be implemented at file object level if it is composed of SpaceStone

# hint) execute any code in the file, the file doesnt need to become an object. first all variables and methods are loaded, then any code inside the file is run
whatever := get_something()

# hint) static every object basically gets instantiated once at runtime anyway (maybe that is bad for big projects, tbd) so you get that object for free and it is used like YourObject  to reference the static instance. works with inferred object names where obj keyword was not used: Util_Math # inferred from file util_math.hh

obj Transform
  + Position
  + Rotation
  + Sapphire/Scale # namespaces are filepath based, not needed here since all apis are here in this file
  # this object gets the rotation methods for free vis composition
  # its namespace is whatever folder it is in: eg$ project://components/transform.hh would make this Components/Transform
end

# override namespace
obj CoolNamespace/Planet
  # file can be anywhere in the project and it's namespace will be set to CoolNamespace instead of being inferred from the directory structure
end

obj //Star
  # force global namespace regardless of file location
end

api Scale
  scale := float3(1, 1, 1)
end

api Rotation
  rotation := float3(0, 0, 0)

  def look_at(target: Transform) -> Rotation
    # some implementation
  end
end

api Position
  position := float3(0, 0, 0)
end

api Transformable
  + Transform
end # composition of compositions

# scratch object, scoped to current file, with _ keyword useful for temp variables
_.whatever: int = 421
_.log _.whatever # can be accessed again

_ := some_waste # this does not override the scratch object

# accessing scope information
_.scopes[0] # current scope
_.scopes[1] # the scope before this one
_.scopes[3] # and so on
# return empty scope object when there's no further scope
