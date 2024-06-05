obj Nice > Other imp SomeAPIComp
end

x = boo.foo
y := boo.hoo
z: int = boo.goo
nice = boo.bar.baz.raz.maz

boo = 42
x = 1
z: string
y = 2
z := 3

fun no_params_no_return
	(3 + 5) * 2 - (8 / 4) + 6 * (7 - 9)
end

fun no_params_no_return;
fun no_params_return -> int;
fun param_with_label(on day: string);
fun params_no_return(a: int, given c: string);
fun params_return(a: int, b: float) -> Base_Object;
fun whatever c: number, like d: string -> string;

fun power value: number, with exponent: number -> number
	value * value
end

fun do_something -> nil
end

obj TestParseProgram > Base_Object imp Nice
	id: int

	fun test_function -> any
	end
end
