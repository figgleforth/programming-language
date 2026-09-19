### Quick Start

> Requires Ruby `3.4.1` or higher, and Bundler

```bash
git clone https://github.com/figgleforth/programming-language.git
cd programming-language
bundle install
bundle exec bin/program examples/hello_world.code -p # => Hello, Code!
```

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

- **`code/`** — the `.code` files that ship with the language. This is the standard library. See the readme file in that folder.
- **`proxies/`** — the Ruby class behind each built-in `.code` type. `proxies/array.rb` is the Ruby half of `code/array.code`. An `@ruby` proxy method in a `.code` file calls into this class.
- **`shared/`** — small pieces that many files need: constants, naming-convention helpers, ASCII art, the `@ruby` proxy helper, the error formatter, the DOM renderer, the hot reloader, and the browser assets (`dom.js`, `live_reload.js`, `view_transition.css`).

The sibling folder [`../examples`](../examples) holds runnable `.code` examples, one per language feature.

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

### Extending the Language

Pipeline: **Lexer → Parser → Type_Checker → Declarator → Interpreter**. Methods: `lex_*` / `parse_*` / `interp_*`. New phase? Same convention, wire into `Interpreter#run`.

#### Adding a new construct

1. **Lex it** — [`lexer.rb`](lexer.rb)`#output` is one big `if/elsif` dispatching on the current char(s). Add a branch (or a `lex_*` helper called from one) that sets `token.type`/`token.value`.
   1. `line_start`/`column_start`/`line_end`/`column_end`/`source_file` are set automatically around every branch — you don't touch them here.
   2. Add any new symbols/keywords to the relevant list in [`constants.rb`](shared/constants.rb) (`RESERVED`, `PERCENT_LITERALS`, an operator list, etc.) so they're recognized/reserved.
2. **Add an AST node** — a new `Code::Foo_Expr < Expression` in [`expressions.rb`](proxies/expressions.rb). Only add `attr_accessor`s for what's structurally new; `value`/`type`/`line..column_end`/`source_file` are inherited.
3. **Parse it** — add a branch to `Parser#begin_expression` (prefix position) or `#complete_expression` (infix/postfix position) in [`parser.rb`](parser.rb), dispatching on `curr?`/`peek`, calling a new `parse_foo_expr`. Build the `Foo_Expr`, set its location (see below), return it.
4. **Type-check it (optional)** — only if it introduces a new literal type or call shape worth statically checking. Extend `infer_type`/`check` in [`type_checker.rb`](type_checker.rb). Most constructs skip this — the static checker only handles literal type mismatches.
5. **Declare it (optional)** — only if the construct is declarative and order-independent (a type, a named function, a route, and so on), so it should work even referenced before its own line runs. Add a case to `Declarator#declare` in [`declarator.rb`](declarator.rb) — nest it under its own key (the way `Type_Expr`/`Func_Expr` do) or flatten it into the enclosing level (the way `Conditional_Expr`/`Circumfix_Expr` do), depending on whether it opens its own scope. Then add the new `*_Expr` to `HOISTABLE_EXPRESSIONS` in [`interpreter.rb`](interpreter.rb), so `#resolve_forward_declaration` actually runs it early when something references it before its own line. Most constructs skip this — a plain value-producing expression should not hoist.
6. **Interpret it** — add a case to `Interpreter#interpret`'s dispatch and a new `interp_foo` in [`interpreter.rb`](interpreter.rb) that walks the `Foo_Expr` and produces a runtime value (a `Code::*` instance, a Ruby primitive, `nil`, etc.).
7. **Test it** — `lexer_test.rb` → `parser_test.rb` → `interpreter_test.rb`/`pipeline_test.rb`, matching the phase you touched.

Worked examples: percent literals (`#parse_percent_literal_expr`/`#interp_percent_literal`), Statement (`#parse_statement_expr`/`#interp_statement`).

#### Lexeme/expression location (`line_start`, `column_start`, `line_end`, `column_end`)

1. Lexer sets these on every `Lexeme` for free — nothing to do there.
2. `Expression`s don't get location for free. `Foo_Expr.new(some_lexeme)` only copies `value`/`lexeme`.
3. Save `start = curr_lexeme` before consuming anything to get the construct's first lexeme's location
4. Build the expr, then `copy_location expr, start` before returning. Copies all four fields from one point — not a span.
   1. Or build the location yourself as a span between two lexemes.
