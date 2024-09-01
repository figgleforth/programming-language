**This language wants to**

1. [Be Turing complete](https://stackoverflow.com/a/7320)
2. Use as few reserved words as possible — `class`, `def`, `self`, etc
3. Support prefix, infix, postfix, and circumfix operators — `!1`, `2+3`, `4!`, `|5|`, respectively
4. Allow alphanumeric and symbolic identifiers to be operators — `5 @#$ 6`, `7 by 8`, `11:22pm`
5. Have builtin web app functionality — like routing, controllers, and views

But hey, not all languages are perfect, and neither is my cholesterol. Anyway, I hesitate to call this a real programming language because it's just a few Ruby programs that transform non-Ruby code into Ruby code, so it's more like a templating language. But tomato, tomato.

**Table of Contents**


| Destination           | What's here?                                                                                 |
|-----------------------|----------------------------------------------------------------------------------------------|
| `examples/`           | Code written in this language, with extension `*.em`                                         |
| `source/`             | The code that make the language work, in Ruby                                                |
| `source/cli/`         | Program for evaluating files in this language, from the command line                         |
| `source/documenter/`  | Nothing at the moment, but someday a program for generating documentation from code comments |
| `source/helpers/`     | Classes and functions that help get stuff done                                               |
| `source/lexer/`       | Program that turns source code into [tokens](./source/lexer/tokens.rb)                       |
| `source/parser/`      | Program that turns tokens into [expressions](./source/parser/exprs.rb)                       |
| `source/interpreter/` | Program that evaluates parsed expressions into final program output                          |
| `source/repl/`        | Program for evaluating source code in the command line, like Ruby's pry or irb               |
| `topics/`             | My notes on various related topics                                                           |
| `readme.md`           | [You are here](./readme.md)                                                                  |
| `test.rb`             | Ruby file that runs `examples/` through the lexer, parser, and interpreter                   |
| `.gitignore`          | Like sunscreen but for blocking files from your repository — Filescreen™                     |
