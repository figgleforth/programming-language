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
*A few samples of the syntax*

```
x = 1;

result = if x == 2 {
  'yes'
else
  'no'
}

%p result # prints 'no'

boo = 'does interpolation work yet? `result`'

while x < 5 {
  x = x + 1
elswhile x < 10 {
  x = x + 2
}

CONSTANT = 42
DHARMA {
  EXPERIMENT = 4815162342
}

numbers = DHARMA.EXPERIMENT

greet_method { -> 'hello' }
greet_with_args { name -> 'hello `name`' }
greeting { for name -> 'Mister `name`' } 

greeting(for: 'Eko') # 'Mister Eko'

Some_Class {
  nothing =;
  
  something = { x y z }
  
  inspect { ->
    "I am some class"
  }
}

some = Some_Class.new
some.something # { x: nil, y: nil, z: nil }
```

*See `tests/parser.rb` or `tests/interpreter.rb` for more.*
