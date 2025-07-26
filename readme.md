## Emerald

A for-fun programming language with mechanics I like.
- Fancy while loops
- Dot-slash scope lookups
- Dot-access _n_-dimensional array elements
- Multiple ways of creating dictionaries
- Intuitive type composition
- First-class functions that can be passed around
- Built-in support for arrays, tuples, dictionaries, and ranges
- Naming conventions enforced at the language level
  - Capitalized for types
  - lowercase for variables and functions
  - UPPERCASE for constants
---
- [Code Examples](#code-examples)
- [Documentation](#documentation)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Running Tests](#running-tests)
  - [Running Your Own Programs](#running-your-own-programs)
- [Todos](./docs/todo.txt)
- [License](#license)
---

## Code Examples

### FizzBuzz
```
fizz_buzz { n;
  if n % 3 == 0 and n % 5 == 0
    'FizzBuzz'
  elif n % 3 == 0
    'Fizz'
  elif n % 5 == 0
    'Buzz'
  else
    '|n|'
  end
}

result = []
1..15.each {;
  result << fizz_buzz(it)
}
result `Gives you ['1', '2', 'Fizz', '4', 'Buzz', 'Fizz', '7', '8', 'Fizz', 'Buzz', '11', 'Fizz', '13', '14', 'FizzBuzz']
result.0  `"1"
result.2  `"Fizz"
result.14 `"FizzBuzz"
```
### Factorial
```
factorial { n;
  if n == 0 or n == 1
    1
  else
    n * factorial(n - 1)
  end
}

factorial(8) `40320
```
### Fibonacci
```
fib { n;
  if n <= 1
    n
  else
    fib(n - 1) + fib(n - 2)
  end
}

[fib(0), fib(1), fib(2), fib(3), fib(4), fib(5)] `[0, 1, 1, 2, 3, 5]
```
## Documentation

For comprehensive syntax examples and language features, see these test files:
- [Lexer Tests](./tests/lexer_test.rb) - Tokenization
- [Parser Tests](./tests/parser_test.rb) - Syntax parsing
- [Interpreter Tests](./tests/interpreter_test.rb) - Language semantics and execution
- [Example Tests](./tests/examples_test.rb) - Small example programs
## Getting Started

### Prerequisites
- Ruby 3.4.1 or higher
- Bundler
```shell script
$ git clone https://github.com/figgleforth/emerald.git
$ cd emerald
$ bundle install
```
### Running Tests
```shell script
$ bundle exec rake test
```
### Running Your Own Programs
```shell script
$ bundle exec rake interp[./your_source.e]
```
## License

This project is licensed under the MIT License, see the [license.md](./license.md) file for details.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)]()
