obj Tests::Four > Core::Base_Object
	imp Equality
	imp Accumulation

	complex := 3 + -5 * -2 - 8 / 4 + -6 * 7 - -9

	fun invoke -> Core::Program;

	fun devoke -> nil
		x: int
		abc = (3 + -5) * -2 - (8 / 4) + -6 * (7 - -9)
		2 + 1
		4 + -1 * 2
		abc = true && true
		true && false
		false && false
		-1
		boo.hoo.try(3 + 4, like: 5, again: abc)
	end
end

obj Blah > Base_Object
	imp Transform, Pimp, Butterfly
	imp Yea, What
	imp Yolo

	obj Inside;

	yo = 1, ho = 2, boo = 3 + 4

	obj Inner
	end

	obj Whatever
		obj Cool;


		obj Boo end
	end

	fun cool end
	fun cool2 ;
	fun cool3;
	fun cool4 end
	fun cool5 end

	fun cool6 >> int;
	fun cool7 -> string;
	fun cool8 >> float;

	fun cool9 >> int
		boo = 42 + 12;
		boo = obj Maybe;
	end

	fun cool11 x: int
	end

	fun cool12 x: int >> int
	end

	fun cool13 x: int, y: float >> any
	end

	fun cool14 like x: int >> int
	end

	fun cool15 x: int, like y: float >> any
	end

	fun cool16 x: int, like y: float >> any
		x = 2;
	end

end
