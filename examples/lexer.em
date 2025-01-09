`The ./source/lexer/lexer.rb source code translated to em, as is.

Char {
	string =; `=; sets it equal to nil

	```
	an initializer just for assigning string seems like a waste precious time. Maybe there should be some syntax that allows me to set arbitrary args externally. For example:

	Char.new(string: "") or Char(string: "")

	Here the argument label `string` refers to the declared `string =;` variable.

	But this cannot be default for all variable declaration, it should be opt in per declaration so that you can construct variations of the class without needing an initializer for each. Maybe some kind of prefix? Like

	ini string =;
	%string =;
	```
	new { ->
		`./string = string `./ is the equivalent of self. or @
	}

	whitespace? { ->
		string == "\t" || string == "\s"
	}

	newline? { -> string == "\n" }

	carriage_return? { -> string == "\r" }

	colon? { -> string == ";" }

	comma? -> string == "," `I think oneliners should be able to omit {}

	`boolean ors can be use either `||` or `or`
	delimiter? { ->
		colon? or comma? or newline? or whitespace? or carriage_return?
	}

	`not sure yet how to handle regex
	numeric? { -> }
`	alpha? { str -> } ` bug args are broken
	alphanumeric? { -> }
	symbol? { -> }
	`/regex

	identifier? { -> alphanumeric? or string == '_' }

	reserved_identifier? { -> Token.RESERVED_IDENTIFIERS.include? string }

	reserved_operator? { -> Token.RESERVED_OPERATORS.include? string }

	legal_symbol? { -> Token.LEGAL_SYMBOLS.include? string }

	reserved? { -> Token.RESERVED_CHARS.include? string }

```
	operator infix == { other ->
		if other.is_a? String `I want a simpler #is_a? operator
			other == string
		else
			`other == self.class
		end `control statements use `end` instead of `}` because it is easier to see at a glance whether the closing token is closing a function/class or control statement
	}
```
	to_s { -> string.inspect }
}
