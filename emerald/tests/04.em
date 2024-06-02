def no_params_no_return end
def no_params_return: int end
def param_with_label(on day: string) end
def params_no_return(a: int, b: float) end
def params_return(a: int, b: float) >> Basic_Object end
def whatever c: number, d: string >> string end

def no_params_no_return;
def no_params_return: int;
def param_with_label(on day: string);
def params_no_return(a: int, b: float);
def params_return(a: int, b: float) >> Basic_Object;
def whatever c: number, d: string >> string;

def square value: number >> number
	value * value
end
