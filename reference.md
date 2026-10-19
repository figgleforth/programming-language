# .code Reference

## Variables

1. Must start with a lowercase letter or `_`.
2. Can end with `!` or `?`

```code
nothing := nil
something: Number = 123
_private_thing := "Yes"
tested? := false
```

## Functions

1. Must start with a lowercase letter or `_`
2. The function body is surrounded with `()` parens
3. The arguments are declared before the arguments/body delimiter `;`
4. The body comes after the arguments/body delimiter `;`
5. The last expression is the return value
6. Return early using `return` keyword

```code
# func_name ( [args]; [body] )

func_with_args ( arg1, arg2 := 1, etc := true;
    # body
)

without_args (;
    # body
)

add ( a, b;
    a + b
)
add(4, 8)  # 12

_privately_do ( x, y, z; )

# A call whose single argument is an anonymous function may drop that argument's parens,
# when the receiver is a member access / call / subscript:
[1, 2, 3].map(n; n * 2)     # == [1, 2, 3].map((n; n * 2))
```

## Named Function Arguments

**Named arguments** — `name := value` at a call site binds by the callee's declared param name, order-independent. Positional args must come first; once you name one, the rest must be named too. `name: value` is not a named argument: after a name, `:` starts a [type annotation](#literal-types), so `sub(a: 1)` raises `Colon_Named_Argument`.

```code
sub ( a, b; a - b )

sub(a := 1, b := 2)   # -1
sub(b := 2, a := 1)   # -1 reordered, same result
sub(1, b := 2)        # -1 positional then named is fine

# sub(a := 1, 2)       raises Positional_Argument_After_Named
# sub(a := 1, a := 2)  raises Duplicate_Named_Argument
# sub(a := 1, c := 2)  raises Unknown_Named_Argument
# sub(1, a := 2)       raises Argument_Given_By_Name_And_Position
```

**Struct-typed params** — `: <...>` instead of a plain type name checks *structurally*, not by name: any argument that has each listed member, with a compatible type, is accepted. `Any` matches any member type. Checked on every call, raising `Type_Contract_Violation` on a mismatch.

```code
f ( right: <name: String, type: Any, value: Any>; right.name )

m := Member('x', String, 4)
f(m)     # 'x' -- Member isn't named in the annotation, it just has all three members
f(nil)   # raises Type_Contract_Violation
```

An unnamed member checks by position: `<String, Number>` needs a String at 0 and a Number at 1.

```code
g ( pair: <String, Number>; pair.0 )

g(<'x', 4>)   # 'x'
g(<4, 'x'>)   # raises Type_Contract_Violation
```

## Recursion

A named function is registered in its enclosing scope as it's declared, so it can call itself.

```code
factorial ( n;
    if n == 0 or n == 1
        1
    else
        n * factorial(n - 1)
    end
)
factorial(8)  # 40320

fib ( n;
    if n <= 1
        n
    else
        fib(n - 1) + fib(n - 2)
    end
)
fib(10)  # 55

fizz_buzz ( n;
    if n % 15 == 0
        'FizzBuzz'
    elif n % 3 == 0
        'Fizz'
    elif n % 5 == 0
        'Buzz'
    else
        n.to_s()
    end
)

for 1..15
    @puts fizz_buzz(it)
end
```

## Forward Declarations

Calling a function or referencing a type works before its own declaration is reached in the file, including mutual recursion.

```code
result := main()   # `main` hasn't been declared yet, but this still works

main (; helper() )
helper (; 42 )

result  # 42
```

```code
is_even ( n;
    if n == 0
        true
    else
        is_odd(n - 1)
    end
)

is_odd ( n;
    if n == 0
        false
    else
        is_even(n - 1)
    end
)

is_even(4)  # true
```

A class-styled alias (`This := That {}`) hoists too — it's a type declaration, just spelled with `:=`:

```code
p := This()

This := That {}
That { greet (; 'hi' ) }

p.greet()  # 'hi'
```

A bare `@load` hoists too, so imports can live at the bottom of the file instead of the top:

```code
sign := Div([P('hi')])
sign.to_s()  # '<div><p>hi</p></div>'

@load 'lang/html.code'
```

`Ident := @load 'file'` / `IDENT := @load 'file'` hoist too — only a Capitalized or UPPERCASE name opts in:

```code
sign := Html_Lib.Div([Html_Lib.P('hi')])
sign.to_s()  # '<div><p>hi</p></div>'

Html_Lib := @load 'lang/html.code'

# html_lib := @load 'lang/html.code'   -- lowercase stays a plain variable, not hoisted
```

A plain variable is never hoisted — reading it before its line runs still raises `Undeclared_Identifier`:

```code
@puts "`a`"   # raises Undeclared_Identifier
a := 123
```

## Classes

1. Must start with an uppercase character
2. Can have an initializer `Self`

```code
My_Class {
    input,
    
    Self ( input;
        self.input = input  # self is the current instance, like this in other languages
        @puts 'Initted with "`input`"'
    )
}

instance := My_Class('some input')  # Initted with "some input"
```

## Constants

1. Must be UPPERCASE
2. Cannot be reassigned after initial declaration

```code
PI := 3.14159
MAX_SIZE := 100
APP_NAME := 'My App'
```

## Comments

```code
# This is a single-line comment
# Stack a few of these for a multi-line comment

###
Or wrap a whole block in ###/### -- everything in between is discarded,
including lines of code, so it doubles as a way to comment out code.
###

####
A longer run of #s on the outer marker can safely nest a same-length
or shorter ### inside it, since only a marker at least as long as the
opening one closes the block -- the same rule ``` fences use to nest.
### this looks like a comment but it's just text in here ###
still inside the outer comment
####
```

## String Interpolation

1. Use backticks inside strings to interpolate expressions
2. Escape with backslash to prevent interpolation

```code
name := 'World'
greeting := "Hello, `name`!"  # "Hello, World!"
math := "2 + 2 = `2 + 2`"    # "2 + 2 = 4"
escaped := "Literal \`backticks\`"
```

## Scope Keywords

`self`, `Self`, and `Global` are bare scope keywords — each is a value on its own, and `Keyword.member` reaches one name in exactly that scope, no outward search:

1. `self` — the current instance only
2. `Self` — the current type only (where statics live)
3. `Global` — the global scope only

```code
My_Class {
    Self.count := 0   # Type-level (static) variable
    value,

    Self ( value;
        self.value = value   # Instance variable (like this.value in other languages)
        Self.count += 1      # Access static from instance
    )

    get_global (;
        Global.PI  # reach a global constant past any local shadow
    )
}
```

## Static Declarations

1. Use `Self.` to declare type-level (static) members
2. Shared across all instances
3. Accessed on the type itself: `Type.member`

```code
Counter {
    Self.count := 0

    Self.increment (;
        count += 1
    )

    Self (;
        Self.count += 1
    )
}

Counter()
Counter()
Counter.count  # 2
```

## Type Composition

1. `|` union: merge all members from both types
2. `&` intersection: keep only shared members
3. `~` removal: remove members of right type from left
4. `^` symmetric difference: keep non-shared members

These four meanings apply to `Type | Other { }` composition, and to `x := A | B`, which gives a new composed type. In a type position — a `: Type` annotation or the right side of `::` — the same symbols compare the values that each type allows: `|` either, `&` both, `~` the left but not the right, `^` exactly one. See [Runtime Type Contracts](#runtime-type-contracts) and [Type Aliases](#type-aliases).

```code
Movable {
    x := 0
    y := 0
    move ( dx, dy;
        x += dx
        y += dy
    )
}

Drawable {
    color := 'black'
    draw (; "Drawing in `color`" )
}

# Combine types
Sprite | Movable | Drawable {
    name := 'sprite'
}

s := Sprite()
s.move(10, 5)
s.draw()
```

Composition chains — `~` can remove a trait mixed in earlier in the same chain:

```code
Flying { can_fly := true }
Swimming { can_swim := true }

Duck | Flying | Swimming { name := 'duck' }
d := Duck()
d.can_fly     # true
d.can_swim    # true

Ostrich | Duck ~ Flying { name := 'ostrich' }
o := Ostrich()
o.can_swim    # true
o.can_fly     # raises Code::Undeclared_Identifier
```

A type can even compose with itself, to extend or override a built-in type's own behavior:

```code
Array | Array {
    each ( func;
        for self.values   # self.values reaches the original Array's own values, despite `each` itself now being redefined
            func(it)
        end
    )
}