5. Need a span (first lexeme → last)? Call `copy_location expr, start` first, then manually overwrite `line_end`/`column_end`/`source_file` from the closing lexeme. Pattern: `parse_struct` in `parser.rb` (search `Manually tracking location`).

#### Ruby-backed types (`Foo {}` + `Code::Foo`)

Two files, independently optional — pure-language types skip #2, rare Ruby-only types skip #1:

1. **`code/foo.code`** — the language-level declaration (`Foo { ... }`). A method that defers to Ruby is just `some_method (; @ruby )`.
2. **`proxies/foo.rb`** — `class Foo < Code::Instance` (or `< Code::Type`), inside `module Code`. `extend Ruby_Proxies` + `proxy :method_name` for 1:1 delegation ([`ruby_proxies.rb`](shared/ruby_proxies.rb)), or hand-write `def proxy_method_name(...)` for custom logic. `@ruby` calls `proxy_#{method_name}` on the proxy instance.
3. **Register the Ruby file** — `require_relative 'proxies/foo'` in [`main.rb`](main.rb)'s "proxies" block (after `proxies/scopes`).
4. **Load the .code file** — `@load 'code/foo.code'` in [`code/global.code`](code/global.code) for always-on, or leave opt-in for the user's own program to `@load` (e.g. `code/database.code`).
5. Nothing else — matching language type ↔ Ruby class is by name, dynamic at construction time (next section).

#### Linking an instance to its runtime type

1. `Interpreter#find_ruby_class_for_type(type)` walks `type.types` (most-derived first), returns the first Ruby constant `Code::#{type_name}` that's a `Class < Code::Instance`.
2. `Interpreter#build_instance_of_type(type, expr)` calls #1: found → `ruby_class.new`; not found → `Code::Instance.new(type.name)`.
3. Either way: `instance.enclosing_scope = type`, `.tag` bound if any, then the type's own language-level body runs on it.
4. This is automatic — no manual registration call for the common case.
5. One manual hook exists: `Interpreter#link_instance_to_type(instance, type_name)`, used only by intrinsics built directly in Ruby (numbers, bools) that skip `build_instance_of_type` entirely — looks up `type_name` in the global scope, sets `instance.enclosing_scope`.

#### Instance/Type without a proxy `Code::Class`

1. Perfectly valid — most user `Type { }`s have no Ruby class; `build_instance_of_type` falls back to plain `Code::Instance.new(type.name)`.
2. A plain `Code::Instance` works normally for everything declared in the language — `declarations` hash, methods, `Self(;)`, composition, structs.
3. Only `@ruby` breaks:
   - Outside a `Func` scope → `Code::Invalid_Ruby_Proxy_Usage`.
   - Instance doesn't `respond_to?("proxy_#{method_name}")` (no Ruby class, or Ruby class missing that one `proxy_*` method) → `Code::Missing_Ruby_Proxy_Declaration`.
4. So: forgetting the Ruby class is safe unless the `.code` body calls `@ruby` — then it's a runtime error on first call, not at declaration time.

#### Quick file map

| Concern | File |
|---|---|
| Tokens, reserved words, operator lists, precedence | [`shared/constants.rb`](shared/constants.rb) |
| Identifier casing rules (`type_identifier?`, etc.) | [`shared/helpers.rb`](shared/helpers.rb) |
| Lexemes → tokens | [`lexer.rb`](lexer.rb), [`proxies/lexeme.rb`](proxies/lexeme.rb) |
| AST node classes | [`proxies/expressions.rb`](proxies/expressions.rb) |
| Tokens → AST | [`parser.rb`](parser.rb) |
| Static literal type checks | [`type_checker.rb`](type_checker.rb) |
| AST forward-declaration ("hoisting") pass | [`declarator.rb`](declarator.rb) |
| Scope hierarchy (`Global`/`Type`/`Instance`/`Func`/...) | [`proxies/scopes.rb`](proxies/scopes.rb) |
| AST → execution | [`interpreter.rb`](interpreter.rb) |
| Runtime errors | [`proxies/errors.rb`](proxies/errors.rb) |
| Ruby-backed built-in types | [`proxies/`](proxies) |
| `proxy`/`proxy_delegate` helpers | [`shared/ruby_proxies.rb`](shared/ruby_proxies.rb) |
| Standard library (`.code` side of built-ins) | [`code/`](standard), auto-loaded via [`code/global.code`](code/global.code) |
| Entry points (`Code.lex`/`.parse`/`.interp`, `+_file` variants) | [`main.rb`](main.rb) |
