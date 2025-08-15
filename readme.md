![Status of project Ruby tests](https://github.com/figgleforth/programming-language/actions/workflows/ruby.yml/badge.svg)

### ![](air.svg)

### Air Programming Language

This is a for-fun programming language with mechanics I like. Some could be silly and some could be serious, for example:

- While loops with elwhile clauses
- Access nested arrays with dot-syntax `array.1.0.8`
- Use `./` to access the current instance
- Classes are called Types and are composable
- Functions and Types are first-class
- Built-in arrays, tuples, dictionaries, and ranges
- Eliminate repetitive keywords like `class`/`def` by enforcing naming conventions at the language level:
	- `UPPERCASE` identifiers are constant
	- `Capitalized` identifiers are Types
	- `lowercase` identifiers are variables and functions

---

- [Code Examples](#code-examples)
	- [Variables](#variables)
	- [Functions](#functions)
	- [Types](#types)
- [Getting Started](#getting-started)
	- [Prerequisites](#prerequisites)
	- [Running Tests](#running-tests)
	- [Explore The Code](#explore-the-code)
- [License](#license)

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
`The syntax for functions is always "<lowercase_ident> { <params> ; <body> }"
`The colon separator between params and body is required, even without params
`The last expression in the body is also the return value but you can be explicit

noop_function {;}

current_year {;
	return 2025
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

#### Types

```
`The syntax for types is always "<capitalized_ident> { <body> }"

Repo {
	user;
	name;
	
	`This is the constructor/initializer called during instantiation
	new { user, name;
		./name = name   `Equivalent to "this.name" or "self.name"
	}
	
	to_s {;
		"|user|/|name|"
	}
}

repo = Repo('figgleforth', 'programming-language')
NAME = repo.to_s()
```

#### Type Composition

- `|` Union
- `~` Difference
- `&` Intersection
- `^` Symmetric Difference

Composition applies operators sequentially, left to right. There is no implicit precedence, so
compositions, regardless of inline or inbody, are evaluated exactly as written. Note that union (
`|`) is left-biased when the same declarations exist on both sides, meaning the left-hand declaration is the one that takes precedence whose value will be for the assignment.

---

Union, where left-hand and right-hand declarations are merged into the left-hand Type. Conflicts are resolved by keeping the left-hand declaration.

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

Difference, where declarations of the right-hand Type are removed from the left-hand Type.

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

Intersection, where only mutual left-hand and right-hand declarations are declared on the left-hand Type.

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

Symmetric difference, where unique declarations from both left-hand and right-hand side are declared, while the intersection is discarded.

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

#### Prerequisites

- Ruby 3.4.1 or higher
- Bundler

```shell script
git clone https://github.com/figgleforth/programming-language.git
cd programming-language
bundle install
```

#### Running Tests

```shell script
bundle exec rake test
```

#### Explore The Code

- [`code/readme`](./code/readme.md) contains detailed information on running your own programs
- [`code/air`](./code/air) contains code written in the toy language
- [`code/ruby`](./code/ruby) contains code implementing the toy language
	- [Lexer#output](./code/ruby/lexer.rb) - Source code to Lexemes
	- [Parser#output](./code/ruby/parser.rb) - Lexemes to Expressions
	- [Interpreter#output](./code/ruby/interpreter.rb) - Expressions to values

### License

This project is licensed under the MIT License, see the [license](./license.md) file for details.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)]()
