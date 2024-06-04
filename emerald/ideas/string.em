obj string

# remove instances of other from self. eg: 'hello world' - 'o' => 'hell wrld'
def - other: string;

# concatenate two strings. eg: 'hello' + 'world' => 'helloworld'
def + other: string;

# split self into an array of substrings, using other as the delimiter. eg: 'hello world' / ' ' => ['hello', 'world']
def / other: string;

# repeat self `other` times. eg: 'hello' * 3 => 'hellohellohello'
def * other: int;

# return the index of the first occurrence of other in self. eg: 'hello world'['o'] => 4. eg: 'hello world'['z'] => nil. eg: 'hello world'['ello'] => 1
def [] other: string;
