# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About Ore

Ore is an educational programming language for web development, implemented in Ruby. It features:

- Naming conventions that replace keywords (Capitalized classes, lowercase functions/variables, UPPERCASE constants)
- Class composition operators instead of inheritance (|, &, ~, ^)
- Dot notation for accessing nested structures and scopes (./, ../, .../)
- First-class functions and classes
- Built-in web server support with routing

## Common Commands

### Testing

```bash
# Run all tests (default task also runs cloc)
bundle exec rake test

# Run specific test file
ruby test/lexer_test.rb

# Run all tests and cloc
bundle exec rake
```

### Running Ore Programs

```bash
# Execute Ore code directly
bundle exec rake interp["4 + 8"]

# Execute Ore file
bundle exec rake interp_file["path/to/file.ore"]
```

### Setup

```bash
# Install dependencies (requires Ruby 3.4.1 and Bundler)
bundle install
```

## Architecture

The codebase follows a three-phase pipeline: **Lexer → Parser → Interpreter**

### Compile-time (lib/compiler/)

Source code is tokenized and parsed into an Abstract Syntax Tree (AST):

- `lexer.rb` - Tokenizes source code into lexemes (tokens)
- `parser.rb` - Parses lexemes into an AST of expression objects
- `lexeme.rb` - Token representation
- `expressions.rb` - AST node definitions

### Runtime (lib/runtime/)

The AST is executed to produce output:

- `interpreter.rb` - Traverses and executes the AST
- `scope.rb` - Manages variable scoping and declarations (Global, Type, Instance, Func, Route, Return scopes)
- `context.rb` - Tracks execution state (routes, servers, loaded files)
- `types.rb` - Runtime type definitions (includes Request, Response, Server classes)
- `errors.rb` - Runtime error definitions
- `server_runner.rb` - HTTP server implementation using WEBrick (handles routing, URL params, query strings)

### Shared (lib/shared/)

Used by both compiler and runtime:

- `constants.rb` - Language constants, operators, precedence table, reserved words
- `helpers.rb` - Utility functions for identifier classification (constant_identifier?, type_identifier?, member_identifier?)

### Entry Point

- `lib/ore.rb` - Main module that ties everything together and provides convenience methods:
	- `Ore.lex(source)` / `Ore.lex_file(filepath)` - Tokenize only
	- `Ore.parse(source)` / `Ore.parse_file(filepath)` - Parse to AST
	- `Ore.interp(source)` / `Ore.interp_file(filepath)` - Full execution

### Standard Library

- `ore/preload.ore` - Auto-loaded into global scope when `with_std: true` (default)
- Standard library path defined in `Ore::STANDARD_LIBRARY_PATH`

## Scope System

Ore uses a sophisticated scope hierarchy:

- **Global** - Top-level scope, can load standard library via `Global.with_standard_library`
- **Type** - Class definitions (tracks `@types`, `@expressions`)
- **Instance** - Class instances
- **Func** - Function scopes (tracks `@expressions`)
- **Route** - HTTP route handlers (extends Func, adds `@http_method`, `@path`, `@handler`, `@parts`, `@param_names`)
- **Html_Element** - HTML element scopes (tracks `@expressions`, `@attributes`, `@types`)
- **Return** - Return value wrapper (tracks `@value`)

Scope operators in the language:

- `./identifier` - Instance scope
- `../identifier` - Parent scope (TBD)
- `.../identifier` - Global scope

## Identifier Naming Conventions

The language enforces naming conventions through the helper functions:

- **UPPERCASE** (constant_identifier?) - Constants
- **Capitalized** (type_identifier?) - Classes/types
- **lowercase** (member_identifier?) - Variables and functions

## Code Style Preferences

### Ruby Code Style

- **Indentation**: Use tabs (equivalent to 4 spaces)
- **Class names**: Use `This_Case` (capitalized with underscores), not `ThisCase`
- **Method definitions**: Omit parentheses - `def something arg` not `def something(arg)`
- **Method calls**: Omit parentheses where possible - `foo.bar arg` not `foo.bar(arg)`
- **Comments**: Only add comments for non-obvious code. Don't comment obvious operations

## Testing

Tests use Minitest and inherit from `Base_Test` (in test/base_test.rb):

- `test/lexer_test.rb` - Lexer tests
- `test/parser_test.rb` - Parser tests
- `test/interpreter_test.rb` - Interpreter tests
- `test/regression_test.rb` - Regression tests
- `test/server_test.rb` - Server and routing tests
- `test/e2e_server_test.rb` - End-to-end server tests

The base test class provides `refute_raises` helper for asserting no exceptions.

## Web Server Features

Ore has built-in web server support:

- **Server class composition** - Create servers by composing with the built-in `Server` class using `|` operator
- **Route syntax** - Routes defined as `method://path` (e.g., `get://`, `post://users/:id`)
- **URL parameters** - Use `:param` syntax in routes, accessed via route function parameters
- **Query strings** - Available via `request.query` dictionary
- **Request/Response objects** - Automatically available in route handlers (from `types.rb`)
- **`#serve_http` directive** - Non-blocking server startup, allows multiple concurrent servers
- **Graceful shutdown** - Servers stop when program exits (handled in Rakefile's `_interp_file`)
- **WEBrick backend** - HTTP server implementation in `server_runner.rb`

## File Loading

The `#load` directive allows importing Ore files:

- Context tracks loaded files to prevent duplicate parsing
- Files are loaded into specified scope via `Context#load_file`
- Expressions are cached in `@loaded_files` hash keyed by resolved filepath