values := Array([1, 2, 3])
doubled := []
values.each(( it;
    doubled.push(it * 2)
))
doubled  # [2, 4, 6]
```

A [struct](#structs) value works as a composition operand too — its named members compose in as ordinary members; an unnamed member has no name to compose in under, so it doesn't transfer:

```code
p := <a := 5, b := 'x'>

Combined | p {
    foo (; a )
}

c := Combined()
c.a       # 5
c.b       # 'x'
c.foo()   # 5
```

In a chain, the *leftmost* operand that declares a given member wins a name collision — including `Self`, the constructor:

```code
A { Self (; self.label := 'A' ) }
B { Self (; self.label := 'B' ) }

Combined | A | B {}
Combined().label   # 'A' -- A's Self ran, not B's; A comes first in the chain
```

A type's own `{}` body always wins over anything pulled in by composition, whatever position it holds in the chain.

### Alias vs. subtype

Two ways to give a type a second name, behaving differently under the [type comparison operators](#comparison):

```code
Whole | Integer {}    # subtype — Whole is a NEW type that composes Integer
Int32 :: Integer      # alias   — Int32 IS Integer, the same type object

4 === Integer          # true
4 === Int32            # true   (alias — identical composed-type set)
4 === Whole            # false  (subtype — 4's set is {Integer, Number}; Whole adds itself)

Whole  =>= Integer     # true   (a Whole is-a Integer)
Integer =>= Whole      # false  (not every Integer is a Whole)
```

Use `::` for a plain synonym (`Int :: Integer` in the standard library); use `| {}` for a distinct, narrower type that `=>=` its parent without being `===` to it.

### Type Aliases

`::` gives a name to a type expression. `:=` stays for values.

1. One type: the alias is that type itself, so `Int === Integer`
2. A composition: the alias is a contract. In it, `|` means either, `&` both, `~` the left but not the right, and `^` exactly one. `&` binds tighter than `|`, and `~` looser
3. A signature: `Func :: (;)` names a function shape. After `::`, a bare `(;)` is a signature, not an empty function
4. An alias of a composition checks values only. It works in an annotation, in a tag (`Array\Shape`), and with `=>=`. `Shape()` raises `Code::Type_Alias_Is_Not_A_Type`, and so does `=/=`. `===` is true only for the same alias
5. An alias hoists, so it works before its own line in the file
6. A second `::` with the same name replaces the first, the same as `:=`. An annotation that names the alias reads it when the check runs, so it follows the replacement
7. The name must be capitalized, because `::` names a type. `lowercase :: true` raises `Code::Invalid_Type_Alias_Name`

```code
Strumber :: String | Number
x: Strumber = 5
x = 'five'           # ok — a String
x = :five            # raises Code::Type_Contract_Violation

Strumber             # Strumber :: String | Number
Strumber.@name       # 'Strumber'
Strumber.@types      # 'String | Number'
5 =>= Strumber       # true

Shape :: Circle | Square
Drawing <shapes: Array\Shape>

Callback :: (;)
run ( callback: Callback; callback() )

x := String | Number # a value: one new Type that composes both, the same as `Both | String | Number {}`, then `x := Both`
```

### Literal Types

A literal in a type position is a type that allows only that one value: a String, a Number (negative ones too), a Symbol, `true`, `false`, or `nil`. Use them for a quick list of allowed values, without an enum.

1. They work in every type position: a variable, a struct member, a param, a return type, and the right side of `::`
2. They mix with type names and with each other, and each operator keeps its set meaning: `Int | "auto"`, `Int ~ 0`
3. A value matches a literal with `==`, so `5.0` matches `5`, but `:fill` does not match `"fill"`
4. Only literals, not expressions: `x + 1` is not a type
5. `Five :: 5` is a type that only `5` satisfies, not a value, so `Five + 1` raises `Code::Type_Alias_Is_Not_A_Type`. For a named value, use a constant: `FIVE := 5`
6. The static type checker checks a literal value against a literal type before the program runs
7. A Dictionary entry uses `=` (`{:mode = "fill"}`), so `name: "fill"` inside `{}` is never an entry

```code
mode: "fill" | "line" = "fill"
mode = "line"            # ok
mode = "dash"            # raises Code::Type_Contract_Violation
other: "fill" | "line" = "fil"   # raises Code::Type_Mismatch before the program runs

Stroke <mode: "fill" | "line" = "fill", width: Number | "auto" = "auto">
draw ( mode: "fill" | "line" -> :ok | :skipped; ... )

Auto    :: "auto"        # one name for a literal that several types share
Inherit :: "inherit"
Width   :: Number | Auto | Inherit
Margin  :: Number | Auto

Port :: Int ~ 0          # any Int except 0
Sign :: -1 | 0 | 1
80 =>= Port              # true
```

A struct member with a literal type tells structs apart. A member typed with one literal starts with that value, so a call does not need to give it:

```code
Ok      <status: 200, body: String>
Missing <status: 404>
Reply   :: Ok | Missing

Missing().status         # 404
Ok(404, 'x')             # raises Code::Type_Contract_Violation

v := <status := 404>
v =>= <status: 404>      # true -- an anonymous struct shape matches by its members
v =>= <status: 200>      # false
v =>= Missing            # false -- a named struct is a type, matched by name

Missing =>= <status := 404>   # true  -- `A =>= B`: A has everything B has
Missing =>= <status := 200>   # false -- a `name := value` member on the right counts as a literal

for replies
when <status: 200>
    "ok: `it.body`"
when <status: 404>
    'missing'
end
```

## Conditionals

1. `if`/`elif`/`else`/`end`
2. `unless` is the negation of `if`
3. Can be used as inline modifiers
4. Any value works as a condition -- truthiness follows Ruby's own rules: only `nil`/`false` are falsy, everything else (`0`/`0.0` included) is truthy
5. A nil with a tag is still a nil: `nil\<reason := 'no column'>`, `nil\Error('oh snap')`, and an instance of a type composed with `Nil` are all falsy and `== nil`. A nil is never `==` anything else, so `nil == false` stays `false`. Read the tag with `.@tag`, and use `when` cases after `else` to tell the kinds of nil apart (see `when` below):

```code
describe ( data;
    if data
        'a value'
    else
    when nil\<reason: String>
        "a nil with a reason: `it.@tag.reason`"
    when nil
        'a plain nil'
    else
        'false'
    end
)

describe(nil\<reason := 'no column'>)  # 'a nil with a reason: no column'
describe(nil)                          # 'a plain nil'
```

6. A tagged type with no `Self` takes call arguments into its tag. `nil\Error('oh snap')` is a nil tagged with `Error('oh snap')`, so `return nil\Error('oh snap')` hands back a falsy value that still carries its message.

```code
if x > 10
    'big'
elif x > 5
    'medium'
else
    'small'
end

unless logged_in
    redirect('/login')
end

# Inline conditionals
@puts 'yes' if condition
@puts 'no' unless condition
```

## While & Until Loops

1. `while` loops while condition is true
2. `until` loops until condition becomes true
3. `elwhile` (or `elswhile`) and `eluntil` (or `elsuntil`) add branches, the same way `elif` does for `if`. The whole chain is one loop: each pass checks every branch in order and runs the first one that holds (a `while` branch on a truthy condition, an `until` branch on a falsy one). When no branch holds, `else` runs and the loop ends
4. A chain keeps one kind. A loop chain takes only loop branches, so `elif` in it raises `Code::Elif_In_Loop_Chain`: write `else`, then an `if` inside it. An `if`/`unless` chain takes only `elif`/`elsif`, so `elwhile` in it raises `Code::Loop_Branch_In_If_Chain`
5. `skip` ends the current pass. `stop` ends the whole loop, and `else` does not run
6. `when` cases work on each branch, the same as on `if`: they see the branch's condition value. The cases after `else` see the last condition that was checked

```code
i := 0
while i < 5
    @puts i
    i += 1
end

j := 0
until j == 5
    @puts j
    j += 1
end

# Chained loops: one loop, the first branch that holds runs each pass
x := 0
y := 0
while x < 4
    x += 1
elwhile y > -8
    y -= 1
else
    @puts 'done'   # runs once, when neither branch holds
end

# `when` on a loop branch, with the cases after `else` for the nil that ends it
while line := read_line(socket)
when 'GET / HTTP/1.1'
    @puts 'the root'
when String
    @puts "a line: `it`"
else
when nil\<reason: String>
    @puts "ended: `it.@tag.reason`"
end
```

## For Loops

1. Iterate over arrays, ranges, or any iterable
2. `it` is the current element
3. `at` is the current index

```code
for [1, 2, 3]
    @puts it      # Current element
    @puts at      # Current index
end

for 1..5
    @puts it      # 1, 2, 3, 4, 5
end

