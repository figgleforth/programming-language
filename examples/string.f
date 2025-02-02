String { `class names capitalized
	& Comparable `composition over inheritance

	data `instance variables lowercase, evaluates to nil unless specified

	new { string; `constructor
		./data = string `./ is like self.data in Ruby
	}

	operator / { right; `right operand
		`./ is the left operand
	} `last expression is the return value

	operator / { left; `left operand
		`./ is the right operand
	}
}

```
function syntax is {;}
the semicolon is required to differentiate from hashes/dictionaries

square { in; in * in }
square(4)

square_later = square
square_later(7)

square_even_later = { in; in * in }
square_even_later(9)

```
