### Motivations

- Some features and syntax that I like and think would be cool
- Integrated documentation where a documentation directory and pages are automatically created from specific comment
  syntax
- Web app focused, so server and MVC constructs as standard features
    - The ultimate goal is to create web apps without external libraries like how one might use Rails with Ruby

### Syntax

*Some of this is implemented, some not.*

Comments

```
# single line comment

###
multiline comment
###
```

---

Variable declaration without value, variables must be lowercase

```
version =;
```

---
Variable with value

```
version = 0
varsion = 0_0
version = 0. # equivalent to 0.0
subversion = .0 # equivalent to 0.0
```

---
Anonymous block

```
{
   version = 0
   what? =; # variables can include ? or !
   okay! =;
}
```

---
Named block aka function

```
set_version {
   version = 0
}
```

---
Function with params

```
set_version { v ->
   version = v
}
```

---
Function call

```
set_version(0.00001)
```

---
Compacted and params with default values

```
set_version { v = 0 -> version = v }
```

---
Function params with labels

```
greeting { for name -> "Hello `name`" # interpolation }

greeting(for: 'Em')
```

---
Blocks assigned to variables. Not sure yet how to call them

```
greeting = { for name -> "Hello `name`" # interpolation }
```

---
Enum and constants, must be caps

```
PI = 3.14

ENVIRONMENT {
   DEV = 0,
   PROD = 1,
   NESTED {
      NICE = 3
   }
}
```

---
Class, must be capitalized

```
Em {
   environment = ENVIRONMENT.DEV; # or ENVIRONMENT.NESTED.NICE
   version =;
}
```

---
Instance

```
lang = Em.new
lang.version
```

---
Class functions

```
Em {
  self.parse {}
}

Em.parse
```

---

Composing classes with other classes, instances, or enums, as opposed to inheritance. Provides local access to the thing
composed

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

print { language = Em.new ->
  &language
  interpret # locally access 
}

print { language = Em.new ->
  &language
  interpret # locally access 
}

print { &language = Em.new -> interpret } # composition compacted into param declaration

lang = Em.new
lang.interpret # local to lang
lang.DEV
```

---
Decompositions, or removing specific compositions. Removes local access to the thing decomposed

```
Eminem {
   & Em
   ~ Runtime
}

lang = Eminem.new
lang.interpret # not callable because Runtime was decomposed
lang.DEV
```

---
Some functional features, with quality of life iteration members

```
[1, 2, 3, 4].where { 
  it % 2 == 0 # `it` refers to the current item
} # returns [2, 4]

[1, 2, 3, 4].where { 
  at < 2 # `at` refers to the index of the current item
} # returns [1, 2]

[1, 2, 3, 4].map { 
  it *= 2
} # returns [1, 2]

[].tap { 
  it << 1 # the array
} # returns [1]
```

---
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
