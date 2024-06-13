obj TopLevelObject > Base_Object imp Hatch, Door, Shelter

imp Hatch # equivalent to adding imp Hatch, Door, Entity to object declaration
imp Door, Shelter # imp keyword doesn't care about indentation because it just adds implementation to the current block/scope

api Hatch
}


api Shelter
}


obj House imp Shelter; # equivalent empty body {}

obj Home > House imp Hatch, Door # equivalent to empty body {} but you can omit { for all blocks
  def address -> string; # unimplemented methods return nil
}

obj NPC > Entity imp Transform # equivalent to empty body {} but you can omit { for all blocks
}

obj Golden_Retriever > Dog;
imp Intelligence, Charm # they can be on separate lines as well, both as top level declaration and regular object declaration

obj Dog
	imp Legs # should be indented when inside an actual block. but it's not enforced by the parser
}

# implementations left out cause i dont feel like doing that now
api Comparison
	def == other;
	def !;
	def ?;
}

api Binary_Operatable
	def + other;
	def - other;
	def * other;
	def / other;
	def % other;
	def ** other;
}

obj Base_Object
	imp Comparison
	imp Binary_Operatable

	def == other
		@.id == other.@.id
	}
}

obj Number > Base_Object imp Binary_Operatable
}

def add left: Number, right: Number -> Number
	left + right
}



# both of these are valid
movable: Transform ### movable can be assigned any object that implements Authenticatable api so you aren't limited to type of object
  both of these are valid

  movable = Player()
  movable = NPC()
###

entity: Entity ###
  both of these are valid

  entity = Player()
  entity = NPC()
###

new(year: float) # top level constructor
}

obj Shelter; # equivalent to an empty object

obj Hatch > Shelter imp Security_System # implements Security_System api

  new # no params here
    super # call parent constructor
    # do something
  }

  def respond_to_intruder # must implement any stubbed methods in the implemented api
    @.type # 'respond_to_intruder(): nil'
    self.@.type # 'Hatch'
    door.@.type # 'Door'
    # @ is the context variable. it contains vitals about the current object so that those variables don't pollute the obj's local scope. mainly a feature to make coding with this language less restrictive in the sense that there aren't so many reserved variable names.
  }
}

obj Hatch > Shelter imp Security_System; # this is also valid

api Door
  door: Door
}

api Security_System > Door # implements door api, so has access to door variable
  def enter_numbers(numbers: int) -> bool as open # aliasing methods internally so that method ident can be verbose externally but simple internally
    # ...
  }

  def close -> bool
    door.close
  }

  def shh_let_them_in!
    if open(4815162342) # calling aliased method
      door.open
    }
  }

  def respond_to_intruder;
}


obj Others
  arg total: int
  arg people: [Person] ###
   arg keyword is shorthand to declaring this as an argument in the constructor.
   so this can be instantiated like Others.new(total: 5, people: []). or Others.new(people: [], total: 5). the order does not matter when using `arg`. neither does the presence. arg just means it is available as an argument to the constructor, but it is optional. this prevents having to write `new` initializers for multiple cases
  ###

  arg leader: Person
    # block that runs whenever leader= is called

    it # represents this `leader`
    it.right_handed = true # mutable within this block

    # no return expected
  }

  new(people: [Person], leader: Person) # equivalent to using arg keyword in front of variable declarations, but in this case the order matters while arg order does not matter
  }

  new people: [Person], leader: Person # parens are optional
  }

  def evil -> bool => false # => can be used in place of a block expression, only when the block is a single line of code. multiline expressions using => are not valid
}

# Context object may have useful info, but also acts as scratch object. can be accessed using @ symbol and exists once for each obj object, and contains varying information depending on where it is called .like @.args contains information when accessed inside a method. when accessed top level, @.args would not have any information as there are no args present in that moment in code. This is cool because an object won't be cluttered with variables and methods irrelevant to everyday programming.
obj Context
  args: [] # if applicable, like inside of a method scope
  scopes: [] ###
    @.scopes[0] # current scope
    @.scopes[1] # the scope before this one
    @.scopes[3] # and so on
  ###

  # function literal represents any type of method signature
  type: string # '(int): int' or '(): float' or '(): nil', 'Context' or 'Base_Object', and so on

  def log; # use ; to stub a method
}

