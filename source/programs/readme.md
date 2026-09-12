### What is in this folder?

This folder holds the standard library. Each file is a `.code` file. Each file adds one or more built-in types, like `String`, `Array`, `Number`, or `Set`.

### Two kinds of file

Most files load on their own. The interpreter loads `global.code` at start-up, and `global.code` loads the rest of these files for you. You do not need an `@load` line for `String`, `Array`, `Number`, `Range`, `Set`, `Dictionary`, `Struct`, `Enum`, `Tuple`, `Bool`, `Context`, `File`, `Directory`, `Date`, `Time`, or `Date_Time`. Each one is ready to use.

A few files do not load on their own. You must add an `@load` line for these yourself, when you need them:

```code
@load 'programs/html.code'      # the Dom type and predefined HTML elements
@load 'programs/html2.code'     # a second, struct-based way to build HTML
@load 'programs/css.code'       # a small CSS builder, formatter, and linter
@load 'programs/database.code'  # Sqlite and the Database type
@load 'programs/server.code'    # the Server type and HTTP routes
@load 'programs/raylib.code'    # 2D game and graphics support (needs the raylib-bindings gem)
```

A file like this costs nothing until you load it. This keeps a small program small, and a bigger program only as big as it needs to be.

### Some files back other files

A few files exist to support another file, and you rarely load them by name yourself:

- `table.code` supports `database.code` (a `Table` is what a `Database` query gives you back).
- `member.code` supports `struct.code` (it gives a struct's `<...>` value its `@.members` list).
- `visitor.code` supports `css.code` and `html2.code` (it holds a small mixin both of them share).

### Why the `@load` line starts with `programs/`

The project root has a shortcut, named `programs`, that points straight at this folder. So the line `@load 'programs/css.code'` works the same way from any `.code` file you run from the project root, including a file in this folder itself.

### Where to see these in use

The [`guides`](../../guides) folder at the project root has a short, runnable `.code` file for almost every feature in this folder.
