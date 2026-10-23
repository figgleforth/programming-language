### What is in this folder?

These are runnable files, showcasing the language. Some written and documented by Claude, others by me.

## The tasks app, three ways

The same tasks app has been written in three ways. See `tasks/`:

- `tasks-components.code`: Dom types from `lang/html.code`, each with its own state and `render(;)`, as in React's component model. A click renders its element again.
- `tasks-page-reload.code`: html2 structs, forms and redirects, with no JavaScript. Each click loads a new page.
- `tasks-live-reload.code`: html2 structs, plain functions and closures, live. A click updates the page without a reload.