# With stride (chunks)
for [1, 2, 3, 4, 5, 6] by 2
    @puts it      # [1,2], [3,4], [5,6]
end
```

## C-Style For Loops

1. `for <counter>, <condition>, <step> ... end` -- comma-separated, like most C-family languages
2. The counter is also readable by its own declared name, in addition to `it`/`at`
3. `it` mirrors the counter's value; `at` is always the plain iteration count (0, 1, 2...), regardless of the step
4. The counter is scoped to the loop -- gone once it ends
5. Any step expression works, not just `++`/`--`
6. Also works as an end-of-line loop: `<expr> for <counter>, <condition>, <step>`

```code
for i := 0, i < 5, i++
    @puts i       # 0, 1, 2, 3, 4 -- same as `it`
end

# Counting down
for i := 5, i > 0, i--
    @puts it      # 5, 4, 3, 2, 1
end

# Any step expression works
for i := 0, i < 10, i += 2
    @puts it      # 0, 2, 4, 6, 8
end

# it vs at: it tracks the counter, at always tracks the iteration count
for i := 0, i < 10, i += 3
    @puts it      # 0, 3, 6, 9   -- the counter, skipping by 3
    @puts at      # 0, 1, 2, 3   -- always +1 per iteration, no matter the step
end

i   # Undeclared_Identifier -- the counter didn't leak past `end`

# End-of-line form
items := []
items.push(it) for i := 0, i < 5, i++
```

## For Loop Verbs

1. `map` transforms each element
2. `select` filters where body is truthy
3. `reject` filters where body is falsy
4. `count` counts where body is truthy

```code
doubled := for [1, 2, 3] map
    it * 2
end  # [2, 4, 6]

evens := for [1, 2, 3, 4, 5] select
    it % 2 == 0
end  # [2, 4]

odds := for [1, 2, 3, 4, 5] reject
    it % 2 == 0
end  # [1, 3, 5]

even_count := for [1, 2, 3, 4, 5, 6] count
    it % 2 == 0
end  # 3
```

`by <stride>,<overlap>` slides each window forward by `stride - overlap` elements, so consecutive windows share `overlap` elements instead of being disjoint:

```code
pairs := for [1, 2, 3, 4, 5, 6] map by 2,1   # stride 2, sliding forward by 1
    <it.0, it.?1>
end  # [<1, 2>, <2, 3>, <3, 4>, <4, 5>, <5, 6>, <6, nil>] -- every consecutive pair, plus a trailing short window

windows := for [1, 2, 3, 4, 5, 6, 7] map by 3,1   # stride 3, sliding forward by 2
    <it.0, it.?1, it.?2>
end  # [<1, 2, 3>, <3, 4, 5>, <5, 6, 7>, <7, nil, nil>] -- each window shares 1 element with the next
```

A trailing window shorter than `stride` is kept, not dropped. Use `.?N` (not `.N`) past index 0, since only the first element is guaranteed. `overlap` must be smaller than `stride`.

## `when`

1. Attaches to `if`/`elif`/`unless`, to each branch of a `while`/`until` chain, and to `for`, comparing against a subject: the condition's value for `if`/`elif`/`unless` and for a `while`/`until` branch, the current element for `for` (the counter, for C-style `for`).
2. The block's own body runs first; a matching `when` then replaces its value. First match wins.
3. Compares with `=>=` (is-a) for a type, bare or tagged (`Number`, `Array\String`, `nil\Error`), or a struct. Every other value compares with `==`, an instance included. So one `when nil\Client_Error` catches every error kind that composes `Client_Error`. Put the most specific case first:

```code
handle ( line;
	if line
		parse(line)
	else
	when nil\Connection_Closed
		stop
	when nil\Client_Error
		socket.write(CODE_400)   # every kind that composes Client_Error
	when nil\Error
		@panic "unexpected: `it`"
	when nil
		stop                     # a plain nil
	end
)
```
4. A bare `when it` matches everything — a catch-all.
5. A case that uses `it` in an expression is a condition of its own: `when it > 3`, `when it =>= Number`, `when it.@tag.reason == 'closed'`. It matches when the expression is truthy, and nothing is compared.
6. On `for`, `else` runs only when nothing matched. On `if`, each group of cases belongs to its branch: the cases after the body see only truthy values, and `else` takes every falsy value (see below). Each `elif` has its own `when` group.
7. One `end` closes the whole block — a `when` clause has none of its own.
8. Inside a matching `when`, `it` holds the matched value — but only `for`, `.each`, and a `when` clause declare `it`; a plain `if`/`unless` with no `when` does not.

```code
result := if 100
    'ran the if body'
when 100
    'perfect'
when Number
    'a number, but not perfect'
else
    'a falsy value'
end  # 'perfect' -- the first match wins, even though `Number` would also match

for [1, 'two', 3]
    @puts 'body runs first'
when String
    @puts 'a string'
when Number
    @puts 'a number'
end

# else runs once per iteration, only when nothing matched that iteration
for [1, 2, 3]
when 99
    @puts 'never matches'
else
    @puts 'else runs each time'
end
```

`when` cases can also follow `else`. They belong to the else branch, so on an `if` they see every falsy value, and the cases after the `if` body never do. The else body runs first, a matching case replaces its value, and a second `else` runs when no case matched. That second `else` catches every value that is left, so nothing can follow it. On `unless`, the branches swap: the cases after the body see falsy values, and the cases after `else` see truthy ones.

```code
if data
    "value: `data`"
else
when nil\Error
    "error: `it.@tag.message`"
when nil
    'a plain nil'
else
    'false'      # nothing matched: here, only `false`
end
```

## Loop Control

1. `skip` continues to next iteration
2. `stop` breaks out of loop
3. `return` exits the function (propagates through loops)

```code
for items
    skip if it.this     # Continue to next
    stop if it.that     # Break out
end

find_first ( predicate;
    for items
        return it if predicate(it)
    end
    nil
)
```

## Splatting a Scope

Every scope keeps two extra fallback places identifier lookup checks after its own declarations — a **read-only** set and a **writable** set — making an instance's members reachable without an `instance.` prefix. Lookup order: `[self, writable, read-only]`.

1. `@splat x` unpacks `x` as a writable splat; `@splatr x` read-only; `@unsplat x` removes it. Works on a function param or by hand anywhere.
2. A `: Type` / `: <...>` annotation on a splat param is enforced at the call, raising `Type_Contract_Violation` right there.
3. Both sets are held *weakly* — a splatted instance isn't kept alive by the splat alone.
4. The standard library works this way — `String`/`Array`/etc. sit on Global's own read-only splat, not declared on Global directly. Reassigning a built-in (`Array = Mine`) just shadows the name; the real one is untouched.

```code
Vector {
    x := 0
    y := 0
}

# Auto-unpack in a parameter
magnitude ( @splatr vec;
    (x ** 2 + y ** 2).sqrt()  # x, y resolve directly
)

v := Vector()
v.x = 3
v.y = 4
magnitude(v)  # 5

# @splat (writable) lets a plain write reach the unpacked instance's own member
double ( @splat vec;
    x *= 2   # writes straight through to vec.x
    y *= 2
    vec
)
doubled := double(v)  # doubled.x: 6, doubled.y: 8

# By hand, anywhere
@splatr some_instance
@unsplat some_instance
```

```code
# The standard library works the same way -- Array is reachable through
# Global's own read-only splat, not declared on Global directly
Mine | Array { extra := true }
Array = Mine          # shadows the name -- the real Array is untouched
[1, 2, 3].length()    # 3 -- still works, Mine composes Array
[1].extra              # true -- and every array literal now has this too
```

An unpacked instance stays visible to functions defined after it, even nested ones:

```code
Point {
    a := 0
    b := 0

    Self ( a, b;
        self.a = a
        self.b = b
    )
}

outer (;
    p := Point(23, 42)
    @splatr p

    inner (;
        a + b   # a, b resolved from p via the splat, despite being nested inside outer
    )

    inner()
)
outer()  # 65
```

## Reopening Scopes (`@push_scope`/`@pop_scope`)

1. `@push_scope <Type or instance>` pushes that scope directly onto the stack, so declarations made inside it become real members of the target
2. `@pop_scope <same target>` pops back to the previous scope — it asserts (by identity) that you're popping what you actually pushed, raising instead of popping the wrong thing
3. Unlike a splat, `@push_scope` mutates its target — reopening a Type extends every instance of it, reopening a specific instance changes only that one

```code
Button {
    label := 'default'
}

@push_scope Button
    css_filter := 'invert()'   # extends the Type itself
@pop_scope Button

b := Button()
b.css_filter   # 'invert()' — every Button gets it, since Button itself was extended

