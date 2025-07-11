Number {
	numerator =;
	denominator =;

	to_s {;
		'the number is |numerator|!'
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

`These should never raise.
assert(true)
assert(Num == Number)
assert(String != Number)

`Uncomment one of these to crash all interpreter tests.
`assert() or assert(false)
