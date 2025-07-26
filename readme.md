### Emerald

A for-fun programming language with mechanics I like. For example:

- While loops with else-while clauses
- Access nested arrays with dot-syntax `array.1.0.8`
- Use `./` to access self
- Composition over inheritance
- Functions and types are first-class
- Built-in arrays, tuples, dictionaries, and ranges
- Eliminate repetitive keywords like `class`/`def` by enforcing naming conventions at the language level:
	- `UPPERCASE` identifiers are constants
	- `Capitalized` identifiers are types
	- `lowercase` identifiers are variables and functions

---

- [Code Examples](#code-examples)
	- [Variables](#variables)
	- [Functions](#functions)
	- [Types](#types)
- [Getting Started](#getting-started)
	- [Prerequisites](#prerequisites)
	- [Running Tests](#running-tests)
	- [Running Your Own Programs](#running-your-own-programs)
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

#### Running Your Own Programs

```shell script
bundle exec rake interp[./your_program.e]
```

#### Explore The Code

- [`code/emerald`](./code/emerald) contains code written in the toy language
- [`code/ruby`](./code/ruby) contains code implementing the toy language
	- [Lexer#output](./code/ruby/lexer.rb) - Source code to Lexemes
	- [Parser#output](./code/ruby/parser.rb) - Lexemes to Expressions
	- [Interpreter#output](./code/ruby/interpreter.rb) - Expressions to values

### License

This project is licensed under the MIT License, see the [license](./license.md) file for details.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)]()
