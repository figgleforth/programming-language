x = boo.foo
y := boo.hoo
z: int = boo.goo
nice = boo.bar.baz

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
fun params_no_return(a: int, b: float, given c: string);
fun params_return(a: int, b: float) -> Base_Object;
fun whatever c: number, like d: string -> string;

fun no_params_return -> int;
fun param_with_label(on day: string);
fun params_no_return(a: int, b: float);
fun params_return(a: int, b: float) -> Base_Object;
fun whatever c: number, d: string -> string;

fun square value: number -> number
	value * value
end

fun do_something -> nil
end

obj TestParseProgram > Base_Object imp Nice
	id: int
end
