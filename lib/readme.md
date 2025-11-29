### What's here?

This [`lib`](/lib) folder contains the implementation of Air in Ruby. The codebase is organized into two main phases:

**Compile-time** (`lib/compiler/`) - Source code to AST

- [`lexeme.rb`](compiler/lexeme.rb) - Token representation
- [`expressions.rb`](compiler/expressions.rb) - AST node definitions
- [`lexer.rb`](compiler/lexer.rb) - Tokenizes source code into lexemes
- [`parser.rb`](compiler/parser.rb) - Parses lexemes into an AST

**Runtime** (`lib/runtime/`) - AST to Execution

- [`interpreter.rb`](runtime/interpreter.rb) - Executes the AST (currently in lib/, should move to runtime/)
- [`errors.rb`](runtime/errors.rb) - Runtime error definitions
- [`scope.rb`](runtime/scope.rb) - Scoping and variable management
- [`types.rb`](runtime/types.rb) - Runtime type definitions
- [`execution_context.rb`](runtime/execution_context.rb) - Execution state management
- [`helpers.rb`](runtime/helpers.rb) - Utility functions

**Orchestration**

- [`air.rb`](air.rb) - Main entry point, requires all components

**Miscellaneous**

- [`constants.rb`](constants.rb) - Language constants and operator definitions

---

### Running Your Own Programs With Ruby

To run an Air program, the source code must go through the [Lexer](compiler/lexer.rb), whose output goes through the [Parser](compiler/parser.rb), whose output goes through the [Interpreter](runtime/interpreter.rb), resulting in final program output.

```ruby
require './lib/air'

lexer   = Lexer.new 'Hello, World!'
lexemes = lexer.output # => array of Lexemes

parser      = Parser.new lexemes
expressions = parser.output # => array of Expressions

interpreter = Interpreter.new expressions
result      = interpreter.output # => Hello, World!
```

Another option is to use one of the [`#Air.lex*`, `Air.parse*`,
`Air.interp*`](runtime/helpers.rb) helpers, which saves you three lines if you only need the output.

```ruby
require './lib/air'

source      = 'Hello, Again!'
lexemes     = Air.lex source # => array of Lexemes
expressions = Air.pase source # => array of Expressions
result      = Air.interp source # => Hello, Again!

source_file = './my_program.air'
lexemes     = Air.lex_file source_file # => array of Lexemes
expressions = Air.pase_file source_file # => array of Expressions
result      = Air.interp_file source_file
```

### Running Your Own Programs By Command Line

This is the quickest way to run code.

```bash
rake interp_file["my_program.air"]
rake interp["4 + 8"] # => 12
```
