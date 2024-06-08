# declarations without value
name: string
pretty: (Date_Time) -> string

# declarations with value
name := 'Coopie'
one := 1.0
two: int = 2

# functions
today := fun # implied return type
end

pretty: string = fun date: Date_Time
end

# objects
Time := obj
	inc Time_Zone
end

Date_Time := obj > Time
	inc Numbers
end

# reassignments
one = 2.0
two = 3