def haunted_castle -> Castle
  @.args # []
  @.type # (Time): Castle

  @.whatever # define any temporary variable that lives until the current scope is exited. any code executed after this line, until the scope is exited, will have access to @.whatever. you cannot override existing vars like @.args or @.type
  @.boo = (bar: int)()

  } # works for methods as well

  @.boo(4) if self.?square # .? returns bool if receiver responds to `boo`, equivalent to Ruby's responds_to?('boo'). I kinda like `self?.` but since identifiers can end in question marks, this will be too ambiguous for the parser.

  _ = not_needed_method_call_result
  not_needed_method_call_result # or just don't store the result
}

def square(value: int) -> int
  value * value
}

def square value: int -> int
  value * value
}

new
  @.args # also works in the constructor since it's also a method
  @.type # method signature, in this case _Spec because constructor returns this obj, aka _Spec
}

def square_and_some(a: int) -> float
  a * a / 4.815 # return keyword is optional
}

def save -> bool # method signature is (): bool
}

def no_args_and_no_return # method signature is (): nil
}

def no_return(name: string) # method signature is (str): nil
}

def no_parens name: string -> string
  "Hello, `name`!"
}

# argument labels

def email(name: string, on day: string) -> string
  # external argument label, allows for greater clarity for the caller. email(person, day) is fine, but email(person, on: day) is explicitly clear

  "`name`, you must enter \n the numbers on `day`!" # interpolation using backticks ``
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

  # enum methods are stateless because enums cannot store data like objects can. and they must return a value satisfying the type of the enum
  greet(name: string)
    "hi `name`"
  }

  yeet name: string
    "bye `name`"
  }
}

#### variables ####

smaller_island: Land_Mass, Hatch, Others = Island() # smaller_island must be an instance that extends Land_Mass and implements at least Hatch and Others

# type is not required. when present, variable can only be that type. when not present, variable can be any type.

untyped = 1
untyped = "hello" # valid
untyped = (1, 2, 3) # valid

typed := 1
typed = "hello" # invalid

static some_static_var: int = 1

first: TokenType = TokenType.literal
second: TokenType = TokenType.identifier
greeting: Another = TokenType.greet('Cooper')
greeting.value # "hi Cooper!"

some_number: int = 42
pri one_number: int = 2
pri two_number := 4

color: (float, float, float, float) = (1.0, 1.0, 1.0, 1.0)
whatever: (int, int, int) = (1, 2, 3) # etc



result: int = multiply(4, 8) # calling some multiply function
year: int = 2023
buoyancy: float = 0.78
question: string = "how cool is that?"
single_quote_string: string = 'single quotes are valid too, and interpolate! `question`'
description: string # uninitialized value is nil
about_me: string = "I was created in `year`" # interpolation
k: range = 0..10


# method signature types are written as (inputs)(outputs)
# anonymous methods
what1 = (a: int)(int) {
  puts a
}

what2: (int)() = ()() {
}

what3: ()(int) = ()(int) {
  42
}

what4: ()() = ()() {
}

square: (float)(float) = (x: float)(float) {
	x * x
}



# these are equivalent. these are calculated lazily
value: float => factor * weight
value: float
	factor * weight
}

some_float: float = 16.23
some_inferred_num := 1987

# dictionary literal specifying the type of the key as str, and type of value as int. any type can be used in either, except I guess nested dictionary as a key? but maybe that should be allowed to as long as the object can be hashed to a string
my_dict: {string: int} =
  some_key: some_integer # keys auto converted to string if they can be
}

another_dict: {string: any} = {
  a: 'hi',
  b: 1234,
  c: Hatch.new,
  d: Hatch()
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
dates: Date = Date.today
times: Time
datetime: Date_Time

# variable type here is the signature of a method
takes_string_returns_nothing: (string)() # writing `nil` is not optional as it needs to be explicit to avoid confusion with tuples

for some_collection_such_as_array
  it # keyword referring to the current item
  ix # keyword referring to the current index
  skip # keyword to skip to the next iteration. I want to be able to use next as a variable name
  stop # keyword to break out of the loop
  # if `it` is a tuple, then `it.0` is the first item, `it.1` is the second, etc. or you may access them using their names
}