@push_scope b
    onclick := { @puts 'clicked' }   # modifies just this instance
@pop_scope b

c := Button()
c.onclick   # raises Code::Undeclared_Identifier — only b was modified
```

## Arrays

1. Created with `[]` brackets
2. Access elements with subscript or dot notation

```code
arr := [1, 2, 3, 4, 5]
arr[0]              # 1
arr.0               # 1 (dot notation)

arr.push(6)         # Add to end
arr.pop()           # Remove from end
arr.length()        # 5
arr.first(2)        # [1, 2]
arr.last(2)         # [4, 5]
arr.reverse()
arr.include?(3)     # true
arr.empty?()        # false

arr.map(x; x * 2)       # a lone anonymous-function argument may drop its own parens
arr.filter(x; x > 2)    # (equivalent to arr.filter((x; x > 2)))
```

## Dictionaries

1. Created with `{}` braces and `key = value` entries, separated by a comma or a new line
2. A bare name on the left is a String key: `{name = 'Jack'}` has the key "name". Write `{:name = 'Jack'}` for a Symbol key, or `{'first name' = 'J'}` for any String
3. Any other left side is evaluated, so any value can be a key: a Number, `true`, `nil`, a struct, or an Array. A struct or an Array compares by its current values, so after one changes, its new value finds the entry and its old value does not. A Set follows its struct and Array elements the same way. Parentheses evaluate a name: `{(camp) = 'hut'}` uses camp's value
4. A key keeps its own type, as in Ruby: `:x` and `'x'` are two keys
5. A `{}` body of only `=` entries (or nothing) is a Dictionary. Anything else is a block with its own scope: `{ x }` gives x, and a `:=` inside it stays inside
6. Read with a subscript, `dict[key]`. A dot reads the Symbol key, then the String key: `dict.x`. A dot never writes: `dict.x = 1` raises `Code::Dictionary_Dot_Write`, so write with a subscript, `dict[:x] = 1`
7. The old `{x: 10}` raises `Code::Colon_Dictionary_Entry`, because after a name `:` starts a type annotation

```code
dict := {:x = 10, :y = 20}
dict[:x]            # 10
dict[:z] = 30       # Assignment

dict.keys()         # [:x, :y, :z]
dict.values()       # [10, 20, 30]
dict.has_key?(:x)   # true
dict.count()        # 3
dict.empty?()       # false
dict.delete(:z)
dict.merge({:a = 1})
dict.fetch(:missing, 'default')

camp := 'beach'
places := {name = 'Jack', :name = :Jack, 123 = <true>, (camp) = 'hut', Vec2(0, 0) = player_a}
places['name']      # 'Jack' -- a bare name is a String key
places[:name]       # :Jack -- another key
places.name         # :Jack -- a dot reads the Symbol key first
places['beach']     # 'hut' -- (camp) uses camp's value
places[Vec2(0, 0)]  # player_a -- a struct key compares by its member values
```

## Sets

1. An unordered collection of unique items -- no literal, build one with `Set(...)`
2. Seed it from an array, a range, or another set

```code
s := Set([1, 2, 2, 3])   # {1, 2, 3} -- dedups
s.add(4)                  # mutating methods return self, so they chain
s.include?(2)             # true
s.length()                # 4
s.values()                # [1, 2, 3, 4] -- a fresh array snapshot

Set([1, 2, 3]) | Set([3, 4])    # union          -> {1, 2, 3, 4}
Set([1, 2, 3]) & Set([2, 3, 4]) # intersection   -> {2, 3}
Set([1, 2, 3]) - Set([2, 3, 4]) # difference     -> {1}
Set([1, 2, 3]) ^ Set([2, 3, 4]) # symmetric diff -> {1, 4}

Set([1, 2]).subset?(Set([1, 2, 3]))   # true
Set([1, 2, 3]).map(n; n * 10)          # [10, 20, 30]

for Set([1, 2, 3])
    @puts it
end
```

## Strings

```code
s := 'Hello, World!'
s.length            # 13
s.0                 # 'H' (dot notation, indexes by character -- same as Array's own .0)
s.upcase()          # 'HELLO, WORLD!'
s.downcase()        # 'hello, world!'
s.split(', ')       # ['Hello', 'World!']
s.trim()            # Remove whitespace
s.chars()           # ['H', 'e', 'l', ...]
s.reverse()
s.include?('World') # true
s.start_with?('He') # true
s.end_with?('!')    # true
s.gsub('World', 'Backend')
s.to_i()            # Convert to integer
s.empty?()          # false
```

## Percent Literals

1. `%string(...)`/`%symbol(...)` turn space-separated bare items into a real Array of String/Symbol literals, preserving each item's own casing
2. `%str`/`%Str`/`%STR` force lower/Capital/UPPER casing on the strings; `%sym`/`%Sym`/`%SYM` do the same for symbols
3. Items can be identifiers, numbers, or operators, not just letters
4. Items split only on whitespace, not on punctuation — `1px` and `file.ext` each stay one item
5. A `` `expr` `` item (see Statement Expressions below) is evaluated immediately, like string interpolation, and folded through the same casing treatment as everything else

```code
%string(boo Hoo COOL)      # [boo, Hoo, COOL]
%symbol(BOO hoo Cool)      # [:BOO, :hoo, :Cool]

%str(Boo hOO COOL)         # [boo, hoo, cool]
%Str(boo HOO cOOl)         # [Boo, Hoo, Cool]
%STR(boo Hoo cool)         # [BOO, HOO, COOL]

%sym(Boo HOO cOOl)         # [:boo, :hoo, :cool]
%Sym(boo HOO cOOl)         # [:Boo, :Hoo, :Cool]
%SYM(boo Hoo cool)         # [:BOO, :HOO, :COOL]

%string(boo 4815 + - *)    # [boo, 4815, +, -, *]

cool := 2342
%string(481516 `cool`)     # [481516, 2342] -- `cool` is interpolated, not stored as-is

%string(1px solid red)     # [1px, solid, red]
%string(file.ext other)    # [file.ext, other]
```

## Statement Expressions

1. `` `expr` `` wraps any expression without running it -- a `Code::Statement`, callable later with `()`
2. Written straight at a call site, `` `expr`() `` just evaluates immediately
3. Stored in a variable, each call re-evaluates the wrapped expression fresh, remembering the scope it was *built* in (a normal closure, wherever `()` is called from)
4. `.memoize = true` caches the first call's result instead of re-running every time
5. `.use_caller_scope = true` does the opposite -- resolves fresh against wherever `()` is actually called from

```code
`1+2`()                    # 3 -- evaluated right away

x := `1+2`
x()                        # 3
x: Statement = `1+2`       # same thing, with an explicit type annotation

counter := 0
increment := `counter += 1`
increment()
increment()
increment()
counter                    # 3 -- each call actually re-ran the body

cached := `counter += 1`
cached.memoize = true
cached()                   # 4
cached()                   # 4 -- didn't run again
```

See `examples/statements.code` for the full picture, including `.use_caller_scope`.

## Numbers

`Number` is the abstract base — never instantiated directly. Each concrete type wraps a Ruby class:

| Language type | Ruby class | literal |
|---|---|---|
| `Integer` | `Integer` | `4` |
| `Float` | `Float` | `4.5` |
| `Decimal` | `BigDecimal` | none — `Decimal('1.50')` / `Decimal(x)` only |
| `Number` | — (base) | — |

`Int`, `Flo`, and `Dec` are short aliases for `Integer`, `Float`, and `Decimal` — `4 === Int` and `4 === Integer` are both true, since an alias is the exact same type, not a subtype.

```code
n := 42
n.abs()             # Absolute value
n.floor()           # Round down
n.ceil()            # Round up
n.round()           # Round to nearest
n.sqrt()            # Square root
n.even?()           # true
n.odd?()            # false
n.to_s()            # '42'
n.clamp(0, 100)     # Clamp to range
```

## Dates & Times

`Date`, `Time`, and `Date_Time` are always available -- no `@load`.

```code
Date.today()                # today
Date.parse('2020-03-15')
Time.now()
Time.at(1_700_000_000)      # from epoch seconds
Date_Time.now()
Date_Time.parse('2020-03-15T09:30:00+00:00')

d := Date.parse('2020-03-15')
d.year         # 2020
d.month        # 3
d.day          # 15
d.weekday      # 0   (0 = Sunday .. 6 = Saturday; Date only)
d.iso8601()    # '2020-03-15'

Time.now().epoch()   # Unix seconds (Time only)

