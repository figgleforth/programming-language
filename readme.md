![Status of project Ruby tests](https://github.com/figgleforth/programming-language/actions/workflows/tests.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)]()

### ![](air.svg)

### Air Programming Language

A clean, expressive language that replaces inheritance with class composition and eliminates boilerplate through naming conventions.

```air
`Define a function - no "def" needed
greet { name;
	"Hello, |name|!"
}

`Define a class - no "class" needed
Person {
	name;

	new { name;
		./name = name
	}

	greet {;
		"Hello, |./name|!"
	}
}

Person('World').greet() `=> "Hello, World!"
```

**Key Features:**

- **Naming conventions replace keywords** - `Capitalized` = classes, `lowercase` = functions/vars,
  `UPPERCASE` = constants
- **Class composition over inheritance** - Use `|` `&` `~` `^` operators to compose classes
- **Clean syntax** - No `class`, `def`, `self`, or `::` keywords
- **Dot notation for everything** - `array.1.0.8` accesses nested structures, `./name` accesses instance vars
- **First-class functions and classes** - Pass them around like any other value
- **Built-in data types** - `Array`, `Tuple`, `Dictionary`, `Range`

---

- [Code Examples](#code-examples)
	- [Variables](#variables)
	- [Functions](#functions)
	- [Classes](#classes)
	- [Class Composition](#class-composition)
- [Getting Started](#getting-started)

---

### Code Examples

#### Variables

```
`Comments start with a backtick

nothing;   `Equivalent to "nothing = nil"
something = true

`Strings can be single or double quoted, and interpolated with "|"
LANG_NAME = "programming-language"
version   = '0.0.0'
lines     = 3_000
header    = "|LANG_NAME| v|version|"   `"programming-language v0.0.0"
footer    = 'Lines of code: |lines|'   `"Lines of code: 3000"

`Ranges
inclusive_range   = 0..2
exclusive_range   = 2><5
l_exclusive_range = 5>.7
r_exclusive_range = 7.<9

`Data containers
tuples = (header, footer)
arrays = [inclusive_range, exclusive_range]

`Dictionaries can be initialized in multiple ways
`Commas and values are optional
dict = {}                       `Empty
dict = {x y}                    `{x: nil, y: nil}
dict = {u, v}                   `{u: nil, v: nil}
dict = { a:0 b=1 c}             `{a: 0, b: 1, c: nil}
dict = { x:4, y=8, z}           `{x: 4, y: 8, z: nil}
dict = { v=version, l=lines }   `{v: "0.0.0", l: 3000}
```

#### Functions

```
`Functions use lowercase names - no "def" keyword needed
`Format: "name { params ; body }"

noop_function {;}

current_year {;
	2025  `Last expression is returned
}

fizz_buzz { n;
	if n % 3 == 0 and n % 5 == 0
		'FizzBuzz'
	elif n % 3 == 0
		'Fizz'
	elif n % 5 == 0
		'Buzz'
	else
		'|n|'
	end
}
```

#### Classes

```
`Classes are defined with capitalized names - no "class" keyword needed

Repo {
	user;
	name;

	`"new" is the constructor
	new { user, name;
		./name = name   `./ is like "this" or "self"
	}

	to_s {;
		"|user|/|name|"
	}
}

repo = Repo('figgleforth', 'programming-language')
NAME = repo.to_s()  `=> "figgleforth/programming-language"
```

#### Class Composition

Air uses operators to combine classes instead of inheritance:

- `|` Union - merge classes (left side wins conflicts)
- `~` Difference - remove declarations
- `&` Intersection - keep only shared declarations
- `^` Symmetric Difference - keep unique declarations from both sides

**Union** - Merge two classes together:

```
Aa {
	a = 1
}

Bb {
	a = 4; b = 2; unique = 10
}

Aa | Bb {}
a = Aa()
a.a `=> 1 due to the left-bias retaining Aa's declaration of "a"

Cc | Bb {
	c = 42
}

c = Cc()
c.a `=> 4
c.b `=> 2
c.unique `=> 10

Union | Cc {
	a = 100
}

u = Union()
u.a `=> 100
u.b `=> 2
u.unique `=> 10
```

**Difference** - Remove declarations from a class:

```
Aa {
	a = 4
	common = 15
}

Bb {
	b = 42
	common = 16
}

AaBb | Aa | Bb {}

Difference | AaBb ~ Bb {
	common = 23
}

d = Difference()
d.a `=> 4
d.b `=> Undeclared_Identifier
d.common `=> 23
```

**Intersection** - Keep only shared declarations:

```
Aa {
	a = 4
	common = 8
}

Bb {
	b = 15
	common = 16
}

Intersected | Aa & Bb {}

i = Intersected()
i.common `=> 8
i.a `=> Undeclared_Identifier
i.b `=> Undeclared_Identifier
```

**Symmetric Difference** - Keep only unique declarations from each side:

```
Aa {
	a = 4
	common = 10
}

Bb {
	b = 8
	common = 10
}

Symmetric_Difference | Aa ^ Bb {}

s = Symmetric_Difference()
s.a `=> 4
s.b `=> 8
s.common `=> Undeclared_Identifier
```

---

### Getting Started

> Requires Ruby 3.4.1 or higher, and Bundler

```shell script
git clone https://github.com/figgleforth/programming-language.git
cd programming-language
bundle install
bundle exec rake test
```

- [`lib/readme`](lib/readme.md) contains detailed information on running your own programs
- [`air`](air) contains code written in Air
- [`lib`](lib) contains code implementing Air
	- [Lexer#output](lib/lexer.rb) – Source code to Lexemes
	- [Parser#output](lib/parser.rb) – Lexemes to Expressions
	- [Interpreter#output](lib/interpreter.rb) – Expressions to values