for some_dictionary
  it.key
  it.val
  stop
  skip
}

for 10 # when a number is provided, it will loop that many times.
  it # eg) when looping 10, the it will be 1-10
  ix # eg) when looping 10 the i will be 0-9
  skip
  stop
}

while locked?
  it # refers to locked?
  ix # refers to the current iteration of this loop
  skip # works here too
  stop # works here too
}

until locked?
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

if locked? and not enabled?
}

# switch statement using special when keyword
when some_enum
  is .brain
    calculate()
  }
  # when another `is` encountered, signifies } of implied block
  is .identifier # no block required
  is .literal whatever(it) # inline
  is .smooth(4)
else
  # this is optional, and acts as the default case
}

def some_method
  do_something unless locked? # if statement may be placed on the same line as the method definition
  some_var := if enabled? # if statement may be used as an expression
    1.0
  else
    0.0
  }
}

# other blocks
some_collection_such_as_array.each # no need to add `do |variable|` like in Ruby
  it
  ix
  stop
  skip
}

collection.where # like Ruby's select and filter, but combined into one
  # should stop and skip be available?
  ix
  it == 'something' # implied return
}

squared := [1, 2, 3].map
  it * it
  # at, stop, skip are also available. stop would bail on the map and could cause the mapped object to have less elements due to early bail.
}

square := Square.new.tap # tap like Ruby
  it # instance
}

only := collection.where
  it == 1
}

api Stone
  mass: float
  ancestor: Stone
  pri value: float # this instance var is private


  def weight -> float
    # ...
  }

  def calculate_something(float) -> int
    # ...
  }

  def label -> string
    "it weighs `mass`!"
  }

  pri def do_something # this method is private. privacy can be controlled per method like this
    # ...
  }

  private # privacy for the rest of the scope. use full spelling `private` for scopes and shorthand `pri` for individual cases

  def secretly_do_nothing
    # ...
  }
}

obj Emerald;

obj Emerald > Gem imp Stone

  weight_in_lb: float

  def value_in_dollars -> float; # stubbed method to be implemented by sub-objects

  pri def do_something
    ancestor.calculate_something(4.8) # ancestor is defined in the Stone api
  }
}

# type comparisons
Emerald >== Gem # is Gem a immediate or extended ancestor? true in this case
Gem >== Emerald # false
Emerald === Gem # is Emerald the same as Gem? false in this case

# also works on instances
emerald = Emerald()
gem = Gem()

emerald >== gem # true
gem >== emerald # false
gem === emerald # false

if emerald is Emerald # equivalent to ===
}

# hint) built-in error api
# Errors are not automatically raised, instead they are passed by value and you are able to choose whether you want to raise or print the error

api Error # compose with this to make custom errors
  def message -> string

  def self.raise # obj methods, don't require an instance so it can be called like Error.raise
    # ...
  }
}

obj Not_Implemented > Error # you may add anything to the body so long as the stubbed method is implemented, whether with a full block or a single line expression
  def message -> string => 'You did not implement this or whatever'
}

def fail_with_error
  Not_Implemented.raise # you can raise an error here
}

obj Transform imp Position, Rotation, Emerald::Scale # namespaces are filepath based, not needed here since all apis are here in this file. this object gets the rotation methods for free vis composition. its namespace is whatever folder it is in, eg if this code was in components/transform.e that would make this Components/Transform
}

# override namespace
obj Cool_Namespace::Planet
  # file can be anywhere in the project and it's namespace will be set to Cool_Namespace instead of being inferred from the directory structure and filename
}

obj ::Star
  # force global namespace regardless of file location
}

api Scale
  scale := (x: 1.0, y: 1.0) # type of this tuple is (float, float)
}

api Rotation
  rotation_degrees := 0.0

  def look_at(target: Transform) -> Rotation
    # some implementation
  }
}

api Position
  position := vec2(0, 0)
}

api Transformable imp Transform # apis composed together
}




obj Emerald
	fun version -> any;
	x: int = 1
	version: string =

	}

}

obj Math
	default_offset: float = 0.0

	cosine: float = ()
	}

	sine: float = (offset: float)
		# ...
	end

	-> sine(offset)
	}
end

api Rotation
	rotation_degrees := 0.0

	look_at: number = (target: any)
		# ...
	}
}
