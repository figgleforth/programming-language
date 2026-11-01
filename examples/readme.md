### What is in this folder?

These are runnable files, showcasing the language. Some written and documented by Claude, others by me.

## Browser events and a login

`live/events_and_login.code` is one live page with a login at the top (a form with `onsubmit`, a signed cookie, and `hash_password`), a search box that filters as you type (`oninput`), and a log of `onchange`, `onkeydown`, `onkeyup`, `onfocus` and `onblur`. Run it with `CODE_SECRET=something bin/program examples/live/events_and_login.code`, then open http://localhost:8080.

## The tasks app, three ways

The same tasks app has been written in three ways. See `tasks/`:

- `tasks-components.code`: Dom types from `lang/web/html.code`, each with its own state and `render(;)`, as in React's component model. A click renders its element again.
- `tasks-page-reload.code`: html2 structs, forms and redirects, with no JavaScript. Each click loads a new page.
- `tasks-live-reload.code`: html2 structs, plain functions and closures, live. A click updates the page without a reload.
