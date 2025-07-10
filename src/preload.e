Number {
	numerator =;
	denominator =;

	to_s {;
		'`numerator`'
	}

	negate {;
		`(numerator / denominator) `I need a literal for a fraction.
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

`assert(false) `If you uncomment this, it'll crash every interpreter test, neat.
