obj Overview > Base_Object imp SomeAPI, OhThisToo # the top level is object Overview. there are no classes in this language, only objects. Everything is an object. this extends `>` Base_Object`. it implements SomeAPI. `imp` can be used here in the obj declaration with subsequent ones separated by comma.

imp AnotherAPI # or as a separate statement.
imp OhThisToo # as many times as you want
imp OrMultiple, LikeHere # and combined statements
imp Binary_Operatable



def no_params_no_return; # end of statement delimiter ; after method declaration is identical to an empty body. preferred for empty method definitions

def no_params_no_return
	# do something
} # alternate end of statement delimiter `}`. preferred in the language design when a body is present

def no_params_no_return end # alternate end of statement delimiter `end`. least preferred. only there if you want this to look more like Ruby

def no_params_int_return :: int # ident after :: is the return type
	42 # implied last statement return
}

def greet(person name: string) # labels in params
	'Hello `name`!' # string intrepolation
}

greet(person: 'Locke')

greet person: 'Locke' # alternate without parens like Ruby

def params_no_return(a: int, given b: float, c: string); # mixed label and non-label, they can be in any order

def params_return(a: int, b: float) :: Base_Object; # no labels

def whatever c: number, like d: string :: string; # no parens!

puts "Magic number! `self.magic_number`" # accessible because the AnotherApi is implemented. really just means that this object inherits the variables and methods oh the api. api's in this language are pre-implemented so it is not like the implementer must implement some methods. `self` works like Ruby

api AnotherAPI
	def magic_number :: number # generic for int or float
		42
	}
}

api Binary_Operatable
	def + other;
	def - other;
	def * other;
	def / other;
	def % other;
	def ** other;
}

some_object: BaseObject
some_reference_var: AnotherAPI # could be any obj that implements this

obj Hatch > Shelter imp Security_System
	def open
		door.open!
	}
} # internal obj, a child statement of Overview object.






# no closing } necessary, as well as no indentation at the top level because the top level statements can be left unindented and will still be children of the object declared at the top level

# named tuple values
color3: (r: float, g: float, b: float, a: float) = (1.0, 1.0, 1.0, 1.0)
color4 := (w: 1.0, x: 1.0, y: 1.0, z: 1.0)

# access tuple values by index
color.0
color.1
color.2 # and so on
color3.r # .g, .b, etc but only when names are present in the tuple declaration
color4.w
