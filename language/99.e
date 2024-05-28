###
file is named spec.ro so code here is scoped to an object named _Spec, inferred from the file name. the leading underscore is used to prevent name collisions with user-defined objects. I don't like indenting so this supports top level code
###


self: Island # set type of self for explicit naming of the object that owns the top level scope of this file. there is no global scope right now, and I don't know if I'll add that. 5/2024

self: Island + Hatch + Others # note; setting type of `self` is only allowed top level

new(year: float) # top level constructor
}

#
obj Hatch
	door: Hatch/Door ###
	 / namespace syntax only allowed where types are used. so a declaration like the following is invalid
		  hatch/door: Door
	###

	def open => door.open

	def close
		self.door.close # self refers to object of this current scope
	}
}

obj Hatch/Door # equivalent to declaring this inside of Hatch. but it can also be any literal, like This/That and that would be valid
	def open
	}

	def close
	}
}

# all code outside of objects and code blocks is scoped to the top level

# the Emerald object is declared inside the Island object because of the self type assignment
obj Hatch
	new(numbers: int)
	}
}

obj Person
	hint: string
}

obj Others
}

obj Hatch
	arg numbers: string # arg keyword is equivalent to declaring the argument in the constructor

	arg person: Person
		# block that runs whenever person= is called

		it # represents this `person`
		it.right_handed = true # mutable within this block

		# no return expected
	}

	# => can be used in place of a block expression, when the block would have a single line
	people: [Person] => []

	###
	multiline expressions using => are not valid

	people: [Person] =>
		peeps = []
		peeps << Person()
	###
}

# Context object may have useful info, but also acts as scratch object. can be accessed using _ symbol
obj Context
	args: []
	scopes: [] ###
		_.scopes[0] # current scope
		_.scopes[1] # the scope before this one
		_.scopes[3] # and so on
	###

	# function literal represents any type of method signature
	type: function # returns like (int) -> int or () -> float or () -> nil, etc

	def log; # use ; to stub a method
}

def square(value: int) -> int
	_.args # [value: int]
	_.type # (int) -> int
	_ = not_needed_method_call_result
	not_needed_method_call_result # or just don't store the result
}

def square(value: int) -> int
	value * value
}

new
	_.args # also works in the constructor since it's also a method
	_.type # method signature, in this case _Spec because constructor returns this obj, aka _Spec
}

def square_and_some(a: int) -> float
	a * a / 4.815 # return keyword is optional
}

def save -> bool # method signature is () -> bool
}

def no_args_and_no_return # method signature is () -> nil
}

def no_return(name: string) # method signature is (str) -> nil
}

# argument labels

def email(name: string, on day: string) -> string
	# external argument label, allows for greater clarity for the caller. email(person, day) is fine, but email(person, on: day) is explicitly clear

	"`name`, you must enter the numbers on `day`!" # internal arg label precedes type as usual
}

email(locke, on: 'Tuesday')
email(locke, 'Tuesday') # label is optional

email jack, on: 'Tuesday' # omit parens like Ruby

# enums, must begin with `enum` and } with ‘}’. They can also have methods, but because they are stateless methods are perfectly fine. Since the method has signature, as long as it matches the signature of the enum, it is fine.

enum TokenType: int
	identifier
	literal = 2
}

enum Another: string
	brain = 'brain'

	# methods here are stateless because enums cannot store data like objects can
	greet(name: int)
		"hi `name`" # must return string to satisfy enum type
	}
}

#### variables ####

# type is not required. when present, variable can only be that type. when not present, variable can be any type.

untyped = 1
untyped = "hello" # valid
untyped = (1, 2, 3) # valid

typed := 1
typed = "hello" # invalid

static some_static_var: int = 1

first: TokenType = TokenType.literal
second: TokenType = .identifier
third: Another = .smooth(4)
third.value # "smoothing 4"

some_number: int = 42
private one_number: int = 2
pri two_number := 4

color: (float, float, float, float) = (1.0, 1.0, 1.0, 1.0)
whatever: (int, int, int) = (1, 2, 3) # etc

