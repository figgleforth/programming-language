nice = hoo.bar.baz
boo = 42
x = hoo.ha
x = 1
z: string
y = 2
z := 3

def no_params_no_return
	(3 + 5) * 2 - (8 / 4) + 6 * (7 - 9)
}
def no_params_no_return;
def no_params_return >> int;
def param_with_label(on day: string);
def params_no_return(a: int, b: float, given c: string);
def params_return(a: int, b: float) >> Base_Object;
def whatever c: number, like d: string >> string;

def no_params_return >> int;
def param_with_label(on day: string);
def params_no_return(a: int, b: float);
def params_return(a: int, b: float) >> Base_Object;
def whatever c: number, d: string >> string;

def square value: number >> number
	value * value
}

obj TestParseProgram > Base_Object imp Nice
	id: int
}
