obj String > Basic_Object

def - other
	# remove instances of other from self. eg: 'hello world' - 'o' yields 'hell wrld'
}

def / other
	# split self into an array of substrings, using other as the delimiter. eg: 'hello world' / ' ' yields ['hello', 'world']
}

def * other
	# repeat self other times. eg: 'hello' * 3 yields 'hellohellohello'
}

def [] other
	# return the index of the first occurrence of other in self. eg: 'hello world' % 'o' yields 4. eg: 'hello world' % 'z' yields nil. eg: 'hello world' % 'ello' yields 1
}
