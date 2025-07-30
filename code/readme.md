### What's here?

The [`ruby`](./ruby) folder contains the implementation of Emerald.

The [
`emerald`](./emerald) folder contains code written in Emerald. Depending on when you're reading this, there may be zero or several files in this directory. I plan to put all runtime declarations there.

### Running Your Own Programs With Ruby

To run an Emerald program, the source code must go through the [Lexer](./ruby/lexer.rb), whose output goes through the [Parser](./ruby/parser.rb), whose output goes through the [Interpreter](./ruby/interpreter.rb), resulting in final program output.

```ruby
require './code/ruby/lexer'
require './code/ruby/parser'
require './code/ruby/interpreter'

lexer   = Lexer.new 'Hello, World!'
lexemes = lexer.output # => array of Lexemes

parser      = Parser.new lexemes
expressions = parser.output # => array of Expressions

interpreter = Interpreter.new expressions
result      = interpreter.output # => Hello, World!
```

Another option is to use one of the [`#_lex*`, `#_parse*`,
`#_interp*`](./ruby/shared/helpers.rb) helpers, which saves you three lines if you only need the output.

```ruby
require './code/shared/helpers'

source      = 'Hello, Again!'
lexemes     = _lex source # => array of Lexemes
expressions = _parse source # => array of Expressions
result      = _interp source # => Hello, Again!

source_file = './my_program.em'
lexemes     = _lex_file source_file # => array of Lexemes
expressions = _parse_file source_file # => array of Expressions
result      = _interp_file source_file
```

Note that `#_parse*` uses Lexer to get its input, and
`#_interp*` uses both Lexer and Parser to get its input. Each of these helper methods call
`#output` and return the result.

### Running Your Own Programs By Command Line

This is the quickest way to run code.

```bash
rake interp[my_program.em]
rake interp_string["4 + 8"] # => 12
```
