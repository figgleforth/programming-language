obj Posts_Controller inc Controller

obj TestsFour > CoreBase_Object
	inc Equality
	inc Accumulation

	id: int

	complex := 3 + -5 * -2 - 8 / 4 + -6 * 7 - -9

	fun invoke -> CoreProgram {
		(x = 1)
		(y = 2)
	}

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
	inc Transform, Pimp, Butterfly
	inc Yea, What
	inc Yolo

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


obj Base_Object

	# instance equality
	fun == other: Base_Object -> bool
		@.id == other.@.id
	end

	fun != other: Base_Object -> bool
		not self == other
	end

	# type equality
	fun === other: Base_Object -> bool
		@.type == other.@.type
	end

	fun !== other: Base_Object -> bool
		not self === other
	end

	fun >== other: Base_Object -> bool
		@.ancestors.include? other
	end

	# eg: 'Base_Object(0x00000001049eec38)
	fun inspect -> string
		"`@.type`(`@.id.to_hash`)"
	end
end

obj Context
	id: int
	type: string
	type_raw: any
#	args: []
#	scopes: [Scope]
end

obj Database
	host: string
	name: string
	username: string
	password: string
end

obj Server
	port: int = 5000
	database: Database
end

obj Controller
	server: Server
end
