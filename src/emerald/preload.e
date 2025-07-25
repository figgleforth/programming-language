Number {
	numerator;
	denominator;

	to_s {;
		'the number is |numerator|!'
	}

	negate {;
		-numerator
	}
}

Num = Number
Int = Integer | Number {}
Flt = Float   | Number {}

String {
	value;
	length {;}
}

Str = String

Func = Function {
	name;
	expressions;
	param_decls;
	signature {;}
}

assert { condition;
	condition == true
}

`These won't crash.
assert(true)
assert(Num == Number)
assert(String != Number)

`Uncomment to crash.
`assert(false) or assert(true)
