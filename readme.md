#### A programming language
- Homoiconic (the code you write _is_ the structure in memory)
- Designed for prototyping
- Minimal reserved keywords
- Composition and inheritance
---
```
`Comments start with backticks

name := "Cooper"      `Declaration with type inference
nothing =;            `Shorthand for = nil
ranges := 1..5        `Inclusive
range2 := 0><3        `Exclusive
range3 := 1.5.<2.0    `Any of .. .< >. ><

PI := 3.14159
GRAVITY := 9.8

MODES {
  DEV  := 0   `It's secretly just a dictionary of CONSTANTs
  PROD := 1
}

mode := MODES.DEV

`This is a Type
Vector2 {
  x := 0
  y := 0
}

`Composition
Thing {
  | Vector2
  
  update { delta;
    y -= GRAVITY * delta
  }
}

`Inheritance
Player > Thing {
  name: String
  
  `Builtin __to_s function, with double undescores to not pollute the user's scope
  __to_s: String {;
    "(Player id=`__id`)"    `Interpolation with backticks
  }
}

p1 := Player()
p1.name = 'Tom`

p2 := Player()
p2.name = 'Jerry'

players := [p1, p2]

`Which player is lucky?
for players
  it `current element
  at `current index
  
  remove it if randf() > 0.5 `replaces the element with nil
  
  skip `this iteration
  stop `and end the loop
end

if players.count == 2
  `Lucky!
elif players.count == 1
  `One player lost
else
  `:(
end `Control flow uses `end` to terminate. It is much easier to subconsciously understand your indentation level with this distinction.
```
---
