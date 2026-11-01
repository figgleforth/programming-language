### What is in this folder?

This folder holds what a web program needs: a server, routes, HTML, and CSS.

### Start with one line

Load one starter file. It gives you the server, one way to build HTML, CSS, and the database.

```
 starter_html2.code ──┬── server.code     the Server type, routes, Request, Response
                      ├── html2.code      one Element struct: div(), p(), h1()
                      │     └── css.code
                      └── ../database.code

 starter_html.code ───┬── server.code
                      ├── html.code       a Type for each tag: Div, P, H1
                      ├── css.code
                      └── ../database.code
```

The two starters differ only in how you build HTML. Pick one.

The two examples below make the same page: a count, and a button that makes it smaller. A click on the button runs its closure on the server. The difference is in how you build a piece of the page, and in what the server sends back after a click.

**`starter_html2`**: a piece of a page is a function that gives back an `Element`. After a click, the route runs again, and the server sends the whole page. `replacement_target_id` on the button tells the browser which element to take from that page, so only `#supplies` changes. Without it, the browser replaces the whole `<body>`.

```code
@load 'lang/web/starter_html2'

water := 40

box := Style_Rule(['#supplies'], [
	Property('padding', '1rem')
	Property('border', '1px solid tan')
])

supplies (;
	div([
		p("Water: `water`")
		button('Drink', onclick := (; water -= 1), replacement_target_id := 'supplies')
	], [Attribute('id', 'supplies')], box)
)

App + Server {
	get:// (;
		page := div([
			h1('Camp')
			supplies()
		])
		Html_Renderer.render(page)
	)
}

@start_server App(port := 8080)
```

**`starter_html`**: a piece of a page is a Type that renders itself, close to a React class component: `Supplies + Div {}` is the component, and `render(;)` gives what goes inside it. After a click, only that element renders again, on the server, and the browser replaces only that element. You do not name it, because the element that holds the button is the part that renders again.

```code
@load 'lang/web/starter_html'

water := 40

Supplies + Div {
	html_id     := 'supplies'
	css_padding := '1rem'
	css_border  := '1px solid tan'

	render (;
		[
			P("Water: `water`")
			Button('Drink', onclick := (; water -= 1))
		]
	)
}

heading := Style_Rule(['h1'], [Property('color', 'sienna')])

App + Server {
	get:// (;
		Div([
			Style(Css_Formatter_Visitor(minify := true).format(heading))
			H1('Camp')
			Supplies()
		])
	)
}

@start_server App(port := 8080)
```

The CSS goes to different places:

```
 starter_html2   box, a Style_Rule, is the div's css argument   ──▶ <div id="supplies">…<style>#supplies{padding:1rem;border:1px solid tan;}</style></div>
 starter_html    css_* members on the Type                      ──▶ <div id="supplies" style="padding:1rem;border:1px solid tan">…</div>
                 heading, a Style_Rule, in a Style element      ──▶ <style>h1{color:sienna;}</style>
```

In both, the CSS of `Supplies` is inside the element, so it stays after a click replaces the element.

What happens after one click:

```
                 the server renders            the server sends                       the browser replaces
 starter_html2   the whole page (the route)    <div><h1>Camp</h1><div id="supplies">…  #supplies, which the button names
 starter_html    only Supplies                 <div id="supplies">…                    #supplies, which the reply names
```

In both, the user sees the same change. The difference is how much work the server does, and who names the element: you (on the button), or the Type.

### Which one to choose

| | `starter_html2` | `starter_html` |
|---|---|---|
| A piece of a page is | a function that gives back data | a Type with its own `render(;)` |
| After a click, the server renders | the whole page | only the element that holds the button |
| Which element changes | the one you name with `replacement_target_id` | that element itself, by its `html_id` |
| You reuse a style by | a function that adds `Attribute`s and `css` | composing a Type: `Card + Div { css_padding := '1rem' }` |
| CSS goes | in a `<style>` block, from a `Style_Rule` that you give as `css` | in the `style` attribute, from `css_*` members; or in a `Style` element, from a `Style_Rule` that you format |
| Tools that read a page | `Html_Lint_Visitor`, `Html_Sanitizer_Visitor`, `Html_Stats_Visitor`, or a visitor of your own | none yet |
| A test checks | `Html_Renderer.render(page)`, a String | `.to_html()`, a String |

Choose **`starter_html2`** when:

1. You want a page to be plain data, which you can build with `map`, walk with a visitor, and check in a test.
2. You want to see each change in the code: the button says which element it replaces.
3. You want to write your own renderer later. Every element has the same shape, so one function can walk all of them.

Choose **`starter_html`** when:

1. You think in components, as in React: each piece of a page keeps its own HTML, and it renders again by itself.
2. A page has many parts that change on their own. Each part renders only itself, so a click does less work on the server.
3. You want to reuse a look by composing Types, and set the style and the attributes as members (`css_*`, `html_*`).

If you do not know yet, start with `starter_html2`. It is the newer one, and it has the tools that read a page.

### Every file

| File | What it gives you |
|---|---|
| `server.code` | The `Server` type, routes (`get://`, `post://`, ...), `Request` and `Response` |
| `html2.code` | `Element`, the lowercase constructors (`div`, `p`, `button`, ...), the formatters, a linter and a sanitizer |
| `html.code` | `Dom`, and one Type for each tag (`Div`, `P`, `Button`, ...) |
| `css.code` | CSS as structs (`Style_Rule`, `Property`, ...), a formatter and a linter |
| `http.code` | An HTTP/1.1 parser: `parse_request`, `response_text`, `keeps_alive?` |
| `http_server.code` | The server loop. `@start_server` loads it for you |
| `live_page.code` | The bytes that a live page sends for a click, and `decode_click` |
| `starter_html2.code`, `starter_html.code` | One line that loads the rest |

### Not in this folder

These files are in `lang/`, because programs that are not web programs use them too:

- `database.code`: `Sqlite`, `Database` and `Table`. Both starters load it.
- `tcp_server.code`, `tcp_socket.code`: TCP connections, under `http.code`.
- `visitor.code`: the mixin that `css.code` and `html2.code` share.

### Where to see these in use

`examples/web_servers.code`, `examples/html2.code`, `examples/html.code` and `examples/css.code`, at the project root.
