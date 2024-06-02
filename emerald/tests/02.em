obj Emerald > GemStone
imp Stone, Rock

(42)
id: int
age: int = 100
name := 'Emerald'
name = 'Emerald!'

obj A;
obj B;
obj C;

obj Stone > Rock imp GemStone
	imp SomethingElse
	imp OtherThing

	id = 1

	obj SpaceRock end

	def value >> float
		1_000
	end
end
