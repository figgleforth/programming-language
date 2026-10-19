![Version](https://img.shields.io/badge/version-0.0.0-2B7FFF.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-2B7FFF.svg)
[![justforfunnoreally.dev badge](https://img.shields.io/badge/justforfunnoreally-dev-2B7FFF)](https://justforfunnoreally.dev)
![Status of project Ruby tests](https://github.com/figgleforth/programming-language/actions/workflows/tests.yml/badge.svg)

### .code

An expressive language for myself, with features I wanted to experience. You can use it to write scripts, servers, and lots of stuff in between.

[Get started](ruby/readme.md) · [Learn by example](examples/readme.md) · [Read the reference](reference.md)

_This page is a short tour that shows the language off. The [reference](reference.md) is the complete description, and it is the page that is kept up to date._

### A full-stack app in one file

Server, database, HTML, and click handlers that run on the server, with no JavaScript.

> [!NOTE]
> For now, one single instance serves every visitor, so all visitors share its state. A separate state for each visitor is [coming soon](#one-state-per-visitor).

```code
@load 'lang/server'
@load 'lang/database'
@load 'lang/html'

db := @connect Sqlite.memory()
Todo <id: Primary_Key, title: String>
todos := db.find_or_create_table(Todo)

List | Div {                      # composition, applied to markup
    html_id := 'list'
    input := Input()
    add := Button('Add')

    Self (;
        add.onclick = (;          # runs on the server
            todos.create(<title := input.value>)
        )
    )

    render (;
        items := for todos.all() map
            Li(it.title)
        end
        [Ul(items), input, add]
    )
}

App | Server {
    list := List()
    get:// (; Html(Body(list)) )
}

@start_server App()
```

### Errors that point at the problem

Each error shows the exact span, the location, and the error type.

```
    1: x := 5
    2: y := x + zz
                ╰─┬─  zz has not been declared
                  ├─  e.code:2:10
                  └─  Undeclared_Identifier
```

### Errors that suggest the fix

Common mistakes come with the correction.

```
    2: f(mode: "fill")
         ╰─┬─  A named argument uses `:=`: `f(mode := "fill")`. After a name, `:` starts a type annotation.
           ├─  colon.code:2:3
           └─  Colon_Named_Argument
```

```
    1: x := (1, 2)
            ╰─┬─  A list of values in `( )` is not a value. Use a struct: `<404, []>`, or `<ok: Bool, data: Any>` for a return type. `( )` around one value groups it, and `(a, b) := ...` destructures.
              ├─  parens.code:1:6
              └─  Values_In_Parentheses
```

`v1.code` and `v2.code` load each other, and `v2.code` reads `limit` before `v1.code` sets it.

```
    2: double := limit * 2
                 ╰─┬─  limit has not been declared yet: v1.code declares it, but v1.code is still loading (v1.code → v2.code → v1.code)
                   ├─  v2.code:2:11
                   └─  Undeclared_Identifier
```

### The Basics

### Variables

Declare with `:=`.

```code
nothing := nil
something: Number = 123
_private := 'Yes'
tested? := false       # names can end in ? or !
pending,               # a trailing comma declares nil

y = 4                  # Cannot_Assign_Undeclared_Identifier
```

### Casing

The case of a name sets its role, and the interpreter enforces it.

```code
Counter {}             # Capitalized: a type
count := 0             # lowercase: a value or function
MAX := 10              # UPPERCASE: a constant

lower :: Integer       # Invalid_Type_Alias_Name
```

### Constants

Uppercase means it never changes.

```code
PI := 3.14159
PI = 3                 # Cannot_Reassign_Constant
```

### Strings

Backticks interpolate anything.

```code
name := 'World'
"Hello, `name`!"       # 'Hello, World!'
"2 + 2 = `2 + 2`"      # '2 + 2 = 4'
"Literal \`ticks\`"    # 'Literal `ticks`'

'Hello'.upcase()       # 'HELLO'
'Hello'.0              # 'H'
```

### Comments

One hash for a line, three for a block, and more to nest.

```code
# A single line.

###
A whole block, code included.
###

####
### Safely nested. ###
####
```

### Functions

### Functions

The last expression is the return value.

```code
add ( a, b; a + b )
add(4, 8)                    # 12

greet ( name := 'friend';
    return 'Hi!' unless name
    "Hello, `name`"
)

[1, 2, 3].map(n; n * 2)      # [2, 4, 6]
[1, 2, 3].map((n; n * 2))    # the same: call(x; ...) is call((x; ...))
```

### Named arguments

Pass by name, in any order.

```code
sub ( a, b; a - b )

sub(b := 2, a := 1)    # -1
sub(1, b := 2)         # positional first, then named
```

### Hoisting

Functions, types, and imports are hoisted, so recursion just works.

```code
main()                       # 55

main (; fib(10) )

fib ( n;
    if n <= 1
        n
    else
        fib(n - 1) + fib(n - 2)
    end
)

@load 'lang/html.code'       # imports can live at the bottom,
                             # and load cycles work
```

### Signatures

Declare a return type with `->`, and name a function's shape to check it.

```code
Formatter :: (Number -> String;)

usd ( cents: Number -> String;
    "$`cents / 100.0`"
)

format: Formatter = usd      # shape matches
format = ( a, b; a )         # Type_Contract_Violation

log ( x -> Nil; x )          # always returns nil
```

### Several values

Return a struct and unpack it by position.

```code
split (-> <Bool, Any>; <false, 'reason'> )

(ok, why) := split()         # false, 'reason'
```

### Types

### Classes

`Self` initializes, and `Self.` declares statics.

```code
Counter {
    Self.count := 0           # shared by every instance
    label,

    Self ( label;
        self.label = label    # self is the instance
        Self.count += 1       # Self is the type
    )

    pi (; Global.PI )         # Global skips local shadows
}

Counter('a')
Counter('b')
Counter.count                 # 2
```

### Composition

Combine types like sets, with no inheritance trees.

```code
Flying   { can_fly := true }
Swimming { can_swim := true }

Duck | Flying | Swimming {}      # | union
Ostrich | Duck ~ Flying {}       # ~ difference
                                 # & both, ^ exactly one

Ostrich().can_swim               # true
Ostrich().can_fly                # Undeclared_Identifier

Array | Array {                  # extend built-ins, too
    second (; self.values.1 )
}
```

### Comparing types

Operators that ask what a type is made of.

```code
Duck === Duck          # same composition
Duck =>= Swimming      # true: Duck is a Swimming, a superset of it
Swimming =<= Duck      # true: the same, read as a subset
Swimming =>= Duck      # false: Swimming has no Flying
Flying =/= Swimming    # true: nothing shared
4 == Any               # true: anything but nil
```

### Aliases and subtypes

`::` names a type, and `| {}` makes a new one.

```code
Int32 :: Integer              # the same type
Whole | Integer {}            # a new type that composes Integer

Strumber :: String | Number   # a contract
x: Strumber = 5
x = 'five'                    # ok
x = :five                     # Type_Contract_Violation
```

### Literal types

A value can be a type.

```code
mode: "fill" | "line" = "fill"
mode = "dash"                  # Type_Contract_Violation

Sign :: -1 | 0 | 1
s: Sign = 0
s = 2                          # Type_Contract_Violation
```

### Dynamic or typed

Start with open values and add types one value at a time, since nothing makes you type a whole file.

```
 open                   locked by inference       locked by declaration
 ───────────────────────────────────────────────────────────────────────
 x := nil               x := 4        → Number    x: Int = 4
 pending,               T { n := 0 }  → Number    x: Int | Nil
 x: Any = 4             <a := 1>      → Number    f ( a: Number; … )
 f ( a; … )                                       f (-> String; … )
 T { n, }                                         mode: "fill" | "line"
```

```code
# Open: takes any value, at any time, and never locks
x := nil
x = 5
x = 'five'                 # still fine

# Locked by inference: the first value sets the type
y := 5                     # Number
y = 4.5                    # ok: every number is a Number
y = 'five'                 # Type_Contract_Violation
y := 'five'                # declare again to change the type

# Locked by declaration: : Type on a variable, param, return, or member
z: Int | Nil               # starts as nil

# Params lock too: a typed param, or one with a default
f ( n: Number; n )         # n stays a Number inside the body
g ( n := 0; n )            # n locks to the type of the value it gets
g('x')                     # coming soon: an error, as with n: Number = 0

P <n: Int>
P(4.5)                     # coming soon: an error, since 4.5 is no Int
```

```code
add ( a: Number, b: Number; a + b )

# Before the program runs: a wrong literal for a declared type, anywhere
x: String = 123            # Type_Mismatch

never_called (;
    add(1, 'oops')         # Type_Mismatch, even here
)

# While the program runs: everything else, at the line that breaks it
s := 'oops'
add(1, s)                  # Type_Contract_Violation

# coming soon: a call above its function is checked before the run too
```

### Structs

Lightweight data in angle brackets, matched by shape.

```code
Ok      <status: 200, body: String>
Missing <status: 404>
Reply   :: Ok | Missing

Missing().status       # 404

f ( m: <name: String, value: Any>;
    m.name
)
f(<name := 'x', value := 4>)       # 'x': any matching shape works

User_Logic {
    greet (; "Hi `name`" )
}

User | User_Logic <name: String>   # data plus methods
User(name := 'Ada').greet()        # 'Hi Ada'
```

### Tagged types

Attach metadata to a type with `\`, and each tag is its own type.

```code
String\<num: Number> {
    to_s (; "number: `@tag.num`" )
}
String\<5>().to_s()            # 'number: 5'

tasks: Array\Task              # a label only: elements are not type-checked
```

### Control Flow

### Conditionals

Only `nil` and `false` are falsy.

```code
if x > 10
    'big'
elif x > 5
    'medium'
else
    'small'
end

redirect('/login') unless logged_in
```

### When

Match inside any branch or loop, and the first match wins.

```code
for [1, 'two', 3]
    when String
        'a string'
    when it > 2
        'a big number'
    else
        'something else'
end
```

### Tagged nil

Tag a nil with a reason, and it stays falsy while `when` tells them apart.

```code
load_user (; nil\Error('not found') )

if user := load_user()
    user.name
else                           # the branch for a falsy value
    when nil\Error
        "error: `it.@tag.message`"
    when nil
        'a plain nil'
    else                       # no case matched
        'false'
end
```

### For loops

`it` is the element, and `at` is the index.

```code
for ['a', 'b']
    @puts "`at`: `it`"          # 0: a, 1: b
end

for [1, 2, 3, 4] by 2           # [1, 2], [3, 4]
    @puts it
end

for i := 0, i < 10, i += 2      # C-style, too
    @puts i
end
```

### Loop verbs

Name the result you want.

```code
for [1, 2, 3] map             # [2, 4, 6]
    it * 2
end

for [1, 2, 3] select          # [1, 3]
    it.odd?()
end

for [1, 2, 3] count           # 2
    it > 1
end

for [1, 2, 3] map by 2,1      # sliding windows of 2, step 1
    <it.0, it.?1>
end                           # [<1, 2>, <2, 3>, <3, nil>]
```

### While and until

Chain branches into one loop, and steer it with `skip` and `stop`.

```code
while x < 4
    x += 1
elwhile y > -8
    y -= 1
else
    @puts 'done'        # neither branch holds
end

for items
    skip if it.hidden
    stop if it.last
end
```

### Collections

### Arrays

Indexed with dots.

```code
arr := [1, 2, 3, 4, 5]
arr.0                  # 1
arr.first(2)           # [1, 2]
arr.include?(3)        # true
arr.filter(x; x > 2)   # [3, 4, 5]
```

### Dictionaries

Any value can be a key.

```code
d := {name = 'Jack', :x = 10, Vec2(0, 0) = player}

d['name']              # 'Jack': a bare name is a String key
d.x                    # 10: dots read Symbol keys
d[:y] = 20             # write with a subscript
d.fetch(:z, 'default') # 'default'

name := 'id'
{name = 'Jack'}        # key is 'name'
{(name) = 'Jack'}      # key is 'id': parentheses use the value
```

### Sets

Unique values, with set operators.

```code
Set([1, 2, 2, 3])                # Set{1, 2, 3}
Set([1, 2, 3]) & Set([2, 3, 4])  # Set{2, 3}
Set([1, 2, 3]) ^ Set([2, 3, 4])  # Set{4, 1}
```

### Ranges

Trim either end, and slice with them.

```code
(1..5).to_a()          # [1, 2, 3, 4, 5]
(1..<5).to_a()         # [1, 2, 3, 4]
(1>..5).to_a()         # [2, 3, 4, 5]
(1>..<5).to_a()        # [2, 3, 4]

(1..5).sum()           # 15
[10, 20, 30, 40][2..]  # [30, 40]
```

### Percent literals

Lists of words, without the quotes.

```code
%string(boo Hoo COOL)    # ['boo', 'Hoo', 'COOL']: casing kept
%str(Boo hOO COOL)       # ['boo', 'hoo', 'cool']
%Str(boo HOO cOOl)       # ['Boo', 'Hoo', 'Cool']
%STR(boo Hoo cool)       # ['BOO', 'HOO', 'COOL']

%symbol(BOO hoo Cool)    # [:BOO, :hoo, :Cool]: casing kept
%sym(Boo HOO cOOl)       # [:boo, :hoo, :cool]
%Sym(boo HOO cOOl)       # [:Boo, :Hoo, :Cool]
%SYM(boo Hoo cool)       # [:BOO, :HOO, :COOL]

%string(1px file.ext + -)  # ['1px', 'file.ext', '+', '-']

cool := 2342
%string(481516 `cool`)     # ['481516', '2342']: interpolated
```

### Power Tools

### Custom operators

Infix, prefix, or postfix, with custom precedence.

```code
double ( n; n * 2 )
add_fifteen ( n; n + 15 )

@operator -> @infix 300 ( left, right; right(left) )
4 -> double -> add_fifteen     # 23

@operator $ @prefix 900 ( amount; Currency(amount, 'USD') )
$42                            # Currency

11:22pm                        # a Time, with : and pm defined
```

### Operators on a type

An operator declared in a type is used only when the left side is that type, and there it wins over a global one with the same symbol.

```code
Vec2 {
    x, y,

    Self ( x, y;
        self.x = x
        self.y = y
    )

    @operator + @infix 700 ( left, right;
        Vec2(left.x + right.x, left.y + right.y)   # numbers: plain +
    )

    to_s (; "Vec2(`x`, `y`)" )
}

Vec2(1, 2) + Vec2(3, 4)        # Vec2(4, 6)
1 + 2                          # 3: + is unchanged everywhere else
```

### Splat

Reach an instance's members without the prefix.

```code
magnitude ( @splatr vec;      # read-only
    (x ** 2 + y ** 2).sqrt()
)

double ( @splat vec;          # writable
    x *= 2                    # writes vec.x
)
```

### Reopen any scope

Add to a type or a single instance, after the fact.

```code
@push_scope Button
    css_filter := 'invert()'  # every Button
@pop_scope Button

@push_scope b
    clicked := true           # just this one
@pop_scope b
```

### Statements

Wrap an expression in backticks to run it later.

```code
counter := 0
tick := `counter += 1`
tick()
tick()                        # counter is 2

tick.memoize = true           # run once, then cache
tick.use_caller_scope = true  # resolve names where tick() is called,
                              # not where it was written
```

### The context

Every scope knows about itself through `@`.

```code
Duck.@name              # 'Duck'
Duck.@composed_types    # Set{'Duck', 'Flying', 'Swimming'}
[1, 2].@type            # 'Array'

Widget { @version := 2 }      # custom metadata

double(@puts 5)         # prints 5, returns 10
add(@puts 1, 2)         # coming soon: prints 1, returns 3
@declare 'count', 3     # a local here, a member in a type body
@todo                   # stops with [TODO]
@todo 'add auth'        # stops with "[TODO] add auth"
```

### The Web

### Servers and routes

Routes are methods, and parameters are arguments.

```code
@load 'lang/server.code'

App | Server {
    Self (; self.port = 3000 )

    get:// (; 'Hello, World!' )

    get://users/:id ( id; "User `id`" )

    get://search (; "Searching `request.query[:q]`" )

    post://login (;
        response.status = 401 unless authorized?(request.body)
        'Done'
    )
}

@start_server App()     # coming soon: a server written in .code itself
```

### Clicks run on the server

Set `onclick` to a closure, and only the component with that `html_id` re-renders.

```code
Counter | Div {
    html_id := 'counter'
    count := 0                # coming soon: one count per visitor
    button := Button('+1')

    Self (;
        # gets the click and every input's value
        # coming soon: a checkbox sends whether it is checked
        button.onclick = (;
            count += 1
        )
    )

    render (;                 # sent back, swapped with a view transition
        [P("Clicked `count` times"), button]
    )
}
```

### Database

A struct is the schema, and the table follows.

```code
@load 'lang/database.code'

db := @connect Sqlite.memory()

User <id: Primary_Key, name: String, joined_at: Date_Time>

users := db.find_or_create_table(User)   # table "users"
ada := users.create(<name := 'Ada'>)
users.find(ada.id)
users.where(<name := 'Ada'>)
users.delete(ada.id)
```

### Records

Data, logic, and table under one name.

```code
User_Logic { greet (; "Hi `name`" ) }
Account | User | User_Logic | users <>

Account.find(1).name              # 'Ada'
Account(name := 'Bob').greet()    # 'Hi Bob'
```

### HTML

Elements are types, and styles and attributes are members.

```code
@load 'lang/html.code'

Card | Div {
    css_padding := '1rem'     # style="padding: 1rem"
    html_class := 'card'      # class="card"
}

Card([H1('Welcome'), P('Hello!')]).to_s()
# <div><h1>Welcome</h1><p>Hello!</p></div>
```

The `class` and `style` attributes, and the escaping, come when a server renders the element.

### CSS

Stylesheets as plain data that you can format and lint.

```code
@load 'lang/css.code'

rule := Style_Rule(['.card'], [Property('color', 'red')])

Css_Formatter_Visitor(minify := true).format(rule)
# '.card{color:red;}'

Css_Lint_Visitor().lint(rule)   # duplicates, prefixes, 0px
```

### Tools

### Hot reload

A program that starts a server is watched, and the browser refreshes on save.

```sh
bin/program app.code
bin/program run app.code         # the same
```

### Every stage, inspectable

See the output of each step with `-p`.

```sh
bin/program lex "4 + 8" -p
bin/program parse "4 + 8" -p
bin/program declare "4 + 8" -p
bin/program interp "4 + 8" -p

bin/program parsef app.code -p   # lexf, parsef, declaref, interpf for files
```

### Everything Else

### Numbers

Integers, floats, and exact decimals.

```code
4                      # Int
4.5                    # Flo
Decimal('1.50')        # Dec

42.clamp(0, 10)        # 10
12 | 4                 # bitwise on numbers
```

### Dates and files

Built in, with no imports.

```code
Date.parse('2020-03-15').weekday     # 0: Sunday
Time.now().epoch()

File.read('./file.txt')
Dir('./src').files()
```

### Modules

Load a file once, and scope it to a name if you like.

```code
@load 'lang/html.code'               # standard library, from anywhere
@load ./tools/my\ module.code        # bare paths work too

Mod := @load './my_module.code'
Mod.Some_Type()
```

### A standard library you can read

The standard library is written in .code, and `@ruby` runs the built-in Ruby method right where it is written, so you can wrap or replace any built-in.

```code
String | String {
    upcase (;
        @puts "upcasing `self`"
        @ruby                   # the built-in upcase runs here
    )
}
'hi'.upcase()                 # prints upcasing hi, gives 'HI'

String | String {
    upcase (; "`@ruby`!" )
}
'hi'.upcase()                 # 'HI!'
```

### Coming soon

### One state per visitor

Today one component serves every visitor, so they all share its values.

```code
App | Server {
    counter := Counter()
    get:// (; Html(Body(counter)) )
}

# Today: two browsers click once each, and both see "Clicked 2 times".
# Coming soon: each browser gets its own Counter, and each sees
# "Clicked 1 times".
```

### Checkboxes in click handlers

Today a click sends each input's `value`, which for a checkbox never changes.

```code
done := Input(html_type := 'checkbox')
save := Button('Save')

save.onclick = (;
    done.value      # today: the same value, checked or not
                    # coming soon: whether the box is checked
)
```

### A server written in .code

The code you write stays the same, and the server under it moves from Ruby into the language.

```code
App | Server {
    get:// (; 'Hello, World!' )
}

@start_server App()

# Today: Ruby's WEBrick reads each request.
# Coming soon: .code reads it from a plain socket, parses the HTTP,
# and finds the route, so you can read and change every step.
```

### Checks before the run, in any order

Today the check before the run sees only a function that is declared above the call.

```code
total := add(1, 'oops')    # today: an error only when this line runs
                           # coming soon: an error before the run

add ( a: Number, b: Number; a + b )
```

### Defaults that set the type

A `:=` default will set the param's type, the same as `:=` does for a variable.

```code
g ( n := 0; n )

g(5)                       # 5
g('x')                     # today: 'x'
                           # coming soon: Type_Contract_Violation
```

### Int means Int

Today a struct member typed `Int` takes any number.

```code
P <n: Int>

P(4)                       # ok
P(4.5)                     # today: ok
                           # coming soon: Type_Contract_Violation
```

### @puts in any argument

Today `@puts` takes every argument after it, so it works only as the last one.

```code
add ( a, b; a + b )

add(2, @puts 1)            # prints 1, returns 3
add(@puts 1, 2)            # today: Missing_Argument
                           # coming soon: prints 1, returns 3
```

### Next steps

[Get started](ruby/readme.md) · [Learn by example](examples/readme.md) · [Read the reference](reference.md)
