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
$ ruby source/repl/repl.rb # WIP interactive repl
$ ruby tests/test.rb # parsing and interpreting tests
```

---
A few samples of the syntax from `tests/cli.em`.

```
# ruby source/cli/cli.rb tests/cli.em

x = 1;

result = if x == 2 {
    'yes'
else
    'no'
}

boo = 'does interpolation work yet? `result`'
@@ boo

@@ 'x before while loop ' + x
while x < 5 {
    x = x + 1
elswhile x < 10 {
    x = x + 2
    @@ "This won't print!"
}
@@ 'x after ' + x

CONSTANT = 42

get_constant { multiplier = 1 ->
    CONSTANT * multiplier
}

@@ get_constant + '!'
@@ get_constant(2)

greet_with_arg { name -> 'hello `name`' }
greet_with_label { for name -> 'Mister `name`' }

@@ greet_with_arg('Eko')
@@ greet_with_label(for: 'Eko')

Some_Class {
    nothing =;
    something = { x y z }

    inspect { ->
        "I am some class"
    }
}

some = Some_Class.new
@@ some.something # { x: nil, y: nil, z: nil }
@@ some.inspect
```

*See `tests/parser.rb` or `tests/interpreter.rb` for more of the syntax.*
