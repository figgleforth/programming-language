# CLAUDE.md

This file gives Claude Code guidance for work in this repository. Use ASD-STE100 (Simplified Technical English) at all times — in chat, in comments, and in documentation. Do not make an exception.

`readme.md` is the language reference for users. It holds the concepts and the examples. This file holds only what Claude needs: file names, method names, dispatch order, gotchas, and known limits. When a topic below has a matching `readme.md` section, read that section first for the language-level behavior.

## Working Relationship

The user writes the code. Claude gives advice by default: review the plan, find the gaps, act as a sounding board. Do not start work on your own, even for a task that looks small. Write code, run commands, or edit `.code` / source files only when the user asks directly. Write a changelog only when asked.

This is a side project. Some changes go through a PR. Other changes go straight to `main`. The user sets the language's direction. Claude does not keep a roadmap.

## About This Language

This is an educational programming language for web development, written in Ruby. The language has no fixed name yet. The Ruby module is `Code`. Source files end in `.code`. The CLI command is `bin/program` (alias: `bin/prog`).

Main features:

- Casing marks a name's role: a capital letter starts a class, a lowercase letter starts a function or variable, all capitals mark a constant.
- Composition operators (`|`, `&`, `~`, `^`) replace inheritance.
- Dot notation (`.`, `..`) reaches nested structures and scopes.
- Functions and classes are first-class values.
- A built-in web server handles routes.
- Use `#` for a one-line comment, with one space after it. Use `###` for a block comment. A longer run of `#` on the outer mark can nest a shorter or equal-length run inside it — the same rule a Markdown fence (` ``` `) uses to nest.

## Common Commands

### Testing

```bash
# Run all tests (default task also runs cloc)
bundle exec rake test

# Run specific test file
ruby tests/lexer_test.rb

# Run all tests and cloc
bundle exec rake

# Force the CI-only tests (a few that boot a real WEBrick server) to run locally too
CI=1 bundle exec rake test
```

The suite runs in serial order and takes about 8 seconds. `hot_reload_test.rb` has 5 tests that boot a real WEBrick server (about 2 seconds); they're `remove_method`'d unless `ENV['CI']` is set — see the `CI_ONLY` list at the bottom of that file. A local `rake test` run reports about `966 runs, 0 skips`. GitHub Actions (which sets `CI`), and a local `CI=1 rake test` run, report about `971`. `database_test.rb` and `server_test.rb` are fast and always run.

### Running Programs

```bash
# Run a file with hot reload (watches for changes)
bin/program <file.code>

# Debug/inspect compilation stages
bin/program lex "4 + 8"              # Show lexer tokens for code string
bin/program parse "4 + 8"            # Show AST for code string
bin/program interp "4 + 8"           # Execute code string

bin/program lexf <file.code>          # Tokenize file
bin/program parsef <file.code>        # Parse file to AST
bin/program interpf <file.code>       # Execute file
```

`bin/prog` is a symlink to `bin/program` and works the same way. The project root also symlinks `program`, `prog`, and `programs` (→ `source/programs`), so `./program <file.code>` works from the root too.

### Setup

```bash
# Install dependencies (requires Ruby 3.4.1 and Bundler)
bundle install
```

## Architecture

Five phases run in this order: Lexer, Parser, Type Checker, Forward Declarator, Interpreter.

`Interpreter` is the main entry point. It owns a `Lexer` and a `Parser`, and its `run(source_code)` method drives all five phases. `Lexer` and `Parser` are plain transform classes — call each on its own too, when you need to.

### One Module: `Code`

Every class lives under one Ruby module, `Code`: the engine (Lexer, Parser, Interpreter, and so on) and the language's own runtime vocabulary (the AST, the scope hierarchy, the built-in value types, the errors).

- The engine: `Lexer`, `Parser`, `Type_Checker`, `Declarator`, `Documenter`, `Interpreter`, `REPL`, `Hot_Reloader`, `Dom_Renderer`, `CLI` — plus `Code.interp`/`.parse`/`.lex` and the constants `ROOT_PATH`/`STANDARD_LIBRARY_PATH`/`VERSION`.
- The runtime vocabulary: the scope hierarchy (`Scope`, `Global`, `Type`, `Instance`, `Func`, `Route`, `Any`, `Nil`, `Bool`, `Server`, `Request`, `Response`, `Return`); every built-in value type (`String`, `Array`, `Number`, `Struct`, `Context`, `Enum`, and more); the AST (`Expression` and every `*_Expr`, `Lexeme`); the error classes; and `constants.rb`.
- This module layout is a Ruby-side detail only. It has no effect on `.code` source or `@load` paths.

### Directory Layout — `source/`

Two kinds of file live here: one flat `.rb` file per pipeline phase (`lexer.rb`, `parser.rb`, `type_checker.rb`, `declarator.rb`, `interpreter.rb`), plus the `proxies/` and `shared/` folders. `source/main.rb` requires every file in load order — read it to see that order.

- `main.rb` — entry point. Requires every component, then defines `Code.lex`/`.parse`/`.declare`/`.interp` (and their `_file` forms), `ROOT_PATH`, `STANDARD_LIBRARY_PATH`, `VERSION`.
- `cli.rb` — `Code::CLI` (the `bin/program` commands). `repl.rb` — `Code::REPL`.
- `lexer.rb` — `Code::Lexer`: source → tokens.
- `parser.rb` — `Code::Parser`: tokens → AST.
- `type_checker.rb` — `Code::Type_Checker`: static checks on the AST.
- `declarator.rb` — `Code::Declarator`: builds `Interpreter#declarations` for forward resolution. See Forward Declarations below.
- `interpreter.rb` — `Code::Interpreter`: runs the program. Owns `@lexer`/`@parser`, `stack`, `routes`, `servers`, `cached_expressions_by_filepath`. `run(source)` is the entry point.
- `programs/` — the `.code` files that ship with the language (the standard library). See Standard Library below.
- `proxies/` — base types load first:
	- `scopes.rb` — the scope hierarchy: `Scope`, `Global < Scope` (bottom of the stack, holds the stdlib), `Type`, `Instance`, `Func`, `Route`, `Return`, `Any`, `Nil`, `Bool`, `Server`, `Request`, `Response`.
	- `lexeme.rb` (`Code::Lexeme`), `expressions.rb` (`Code::Expression` and every `*_Expr`), `errors.rb`, `func_signature.rb`, `return.rb`.
	- One Ruby class per built-in `.code` type (`string.rb` ↔ `programs/string.code`, and so on): `string array number range set dictionary struct context enum statement member file_system temporal database table`. Each is `class X < Instance`.
- `shared/` — pulled in across the codebase: `constants.rb` (operators, precedence, reserved words), `helpers.rb` (`module Helpers`: identifier casing, `assert`), `ascii.rb` (`Code::Ascii`), `ruby_proxies.rb`, `declaration_accessors.rb`, `cached_by_path.rb`, `error_formatter.rb` (`Code::Error_Formatter`), `documenter.rb` (`Code::Documenter` — a separate doc-comment pass, not in the run pipeline), `dom_renderer.rb` (`Code::Dom_Renderer`), `hot_reloader.rb` (`Code::Hot_Reloader`), and the browser assets `interpreter.rb` serves by literal path (`dom.js`, `live_reload.js`, `view_transition.css`).

The project root symlinks `programs` → `source/programs`, so a `.code` file's own `@load 'programs/x.code'` line resolves the same way whether it runs from the standard library or from your own program.

### Standard Library

- `source/programs/global.code` loads by default (`load_standard_library` is `true`). It lands in its own `Standard_Library` scope, added to Global's readable scope — not as direct Global declarations. See Splatting a Scope below.
- `Code::STANDARD_LIBRARY_PATH` holds the path.
- `source/programs/readme.md` lists which files load by default, and which files need an explicit `@load`.

## Type Checker

`source/type_checker.rb` runs between the parser and the interpreter. `Interpreter#output` calls it before the run loop starts, so it also checks a file loaded with `@load`.

### What It Checks

- A typed variable assignment: `x: String = 123` raises `Type_Mismatch`. Only a literal right side triggers this.
- A typed function parameter default: `go ( x: Number := 'bad'; x )` raises at the param default.
- A call-site argument type: `add(1, 'oops')` raises when `add` has typed params and the argument is a known literal.

An annotation with a non-literal right side (an identifier, a function call) is not checked. Only a literal mismatch raises.

### How It Works

`Type_Checker` has two core methods:

- `infer_type(expr)` maps an expression to a type name string (`'String'`, `'Number'`, `'Symbol'`). For an `Identifier_Expr` it looks the name up in `type_by_identifier`. It returns `nil` when the type is not known.
- `check(expr)` is the recursive dispatcher. It returns `nil` (no error) or a `Type_Mismatch`. It recurses into every expression kind that has children.

`type_by_identifier` is a hash built during the walk:
- A typed assignment (`x: String = ...`) registers `'x' => 'String'`.
- A named function with typed params (`add ( a: Number; ... )`) registers `'add' => ['Number', 'Number']`, through `register_func`.

`check_call` checks a call site. It looks up the receiver name in `type_by_identifier`, reads the param type array, and compares each literal argument's inferred type against the expected type.

### Gotcha

`Type_Checker` lives inside `module Code`. A bare `Array` inside the module means `Code::Array`, not Ruby's `::Array`. Use `::Array` to check a real Ruby array (for example, `signature.is_a? ::Array`).

### Known Limitation

A call site before the function's own definition is not checked — the signature is not registered yet when the parser reaches the call. A two-pass approach would fix this.

### Errors

- `Code::Type_Mismatch < Code::Type_Checking_Failed` — carries `expression`, `declared`, and `inferred`.
- `Code::Type_Checking_Failed` — `output` raises this when it collects any error.

## Runtime Type Contracts (`:=`)

See readme.md's "Runtime Type Contracts" section for the language-level rules and examples. This is a separate, runtime check — the interpreter handles it, not the static Type Checker above.

- `interp_infix_declaration` (`interpreter.rb`) implements `:=`. `interp_infix_assignment` implements plain `=`, and raises `Code::Cannot_Assign_Undeclared_Identifier` when the identifier does not exist yet.
- `:=` always declares on the current scope (`stack.last`). It shadows a same-named identifier from an enclosing scope, rather than reusing it. Plain `=` and compound operators (`+=`, and so on) still resolve through the enclosing scope, via `scope_for_identifier` — this is how a closure keeps reading and writing an outer variable:

```code
counter := -1
increment (;
	counter := 99   # a new local -- does not touch the outer counter
	counter += 1    # `+=` resolves outward, so this changes the local
)
increment()
counter           # still -1
```

- `#annotation_type_names` and `#type_contract_satisfied?` (`interpreter.rb`) implement the OR-regardless-of-operator rule for `: Type` annotations. `#annotation_type_names` reads every operand name in a composition chain, whatever operator joins them. `#type_contract_satisfied?` treats that list as alternatives (`.any?`) — it never composes them.
- A mismatch raises `Code::Type_Contract_Violation`, not `Type_Mismatch`.

## Forward Declarations

See readme.md's "Forward Declarations" section for the language-level behavior and examples. This section covers the Ruby implementation.

### `Declarator` (`source/declarator.rb`)

Walks the whole top-level AST once, before interpretation, and builds `Interpreter#declarations`: `Hash{::String => Code::Declaration}`. `Code::Declaration = Data.define(:key, :expr_or_decl, :expr)`. `expr` is always the original expression — what `interpret` needs to run to bring the declaration into being. `expr_or_decl` is a more readable rendering (a nested Hash for a `Type_Expr`/`Func_Expr`/`Route_Expr` body, or the raw value expression for `:=`/`=`). Inspect either one with `bin/prog declare <code>` / `declaref <file>`.

`#declare` dispatches on the expression kind:

- Nests under its own key: `Type_Expr`, `Func_Expr` (named only), `Route_Expr`, `Func_Signature_Expr`. Each recurses into its own body or params through `#declare_all`.
- Flattens into the enclosing level: `Conditional_Expr` (`if`/`unless`/`while`/`until` do not push their own scope, so a `:=` inside a branch lands in the enclosing scope) and `Circumfix_Expr` (a grouping does not push a scope either).
- Excluded on purpose: `For_Loop_Expr` (pushes its own scope per iteration — loop-local, not forward-referenceable), `Call_Expr` (its arguments can use `:=` for named-argument passing — see Named Function Arguments — which is not a declaration), and a bare `Identifier_Expr` (reads a value, does not declare one).
- Literals (`String_Expr`/`Number_Expr`/`Symbol_Expr`) are stored as the value on the right of a `:=`/`=`, through `#resolve_value` — a separate helper used only for right-side resolution.

### `@load` (`Declarator#declarations_for_load`)

A bare `@load 'file'` participates too: the `Call_Expr` branch of `#declare` computes the loaded file's own Declarator output (parsed and declared once, cached in `cached_declarations_by_filepath`, keyed by resolved path), then rebinds every entry's `.expr` to the `@load` directive itself — not the isolated node it came from in the other file. This matters because a loaded file's declarations depend on each other (`Div | Dom {}` needs `Dom` too), and because forcing one name has to mark the whole `@load` as forced, so `#output` does not re-run the whole file a second time when it reaches that line for real.

`Ident := @load 'file'` (a named, namespace-isolating load — see File Loading below) needs none of this. The existing `Infix_Expr` branch, plus `#hoistable_declaration_expr?`'s casing check (next section), handles it — forcing the whole `Infix_Expr` re-runs the real assignment.

### Interpreter (`#resolve_forward_declaration`)

`#interp_identifier`'s final `else` branch consumes this — the case where ordinary lookup found nothing. It checks `declarations[name]`. When it finds a hoistable declaration, it runs `.expr` immediately (against `#global`, not whatever scope is on top of `stack`), then retries the lookup.

- `HOISTABLE_EXPRESSIONS` (`Func_Expr`, `Type_Expr`, `Route_Expr`, `Struct_Expr`, `Func_Signature_Expr`, `Operator_Expr`, `Operator_Overload_Expr`) lives on `Interpreter`, not `constants.rb`, because it references `Expression` subclasses that load later. `#hoistable_declaration_expr?` also unwraps one level of `:=`/`=` to catch `This := That {}`. A named `@load` needs a Capitalized or UPPERCASE left-hand name too (`Code.type_of_identifier`) — a lowercase `mod := @load 'file'` stays a plain variable. A bare `@load` is checked separately, through `#bare_load_directive_expr?`, kept out of the recursive unwrap on purpose.
- Forcing a declaration marks its `.expr` in `@forced_declarations` (an identity-tracked `Set`). `#output`'s own top-level walk skips any expression already in that set. The skip keeps the running `result` rather than resetting it with a bare `next` — otherwise a skipped last statement would silently turn the whole program's result into `nil`.
- The whole mechanism only fires when Global is reachable — guarded by `stack.any? { |s| s.equal? global }`, an identity check (not `#include?`, which is `==` and can hit a language type's own overload). A plain `x.y` dot access excludes Global from its lookup on purpose (`#interp_dot_scope`'s `exclude_global_scope: true`), so a member missing on `x` stays missing. One consequence: a plain identifier reference (`This()`) hoists, but `.method()` does not hoist the method it calls on its own — `sign.warning()` only works once `warning`'s own declaration has run, even if `sign`'s type was forced early. See `examples/forward_declarations.code`.
- `#global` is a dedicated reference, set once when Global is created, independent of `stack` (which `#interp_member_access` swaps out during dot-access resolution).
- `declarations` is saved and restored around `#load_file_into_scope`'s recursive `#output` call, the same way `@input` already is — otherwise loading a file would overwrite the outer program's own `declarations`.

### Known Limitation

`declarations` is keyed by name at one flat level per file. A declaration nested inside a Type or Func body (or a top-level `if`/tuple, which flattens into the same level) is not told apart from a genuinely top-level one. Forcing one runs only that one inner expression, not the construct around it.

## Scope System

The language uses a scope hierarchy, all defined in `source/proxies/scopes.rb`:

- **Global** — the global scope. Pushed as the bottom of `Interpreter#stack` on first `run`. Standard library declarations live here. Execution state (routes, servers, loaded files) lives directly on `Interpreter`.
- **Type** — class definitions (tracks `@types`, `@expressions`).
- **Instance** — class instances.
- **Func** — function scopes (tracks `@expressions`).
- **Route** — HTTP route handlers (extends Func, adds `@http_method`, `@path`, `@handler`, `@parts`, `@param_names`).
- **Html_Element** — HTML element scopes (tracks `@expressions`, `@attributes`, `@types`).
- **Return** — return-value wrapper (tracks `@value`).

Each scope also carries readable and writable fallback scopes — extra places identifier lookup checks after the scope's own declarations, set with `@splat`/`@splatr` (see Splatting a Scope below). This is a different mechanism from `@push_scope`/`@pop_scope` (see Reopening a Scope below), which pushes a scope directly onto the interpreter's stack rather than adding a fallback.

See readme.md's "Scope Keywords" section for the language-level rules on `self`/`Self`/`Global`.

An identifier with no keyword prefix searches every scope on the stack, from current to global, proxy methods included. `self.x` searches only the current instance (no fall back to global); `Self.x` only the current type; `Global.x` only the global scope. An identifier starting with `_` is private by convention (for example `_private_var`).

- `self.` outside an instance context raises `Cannot_Use_Instance_Scope_Operator_Outside_Instance`.
- `Self.` outside a type context raises `Cannot_Use_Type_Scope_Operator_Outside_Type`.
- `Global.`/`Self.`/`self.` followed by a literal (`Global.123`) raises `Invalid_Dot_Infix_Right_Operand`.

### Implementation Notes

- `#parse_self_prefixed_identifier` (`parser.rb`) synthesizes a `scope_operator` lexeme on `self.funk (;)` / `Global.x,` — the function-name and nil-init positions. `#scope_for_identifier` and `#track_static_declaration` match on that lexeme.
- **Dot access (`x.y`)** resolves `y` only against `x`, plus global scope, through `#interp_member_access` — never the ambient call stack. Without this, a missing member on `x` could fall through to an unrelated same-named member still active further down the stack.
- **Nil receiver.** `x.y` (read, call, or write) where `x` is `nil` raises `Code::Receiver_Is_Nil`, not a bare `Undeclared_Identifier`. `nil` is still a real scope with its own declared members, so `nil.to_s()` still works. The read path (`#interp_dot_scope`) translates `Undeclared_Identifier` to `Receiver_Is_Nil` only when the receiver really is `Code::Nil`; the write path (`#assign_dot_member`) checks this up front. `x.?y` on a nil `x` still returns `nil`.
- `#current_instance` (`interpreter.rb`) is the nearest `Code::Instance` in the stack, found by role, not by position. `self` resolution and `#check_dot_access_permissions!`'s privacy check both use it, since `#interp_func_body` always pushes a fresh `Func` frame on top of the instance — `stack.last` during a method body is never the instance itself.
- `#static_var_declaration_expr?` (`interpreter.rb`) recognizes `Self.x := value` by its AST shape — a `.` dot-target with a bare `Self` identifier on the left — so it runs once during the type body walk, not once per instance.

## Reopening a Scope

`@push_scope scope` pushes a `Type` or `Instance` directly onto the interpreter's stack, so its members become reachable with no prefix. A bare declaration made while "inside" lands on the pushed scope itself — this mutates the target, unlike a splat (see Splatting a Scope), which only adds a lookup fallback. `@pop_scope scope` pops back out. It checks, by identity, that `scope` is exactly what `@push_scope` last pushed, and raises a plain `RuntimeError` otherwise.

Implemented as `#interp_context_stack_function`'s `push_scope`/`pop_scope` cases, calling `#push_scope`/`#pop_scope` on the interpreter's `stack`.

## Static Declarations

See readme.md's "Static Declarations" section for the language-level rules and examples.

- Static declarations are tracked in `type.static_declarations`.
- Calling an instance method pushes both the type scope and the instance scope onto the stack.
- An instance links to its type through `instance.enclosing_scope = type`.

## Member Creation Is Strict

A member must be declared in a type's own body before anything can write to it — from outside with `.`, or from inside one of the type's own methods (`Self(;)`, the constructor, included) with `self.`/`Self.`. Nothing ever self-declares a brand-new member on an instance.

- `self.`/`Self.` writing to an already-declared member works from any method, `Self(;)` included — it is a plain reassignment, not a declaration. Self-declaring a brand-new member this way, even inside `Self(;)`, raises `Code::Cannot_Assign_Undeclared_Identifier`, the same as an external `.` write always has.
- `#still_under_construction?` (`interpreter.rb`) grants one narrower exception: a `Code::Type`'s own `declaration_in_progress` flag (true only while its `{}` body is being walked). This is what lets `Self.count := 0` self-declare a brand-new static inside the type's own body. `Code::Instance < Code::Type` in Ruby, but only the `Type` object ever gets `declaration_in_progress` set — an instance under construction never has it.
- A constant-named member (`X.SOME_CONST = ...`) can never be reassigned through `.` — it raises `Code::Cannot_Reassign_Constant`.
- Plain `=`, plain `:=`, and destructuring dot-targets all share one implementation: `#assign_dot_member` in `interpreter.rb`. `:=` onto an existing member re-infers and overwrites its recorded type. `=` checks the new value against any previously recorded type.
- A `.`-write onto a `nil` receiver raises `Code::Receiver_Is_Nil`, not `Cannot_Assign_Undeclared_Identifier` — see Nil Receiver under Scope System above.

## Class Composition Operators

See readme.md's "Type Composition" section for the language-level rules, chaining, and the `Alias vs. subtype` distinction. This section covers only the Ruby implementation.

- `interp_composition`'s `|` case only fills in a key the accumulating scope does not already have (`curr_scope[key] = ... unless curr_scope.has?(key)`, `source/interpreter.rb`). A chain (`A | B | C { }`) applies strictly left to right, so the leftmost operand that declares a name wins — `Self` included.
- The type's own literal `{ }` body always wins over anything composition brought in, whatever position it holds in the chain — the composition steps run first, the body's own declarations run last and overwrite unconditionally.
- `~` (difference) protects `Self` from removal, even when the right-hand operand also declares one. `&`/`^` have no such protection, and can drop `Self` like any other key.
- `interp_struct_composition` (the sibling that composes structs, via `Both | Abc | Def <extra: String>`) mirrors the same leftmost-wins rule for `|`, matched by member name.

### Composing With a Struct Value

`Code::Struct < Instance < Type < Scope` (`source/proxies/struct.rb`, `source/proxies/scopes.rb`), and `interp_composition`'s only requirement of its right-hand operand is `is_a? Code::Scope` — so a struct value satisfies it like any Type would. A named struct member is an ordinary `declare`d entry (`Struct#initialize` calls `declare name, values[i], type_names[i]` for each named member), so `|`/`~`/`&`/`^` treat it as just another declaration to merge.

- An unnamed struct member never transfers — `Struct#initialize` only declares members that have a name.
- A struct declared with no values composes fine too, but every member comes through `nil`.
- There is no `Self`-collision case here, since structs have no constructor.

## Type Comparison Operators

See readme.md's "Comparison" section (under Operators) for `===`/`=!=`/`=>=`/`=<=`/`=/=` and their examples. All five are handled by `#interp_comparison_infix` (`interpreter.rb`, dispatched from `#interp_infix`).

- Struct members factor into all five: `===`/`=!=` also require the structures to match (`left.tag_instance&.type_objects == right.tag_instance&.type_objects`); `=>=`/`=<=` also require the member-poor side's members to sit entirely inside the member-rich side's; `=/=` also requires the members to share nothing. An unstructured side counts as having no members.
- `Any` is a real declared type (`source/programs/global.code`), but `==`/`!=`/`=>=`/`=<=`/`=/=` special-case it: any value or type that is not `nil` counts as equal to, or a superset of, `Any` — in either operand position, with no composition needed. `===`/`=!=` are the one exception: they stay exact composed-type-set equality, since that is what the codebase uses throughout as a structural type-dispatch check (`node === Element`, and so on). `ANY_WILDCARD_COMPARISON_OPERATORS` (`constants.rb`) lists the five that get the wildcard; `#any_type?` identifies the literal `Any` type by name.
- `"Flying" == Flying` is `true`, in either operand order, when the string spells the type's own `.name` — `==`/`!=` only, and only for a bare Type (not an Instance or Struct). `#string_value_and_bare_type` checks this, right after the `Any` wildcard. This is what lets `set.include?(SomeType)` match a collection of type-name strings.

## Structs

See readme.md's "Structs" section for `<...>` and `\` tagging, chains, and the concept of "each declared tag is its own type." This section covers the Ruby implementation.

`parse_struct` (`parser.rb`) builds a `Code::Struct_Expr`; `interp_struct` (`interpreter.rb`) builds a `Code::Struct` instance (`source/proxies/struct.rb` — no paired `.code` file). `source/programs/struct.code` and `source/programs/member.code` are a separate, higher-level `Member`/`Struct` layer on top of it, loaded by default through `source/programs/global.code`.

`\`'s right side resolves through `#resolve_tag_node` (`#resolve_tag_reference` is a thin `expr.tag` delegator), dispatched from `interp_type`/`#interp_tagged_type_declaration`. There is no standalone `\expr` expression — `\` only ever trails a type name. `Identifier_Expr` carries the tag on `.tag`; a tagged `Param_Expr` (`x: Abc\<Number>`) reaches it through `param.type.tag`, since `param.type` is itself an `Identifier_Expr`.

A named reference's right side must resolve to a real `Code::Struct` or `Code::Type`, or it raises `Code::Tag_Reference_Must_Be_Type_Or_Struct`. Referencing a real declared Type with no matching tagged variant yet does not raise — it auto-declares one on the spot (`#declare_tagged_type_variant`), so `Array\String` works with no `Array\String {}` written first.

- A member is any expression, evaluated normally at interpret time — an identifier like `Number` resolves to the real `Code::Type`.
- The bare integer shorthand (`Abc\4815`, a "version tag") is handled by `#integer_tag_next?`/`#type_then_integer_tag_next?`/`#integer_tag_struct_expr` (`parser.rb`).
- Named members reuse `parse_identifier_expr`'s `: Type` annotation parsing for each member. Three named forms: `name: Type`, `name := value`, and `name: (params -> ret;)` (a func-signature type). A `:` right after a bare identifier, followed by anything that is not a capitalized type name or `<...>`, raises `Code::Invalid_Struct_Member_Annotation` at parse time — without this check, the leftover `:` reparses as a `:symbol` literal starting a new member.
- A struct is only ever reachable through `@` (`@.tag`, `x.@tag`, and so on) — never auto-unpacked into the struct's own scope, and never through plain `.tag`. Every reflective accessor is `@`-only, held as a plain Ruby ivar on `Code::Struct`, surfaced by `#context_vital`:
  - `@.name` — the struct's own identifier, or `nil`.
  - `@.names` / `@.type_names` / `@.values` — parallel per-member arrays.
  - `@.type_objects` / `@.types` — the same thing: the per-member type-object list.
  - `@.members` — an `Code::Array` of `Code::Member`, populated by `#build_struct` only when the `struct.code`/`member.code` layer is loaded.
  - `@.composed_types` — the composed-type `Set`. `@.type` — the first member's type.
  - `s.types` / `s.names` / `s.values` (plain `.`) resolve a member of that name, or raise — the `.` namespace on a struct is user members only.
- `name` is `@`-only across the board (`Type.@name`, `instance.@name`, `enum.@name`, `struct.@name`), backed by `Scope#name`. A plain `.name` reads a declared member of that name or raises.
- Reference forms (`x := Abc\<Number>`) `dup` the matched variant rather than mutating it in place. `Object#dup` is shallow, so `@declarations`/`@static_declarations` are re-forked too, or tagging one reference would mutate every other reference sharing that variant.
- Constructing from a tagged reference binds `.tag` onto the instance before `type.expressions` (and so `Self(;)`) run, so `Self`'s own body can read it through `self.@tag`. Member values are never forwarded as constructor arguments — `(...)` still binds to `Self`'s own declared params.

### Tag Chains

`#resolve_tag_node` walks the nested `.tag` field: it resolves one link to a `Code::Struct`, and if that node carries its own `.tag`, resolves that too and hangs it off `struct.tag_instance` plus `#declare_tag(struct)`. Each link is a real `Code::Struct`, so `@tag.@tag.@tag` is ordinary `@`-access down the chain.

Two chains sharing a prefix are distinct variants — `Thing\One\Two {}` and `Thing\One\Three {}` do not merge. `#declare_tagged_type_variant`'s collision check pairs `Struct#structure_declaration_equal?` (top-level structure) with `#tag_chains_equal?` (recursive equality down `.tag_instance`). `#find_tagged_type_variant` filters candidates through `#tag_chains_satisfy?` (a recursive `=>=`-style match) before its own exact-or-compositional pick.

### Runtime Re-Tagging

`x.@tag = new_tag` re-tags at runtime — `@`-only, like reading it. `#assign_context_member` (`interpreter.rb`) handles both `x.@tag =` and `self.@tag =`, in a dedicated branch before the built-in-`@`-member check:

- Only allowed when `x`'s type was declared with a tag (`receiver.tag_instance` present) — otherwise it raises `Cannot_Assign_Undeclared_Identifier`.
- `#tag_struct_for_reassignment` normalizes `new_tag` to its tag `Code::Struct`.
- The new tag must `=>=` the current one at every chain link (`#tag_chains_satisfy?`), or it raises `Code::Tag_Signature_Violation`.
- On success: `receiver.tag_instance = new_tag`, then `#declare_tag(receiver)`. No already-run method re-runs.
- Plain `x.tag = new_tag` (no `@`) does none of this — it raises `Cannot_Assign_Undeclared_Identifier` unconditionally.

### Each Declared Tag Is Its Own Type

`#interp_tagged_type_declaration` handles a tagged declaration, as a sibling of `#interp_bare_type_declaration` (plain, untagged `Type { ... }`). Both funnel into `#declare_tagged_type_variant`, then `#finish_type_declaration`. Each variant is kept in a per-scope list (`Scope#tagged_type_variants`, keyed by base name), not a single mangled-string-keyed member — so `String\<dict: Dictionary> {}` and `String\<other: Dictionary> {}` stay distinct.

A reference resolves by inferring a type name for each supplied value and matching it against the declared variants for that base name. `#member_candidate_type_names` returns every type a value composes, its own name first — so a `Div` satisfies a member declared `Dom`, even though nothing is literally named `Dom`. `Code::Struct#satisfied_by_candidates?` checks a declared variant against those candidates; `#find_tagged_type_variant` filters through `#tag_chains_satisfy?` first, then prefers an exact match before a compositional one. A lone unnamed struct-valued member spreads at declare time, but not at reference time by default — `#interp_type`'s reference branch retries with spreading applied when the unspread shape finds nothing. A reference with no matching declared variant either auto-declares one, or raises `Code::Undeclared_Tagged_Type`.

### Runtime Wiring

- `Code::Struct < Instance`, not `Scope` — the `enclosing_scope` method-lookup fallback (see `#interp_identifier`) is gated on `is_a?(Code::Instance)`, and `Struct` needs that fallback for `struct.code`'s own declarations (`==`, `include?`) to be reachable at all.
- Every `Code::Struct.new` call site also calls `link_instance_to_type(struct, 'Struct')`, linking it to whichever `Struct` type is declared — the bare Ruby fallback, or `struct.code`'s own `Struct { }`.
- `.tag` is `@`-only, read live off `tag_instance` by `#context_vital`'s `'tag'` case. Composition (`Tasks | Container\<Connection> {}`) does not copy `tag_instance` for free — `#interp_composition`'s `|` case copies it explicitly, with the same leftmost-wins rule as everything else.
- `Type` (and so `Instance`, and `Struct`) carries two separate accessors, both holding a `Code::Struct`: `.tag_instance` (what a specific reference or instance was tagged with) and `.tag_declaration` (the type's own declared tag — named or positional members, annotations, defaults). Both live on `Type`, not `Scope`, since a tagged reference is a `dup` of the type — a `Type`-vs-`Instance` check cannot stand in for "declared" vs "supplied."

### Bare Named Structs

`Ident<...>` where `Ident` is genuinely undeclared builds a plain `Struct`, with `@.name` set from the identifier — implemented in `#interp_struct`/`#register_bare_named_struct` (`interpreter.rb`), gated on `expr.name.is_a?(Code::Lexeme)`. Conflict detection checks both `find_in_stack(name)` and `tagged_variants_for(name)`, since a tagged Type declaration never registers under the plain identifier namespace.

- Redeclaring a bare named struct with the identical shape is a no-op (`#structure_declaration_equal?`, order-insensitive once every member is named). A different non-empty shape still raises `Code::Undeclared_Tagged_Type`.
- A member's own `: Type` annotation can name the struct being declared. `#predeclare_bare_named_struct_stub` declares an empty stand-in before the members are interpreted, then `#register_bare_named_struct` swaps the finished struct in and `#repoint_struct_self_reference` points the self-referential slots at it. Since `Struct_Expr` is already hoisted, this also makes mutually-referential structs work.
- An empty `Name <>` is a forward declaration — a later `Name <...full...>` fills it in, keyed on `existing.equal?(stub)`.

## Enums (not finalized — don't rely on yet)

See readme.md's "Enums" section for the language-level shape. `Code::Enum_Expr` (`#parse_enum_expr`) and `#interp_enum`/`#build_enum`/`#build_enum_member` (`interpreter.rb`) implement it. Its language-level body lives in `source/programs/enum.code`; the Ruby class is `source/proxies/enum.rb`.

The enum's reflective data is `@`-only — `@.keys`/`@.values`/`@.types` (parallel Arrays), `@.type` (backing type), `@.count` — held as plain Ruby ivars on `Code::Enum`, not `@declarations`, so a member named `KEYS`/`TYPES` cannot clash.

### Enum vs. Subscript Disambiguation

`Name [ ... ]` in statement or value position is an enum declaration; `name[i]` is an array or dictionary subscript. `#bare_enum_declaration_follows?` (`parser.rb`) decides by looking ahead into the brackets. It reads as an enum when the body has any of: nothing, a `,`, a `:=`/`=`/`NAME:` member form, a nested `NAME [`, or two or more items. A single bare item (`Name [ ONE ]`) reads as a subscript — write `Name [ ONE, ]` (a trailing comma) to force a one-option enum.

### Annotated Form

Any `Capitalized: Type [` annotation (`#annotated_enum_declaration_follows?`) makes it an enum unconditionally, whatever the item count. The base can be `Enum` (with an optional `\Backing_Type` tag), or the backing type on its own. Either way the backing type lands on `expr.type`, read by `#build_enum` into `instance.enum_type` / `@.type`.

**Not enforced yet:** each member's own `: Type` annotation is stored but never checked. The backing type is recorded but not yet used to coerce or check member values. Do not build real functionality on Enum type annotations until this is resolved.

## Destructuring

See readme.md's "Structs" section area for the language-level examples; `#interp_destructuring_declaration` (`interpreter.rb`) implements it, dispatched from `#interp_infix_declaration` when `expr.left` is a `()`-grouped `Circumfix_Expr`.

- A plain-identifier target always declares fresh on the current scope.
- Asking for more targets than the source has values raises `Code::Destructuring_Arity_Mismatch`; extra values are discarded.
- An existing-member target (`thing.member`) reassigns through the same `#assign_dot_member` path as `thing.member = value`.
- Only `Code::Tuple`/`Code::Struct` sources work (`Code::Invalid_Destructuring_Source` otherwise). A target that is neither a plain identifier nor an existing-member dot-expression raises `Code::Invalid_Destructuring_Target`.
- Not implemented: the bare, no-parens form `a, b := ...` — this needs lookahead past the whole comma run to tell it apart from independent nil-init declarations. Not urgent.

## Percent Literals

See readme.md's "Percent Literals" section for the eight kinds and their examples. `#parse_percent_literal_expr` (`parser.rb`) builds a `Code::Percent_Literal_Expr`; `#interp_percent_literal` (`interpreter.rb`) interprets it.

- Items split only on whitespace or `,`, not per lexer token — `1px`/`file.ext` are each one item, even though the lexer tokenizes them as several lexemes. `#parse_percent_literal_item` parses one token through `#parse_percent_literal_token`, then merges further tokens through `#merge_percent_literal_items` while `#lexeme_adjacent?` finds no gap in the source. A merged item becomes a plain `Identifier_Expr` carrying the concatenated text. A backtick item never merges.
- `#parse_percent_literal_token` reads one bare token at a time, never through the general `#parse_expression` — a symbolic operator item (`+`/`-`) is also a valid prefix operator, and ordinary expression parsing would swallow the next item as its operand.
- The one remaining `else -> #parse_expression` branch exists so an invalid item still consumes at least one token, or the parser would loop forever on it.

## `@` Is `Context`

See readme.md's "The Context (`@`)" section for the language-level reflective members and function list. `@` resolves to a `Context` (`Code::Context < Code::Instance`, `source/proxies/context.rb`). There is no per-scope Context object — nothing is cached on a scope.

- One shared `Context` (`Interpreter#shared_context`, built once) holds the `@` functions as bodiless callable stand-ins — a `Code::Func` carrying `#context_function_name`. `#bind_context_func(name, subject)` hands out a cheap `dup`, with `enclosing_scope` set to the subject.
- Reflective vitals (`name`, `display_name`, `composed_types`, `types`, `type`, `tag`, `object_id`, `size_in_bytes`, `root_path`, `static_declarations`, plus the Struct-only and Enum-only ones) are never stored — `#context_vital(name, scope)` computes each one on demand, so a read after `x.@tag =` is live, not stale.
- `#context_for(scope)` builds a transient `Code::Context` (subject = `scope`) only for a bare `@` (alone, or `@.foo`).

### Resolving `@name` / `x.@name` / `@.name`

`#interp_at_word_on(scope, ident_expr)` is the one resolver. It unwraps a `Code::Context` scope to its `.subject`, then dispatches: a `Context::FUNCTIONS` name to `#bind_context_func`; a `Context::VITALS` name to `#context_vital`; a user `@x` member to `#user_at_member_owner`; else `Undeclared_Identifier`.

`Code::Context::MEMBERS` is the one source of truth. It maps each name to `{}` (a vital), `{ fn: :intrinsic }`, or `{ fn: :stack }`. `FUNCTIONS`/`STACK_FUNCTIONS`/`VITALS` derive from it. `source/programs/context.code` is the hand-written mirror, and `tests/context_test.rb` asserts its members equal `MEMBERS.keys`. Adding a member takes one `MEMBERS` entry and one `context.code` line.

Call dispatch (`#interp_call`, `when Code::Func`): a context function never runs through `#interp_func_body` and gets no pushed frame. A `STACK_FUNCTIONS` member runs in the caller's own frame, through `#interp_context_stack_function`. Everything else runs through `#interp_intrinsic`.

### User-Declarable `@` Members

See readme.md's "The Context (`@`)" section for the language-level example. `@x := …` outside a Type body raises `Code::Context_Declaration_Outside_Type`. It stores on the Type's `Scope#at_members` — effectively a static, read by every instance. Declaring a name that is already a `Code::Context::VITALS` or `FUNCTIONS` member raises `Code::Cannot_Override_Context_Member`. `x.@x = v` requires the member to already be declared on the type.

## Statement Expressions

See readme.md's "Statement Expressions" section for the language-level rules, including captured-vs-caller scope and `.memoize`. `#parse_statement_expr` (`parser.rb`) builds a `Code::Statement_Expr`; `#interp_statement` (`interpreter.rb`) builds a `Code::Statement` instance (`source/proxies/statement.rb` plus `source/programs/statement.code`).

- **Two construction paths.** A backtick literal (`` `expr` ``) builds the Ruby object directly — `#interp_statement` is the only place that can set `captured_scope`, since it runs with a live `stack` to read. An explicit `Statement(...)` call goes through the normal Type-construction path instead; real argument binding happens once `Self(;)`'s own body runs.
- `use_caller_scope`/`memoize`/`_memoized`/`_memoized_value` are ordinary language members in `statement.code`, not Ruby `attr_accessor`s — `#invoke_statement` reads and writes them through `Scope#[]`/`#[]=`. `captured_scope` stays a Ruby `attr_accessor`, since it holds a live Ruby `Scope`, not a language-representable value.
- A bare backtick literal skips the normal Type-construction path, so `#interp_statement` also runs the type's own language-level body on the instance (`#run_type_body_on_instance`) — otherwise `use_caller_scope`/`memoize` would only exist on instances built the `Statement(...)` way.
- `#invoke_statement` is the single place `use_caller_scope`/`memoize` are enforced, called from `#interp_call`'s `Code::Statement` branch. It does not apply to a bare `` `expr`() `` written and called in the same place, or to a `` `expr` `` item inside a percent literal or array literal — neither of those ever builds a real `Code::Statement`.
- Pushing the captured scope back on top (rather than swapping the whole stack) works because identifier lookup searches innermost-first — the same trick `#interp_func_body` uses for ordinary `Func` closures.

## Identifier Naming Conventions

The language enforces naming conventions through helper functions:

- UPPERCASE (`constant_identifier?`) — constants.
- Capitalized (`type_identifier?`) — classes and types.
- lowercase (`member_identifier?`) — variables and functions.

## Function Conventions

See readme.md's "Functions" and "Labeled & Named Function Arguments" sections for the language-level rules and examples.

- `(...)` also means a grouping, a call's argument list, and a Tuple, so a bare `(` alone does not say which is coming. `func_declaration_follows?` (`parser.rb`) disambiguates by depth-checking for a bare `;` at nesting level 1 before the matching `)` closes.
- A no-body func is a signature (`Code::Func_Signature_Expr`) when it declares a return type, or was written with the `name: (…)` colon form. `#parse_func` tracks `signature_colon` for the colon form. A bare `foo (;)` stays a real, empty function.
- The spread lambda sugar (`xs.map(x; x * 2)`) only applies when the receiver is a member access, call result, or subscript — never a bare identifier, which still declares. `anon_func_param_list_follows?` (`parser.rb`) checks the tokens before `;` are genuinely param-list-shaped. `#complete_expression` plus a `member_rhs` flag handle this.

## Variadic Parameters

See readme.md's "Recursion" and array sections for related context; the language-level rules for `x...` live in `source/programs/array.code` (`Arguments | Array {}`; `Args` is an alias). `...` is a dedicated lexer token, distinct from the range base `..`, and only carries meaning in a param list (`Param_Expr#variadic`, `#wrap_arguments_array`).

- A variadic param takes the whole unconsumed positional tail. Params declared after it get named args, defaults, or `Missing_Argument` — never positionals.
- `rest := <value>` at a call site: an Array spreads into the tail; anything else raises `Type_Contract_Violation`.
- When a func has a variadic param, an unknown named arg binds by its own name into the call scope instead of raising `Unknown_Named_Argument` — a variadic body cannot rely on any given name being set.
- Override `Arguments#push` (`source/programs/array.code`) for a typed variadic.
- The static `Type_Checker` skips a func with a variadic param entirely.

## Labeled Function Arguments

See readme.md's "Labeled & Named Function Arguments" section for the language-level rules and examples.

- Matching is purely positional — a labeled argument's label must match whatever is declared at that same param index. Labels never reorder arguments.
- `label: value` parses as an ordinary `:` `Infix_Expr` (the same production named struct members use). `#interp_func_body` unwraps it through `#classify_argument` before interpreting.

## Named Function Arguments

See readme.md's "Labeled & Named Function Arguments" section for the language-level rules and examples.

- The ordering rule: positional arguments must come before all named arguments. Reverting to positional after a named argument raises `Code::Positional_Argument_After_Named`.
- A named argument whose name matches no declared param raises `Code::Unknown_Named_Argument`, checked up front, before param binding — so a typo is reported directly, not as a confusing `Code::Missing_Argument` on an unrelated param.
- `name := value` parses as an ordinary `:=` `Infix_Expr`. `#classify_argument` tells it apart from a labeled (`:`) or plain positional argument. `#interp_func_body` builds a `named_args` hash alongside the positional `arg_values` array, and checks it first when binding each declared param.

## Struct-Typed Function Parameters

A function param can be typed with an inline struct (`: <...>`) instead of a plain type name — structural, not nominal. Any argument that has each named member, with a compatible type, satisfies it.

```code
f ( right: <name: String, type: Any, value: Any>; right.name )
```

- `Any` is a wildcard within a struct annotation's member types.
- Checked at every call — unlike a plain `: Type` param annotation, this is a real, always-checked contract.
- A `: <...>` param annotation parses onto `Param_Expr#type` as a `Struct_Expr`. `#check_struct_type_contract` (`interpreter.rb`) runs on every bound argument whose `param.type.is_a?(Code::Struct_Expr)`, reusing `#member_candidate_type_names`.

## Class Conventions

See readme.md's "Classes" section for the language-level rules and constructor example.

### `Self` Is an Ordinary Function Member

The constructor is a function named `Self`, declared and reachable like any other. `Type()` is the only construction sugar; `X.Self`/`X.Self(...)` are not special-cased.

- `Type.Self` (bare, no parens) is an ordinary reference to the declared function — it returns the raw `Code::Func`, uncalled. A type's body runs directly onto the type's own scope, not just per-instance, so `Self` stays declared there even after it is deleted off each instance right after construction. `#interp_member_access` (`interpreter.rb`) special-cases a dot-target literally named `Self`/`self` (no scope operator), doing `receiver[name]`/`receiver.has?(name)` directly instead of routing through `#interp_identifier`.
- `Type.Self()` (called) is an ordinary call on that `Func` — it never goes through `#interp_type_call`'s instance-building path, so no `Instance` is pushed, and a constructor body's `self.x = ...` raises `Code::Cannot_Use_Instance_Scope_Operator_Outside_Instance`. This is left as-is, not designed for.
- `instance.Self` raises `Code::Undeclared_Identifier` — `Self` is deleted off an instance the moment construction finishes (`instance.delete :Self` in `#interp_type_call`).

**Storing a method reference as a value.** `f := instance.some_method` (no call), then `f(...)` later, still reaches the instance's other methods. `#rebind_func_to_scope` (`interpreter.rb`) rebinds a found `Code::Func`'s `enclosing_scope` to whatever Instance/Type it was found on. This happens once per method, guarded by `enclosing_scope.instance_of?(Code::Type)` (exact class) rather than `is_a?` — since `Code::Instance < Code::Type` in Ruby, `is_a?` would also match an already-bound method and re-rebind it on every later read through an unrelated container.

## Splatting a Scope

See readme.md's "Splatting a Scope" section for the language-level rules and examples.

- `Scope#readable_scopes`/`Scope#writable_scopes` (`scopes.rb`) are `ObjectSpace::WeakMap`s (`wm[x] = x`, since Ruby's stdlib has no weak Set), so membership cannot keep an instance alive on its own.
- `Scope#add_readable_scope`/`#add_writable_scope`/`#remove_readable_scope`/`#remove_writable_scope` are the only code that touches the WeakMaps directly. `#interp_context_stack_function`'s `splat`/`splatr`/`unsplat` cases, and the param-shorthand handling in `#interp_func_body`, both call these.
- Lookup order, for reads and writes, is: own `@declarations` first, then `@writable_scopes` (most-recently-added first), then `@readable_scopes`.
- The param shorthand only unpacks a `Type`/`Instance` value. `@splat`/`@splatr` as bare directives run the target through `#maybe_instance` first, then raise `Code::Invalid_Scope_Function_Argument` if it still is not one.
- `source/programs/global.code` loads into its own `Standard_Library` scope, added to Global's readable scope — so `String`/`Array`/etc. are reachable but not directly declared on Global. Reassigning a built-in (`Array = Mine`) can never mutate the real one, since `Scope#[]=` only writes through `writable_scopes`, never `readable_scopes` — it creates a new entry directly in Global's own declarations instead.

### In a Function Param List

`@splat`/`@splatr` on a param unpacks that argument for the whole body. A `: Type`/`: <...>` annotation on a splat param is enforced at the call (`#check_splat_param_type_contract`), unlike a plain param annotation — the wrong shape fails here with `Type_Contract_Violation`, instead of an `Undeclared_Identifier` deep in the body.

## Operator Overloading

See readme.md's "Operator Overloading" section for the language-level rules and examples.

- `scan_and_register_operator_overloads_before_parsing` (`parser.rb`) pre-scans and registers precedence before the main parse, since fixity and precedence affect how the rest of the file parses.
- Represented internally as `Code::Operator_Overload_Expr` (fixity, precedence, operator lexeme, `Func_Expr` body).
- Dispatch (`#find_operator_overload`, `interpreter.rb`) checks the left operand's own declarations first, then its `enclosing_scope`, then falls back to a lexically- or dynamically-scoped global operator, found by searching `stack.reverse_each` and deliberately excluding `Code::Type`/`Code::Instance` scopes.
- That exclusion prevents infinite recursion: a Type merely being on the call stack, because one of its methods is running, says nothing about whether the current operands belong to it. Without the exclusion, an overload that reuses its own operator symbol on unrelated operands (even plain `1 == 1`) would recurse forever.

## Ranges

See readme.md's "Ranges" section for the four operators and their examples. `RANGE_OPERATORS = %w(.. ..< >.. >..<)` (`constants.rb`); `#interp_range_infix` (`interpreter.rb`) handles them, dispatched from `#interp_infix`. `...` is not a range operator — it is reserved for variadic-param sugar.

- **Lexing.** `..` is a prefix of both `..<` and `...`; `>..` is a prefix of `>..<`. `#lex_operator` builds the operator char by char, and keeps going only while a longer range op could still match the next char. A `>`-guard keeps `Type<Struct>.member` from lexing `>.` as a bogus token.
- **Endless/beginless.** A range with no operand on one side is open-ended — `2..` (`expr.right` nil) or `..3` (`expr.left` nil). `#interp_range_infix` reads a nil side as a nil `::Range` endpoint. Iterating an endless one loops forever; slicing is fine.
- `Code::Range` is an ordinary Instance (`source/proxies/range.rb`, `source/programs/range.code`), not a `::Range` subclass — it wraps the real `::Range` in `.range`. `.to_s` renders `1..5` / `1..<5`; it cannot tell `>..` from `..`, since the start bump is already baked into `.range`.
- As a subscript, `#interp_subscript` unwraps the `Code::Range` to its `.range` before indexing; the sliced Array is re-linked through `#wrap_prog_array`.

## Built-in Types and Intrinsic Methods

See readme.md's per-type sections (Arrays, Dictionaries, Sets, Strings, Numbers, Dates & Times, File & Dir) for the language-level method lists and examples. The built-in types (String, Array, Set, Range, Dictionary, Number) have Ruby methods that delegate to Ruby's native implementations, declared with a `proxy_` prefix (see `source/shared/ruby_proxies.rb`). Each has a Ruby class in `source/proxies/` (or `scopes.rb` for the oldest ones) and a paired `.code` file declaring its surface.

**Wiring a Ruby-built instance's type identity.** A `Code::Instance` created in Ruby seeds `@types` from its Ruby class name, which fails every `===` / return-type check. Two shared helpers fix this, and are the only places instance `.types` gets set from a name:

- `#adopt_type(instance, type_name)` — `#link_instance_to_type` (sets `enclosing_scope` to `global[type_name]`), then `instance.types = enclosing_scope.types`. Used by `#finish_intrinsic_instance`, the `@ruby` proxy return, `#wrap_prog_array`/`#wrap_arguments_array`, and `#maybe_instance`'s nil branch.
- `#prefix_type(scope, name)` — puts `name` at the front of a scope's composed set, so `Ident <...>` and a named schema instance are `Ident`-shaped, not just `Struct`-shaped.

### Intrinsic Method Implementation Pattern

In `.code`:

```code
String {
    upcase (; @ruby )
    downcase (; @ruby )
}
```

In Ruby (`scopes.rb` or a `proxies/` file):

```ruby
class String < Instance
	extend Ruby_Proxies

	proxy_delegate 'value' # Delegate to @value
	proxy :upcase # Calls @value.upcase
	proxy :downcase # Calls @value.downcase
end
```

A custom Ruby handler covers a method that needs special logic:

```ruby
def proxy_concat other_array
	values.concat other_array.values # Extract Ruby array first
end
```

Some methods (`find`, `any?`, `all?`, and so on) run in `.code` with a `for` loop, instead of a Ruby proxy, because they need to call `.code` functions.

### Per-Type Ruby Notes

- **String** — `.N` positional dot-index (`"abc".0`) goes through `#interp_dot_string`, a narrower dispatch than Array/Tuple's — reusing that one would also pick up its `.each` shorthand, and Ruby's own String has no `#each`. Defined in `source/programs/string.code`, implemented in `scopes.rb`.
- **Array** — `concat` is destructive: a plain passthrough to Ruby's own `Array#concat`, unlike every other Array-combining method (`map`/`filter`/`flatten`/`reverse`/`sort`/`uniq`), which all return a new Array. Prefer `[a, b].flatten()` to combine two arrays without mutating either.
- **Set** — backed by a Ruby `::Set` in `Code::Set#@set` (`source/proxies/set.rb`, `source/programs/set.code`). `include?` and `@operator ==` are implemented in `.code`, not `@ruby`, since Ruby's own `Set#include?`/`#==` use `hash`/`eql?` identity and never see a custom element type's `@operator ==`. The `|`/`&`/`-`/`^` operators are handled by the Ruby backing directly — `#interp_logical_infix`/`#interp_arithmetic_infix` reach `Code::Set#|` and so on, without consulting an operand's own overloads. `Set_Like := Set | Array | Range` (`set.code`) is the polymorphic-param alias; `Code::Set#to_ruby_set` coerces any of the three.
- **Range** — see Ranges above.
- **Number** — see readme.md's "Numbers" section for the type table (`Integer`/`Float`/`Decimal`/`Number`, each one's Ruby class and literal) and the `Int`/`Flo`/`Dec` aliases. `#maybe_instance` picks the class off the already-evaluated Ruby value's class; bare `Integer`/`Float` inside `module Code` mean `Code::Integer`/`Code::Float` — use `::Integer`/`::Float` for the Ruby classes. `#find_ruby_class_for_type` picks the most-derived candidate (longest ancestor chain). `#inferred_type_name` collapses any numeric to `'Number'` when recording a type from a value, so `sum := 0` then `sum = 1.5` still works; `#type_name_to_string` still returns the leaf, used for `===`/display. `===` is exact type-set equality, so `4 === Integer` is true but `4 === Number` is false — use `4 =>= Number` for the is-a check.
- **Date/Time/Date_Time** — each wraps a Ruby stdlib value (`::Date`/`::Time`/`::DateTime`) through the shared `Temporal` mixin (`source/proxies/temporal.rb`). `Temporal#<=>` unwraps either side of a comparison. These are the types a `Date`/`Time`/`Date_Time` table column maps to; `Table#linked_temporal` (`table.rb`) links a value read back from such a column.
- **File/Dir** — `source/programs/file.code` declares `File | File_System {}`; the Ruby class is `Code::File_System` (`source/proxies/file.rb`), not `Code::File`, so bare `File` inside `module Code` stays Ruby's `::File`. Same trick for `Dir` (`Code::Directory`, `source/proxies/dir.rb`). `find_ruby_class_for_type` walks composed types to resolve either.

## Loop Control Flow

See readme.md's "For Loops", "For Loop Verbs", and "Loop Control" sections for the language-level rules and examples, including the stride-with-overlap form (`by <stride>,<overlap>`).

### Implementation Notes

- `it`/`at` come from a fresh `Scope` pushed per iteration.
- `for`'s stride path (`by N`) wraps each chunk as a real `Code::Array`, through `Code::Array.new(chunk)`, so `it` supports `==`/`.push`/etc, not just dot-index access.
- The overlap form (`by N,overlap`) computes `step = stride - overlap`, then builds windows with `(0...values_array.length).step(step).map { |i| values_array[i, stride] }`, keeping only full-size windows (`chunk.length == stride`). A trailing window that cannot reach the full `stride` is dropped, unlike the plain no-overlap chunking above, which keeps a final undersized chunk through Ruby's `each_slice`. `overlap` must be a smaller integer than `stride`. `Code::For_Loop_Expr#overlap` (`source/proxies/expressions.rb`) holds the parsed value; `interp_for_loop` (`interpreter.rb`) validates and applies it.
- `return value` creates a `Code::Return` object. A `for` loop detects one and propagates it up to the function; the function unwraps it and returns the inner value.
- Truthiness (`#truthy?`, `interpreter.rb`) is uniform across `if`/`unless`/`while`/`until`, and delegates to Ruby's own `!!value` rule — only `nil`/`false` are falsy.

## Code Style Preferences

### Ruby Code Style

- Indentation: use tabs (equal to 4 spaces).
- Class names: use `This_Case`, not `ThisCase`.
- Method definitions: omit parentheses — write `def something arg`, not `def something(arg)`.
- Method calls: omit parentheses where you can — write `foo.bar arg`, not `foo.bar(arg)`.
- Comments: add a comment only for code that is not obvious. Keep each comment to 1–2 sentences, on one `#` line that wraps naturally in the editor. Start a new `#` line only for a separate second point, never to wrap one long sentence across lines.

## Testing

Tests use Minitest and inherit from `Base_Test` (`tests/base_test.rb`):

- `tests/lexer_test.rb` — lexer tests.
- `tests/parser_test.rb` — parser tests.
- `tests/interpreter_test.rb` — interpreter tests.
- `tests/type_checker_test.rb` — static type checker tests.
- `tests/composition_test.rb` — class composition operator tests.
- `tests/pipeline_test.rb` — full lex → parse → interpret pipeline tests.
- `tests/error_test.rb` — runtime error tests.
- `tests/proxies_test.rb` — Ruby proxy method tests.
- `tests/regression_test.rb` — regression tests.
- `tests/server_test.rb` — server and routing tests.
- `tests/e2e_server_test.rb` — end-to-end server tests.
- `tests/database_test.rb` — database and ORM tests.

`Base_Test` provides a `refute_raises` helper, for asserting that a block raises no exception.

## Database and ORM

See readme.md's "Database" and "Record ORM" sections for the language-level API and examples. `source/programs/database.code` (which `@load`s `source/programs/table.code`) gives you `Database`/`Sqlite` and `Table`.

- `Sqlite(url)` builds an unconnected `Database`. `@connect` interprets its argument, links it to the `Database` type, and lazily builds and caches the Sequel connection on it (`#interp_intrinsic`'s `connect` case). A second `@connect` on the same `Database` returns the same cached connection. Connecting with no `url` raises `Code::Url_Not_Set_For_Database_Instance`.
- A schema is a named Struct — one member per column. The struct's `.name` decides the table name (through `Sequel::Inflections`, pluralize/underscore), so an anonymous schema struct raises `Code.assert` in every method that takes one.
- Column type names are matched by string in `Database#proxy_create_table` (`database.rb`): `Primary_Key` → auto-increment primary key; `String`/`Text` → text; `Int` → integer; `Number` → numeric; `Bool` → boolean (SQLite stores 0/1/NULL); `Date`/`Time`/`Date_Time` → the matching Ruby date/time column; `Flo`/`Float`/`Decimal`/`Blob`/`Binary` → mapped, but no language type backs these yet; an `Enum`-typed member → text.
- `Database#find_table` is a `proxy_overload` — `Code::Struct` routes to `#find_table_struct`, `::String` to `#find_table_named`. `#table_name_for` is the single place a table name is derived from a schema struct.
- A record is a `Code::Struct`, named after the schema, built by `Table#row_to_struct` → `Interpreter#build_struct` (`table.rb`). `find`/`update`/`delete` take a primary key; `find_by`/`where`/`create`/`update` take a Struct of `name := value` members. A filter/attrs Struct naming a column the schema does not have raises `Code::Table_Invalid_Filter_Column`, checked in `#check_filter_columns!` before the query runs.
- **Bool round-trip.** `#coerce_column_value` maps SQLite's 0/1/NULL back to a real `true`/`false`/`nil`.
- **Date/Time/Date_Time round-trip.** A value reads back as the matching wrapper instance, linked to its global type through `#linked_temporal`.
- Implementation: Sequel plus SQLite. `Database`/`Table` proxy methods: `source/proxies/database.rb`, `source/proxies/table.rb`. Tests: `tests/database_test.rb`, plus the temporal-column round-trip in `tests/temporal_test.rb`.

## Web Server Features

See readme.md's "Web Server", "Routes", and "Request & Response" sections for the language-level API and examples.

- **Route precedence.** `#match_route` (`interpreter.rb`) collects every route whose segment count and literal/`:param` segments match, then picks the one with the fewest `:param` segments — so a fully literal route always beats a `:param` route for the same path, whatever order they were declared in. `#min_by` keeps the first on a tie. This is what lets `source/programs/server.code`'s built-in `get://favicon.ico` (and the two `apple-touch-icon` routes) shield an app from a browser icon probe hitting `get://:id`.
- WEBrick implements the HTTP server, in `server_runner.rb`.

## HTML Rendering

See readme.md's "HTML Elements" section for the language-level API and examples. Load `source/programs/html.code` for the `Dom` type and predefined elements.

- A route returning a `Dom` instance auto-renders to an HTML string.
- HTML rendering only runs when `render(;)` is called by a Server instance.
- A fence block starting with `html\n` is treated as raw HTML tokens by the lexer.

## CSS (`source/programs/css.code`)

See readme.md's "CSS" section for the AST node structs and formatter/linter API. `@load 'source/programs/css.code'` also loads `source/programs/visitor.code`, for the shared `Warnings_Visitor` mixin.

- `Css_Formatter_Visitor#format`'s `nested_in_rule` flag decides whether `format_style_rule` synthesizes a `&` prefix on its own selectors. It is passed `true` only from `format_style_rule`'s own recursive call over `rule.rules` — real CSS nesting. Every other caller (`format_stylesheet`, `format_at_rule`, `format_scope_rule`) leaves it `false`, even though those also increment `depth` — `depth > 0` alone cannot tell "nested inside another selector" apart from "indented because an `@media`/`@scope` wraps it."
- `Css_Lint_Visitor | Warnings_Visitor`'s `lint(node)` resets `self.warnings`, then checks each `Property` for a duplicate name, a hardcoded vendor prefix, and a redundant zero-unit. Given a whole `Stylesheet`, it also runs `check_animation_transform_clash` — a state rule that sets `transform` while the base selector runs an `animation` whose keyframes also animate `transform` warns, since the running animation overrides the hover value every frame.

## Struct-Based HTML (`source/programs/html2.code`)

See readme.md's "Struct-Based HTML" section for the node shape and examples. This coexists with `html.code`'s `Dom` types — it only builds an HTML string, and does not hook into the server-side live-render pipeline (route responses, `onclick` wiring, `dom.js`). `@load 'source/programs/html2.code'` also loads `visitor.code` and `css.code`.

- `Html_Formatter_Visitor` appends an attached `css` as one more child, an embedded `<style>` block, using `[el.children, [css_child(el.css)]].flatten()` — not `.concat`, which would mutate `el.children` in place and duplicate the `<style>` tag on a second render.
- `Html_Lint_Visitor | Warnings_Visitor` checks for a void element given children, an `<img>` missing `alt`, an empty non-void container, and a duplicate attribute name — a real possibility now that `attributes` is an ordered Array, not a Dictionary.
- Element constructors are lowercase (`div`, `p`, `h1`, and so on) — a capitalized name before `(` would route to type-reference parsing instead of a function declaration.

## Shared Visitor Mixin (`source/programs/visitor.code`)

`Warnings_Visitor` (`warnings := []`, plus `warn(message)`) is composed into both `Css_Lint_Visitor` and `Html_Lint_Visitor`, so neither hand-rolls its own accumulator. Loaded automatically by both `css.code` and `html2.code`.

## File Loading

See readme.md's "@load" section for the language-level rules on bare `@load` vs. `some_lib := @load 'file'`, and their examples.

- `Interpreter@cached_expressions_by_filepath` caches parsed expressions by resolved path, to avoid duplicate parsing.
- `Scope#loaded_filepaths` (a `Hash`, keyed by resolved filepath) dedupes running a file into a given scope — a later `@load` of the same file into the same scope returns the stored result directly, instead of re-running the file.
- Comment lexemes are filtered out before parsing, matching `#run`'s own top-level behavior — otherwise a trailing comment at the end of a loaded file's body would become that body's return value.
- Bare `@load 'file'` merges the file's declarations into `stack.last`. `some_lib := @load 'file'` creates a fresh `Code::Scope` named after the left-hand identifier, and loads the file into that instead.

### Bare (Unquoted) Paths

`@load` also accepts a bare, unquoted path, when it starts with `./`, `../`, or `~/` — implemented entirely in the lexer (`load_path_pattern?`/`lex_load_path`/`preceded_by_at_load?`, `source/lexer.rb`), which emits an ordinary `:string`-typed lexeme, so the parser and interpreter need no changes.

- The leading marker is mandatory, so it does not collide with `@load some_var`. A bare `@load asdf/asdf` with no marker still parses as ordinary division.
- `preceded_by_at_load?` looks back at already-lexed tokens, since the decision depends on what precedes the marker.
- `~`/`.`/`..` resolution comes for free from the existing `::File.expand_path` call in `Declarator.resolve_load_filepath` / `Interpreter#load_file_into_scope`.
- "Current directory" means the process's working directory when `bin/prog` started — not the directory holding the `.code` file that wrote the `@load` line. This matches a shell's own relative-argument behavior.
- Only the literal two characters `~/` are recognized — `~otheruser/path` is not supported, and falls through to ordinary parsing (`~` as the difference-composition operator).
