### Motivations

- Some features and syntax that I like and think would be cool
- I want to type as little as possible, so no need for `class`/`var` prefixes because capitalization determines the
  construct
- As few reserved words as possible. I want to be able to use any name
- Integrated documentation where a documentation directory and pages are automatically created from specific comment
  syntax
- Web app focused, so server and MVC constructs as standard features
    - The ultimate goal is to create web apps without external libraries like how one might use Rails with Ruby

---

```bash
# requires ruby 3.2.2 or newer
$ ruby source/repl/repl_old.rb # WIP interactive repl
$ ruby tests/test.rb # parsing and interpreting tests
```

---
*A few samples of the syntax*

```
variable_without_value =;
with_value = 0.1
interpolation = 'version `with_value`'

CONSTANT = 48151
ENUM {
  CONSTANT = 62342
}

greet_method { 'hello' }
greet_with_args { name -> 'hello `name`' }

Some_Class {
  # same syntax for variables, constants, and methods
}
```

*See `tests/parsing.rb` or `tests/interpreting.rb` for more.*