# named tuple values
color3: (r: float, g: float, b: float, a: float) = (1.0, 1.0, 1.0, 1.0)
color4 := (w: 1.0, x: 1.0, y: 1.0, z: 1.0)

# access tuple values by index
color.0
color.1
color.2 # and so on
color3.r # .g, .b, etc but only when names are present in the tuple declaration
color4.w

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
my_dict: {string: int} =
	some_key: some_integer # keys auto converted to string if they can be
}

### idea) generic type alias constructor for any dictionary, regardless of key/val types
my_dict: dictionary = dict # constructs an empty dictionary
###

tuples: (int, int) = (4.8, 1.5) # this can never be confused with a method returning nil because that must explicitly be defined as (nil)(args, ...)

day: string = day_of_week() # method parens may not be omitted, it's one thing I find confusing sometimes in Ruby

enabled?: bool = true # the ? is a valid character for variable and method names, but not object names (eg, Emerald?) because the ? means the object can be optional whereas the ? in a variable or method name is just part of its name

# ways of calling constructor
# note; as long as the type or the constructor contain the literal name, then it should be possible to know which object
assorted1: Sandwich = new(1) # type mentions literal
assorted3 := Sandwich(3) # constructor mentions literal
assorted2: Sandwich = Sandwich(2) # both

sandwiches: [Sandwich] = [assorted1, assorted2, assorted3] # initialize your array of Sandwiches here

# type hinting
monday: string = 'Monday'
weekday: string = 'Friday'
dates: Date = .today
times: Time
datetime: DateTime

# variable type here is the signature of a method
takes_string_returns_nothing: (string) -> nil # writing `nil` is not optional as it needs to be explicit to avoid confusion with tuples

# hint) blocks except `self: ` all must begin with their respective keyword and finish with `}` #
# obj ...
# }

for some_collection_such_as_array
	it # keyword referring to the current item
	at # keyword referring to the current index
	stop # keyword to break out of the loop
	next # keyword to skip to the next iteration, maybe it should be called next?
	# if `it` is a tuple, then `it.0` is the first item, `it.1` is the second, etc. or you may access them using their names
}

for some_dictionary
	it.key
	it.val
	stop
	next
}

for 10 # when a number is provided, it will loop that many times.
	it # eg) when looping 10, the it will be 1-10
	at # eg) when looping 10 the i will be 0-9
	next
	stop
}

while locked?
	it # refers to locked?
	at # refers to the current iteration of this loop
	next # works here too
	stop # works here too
}

if condition
}

if locked? || enabled?
}

if locked? or enabled?
}

if locked? && !enabled?
}

if locked? and !enabled?
}

# switch statement using special when keyword
when some_enum
	is .brain
		calculate()
	# when another `is` encountered, signifies } of implied block
	is .identifier # no block required
	is .literal: whatever(it) # inline
	is .smooth(4)
		# blocks may be explicit
	}
else
	# this is optional, and acts as the default case
}

def some_method
	do_something if enabled? # if statement may be placed on the same line as the method definition
	some_var := if enabled? # if statement may be used as an expression
		1.0
	else
		0.0
	}
}

# other blocks
some_collection_such_as_array.each # no need to add `do |variable|` like in Ruby
	it
	at
	stop
	next
}

collection.where # like Ruby's select and filter, but combined into one
	# should stop and next be available?
	at
	it == 'something' # implied return
}

squared := [1, 2, 3].map
	it * it
	# at, stop, next are also available. stop would bail on the map and could cause the mapped object to have less elements due to early bail.
}

only := collection.where
	it == 1
}

# and so on for filter, etc. though the names of these methods may change

_.log result # arrow is shorthand for debug printing to console
_.log 'nice' if enabled? # print 'nice' if enabled?
_.log result + 4, "the result is `result`" # takes an array of expressions, prints each on a new line
_.warn 'some warning' # debug print warning
_.error 'some error' # debug print error

