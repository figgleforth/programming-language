**Goals**

1. [Be Turing complete](https://stackoverflow.com/a/7320)
2. Use as few reserved words as possible — `class`, `def`, `self`, etc
3. Support prefix, infix, postfix, and circumfix operators — `!1`, `2+3`, `4!`, `|5|`, respectively
4. Flexible custom operator system — `5 @#$ 6`, `7 by 8`, `11:22pm`, etc
5. Builtin web app functionality — like routing, controllers, and views

Source code in this language is processed by several Ruby programs that transform it into equivalent Ruby code, so it's more like a templating language.

**Table of Contents**

| Destination                               | What's here?                                                               |
|-------------------------------------------|----------------------------------------------------------------------------|
| [examples/](examples)                     | Code written in this language, with extension `*.em`                       |
| [source/](source)                         | The code that make the language work, in Ruby                              |
| [source/documenter/](source/documenter)   | `TODO`Generating documentation from code comments                          |
| [source/helpers/](source/helpers)         | Classes and functions that help get stuff done                             |
| [source/interpreter/](source/interpreter) | `WIP` Program that evaluates parsed expressions into final program output  |
| [source/lexer/](source/lexer)             | Program that turns source code into [tokens](./source/lexer/tokens.rb)     |
| [source/parser/](source/parser)           | Program that turns tokens into [expressions](./source/parser/exprs.rb)     |
| [source/repl/](source/repl)               | Program like Ruby's irb, or pry                                            |
| [readme.md](readme.md)                    | [You are here](./readme.md)                                                |
| [test.rb](test.rb)                        | Ruby file that runs `examples/` through the lexer, parser, and interpreter |
| [.gitignore](.gitignore)                  | Like sunscreen but for blocking files from your repository — Filescreen™   |