Date.parse('2020-01-01') < Date.parse('2021-01-01')   # true -- all of < > <= >= == != work
```

`Time` and `Date_Time` also have `.hour`, `.minute`, `.second`.

## Ranges

Base is two dots `..`; the others add a `<` or `>` to trim an end. (`...` is not a range operator — it's the variadic-param sugar.)

1. `..` inclusive range
2. `..<` exclusive end
3. `>..` exclusive start
4. `>..<` exclusive both

```code
1..5    #   1, 2, 3, 4, 5    (inclusive)
1..<5   #   1, 2, 3, 4       (exclusive end)
1>..5   #      2, 3, 4, 5    (exclusive start)
1>..<5  #      2, 3, 4       (exclusive both)

for 1..10
    @puts it
end
```

A range is a real value with its own methods:

```code
r := 1..5
r.start()          # 1
r.finish()         # 5
r.length()         # 5
r.include?(3)      # true
r.to_a()           # [1, 2, 3, 4, 5]
r.sum()            # 15
r.map(n; n * n)             # [1, 4, 9, 16, 25]
r.filter(n; n % 2 == 0)     # [2, 4]

x: Range = 1..5    # a `: Range` contract holds
1..5 === Range     # true
```

A range also works as an Array or String subscript — each operator keeps its own end/start rule, so `[1..3]` is one element longer than `[1..<3]`. Endless and beginless forms slice too; a negative endpoint counts from the end:

```code
xs := [10, 20, 30, 40, 50]
xs[1..3]     # [20, 30, 40]      inclusive
xs[1..<3]    # [20, 30]          exclusive end
xs[2..]      # [30, 40, 50]      endless
xs[..3]      # [10, 20, 30, 40]  beginless
xs[..-1]     # [10, 20, 30, 40, 50]   -1 is the last index
"abcdef"[0..<2]   # 'ab'
```

## File & Dir

```code
content := File.read('./file.txt')
File.write_string_to_file('./out.txt', 'Hello!')
File.list_directory('./src')          # sorted child names

d := Dir('./src')
d.children()     # full paths of every child
d.subdirs()      # child directories, as paths
d.files()        # child files, as paths
d.size()         # recursive total bytes
d.size_of(path)  # one file's bytes, or one dir's recursive total
Dir.pwd()        # -> Dir
```

Both are always loaded — no `@load`.

## The Context (`@`)

`@` is the current scope's *context* — reflective facts about wherever it's written, plus a set of built-in functions. Every scope has one: Global, a Type, an instance, a function body. There's no separate "directive" concept — `@word` is just `@.word`.

```code
@ === Context      # true
@.name             # 'Global' at the top level
@.to_s()           # '@Global'
```

`@word` is shorthand for `@.word` — `@name` is `@.name`, and `@puts x` / `@load 'f'` call a function member.

### Reflective vitals

Read-only facts about the scope, computed live on every access:

```code
Flying { airborne := true }
Duck | Flying {}

Duck.@name              # 'Duck'
Duck.@composed_types    # Set{'Duck', 'Flying'} — own name plus every |/&/~/^ type
Duck.@object_id         # the plain Ruby number

[1, 2, 3].@type         # 'Array' — @type / @types read on any value
nil.@type               # 'Nil'
```

Reflection lives on `@` only — a struct member named `name` or `types` never collides with the reflective accessor of the same name:

```code
Row <name: String, types: Number>
r := Row('cooper', 3)

r.name         # 'cooper'        — the member
r.@name        # 'Row'           — the struct's identifier
r.@type_names  # ['String', 'Number']
r.@names       # ['name', 'types']
```

### Function members

`@puts`, `@assert`, `@refute`, `@sleep`, `@load`, `@declare`, `@push_scope` / `@pop_scope`, `@connect`, `@start_server` / `@stop_server`, and the scope functions `@splat` / `@splatr` / `@unsplat` all live on the context. A bare `@puts` (no call) is the function itself, so it can be captured:

```code
kept := @puts('logged')   # prints 'logged', returns it unchanged (a passthrough)
p := @puts
p('again')                # 'again'
```

`@raise`, `@panic`, `@unreachable`, and `@todo` are different: they stop the program, so a bare one is always a call, never the function itself. Parens are optional, and each argument adds one line to the message:

```code
@unreachable                                # This code should be unreachable.
@unreachable "the cache is empty", count    # the same line, then one line per argument
@raise "boom", "while saving"               # boom, then while saving
@raise Error("my message")                  # raises the value itself: Error: my message
@todo                                       # [TODO]
```

### Your own `@` members on a Type

Inside a `Type { }` body you can hang your own members off the type's context. They show up under `@` only, so they can't collide with the type's real members. A built-in name (`@name`, `@types`, ...) is reserved.

```code
Widget {
    @version := 2
    @author: String = 'me'

    stamp (; "widget v`@version` by `@author`" )
}

Widget.@version   # 2
w := Widget()
w.@version        # 2 — an instance reads through to its type's context
```

## @load

1. Imports another Code file
2. A file is only run once per scope it's loaded into — loading the same file into the same scope again returns the first run's result instead of re-running it
3. Imports may be scoped by assigning the @load to a variable
4. The path can also be written bare (unquoted), as long as it starts with `./`, `../`, or `~/` — a `\ ` pair escapes a literal space, the same way a shell's own tab-completion writes one

```code
@load 'lang/string.code'
@load 'lang/array.code'
@load './my_module.code'
my_mod := @load './my_module.code'
my_mod.Some_Type()

@load './my_module.code'   # already loaded into this scope -- returns the same result again, doesn't re-run

@load ../shared/thing.code
@load ~/.config/backend/init.code
@load ./tools/blah\ blah/hello.code   # -> tools/blah blah/hello.code

@load asdf/asdf.code   # NOT a bare path -- no leading ./, ../, or ~/, so this parses as ordinary
                        # division (asdf / asdf . code) same as it always has
```

A relative path resolves the same way wherever you start `bin/program`. The first place where the file exists wins:

1. The folder of the file that holds the `@load`. So `@load ./helper` in `app/main.code` finds `app/helper.code`.
2. The folder you started `bin/program` from. Code with no file of its own (`bin/program interp "..."`) starts here.
3. The language's own folder (`source/`). This is how `@load 'lang/html'` finds the standard library from anywhere.

`../x` climbs one folder, `../../x` climbs two, and `~/x` starts at your home folder. Only your own `~/` works: `~otheruser/path` is not a bare path.

## @puts

```code
@puts 'Hello, World!'
@puts variable
@puts "Value: `expression`"
```

`@puts` is a passthrough: it prints, then returns the original value unchanged, so it can sit inline anywhere an expression is expected:

```code
double ( n; n * 2 )
double(@puts 5)   # prints 5, returns 10 -- the call still gets the real 5
```

### Telling printed values apart

Each built-in collection prints inside a different bracket, so you can tell what you're looking at at a glance:

```code
@puts [1, 2, 3]      # [1, 2, 3]      -- Array
@puts {x = 1, :y = 2}   # {x = 1, :y = 2}   -- Dictionary
@puts <1, 2, 3>      # <1, 2, 3>      -- Struct
```

A custom type prints as raw internals until it defines its own `to_s(;)` — see [Classes](#classes):

```code
Point {
    x := 1
    greet (; 'hi' )
}
@puts Point()   # #<Code::Instance name="Point" declarations=["x", "greet"]>
```

Nothing enforces a bracket convention for your own types, but a non-colliding one keeps output easy to scan.

## @declare

1. Declares an identifier on the current scope from a runtime String name, rather than a literal identifier written in the source (what `:=` needs)
2. `@declare name` declares `nil`; `@declare name, value` and `@declare name, value, type` add a value and, optionally, a type
3. Passed a Struct instead of a name, spreads every *named* member onto the current scope in one go — each member's own name, value, and declared type carry over directly

```code
@declare 'flare_count'          # flare_count == nil
@declare 'flare_count', 3       # flare_count == 3
@declare 'ration', 2, Number    # same as `ration: Number = 2`

supplies := <water: Number = 40, wood: Number = 12>
@declare supplies               # water == 40, wood == 12
```

## Web Server

1. Compose with `Server` type
2. Define routes with HTTP method syntax
3. Boot with `@start_server` (background thread; `@stop_server` to shut one down)

```code
@load 'lang/server.code'

App | Server {
    Self (;
        self.port = 3000
    )

    get:// (;
        'Hello, World!'
    )

    get://about (;
        'About page'
    )
}

@start_server App()
```

## Routes

1. HTTP methods: `get://`, `post://`, `put://`, `delete://`, `patch://`
2. URL parameters with `:param` syntax
3. Query params via `request.query`