favorite_thing := _.input # idea; reading from console. when the line with _.input is executed, the program waits for input from the console. when the user presses enter, the input is stored in the variable on the left side of the _.input operator

# interfaces
# objects that use api interfaces must implement any stubbed methods in the interface
# usage is with +, because you are composing the object with the interface
#
# obj ObjectReceivingComposition + SomeComposingAPI
#
#
# obj ObjectReceivingComposition + SomeComposingAPI, AnotherComp, AnotherAndSoOn
#
# interfaces are called APIs, and start with the api keyword. the block is its body

api Stone
	mass: float
	ancestor: Stone
	pri value: float

	# stubs are only allowed in api blocks because otherwise it's too ambiguous and difficult to determine whether the next line is the body of this method or a sibling statement
	def weight -> float
	}

	def calculate_something(float) -> int
	}

	def label -> string
		"it weighs `mass`!"
	}

	pri def do_something # this method is private. privacy can be controlled per method like this
	}

	private # privacy for the rest of the scope. use full spelling `private` for scopes and shorthand `pri` for individual cases

	def secretly_do_nothing;
}

obj Opal
}

obj Opal > Gem # inheritance todo; do I like this syntax and keyword?
	+ Stone # composition

	# must implement stubbed methods, but get variables and implemented methods for free

	weight_in_lb: float

	def value_in_dollars -> float; # stubbed method to be implemented

	pri def do_something
		ancestor.calculate_something(4.8) # ancestor is defined in the Stone api
	}
}

# type comparisons
Opal >== Gem # is Gem a immediate or extended ancestor? true in this case
Gem >== Opal # false
Opal === Gem # is Opal the same as Gem? false in this case

# also works on instances
opal = Opal()
gem = Gem()

opal >== gem # true
gem >== opal # false
gem === opal # false

if opal is Opal # equivalent to using ===
}


# hint) built-in error api
# Errors are not automatically raised, instead they are passed by value and you are able to choose whether you want to raise or print the error

api Error # compose with this to make custom errors
	def message -> string
}

obj NotImplemented + Error # you may add anything to the body so long as the stubbed method is implemented, even if it is calculated like message here with the => keyword
	def message ->string => 'You did not implement this or whatever'
}

###

the reason for this + key symbol is because the object and its composition declarations are very pleasing to read. the + symbol also implies adding stuff together

obj Something
	+ ComposeThis
	+ ComposeThat
}

look at how beautiful that is. even the short form is neat

obj Something + ComposeThis, ComposeThat
}

###

+ Stone # works at file level too, notice no object block and no indent
+ ComposeThis, ComposeThat

# this top level's api implementations:
def weight -> float
	# must implement according to api
}

pri def do_something -> float
	ancestor.calculate_something(4.8)
} # must also be implemented at top level if it is composed of Stone

# hint) execute any code in the file, the file doesnt need to become an object. first all variables and methods are loaded, then any code inside the file is run
whatever := get_something()

# hint) static every object basically gets instantiated once at runtime anyway (maybe that is bad for big projects, tbd) so you get that object for free and it is used like YourObject  to reference the static instance. works with inferred object names where obj keyword was not used: Util_Math # inferred from file util_math.hh

obj Transform
	+ Position
	+ Rotation
	+ Emerald/Scale # namespaces are filepath based, not needed here since all apis are here in this file
	# this object gets the rotation methods for free vis composition
	# its namespace is whatever folder it is in: eg$ project://components/transform.hh would make this Components/Transform
}

# override namespace
obj CoolNamespace/Planet
	# file can be anywhere in the project and it's namespace will be set to CoolNamespace instead of being inferred from the directory structure and filename
}

obj /Star
	# force global namespace regardless of file location
}

api Scale
	scale := (x: 1.0, y: 1.0) # type of this tuple is (float, float)
}

api Rotation
	rotation := (0, 0)

	def look_at(target: Transform) -> Rotation
		# some implementation
	}
}

api Position
	position := float2(0, 0)
}

api Transformable
	+ Transform
} # composition of compositions

