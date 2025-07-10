Number {
	numerator =;
	denominator =;

	to_s {;
		'`numerator`'
	}

	negate {;
		-numerator
	}
}

Num := Number
Int := Integer | Number {}
Flt := Float   | Number {}

String {
	value =;
	length {;}
}

Str := String

Func := Function {
	name =;
	expressions =;
	param_decls =;
	signature {;}
}

assert { condition = false;
	condition == true
}

assert(true)
assert(Num == Number)
assert(String != Number)

`Uncomment one of these to crash all interpreter tests!
`assert()
`assert(false)