```code
App | Server {
    # Static route
    get://users (;
        'All users'
    )

    # URL parameter
    get://users/:id ( id;
        "User `id`"
    )

    # Multiple params
    get://posts/:post_id/comments/:id ( post_id, id;
        "Comment `id` on post `post_id`"
    )

    # Query strings: /search?q=term
    get://search (;
        query := request.query[:q]
        "Searching for `query`"
    )
}
```

## Request & Response

```code
post://login (;
    username := request.body[:username]
    password := request.body[:password]

    if authenticate(username, password)
        response.redirect('/dashboard')
    else
        response.status = 401
        'Unauthorized'
    end
)

get://api/data (;
    response.headers['Content-Type'] = 'application/json'
    '{"status": "ok"}'
)
```

## Database

1. `@load 'lang/database.code'` -- this pulls in `lang/table.code` too
2. `Sqlite(url)` builds a database; `@connect` opens it and **returns it**
3. `Sqlite.memory()` for an in-memory db, `Sqlite.local('a/path.db')` for a file at that path verbatim -- the parent directory has to already exist

```code
@load 'lang/database.code'

db := @connect Sqlite('./data/app.db')
```

A schema is a **named Struct** -- one member per column, its type deciding the column type. The table name comes from the struct's name (`User` -> `users`), so the struct has to be named.

```code
User <
    id: Primary_Key
    name: String
    email: String
    joined_at: Date_Time
>

db.find_or_create_table(User)   # -> a Table (creates it if missing)
db.table_exists?(User)          # true          (also takes a bare :users)
db.tables()                     # [users]  -- Symbols
db.find_table('users')          # -> a Table, or nil
db.delete_table!(User)          # also takes a bare :users
```

Column types: `Primary_Key`, `String`/`Text`, `Int`/`Integer`, `Number`, `Float`, `Decimal`, `Bool`, `Date`, `Time`, `Date_Time`, and an `Enum` (stored as text). A member of any other type (`Array`, `Dictionary`, `Set`, `Range`, `Rational`, `Symbol`, `Buffer`, a nested struct) gets no column yet, and nothing reports it.

## Record ORM

`db.find_or_create_table(schema)` returns a `Table`. CRUD lives on that object. You can also compose the table into a struct (see the end of this section).

```code
User <
	id: Primary_Key
	name: String
>

users := db.find_or_create_table(User)

cooper := users.create(<name := 'Cooper'>)   # attrs are a `:=`-member Struct
users.create(<name := 'Luna'>)

users.all()                       # Array of record Structs
users.find(cooper.id)             # one record Struct, or nil
users.find_by(<name := 'Luna'>)   # first match, or nil
users.where(<name := 'Luna'>)     # Array of matches
users.update(cooper.id, <name := 'Cooper II'>)
users.delete(cooper.id)
users.count()
```

- A record is a `Struct` named after the schema -- read members by name (`record.name`), or `record.to_h` for the whole row
- `Bool` columns round-trip as real `true`/`false`; `Date`/`Time`/`Date_Time` columns round-trip as the matching wrapper (`record.joined_at.year`)
- A filter naming a column the schema doesn't have raises `Code::Table_Invalid_Filter_Column`

Compose the table into a struct to keep the data, its logic, and its table under one name. The table's methods stay bound to the table, so `User_Record.find` reads `users`:

```code
User_Logic {
    greet (; "Hi `name`" )
}
User_Record | User | User_Logic | users <>

User_Record.create(<name := 'Ada'>)
User_Record.find(1).name            # 'Ada'
User_Record(name := 'Bob').greet()  # 'Hi Bob' -- a record built in memory gets the logic
```

- A record that `find`, `where`, or `all` returns is still a plain `User` struct, with no logic
- The table's own members (`columns`, `database`, `table_name`) also come in, after the schema's members

## HTML Elements

1. Compose with HTML element types from `lang/html.code`
2. `css_*` prefix sets inline CSS properties
3. `html_*` prefix sets HTML attributes
4. `.to_s()` renders an element and its children to string directly
5. When a server renders a page, text children, attribute values, and `css_*` values are escaped, so text from a user can never become markup. The text inside `Script` and `Style` stays raw, because it is JavaScript or CSS

```code
@load 'lang/html.code'

Card | Div {
    css_padding := '1rem'
    css_border_radius := '8px'
    css_background_color := '#fff'

    html_class := 'card'
    html_data_value := 42
    html_aria_label,
}

Link | A {
    html_href = '#'
    html_target := '_blank'
}

page := Html([
    Head(Title('My Page'))
    Body([
        H1('Welcome')
        Card([
            P('Hello!')
            Link('Click me')
        ])
    ])
])
```

## CSS

1. `@load 'lang/css.code'` -- CSS is plain data: `Property`/`Style_Rule`/`At_Rule`/`Scope_Rule`/`Custom_Property_Rule`/`Layer_Order`/`Keyframe`/`Variable_Declaration`/`Css_Function`/`Color` are all bare structs, no parser involved
2. `Css_Formatter_Visitor` walks the tree into a real CSS string -- pretty by default, `minify := true` for one line
3. A rule nested inside another rule's `rules` gets a synthesized `&` prefix; a rule inside an `At_Rule`/`Scope_Rule` body does not, since there's no parent selector to refer to
4. `Css_Lint_Visitor` checks for duplicate properties, hardcoded vendor prefixes, and redundant zero-units (`0px` -> `0`). Given a whole `Stylesheet`, it also warns when a state rule (`:hover`, `:focus`, ...) sets `transform` while the base selector runs a keyframe `animation` that also animates it -- the animation overrides the hover value every frame

```code
@load 'lang/css.code'

rule := Style_Rule(['.card'], [Property('color', 'red'), Property('padding', '8px')])

Css_Formatter_Visitor().format(rule)
# ".card {\n    color: red;\n    padding: 8px;\n}"

Css_Formatter_Visitor(minify := true).format(rule)
# ".card{color:red;padding:8px;}"

Css_Lint_Visitor().lint(Style_Rule(['.a'], [Property('color', 'red'), Property('color', 'blue')]))
# ["Duplicate property 'color'"]
```

## Struct-Based HTML

1. `@load 'lang/html2.code'` -- same spirit as CSS above: `Element <tag, attributes: Array\Attribute, css: Css, children>` is the one node shape, and lowercase constructors (`div`, `p`, `h1`, ...) build it. Coexists with `lang/html.code`'s `Dom` types above -- this one only builds an HTML string, it doesn't hook into the server's live-render pipeline
2. `attributes` is an ordered `Array\Attribute`, not a Dictionary -- attributes keep their given order and can even collide (see `Html_Lint_Visitor` below)
3. `css` takes any css.code struct directly -- `Html_Formatter_Visitor` renders it as an embedded `<style>` child wherever it's attached
4. `Html_Render`/`Html_Format` are compact/pretty formatter instances; void tags (`br`, `img`, `input`, ...) never get a closing tag in either mode
5. `Html_Stats_Visitor` (node count, depth, unique tags), `Html_Sanitizer_Visitor` (strips `script`/`iframe`/`object`/`embed` and `on*`/`javascript:` attributes), and `Html_Lint_Visitor` (void element given children, `<img>` missing `alt`, empty containers, duplicate attributes) walk the same tree for their own purposes
6. Text children and attribute values are escaped (`&`, `<`, `>`, `"`, `'`), so text from a user can never become markup -- `p('<b>')` renders `<p>&lt;b&gt;</p>`. The text inside `script` and `style` stays raw, because it is JavaScript or CSS

```code
@load 'lang/html2.code'
@load 'lang/css.code'

page := div([
    h1('Welcome'),
    p('Hello!', [Attribute('class', 'greeting')])
], [], Style_Rule(['.greeting'], [Property('color', 'blue')]))

Html_Render.render(page)
# '<div><h1>Welcome</h1><p class="greeting">Hello!</p><style>.greeting{color:blue;}</style></div>'
```

## Operators

### Arithmetic

```code
+ - * / %     # Basic math
**            # Exponentiation
<< >>         # Bitwise shift / Array append
```

### Bitwise

`&`, `^`, and `|` on numbers are bitwise AND, XOR, and OR. Prefix `~` is bitwise NOT. They bind tighter than the comparisons, as in Ruby: `a | b == 5` is `(a | b) == 5`.

```code
MASK  := 12
OTHER := 3

MASK | 4           # 12
MASK & 4           # 4
MASK ^ OTHER       # 15
~MASK & 15         # 3
MASK | OTHER & 6   # 14 -- `&` binds tighter than `|`
```

