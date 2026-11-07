### What is in this folder?

This folder holds the standard library. Each file is a `.code` file. Each file adds one or more built-in types, like `String`, `Array`, `Number`, or `Set`.

### Two kinds of file

Most files load on their own. The interpreter loads `global.code` at start-up, and `global.code` loads the rest of these files for you. You do not need an `@load` line for `String`, `Array`, `Number`, `Range`, `Set`, `Buffer`, `Dictionary`, `Struct`, `Enum`, `Bool`, `Context`, `File`, `Directory`, `Date`, `Time`, or `Date_Time`. Each one is ready to use.

A few files do not load on their own. You must add an `@load` line for these yourself, when you need them:

```code
@load 'lang/web/starter_html2'  # everything for a web program: see web/readme.md
@load 'lang/database.code'      # Sqlite and the Database type
@load 'lang/password.code'      # hash_password and password_matches?, for a login
@load 'lang/iterable.code'      # Iterable: compose it into a type to give it `next`
@load 'lang/raylib.code'        # 2D game and graphics support (needs the raylib-bindings gem)
@load 'lang/raygui.code'        # buttons, sliders, panels and other controls; also loads raylib
@load 'lang/grid.code'          # Grid: width, height, and one float in each cell
@load 'lang/random.code'        # Random: a random number generator with its own seed
@load 'lang/shapes.code'        # Rect, Point and Color, which raylib and raygui both read
@load 'lang/math.code'          # vectors, Rectangle, and lerp
```

A file like this costs nothing until you load it. This keeps a small program small, and a bigger program only as big as it needs to be.

### Some files back other files

A few files exist to support another file, and you rarely load them by name yourself:

- `table.code` supports `database.code` (a `Table` is what a `Database` query gives you back).
- `member.code` supports `struct.code` (it gives a struct's `<...>` value its `@.members` list).
- `visitor.code` supports `web/css.code` and `web/html2.code` (it holds a small mixin both of them share).
- `tcp_server.code` and `tcp_socket.code` support `web/http.code`. Other servers, such as a chat or a game server, can use them too, so they stay out of `web/`.

### The web folder

[`web/`](web/readme.md) holds what a web program needs: the server, routes, HTML, and CSS. Its readme tells you which starter file to load.

### Where to see these in use

The [`examples`](../examples) folder at the project root has a short, runnable `.code` file for almost every feature in this folder.
