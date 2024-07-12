### Motivations

- Some features and syntax that I like and think would be cool
- I want to type as little as possible, so no need for `class`/`var` prefixes because capitalization determines the
  construct
- As few reserved words as possible. I want to be able to use any name
- Integrated documentation where a documentation directory and pages are automatically created from specific comment
  syntax
- Web app focused, so server and MVC constructs as standard features
    - The ultimate goal is to create web apps without external libraries like how one might use Rails with Ruby

*Most of the syntax below is parsing, some is not.*

### Syntax

Comments

```
# single line comment

###
multiline comment
###
```

Variable declarations

```
version =; # without a value
version = 0
version = 100_000
version = 0. # equivalent to 0.0
version = .0 # equivalent to 0.0
```

String interpolation

```
version_label = "Em version `version`"
version_label = 'Em version `version`'
```

Blocks and functions

```
# Anonymous block
{ 
   version = 0
   what? =; # variables can include ? or !
   okay! =;
}

# Named block (aka function)
set_version {
   version = 0
}

# With params
set_version { v ->
   version = v
}

# Calling functions
set_version(0.00001)

# Compacted and params with default values
set_version { v = 0 -> version = v }

# Function params with labels
greeting { for name -> "Hello `name`" }
greeting(for: 'Em')

# Blocks assigned to variables. Not yet sure how to call blocks stored in variables
greeting = { for name -> "Hello `name`" }
```

Enums and constants, must be caps

```
ENVIRONMENT {
   DEV = 0,
   PROD = 1,
   NESTED {
      NICE = 3
   }
}

PI = 3.14
```

Classes, must be capitalized

```
Em {
   environment = ENVIRONMENT.DEV
   env = ENVIRONMENT.NESTED.NICE
   version =;
   self.parse {} # class functions
}

lang = Em.new # instance
lang.version

Em.parse
```

Composition allows merging of constructs

```
Runtime {
  interpret {}
}

ENVIRONMENT {
   DEV,
   PROD
}

Em {
   & Runtime
   & ENVIRONMENT
}

Em.DEV
em = Em.new
em.interpret

print { language = Em.new ->
  &language
  interpret # local access to the interpret function
}

print { &language = Em.new -> interpret } # composition compacted into param declaration
```

Decompositions, or removing specific compositions. Removes local access to the thing decomposed

```
Eminem {
   & Em
   ~ Runtime
}

Eminem.DEV
lang = Eminem.new
lang.interpret # not callable because Runtime was decomposed

Eminem > Em { } # inheritance, the `>` symbol implies that the left-hand class is more than the right-hand class
```

Functional programming features

```
[1, 2, 3, 4].where
  it # refers to the current item
  at # refers to the index of the current item
}

[1, 2, 3, 4].map 
  it *= 2
}

[].tap 
  it # refers to the construct tapped into
}

"".tap
  it += 'Hello'
}
```

Flow control, no need for `}` in the middle of control flow chains. But it's required to close out the flow control
construct

```
if true
}

if false
else
}

if a > b
elsif a < c # or elif
else
}

while true
}

while false
else
}

while a > b
  skip # skip this iteration
  stop # stop the loop
elswhile a < c
else
}
```

Macros

```
%s(boo hoo moo) # [:boo,  :hoo,  :moo]
%S(boo hoo moo) # [:BOO,  :HOO,  :MOO]

%v(boo hoo moo) # ['boo', 'hoo', 'moo']
%V(boo hoo moo) # ['BOO', 'HOO', 'MOO']

%w(boo hoo moo) # ["boo", "hoo", "moo"]
%W(boo hoo moo) # ["BOO", "HOO", "MOO"]

%d(boo hoo moo) # {boo: nil, hoo: nil, moo: nil}
```
