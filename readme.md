Status: Not working

Source code in this language is processed by a few Ruby programs that transform it into equivalent Ruby code, so it's more like a templating language

**Goals**

1. Use as few reserved words as possible — `class`, `def`, `self`, etc
2. Support prefix, infix, postfix, and circumfix operators — `!1`, `2+3`, `4!`, `|5|`, respectively
3. Flexible custom operator system — `5 @#$ 6`, `7 by 8`, `11:22pm`, etc
4. Builtin web app functionality — server, controllers, models, and views
5. [Be Turing complete](https://stackoverflow.com/a/7320)

**Table of Contents**

| Destination                               | What's there?                                                                |
|-------------------------------------------|------------------------------------------------------------------------------|
| [examples/](examples)                     | various examples with extension `*.f`                                        |
| [source/](source)                         | `WIP` The code that make the language work, in Ruby                          |
| [source/interpreter/](source/interpreter) | `WIP` Program that evaluates parsed expressions into final program output    |
| [source/lexer/](source/lexer)             | `WIP` Program that turns source code into [tokens](./source/lexer/tokens.rb) |
| [source/parser/](source/parser)           | `WIP` Program that turns tokens into [expressions](./source/parser/exprs.rb) |
| [test.rb](test.rb)                        | "test" file that runs `/examples` through the lexer, parser, and interpreter |
