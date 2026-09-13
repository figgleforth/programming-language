### Quick Start

> Requires Ruby `3.4.1` or higher, and Bundler

```bash
git clone https://github.com/figgleforth/programming-language.git
cd programming-language
bundle install
bundle exec bin/program guides/hello_world.code -p # => Hello, Code!
```

### Table of Contents
 
- [Project Structure](#project-structure)
- [Extending the Language](#extending-the-language)

### Project Structure

- [`source/readme`](../source/readme.md) details the architecture and contains instructions for running your own programs
- [`guides`](../guides) contains more useful code examples
- [`source/programs`](../source/programs) contains code for the standard library
- [`source`](../source) contains code implementing the language
    - [Lexer](../source/lexer.rb) – Source code to Lexemes
    - [Parser](../source/parser.rb) – Lexemes to Expressions
    - [Type_Checker](../source/type_checker.rb) – Basic type annotation checking
    - [Interpreter](../source/interpreter.rb) – Entry point; `run(source)` lexes, parses, and executes

### Extending the Language

Pipeline: **Lexer → Parser → Type_Checker → Interpreter**. Methods: `lex_*` / `parse_*` / `interp_*`. New phase? Same convention, wire into `Interpreter#run`.

#### Adding a new construct

1. **Lex it** — [`lexer.rb`](../source/lexer.rb)`#output` is one big `if/elsif` dispatching on the current char(s). Add a branch (or a `lex_*` helper called from one) that sets `token.type`/`token.value`.
   1. `line`/`column`/`line_end`/`column_end`/`source_file` are set automatically around every branch — you don't touch them here.
   2. Add any new symbols/keywords to the relevant list in [`constants.rb`](../source/shared/constants.rb) (`RESERVED`, `PERCENT_LITERALS`, an operator list, etc.) so they're recognized/reserved.
2. **Add an AST node** — a new `Code::Foo_Expr < Expression` in [`expressions.rb`](../source/proxies/expressions.rb). Only add `attr_accessor`s for what's structurally new; `value`/`type`/`line..column_end`/`source_file` are inherited.
3. **Parse it** — add a branch to `Parser#begin_expression` (prefix position) or `#complete_expression` (infix/postfix position) in [`parser.rb`](../source/parser.rb), dispatching on `curr?`/`peek`, calling a new `parse_foo_expr`. Build the `Foo_Expr`, set its location (see below), return it.
4. **Type-check it (optional)** — only if it introduces a new literal type or call shape worth statically checking. Extend `infer_type`/`check` in [`type_checker.rb`](../source/type_checker.rb). Most constructs skip this — the static checker only handles literal type mismatches.
5. **Interpret it** — add a case to `Interpreter#interpret`'s dispatch and a new `interp_foo` in [`interpreter.rb`](../source/interpreter.rb) that walks the `Foo_Expr` and produces a runtime value (an `Code::*` instance, a Ruby primitive, `nil`, etc.).
6. **Test it** — `lexer_test.rb` → `parser_test.rb` → `interpreter_test.rb`/`pipeline_test.rb`, matching the phase you touched.

Worked examples: percent literals (`#parse_percent_literal_expr`/`#interp_percent_literal`), Statement (`#parse_statement_expr`/`#interp_statement`).

#### Lexeme/expression location (`line`, `column`, `line_end`, `column_end`)

1. Lexer sets these on every `Lexeme` for free — nothing to do there.
2. `Expression`s don't get location for free. `Foo_Expr.new(some_lexeme)` only copies `value`/`lexeme`.
3. Save `start = curr_lexeme` before consuming anything to get the construct's first lexeme's location
4. Build the expr, then `copy_location expr, start` before returning. Copies all four fields from one point — not a span.
   1. Or build the location yourself as a span between two lexemes.
5. Need a span (first lexeme → last)? Call `copy_location expr, start` first, then manually overwrite `line_end`/`column_end`/`source_file` from the closing lexeme. Pattern: `parse_struct` in `parser.rb` (search `Manually tracking location`).

#### Ruby-backed types (`Foo {}` + `Code::Foo`)

Two files, independently optional — pure-language types skip #2, rare Ruby-only types skip #1:

1. **`programs/foo.code`** — the language-level declaration (`Foo { ... }`). A method that defers to Ruby is just `some_method (; @ruby )`.
2. **`source/proxies/foo.rb`** — `class Foo < Code::Instance` (or `< Code::Type`), inside `module Code`. `extend Ruby_Proxies` + `proxy :method_name` for 1:1 delegation ([`ruby_proxies.rb`](../source/shared/ruby_proxies.rb)), or hand-write `def proxy_method_name(...)` for custom logic. `@ruby` calls `proxy_#{method_name}` on the proxy instance.
3. **Register the Ruby file** — `require_relative 'proxies/foo'` in [`source/main.rb`](../source/main.rb)'s "proxies" block (after `proxies/scopes`).
4. **Load the .code file** — `@load 'programs/foo.code'` in [`source/programs/global.code`](../source/programs/global.code) for always-on, or leave opt-in for the user's own program to `@load` (e.g. `programs/database.code`).
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
   - Outside a `Func` scope → `Code::Invalid_Ruby_Proxy_Directive_Usage`.
   - Instance doesn't `respond_to?("proxy_#{method_name}")` (no Ruby class, or Ruby class missing that one `proxy_*` method) → `Code::Missing_Ruby_Proxy_Declaration`.
4. So: forgetting the Ruby class is safe unless the `.code` body calls `@ruby` — then it's a runtime error on first call, not at declaration time.

#### Quick file map

| Concern | File |
|---|---|
| Tokens, reserved words, operator lists, precedence | [`source/shared/constants.rb`](../source/shared/constants.rb) |
| Identifier casing rules (`type_identifier?`, etc.) | [`source/shared/helpers.rb`](../source/shared/helpers.rb) |
| Lexemes → tokens | [`source/lexer.rb`](../source/lexer.rb), [`lexeme.rb`](../source/proxies/lexeme.rb) |
| AST node classes | [`source/proxies/expressions.rb`](../source/proxies/expressions.rb) |
| Tokens → AST | [`source/parser.rb`](../source/parser.rb) |
| Static literal type checks | [`source/type_checker.rb`](../source/type_checker.rb) |
| Scope hierarchy (`Global`/`Type`/`Instance`/`Func`/...) | [`source/proxies/scopes.rb`](../source/proxies/scopes.rb) |
| AST → execution | [`source/interpreter.rb`](../source/interpreter.rb) |
| Runtime errors | [`source/proxies/errors.rb`](../source/proxies/errors.rb) |
| Ruby-backed built-in types | [`source/proxies/`](../source/proxies) |
| `proxy`/`proxy_delegate` helpers | [`source/shared/ruby_proxies.rb`](../source/shared/ruby_proxies.rb) |
| Standard library (`.code` side of built-ins) | [`source/programs/`](../source/programs), auto-loaded via [`source/programs/global.code`](../source/programs/global.code) |
| Entry points (`Code.lex`/`.parse`/`.interp`, `+_file` variants) | [`source/main.rb`](../source/main.rb) |