An UPPERCASE name can be a type or a constant. `MASK | OTHER` is bitwise when `MASK` holds a value, and a [composition](#type-composition) when it is a type (`H1 | Dom {}`).

### Comparison

```code
== !=             # Equality
< <= > >=         # Relational
<=>               # Spaceship (three-way)
=~ !~             # Regex match
=== =!=           # Composed-type-set equality
=>= =<=           # Composed-type-set superset (and its mirror) =>= means "left superset of right?", and its mirror
=/=               # Composed-type-set disjointness means they don't share anything
```

`===`, `=!=`, `=>=`, `=<=`, and `=/=` compare *composed types* — a type's own name plus everything picked up via `|`/`&`/`~`/`^` — not values:

```code
Flying { can_fly := true }
Swimming { can_swim := true }

Duck | Flying | Swimming { name := 'duck' }
Fish | Swimming { name := 'fish' }

Duck === Duck          # true  (identical composed types)
Duck === Fish          # false (Duck also composes Flying)
Duck =!= Fish          # true

Duck =>= Swimming      # true  (Duck composes with at least Swimming)
Swimming =>= Duck      # false
Swimming =<= Duck      # true  (=<= is =>= with the operands flipped)

Duck =/= Fish          # false (both compose Swimming — not disjoint)
Flying =/= Swimming    # true  (share nothing)
```

All five also take [Structs](#structs) into account. An untagged type counts as having no members, so plain comparisons above are unaffected:

```code
Abc\<Number> {}
Abc\<Number> === Abc\<String>   # false — same composed type, different tag
Abc === Abc                     # true  — neither side tagged
```

A tag is-a its parent tag, on any tagged type. A tag that composes another type satisfies a tag of that type with `=>=`, but a parent never satisfies a child, and `===` stays exact:

```code
Client_Error | Error {}
Bad_Header   | Client_Error {}

nil\Bad_Header =>= nil\Client_Error       # true
nil\Bad_Header =>= nil\Error              # true  — Error is a struct; its name counts too
nil\Client_Error =>= nil\Bad_Header       # false — a parent is not a child
nil\Bad_Header === nil\Client_Error       # false
Array\Bad_Header =>= Array\Client_Error   # true
```

`Any` is a universal wildcard for `==`/`!=`/`=>=`/`=<=`/`=/=`: anything that isn't `nil` counts as equal to it, no composition needed. `===`/`=!=` are the exception — exact type-set equality, so a bare `Any` only matches `Any` itself there.

```code
String == Any     # true
4 == Any          # true
nil == Any        # false — the one exception
String =>= Any    # true — Any really is a superset of everything

String === Any    # false — === doesn't wildcard; neither composes the other
Any === Any       # true
```

A String compares equal (`==`/`!=` only) to a bare Type whose `@name` it spells:

```code
Flying { can_fly := true }
Duck | Flying {}

"Flying" == Flying                       # true
Duck.@composed_types.include?(Flying)    # true — the set holds the string 'Flying'
```

### Logical

```code
&& and        # Logical AND
|| or         # Logical OR
! not         # Logical NOT
```

### Assignment

```code
:=            # Declaration — introduces a new identifier, infers and locks its type
=             # Assignment — requires the identifier to already be declared
+= -= *= /=   # Compound assignment
&&= ||=       # Logical compound
<<= >>=       # Shift compound
```

## Operator Overloading

1. Declare with `@operator`, a symbol or identifier, a fixity (`@infix`, `@prefix`, `@postfix`), a precedence number, and a function body
2. Overloads are stored as regular functions in the declaring scope, so one can be scoped to a single function without leaking out
3. Precedence controls how overloaded operators combine with each other and with built-ins
4. A type's own overload always wins over a same-named one declared elsewhere — dispatch checks the left operand's type first, falling back to scope only if it has none

```code
# Redefine + only inside this function — everywhere else, + still adds
scoped := compute (;
    @operator + @infix 700 ( left, right;
        left * right
    )
    3 + 4
)

3 + 4      # 7 (unaffected outside)
scoped()   # 12

# Build a pipeline operator
@operator -> @infix 300 ( left, right;
    right(left)
)

double ( n; n * 2 )
add_fifteen ( n; n + 15 )

4 -> double -> add_fifteen  # 23

# Invent new literal syntax
Time { hour, minute, period, }

@operator : @infix 700 ( hour, minute;
    t := Time()
    t.hour = hour
    t.minute = minute
    t
)

@operator pm @postfix 600 ( left: Time;
    left.period = 'pm'
    left
)

11:22pm  # Time(hour := 11, minute := 22, period := 'pm')

# Or a prefix operator that builds a value from a bare literal
Currency { amount, name, code, }

@operator $ @prefix 900 ( amount;
    c := Currency()
    c.amount = amount
    c.name = 'US Dollar'
    c.code = 'USD'
    c
)

$42  # Currency(amount := 42, name := 'US Dollar', code := 'USD')

# A type's own overload beats a same-named global one (a fresh symbol, ~>, since redeclaring -> here would just overwrite the pipeline above)
@operator ~> @infix 300 ( left, right; 999 )

Wrapped {
    val,
    Self ( v; self.val = v )
    @operator ~> @infix 300 ( left, right; left.val )
}

a := Wrapped(42)
a ~> 1          # 42 — Wrapped's own ~> wins
5 ~> double     # 999 — global ~> still applies to everything else
```

## Runtime Type Contracts

1. `:=` infers a type from its right-hand side and locks the identifier to it
2. Subsequent `=` assignments are checked against that locked type; `:=` again re-infers and re-locks
3. A mismatch raises `Code::Type_Contract_Violation` when it runs. The static type checker finds some mismatches first (for example, a literal after a `: Type`) and raises `Code::Type_Mismatch` before the program runs
4. `x: Type` with no value declares `nil`, locked to that type
5. `:=` cannot follow a `: Type`, because it takes its type from the value. A typed variable, param default, or struct member uses `=`: `x: Int = 4`, `f ( n: Int = 0; )`, `<n: Int = 0>`. `x: Int := 4` raises `Code::Cannot_Annotate_Inferred_Declaration` when the file is parsed
6. A typed param is checked on every call, and so is its default when the call uses it

```code
x := 4        # declares x, infers Number, locks x to that type
x = 8         # ok — same type
x = 'hello'   # raises Code::Type_Contract_Violation ("expected Number, got String")

x := 4
x := 'hello'  # fine — re-declaring with := re-infers and re-locks the type
x             # 'hello'

y = 4         # raises Code::Cannot_Assign_Undeclared_Identifier — y was never declared

z: Int        # declares z as nil, locked to Int
z = 4         # ok
z = 'hello'   # raises Code::Type_Contract_Violation
z: Int := 4   # raises Code::Cannot_Annotate_Inferred_Declaration — write z: Int = 4

double ( n: Int = 1;
    n * 2
)
word := 'four'
double(word)  # raises Code::Type_Contract_Violation — checked on the call
```

A `: Type` annotation can join types, and [literals](#literal-types), with `|`, `&`, `^`, or `~`. Each one compares the values that the types allow: `|` either, `&` both, `~` the left but not the right, `^` exactly one. An annotation never builds a new composed type. `nil` passes every annotation. Give an annotation a name with [`::`](#type-aliases).

```code
x: Int | Nil = 1           # ok — an Int
x: Number & Integer = 4    # ok — both
x: Number ~ Float = 1.5    # raises Code::Type_Contract_Violation — a Float
x: Integer ^ Number = 4    # raises Code::Type_Contract_Violation — both, not exactly one
```

This holds everywhere a `: Type` annotation appears: a first assignment, a later reassignment, a bare `x: Type`, a param and its default, a function's own return type ([Function Signatures](#function-signatures)), and a destructuring target's own `: Type`.

Declaring a combined type first does *not* give a reusable OR check — a single named type in annotation position checks real is-a membership, not "one of the types it composed":

```code
Int_Or_Nil | Int | Nil {}
x: Int_Or_Nil = 4     # raises Code::Type_Mismatch, even though 4 is an Int (a literal, so the static checker finds it)
```

Spell out `x: Int | Nil` at each spot you need it. Declaring a combined type first *is* the right move for the other direction — a value that must actually be, or extend, that whole combined type:

```code
Combined | A | B {}
c := Combined()
x: Combined = c    # ok — c really is a Combined
```

## Function Signatures

1. `(Param, Param -> Type;)` is a signature — a function's shape (param types, return type) with no body, same `-> Type` placement a real function uses
2. A real function declares its return type with `-> Type` before `;`; a self-declaring signature uses the same shape under its name (`double: (Number -> Number;)`)
3. Assigning a function to a signature-typed identifier checks its actual shape — mismatches raise `Code::Type_Contract_Violation`
4. Any function with a declared return type is checked on every call, signature or not
5. An untyped or `Any` param or return matches any type in that slot, on either side. The param count must still match, and any other typed slot must match exactly
6. `(;)` matches any function, whatever its params and return type — write `x: (;)` for "any function"
7. A signature-typed param, inline (`fn: (Number -> Number;)`) or named (`fmt: Currency_Formatter`), is checked with the same rules on every call
8. Parentheses after `->` group one type: `-> (String | Number)`. A list there is not a type: `-> (String, Number)` raises `Code::Values_In_Parentheses` when the file parses. Use a struct shape for several values: `-> <String, Number>`

```code
Currency_Formatter := (Number -> String;)    # takes a Number, returns a String

format_usd ( cents: Number -> String;
    "$" + (cents / 100.0).to_s()
)

format_eur ( cents: Number -> String;
    "€" + (cents / 100.0).to_s()
)

formatter: Currency_Formatter = format_usd
formatter(1050)                         # "$10.5"

formatter = format_eur                  # ok — same shape: (Number) -> String
formatter(1050)                         # "€10.5"

formatter = ( cents; 'free' )           # ok — an untyped param or return matches any type
formatter = ( a, b; a )                 # raises Code::Type_Contract_Violation — wrong param count
formatter = ( cents: String; cents )    # raises Code::Type_Contract_Violation — String is not Number

keep: (Any -> Bool;) = ( n: Int -> Bool; n > 2 )    # ok — Any matches Int
```

`(;)` takes any function, and a signature-typed param is checked when you call:

```code
any_function: (;) = format_usd
any_function = ( a, b; a + b )          # ok — (;) matches any function
any_function = 5                        # raises Code::Type_Contract_Violation — not a function

apply ( fn: (Number -> Number;), n: Number; fn(n) )
apply(( x; x * 2 ), 4)                  # 8
apply(( x: String; x ), 4)              # raises Code::Type_Contract_Violation
```

A declared return type is enforced on its own, with no signature involved:

```code
lying ( a -> Number; a.to_s() )
lying(5)   # raises Code::Type_Contract_Violation — declared Number, actually returned String
```

A `Nil` return type is like a void function, it swallows whatever you try to return and will return `nil` instead.

```code
nothing ( anything: Any -> Nil;
	anything
)

nothing(123)        # nil
nothing('456')      # nil
nothing(nothing)    # nil
```

## Structs

1. `<...>` attaches runtime-inspectable metadata (a struct) to a standalone value. Tagging a *Type* itself uses `\` instead — `Array\<String> {}` (inline literal), `Array\Task_Schema {}` (named reference to a declared struct or Type), `Primary_Key\4815` (a bare integer "version tag")
2. `\` chains: `Thing\One\Two {}` tags `Thing` with `One`, itself tagged with `Two`. `.tag` is `One`, `.tag.tag` is `Two`
3. Each declared tag is its own type — `Abc\<Number> {}` and `Abc\<String> {}` share no `Self`/methods; `Thing\One\Two` and `Thing\One\Three` are distinct too
4. A reference matches a declared tag by type, at every link of the chain. A real Type with no matching variant yet auto-declares one; anything else with no match raises `Code::Undeclared_Tagged_Type`
5. Reachable through `.tag` (`.tag.types`, `.tag.some_name`) — bound before `Self(;)` runs, never forwarded as constructor args
6. `x.tag = new_tag` re-tags at runtime, only on a value whose type was declared with a tag, and only when `new_tag` composes at least everything the current tag does (`=>=`) — otherwise `Code::Tag_Signature_Violation`
7. Bare `<...>` (no `\`) on an *undeclared* identifier builds a plain named struct instead of raising; a name already taken by a real Type still takes priority
8. A bare named struct's member can be annotated with the struct's own name (`Node <name: String, parent: Node>`), so two structs can reference each other. An empty `Name <>` is a forward declaration a later `Name <...>` fills in; redeclaring with a *different* shape raises `Code::Undeclared_Tagged_Type`
9. A Type composed into a struct brings its methods with it, so the data and its logic can live apart: `User | User_Logic <name: String, age: Int>`, then `User('Ada', 36).greet()`. The methods go after the data members, so positional arguments fill the data members in order
10. An instance composed into a struct brings its type's methods too, but they stay bound to that instance: `Tasks | Task | tasks_table <>` gives a `Tasks.find` that runs on `tasks_table`. See Record ORM

```code
String\<dict: Dictionary> {
    to_s (; "dict: `tag.dict`" )
}
String\<num: Number> {
    to_s (; "number: `tag.num`" )
}

String\<{:x = 1}>().to_s()   # "dict: {:x = 1}"
String\<5>().to_s()       # "number: 5"

Format_A {} Format_B {} Format_C {}
Payload\Format_A\Format_B\Format_C {
    trace (; [self.tag.@type_names.0, self.tag.tag.@type_names.0, self.tag.tag.tag.@type_names.0] )
}
Payload\Format_A\Format_B\Format_C().trace()   # ['Format_A', 'Format_B', 'Format_C']

Thing := <String, Number>   # anonymous struct -- @.name is nil
n := Named<String, Number>  # bare <...>, no `\` -- Named is undeclared, so this builds a plain named struct instead
n.@name                     # 'Named'

Tree <
    value: Number
    children: Array
    parent: Tree             # a member typed with the struct's own name
>
```

### Several Values

1. A struct holds an ordered list of values: `<404, []>`. Read a value by its position with `.0` or `[0]`
2. `(status, body) := <404, []>` takes the values out by position. The `( )` on the left is the list of targets
3. A function returns several values as a struct. The return type is a struct shape, by name (`-> <ok: Bool, data: Any>`) or by position (`-> <Bool, Any>`). Each call checks the value it returns
4. `( )` around one value groups it. A list of values in `( )` is not a value: `(404, [])` raises `Code::Values_In_Parentheses`
5. A Type in a positional member is the member's type, not its value: `<Number>` is a slot for a Number. Give the member a name to keep a Type as a value: `<type := Number>`

```code
fetch (-> <ok: Bool, data: Any>;
    <ok := true, data := [1, 2]>
)
fetch().ok                  # true

split (-> <Bool, Any>;
    <false, 'reason'>
)
(ok, why) := split()        # ok is false, why is 'reason'

pair := <404, []>
pair.0                      # 404
pair[1]                     # []

broken (-> <ok: Bool>;
    <ok := 5>
)
broken()                    # raises Code::Type_Contract_Violation -- ok is not a Bool

pair := (404, [])           # raises Code::Values_In_Parentheses
```

## Enums (not finalized — don't rely on yet)

```code
Task_Type [
	TODO
	BUG,
	DONE: Priority             # type-annotated -- still Symbol-valued, annotation is metadata only
	CANCELLED: Priority = 99   # type-annotated with an explicit value
	ARCHIVED := 'archived'     # self-declared value, no annotation
]

Task_Type.TODO      # :TODO         -- a member value is a plain `.` access
Task_Type.@keys     # [TODO, BUG, DONE, CANCELLED, ARCHIVED]   -- reflective data is `@`-only
Task_Type.@count    # 5
```

Self-declaring, like `Type { }` and a named `func (;)` — no `:=`. `Name [ ... ]` is an enum when the brackets hold a comma, two-plus items, a member form, or nothing; a lone bare item (`Name [ ONE ]`) reads as an ordinary subscript instead. Force a one-option enum with a trailing comma or an annotation:

```code
Suit [ HEARTS DIAMONDS CLUBS SPADES ]   # space-separated is fine
Solo [ ONLY, ]                          # trailing comma -- a one-option enum
Level: Enum\Int [ LOW, HIGH ]           # annotated: always an enum; Int is the backing type
Level: Int [ LOW, HIGH ]                # same -- the backing type on its own, no `Enum\`
```

Enums are syntactically present but not finalized: each member's `: Type` annotation and the backing type are parsed and stored, but not enforced — nothing raises if a value doesn't match. The older forced-type spelling (`TYPE_IDENT :: Type { ... }`) no longer exists. Don't rely on Enum type-checking yet.

## Shorthand Nil-Initialization

Trailing comma declares variable as nil if undefined. 

```code
Type {
	undefined_var,      # equivalent to `undefined_var := nil`	
}

here_too,               # here_too := nil
```

A bare annotated identifier with nothing assigned behaves the same way — no need to write `= nil` just to make an already-self-declaring annotation (`x: Number`, or a struct annotation) actually declare something:

```code
thing: <String, Number>   # same as thing: <String, Number> = nil
thing                     # nil

x: Number                 # same as x: Number = nil
x                         # nil
```
