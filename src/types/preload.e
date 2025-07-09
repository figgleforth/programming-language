Number {
	numerator =;
	denominator =;

	to_s {;
		'`numerator`'
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
