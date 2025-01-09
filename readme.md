Source code in this language is processed by a few Ruby programs that transform it into equivalent Ruby code, so it's more like a templating language.

**Goals**

1. Use as few reserved words as possible — `class`, `def`, `self`, etc
2. Support prefix, infix, postfix, and circumfix operators — `!1`, `2+3`, `4!`, `|5|`, respectively
3. Flexible custom operator system — `5 @#$ 6`, `7 by 8`, `11:22pm`, etc
4. Builtin web app functionality — routing, controllers, models, and views
5. [Be Turing complete](https://stackoverflow.com/a/7320)

**Table of Contents**

| Destination                               | What's here?                                                                     |
|-------------------------------------------|----------------------------------------------------------------------------------|
| [examples/](examples)                     | `/source` rewritten in this language (extension `*.em`)                          |
| [source/](source)                         | The code that make the language work, in Ruby                                    |
| [source/documenter/](source/documenter)   | Generating documentation from code comments                                      |
| [source/helpers/](source/helpers)         | Classes and functions that help get stuff done                                   |
| [source/interpreter/](source/interpreter) | Program that evaluates parsed expressions into final program output              |
| [source/lexer/](source/lexer)             | Program that turns source code into [tokens](./source/lexer/tokens.rb)           |
| [source/parser/](source/parser)           | Program that turns tokens into [expressions](./source/parser/exprs.rb)           |
| [source/repl/](source/repl)               | Program like Ruby's irb, or pry                                                  |
| [readme.md](readme.md)                    | [You are here](./readme.md)                                                      |
| [test.rb](test.rb)                        | Ruby file that runs `examples/` through the lexer, parser, and interpreter       |
| [.gitignore](.gitignore)                  | Like sunscreen but for blocking files from your repository — Filescreen™         |
