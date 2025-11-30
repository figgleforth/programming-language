![Status of project Ruby tests](https://github.com/figgleforth/ore-lang/actions/workflows/tests.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)]()

### ![](ore.svg)

### Programming Language For Web Development

```ore
Hello {
	subject;
	
	new { subject;
		./subject = subject
	}
	
	output {;
		"Hi, |subject|!"
	}
}

Hello().output()         `"Hi, !"
Hello('World').output()  `"Hi, World!"
```

- Naming conventions replace keywords
	- `Capitalize` classes
	- `lowercase` variables and functions
	- `UPPERCASE` constants
- Class composition replaces inheritance
	- `|` Union - merge classes (left side wins conflicts)
	- `&` Intersection - keep only shared declarations
	- `~` Difference - discard right side declarations
	- `^` Symmetric Difference - discard shared declarations
- Dot notation for convenience
	- `array.1.0.8` accesses nested structures
	- `./identifier` accesses instance scope
	- `../identifier` to be determined
	- `.../identifier` accesses global scope
- First-class functions and classes
- Built-in data types - `Array`, `Tuple`, `Dictionary`, `Range`, `Server`
- Web server support with routing
	- Route definitions use `method://path` syntax (e.g., `get://`, `post://users/:id`)
	- URL parameters via `:param` syntax
	- Query string access via `request.query`
	- Request/response objects automatically available
	- Non-blocking `#serve_http` directive allows multiple servers
	- Graceful shutdown handling when program exits

---

- [Code Examples](#code-examples)
	- [Variables](#variables)
	- [Functions](#functions)
	- [Classes](#classes)
	- [Web Servers](#web-servers)
	- [Class Composition](#class-composition)
- [Getting Started](#getting-started)

---

### Code Examples

#### Variables

```
`Comments start with a backtick

nothing;            `Syntactic sugar for "nothing = nil"
something = true

`Strings can be single or double quoted, and interpolated with "|"
LANG_NAME = "ore-lang"
version   = '0.0.0'
lines     = 4_815
header    = "|LANG_NAME| v|version|"   `"ore-lang v0.0.0"
footer    = 'Lines of code: |lines|'   `"Lines of code: 4815"

`Ranges
inclusive_range   = 0..2
exclusive_range   = 2><5
l_exclusive_range = 5>.7
r_exclusive_range = 7.<9

`Data containers
tuples = (header, footer)
arrays = [inclusive_range, exclusive_range]

`Dictionaries can be initialized in multiple ways, commas and values are optional
dict = {}                       `{}
dict = {x y}                    `{x: nil, y: nil}
dict = {u, v}                   `{u: nil, v: nil}
dict = { a:0 b=1 c}             `{a: 0, b: 1, c: nil}
dict = { x:4, y=8, z}           `{x: 4, y: 8, z: nil}
dict = { v=version, l=lines }   `{v: "0.0.0", l: 4815}
```

#### Functions

```
`Syntax: <function_name> { <params, ...> ; <body> }, where ";" is the delimiter between params and body.

noop_function {;}

best_show {;
	"Lost"  `Last expression is return value
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
	end             `Control flows close with `end`
}                       `Code blocks close with `}`
```

#### Classes

```
`Syntax: <class_name> { <body> }

Repo {
	user;
	name;

	`"new" is reserved for constructors
	new { user, name;
		./user = user
		./name = name
	}

	to_s {;
		"|user|/|name|"
	}
}

Repo('figgleforth', 'ore-lang').to_s() `"figgleforth/ore-lang"
```

#### Web Servers

```ore
`Builtin Server class
Server {
	port;
	new { port;
		./port = port
	}
}

`Create servers by composing with Server
Web_App | Server {
	`Define routes using HTTP method and path
	get:// {;
		"<h1>Welcome to Ore!</h1>"
	}

	get://hello/:name { name;
		"<h1>Hello, |name|!</h1>"
	}

	post://submit {;
		"Form submitted"
	}
}

API_Server | Server {
	get://api/users {;
		"[{\"id\": 1, \"name\": \"Alice\"}]"
	}
}

`Both servers run concurrently in background threads
app = Web_App(8080)
api = API_Server(3000)
#serve_http app
#serve_http api
```

### Getting Started

> Requires Ruby 3.4.1 or higher, and Bundler

```shell script
git clone https://github.com/figgleforth/ore-lang.git
cd ore-lang
bundle install
bundle exec rake test
```

- [`lib/readme`](lib/readme.md) details the architecture and contains instructions for running your own programs
- [`ore`](ore) contains code written in Ore
- [`lib`](lib) contains code implementing Ore
	- [Lexer#output](lib/compiler/lexer.rb) – Source code to Lexemes
	- [Parser#output](lib/compiler/parser.rb) – Lexemes to Expressions
	- [Interpreter#output](lib/runtime/interpreter.rb) – Expressions to values
