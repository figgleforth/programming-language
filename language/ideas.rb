# This is a file named ideas.rb. The file content is also the body of the “object” the file represents. I haven't picked a file extension yet, so this will do for now.

# If object name is omitted, the name of the object is generated from the filename. for example, a file named my_program.rb would generate an object named My_Program.

self: Ideas
end

self: Ideas(title: str) # constructor 
end

self: Idea -> interface
self: Idea -> class # default?
self: Idea -> struct

# self refers to the file, so we are setting the file to be Ideas

will_initialize
end

dod_initialize
end

## functions

square(value: num) -> num
  value * value
end

divide(a: num, b: num) -> num
  if b == 0
    # can’t divide
  else
    other_method(arg, test)
  end
end

# function in variable

calculator: (num, num) -> num

# when lexer parses a line split by white spaces, check the last character to see if it is a colon. that's the simplest way to get the syntax working.

# maybe I need to split character by character since this syntax has a lot of instances ofwhite space after colons

## variables

result: num = multiply(4, 8)

age: int = 35
buoyancy: float = 0.78
cars: num = 1
description: str

evaluate: func # without args and return
find_something: () # shorthand for func

grow: func(type, ...) # with args only
heal: (type, ...) # shorthand for args only

interpret: type() # with return only
jelly: type(type, ...) # with args and return

k: range

# self is a keyword referring to the current scope. When used at the root level like this it represents this file. When used within a scope, it would represent the scope that it is used in. You wouldn't use self as a return type elsewhere, though, only here in the class name declaration. Elswhere self just refers to the scope you are in.

# `: ` is type token keyword. Notice that type tokens are always followed by a type.

question: str = “What’s the name of this language?”

some_number: num = 4.8 # `num` abstracts numbers so you don't have to specify int or float. call #type on it to get true type: eg) int, float. Usage of num is optional. 
some_int: int = 15
some_float: float = 16.23
some_number2: num = 42
some_inferred_num := 1987 # := infers the type

assorted: Sandwich = new(2) # omit the class name when new-ing if the type is declared 
assorted2 := Sandwich(3) # use class constructor when inferring type
assorted3: Sandwich = Sandwich(4) # this is fine too

day: string = day_of_week # method parentheses can be left out when calling one with no arguments

enabled?: bool = true # ? is valid for variable names

sandwiches: [Sandwich] = [...]

for sandwiches
  log(it) # it is the current item
  log(i) # current index
  
  # interpolation
  "[it] is delicious"
end


# function signatures
# (type, ...) -> type
# this    “(type, ...)”
# returns “->“
# that    “type”

### functions

divide(a: num, b: num) -> num
  a / b
end

multiply(a: num. b: num) -> num
  a * b
end

reset_password(account: Account)
  # ...
end

locked?(account: Account) -> bool
  account.locked_at?

# ? is like .present?. I guess this means I can’t use ? for variable names otherwise I can’t do this, and this is cooler than ? in names. I could probably allow it, and determine order of preference for lookups, maybe variables first then functions. just an idea. Or if not as variable exists, then we fall back to checking if the bool is true.
  
end

lock!(account: Account)
  account.locked_at = Calendar.now
  account.save
end

tuple_return_type() -> (int, float)
  a: int, b: float = other_tuple()
end


result := add(4, 8) # inferred typing
# what if = checks for existing before inferring type, if exists then set the new value, otherwise create and infer type

[result] # print to console
[result + 4, “the result is [result]”] # each  prints own line. 


# ? is valid for method names too. Notice that methods and variables can share names as well. This works because methods have to be called with parentheses so if you omit the parentheses, then it refers to the variable.
enabled?() -> bool
  true
end

# notice that the method body is everything between the return type and the `end` keyword
day_of_week() -> str
  'Sunday'
end

method_with_default_argument_values(a: num = 87)
end

# inner class without an initializer. notice @slices, that lets you map initializer arguments to variables, without manually writing an initializer. "Mapped initializer args"
Sandwich(slices: num) -> class
  slices: num = @slices
end

# inner class with an initializer. 
Sandwich(slices: num) -> class
  slices: num
  lettuce: bool = true # default value
  
  new(slices: num)
    @slices = slices
  end
end

# in her class with a mix of mapped initializer arguments, and in initializer. argument can be omitted by the caller, if there is a default value in the constructor.
Sandwich(slices: num, lettuce: bool = true) -> class
  slices: num
  lettuce: bool = @lettuce
  
  new(slices: num, lettuce: bool = true) # new keyword doesn't require return type
    slices = @slices
  end
end

Sandwich(name: str) -> class
  delicious?: bool()
    true
  end
end

# composition
TurkeySub() -> class
  has Sandwich.variables.private
  has Sandwich.functions.public
end

# inheritance
TurkeySub() -> Sandwich
end

# create code blocks that you can use as a scratch pad in the middle of a file anywhere. This would be one token, ignored like a comment.
```
something := whatever()
```

# if there is a syntax error, maybe the lexer can peak ahead until it finds the first valid code, continue evaluating while it prints to the console that there was an issue parsing

zero_to_one: range = 0 ~ 1 # 0..1
zero_to_less_than_one := 0 ~~ 1

# Jonathan Blow refers to interpreters as frontend of a programming language and the compiler as the backend

sandwich..meat # sandwich&.meat

for collection
  stop # cancel iteration
  next
  it # current element
  i # index
end

for 10
  it # 1-10
  i # 0-9
end

while locked?
  bail # works here too
end

if condition
end

# I really don't like that I can't tell whether something is a variable or function in Ruby.

