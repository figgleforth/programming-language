### What is in this folder?

This folder holds the Ruby code for the language. All of it sits in one Ruby module: `Code`. A file in this folder can use a class or a constant from any other file in this folder. It does not need a prefix.

Source code moves through five steps, in this order:

1. Lexer
2. Parser
3. Type Checker
4. Declarator
5. Interpreter

### The main files

- **`main.rb`** — the entry point. It loads every other file, in the correct order. It also adds the module-level helper methods: `Code.lex`, `Code.parse`, `Code.interp`, and their `_file` versions (they read a file first).
- **`cli.rb`** — the `Code::CLI` class. This runs the `bin/program` commands.
- **`repl.rb`** — the `Code::REPL` class. This runs the interactive REPL.
- **`lexer.rb`**, **`parser.rb`**, **`type_checker.rb`**, **`declarator.rb`**, **`interpreter.rb`** — one file per pipeline step above.

### The subfolders

- **`programs/`** — the `.code` files that ship with the language. This is the standard library. See the readme file in that folder.
- **`proxies/`** — the Ruby class behind each built-in `.code` type. `proxies/array.rb` is the Ruby half of `programs/array.code`. An `@ruby` proxy method in a `.code` file calls into this class.
- **`shared/`** — small pieces that many files need: constants, naming-convention helpers, ASCII art, the `@ruby` proxy helper, the error formatter, the DOM renderer, the hot reloader, and the browser assets (`dom.js`, `live_reload.js`, `view_transition.css`).

### How to run a program from Ruby

Call `run` with source code. It lexes, parses, and runs the code in one step.

```ruby
require './source/main'

interpreter = Code::Interpreter.new
result      = interpreter.run "'Hello, World!'" # => Hello, World!
```

You can also run each step by hand:

```ruby
require './source/main'

lexer       = Code::Lexer.new "'Hello, World!'"
lexemes     = lexer.output       # => array of Lexemes

parser      = Code::Parser.new lexemes
expressions = parser.output      # => array of Expressions

interpreter       = Code::Interpreter.new
interpreter.input = expressions
result            = interpreter.output # => Hello, World!
```

Or use the short `Code` module methods:

```ruby
require './source/main'

source      = '"Hello, Again!"'
lexemes     = Code.lex source        # => array of Lexemes
expressions = Code.parse source      # => array of Expressions
result      = Code.interp source     # => Hello, Again!

source_file = './my_program.code'
lexemes     = Code.lex_file source_file
expressions = Code.parse_file source_file
result      = Code.interp_file source_file
```

### How to run a program from the command line

This is the fastest way to run a `.code` file:

```bash
bundle exec bin/program file.code
```

You can also give it source code directly:

```bash
bundle exec bin/program interp "4 + 8" -p
```

For the full list of commands (lexing, parsing, declaration inspection, the REPL, and more), run:

```bash
bundle exec bin/program --help
```
