### What is in this folder?

This folder holds the standard library. Each file is a `.code` file. Each file adds one or more built-in types, like `String`, `Array`, `Number`, or `Set`.

### Two kinds of file

Most files load on their own. The interpreter loads `global.code` at start-up, and `global.code` loads the rest of these files for you. You do not need an `@load` line for `String`, `Array`, `Number`, `Range`, `Set`, `Buffer`, `Dictionary`, `Struct`, `Enum`, `Bool`, `Context`, `File`, `Directory`, `Date`, `Time`, or `Date_Time`. Each one is ready to use.

A few files do not load on their own. You must add an `@load` line for these yourself, when you need them:

```code
@load 'lang/html.code'                # the Dom type and predefined HTML elements
@load 'lang/html2.code'               # a second, struct-based way to build HTML
@load 'lang/css.code'                 # a small CSS builder, formatter, and linter
@load 'lang/database.code'            # Sqlite and the Database type
@load 'lang/server.code'              # the Server type and HTTP routes
@load 'lang/protocols/http.code'      # an HTTP/1.1 parser: parse_request, response_text, and their Request and Response
@load 'lang/iterable.code'            # Iterable: compose it into a type to give it `next`
@load 'lang/raylib.code'              # 2D game and graphics support (needs the raylib-bindings gem)
```

A file like this costs nothing until you load it. This keeps a small program small, and a bigger program only as big as it needs to be.

### Some files back other files

A few files exist to support another file, and you rarely load them by name yourself:

- `table.code` supports `database.code` (a `Table` is what a `Database` query gives you back).
- `member.code` supports `struct.code` (it gives a struct's `<...>` value its `@.members` list).
- `visitor.code` supports `css.code` and `html2.code` (it holds a small mixin both of them share).
- `http_server.code` is the server loop. `@start_server` loads it into a scope of its own (unless `CODE_SERVER=webrick`).
- `tcp_server.code` and `tcp_socket.code` support `protocols/http.code`.

### Protocols

`protocols/` holds wire formats: the bytes that two programs send each other. `http.code` reads HTTP/1.1, and `live_page.code` reads a click that a live page sends as bytes (`decode_click`).

### Where to see these in use

The [`examples`](../examples) folder at the project root has a short, runnable `.code` file for almost every feature in this folder.
