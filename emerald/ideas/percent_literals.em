# percent literals
%S(abe boo cool) # [:ABE,  :BOO,  :COOL]
%s(abe boo cool) # [:abe,  :boo,  :cool]

%V(abe boo cool) # ['ABE', 'BOO', 'COOL']
%v(abe boo cool) # ['abe', 'boo', 'cool']

%W(abe boo cool) # ["ABE", "BOO", "COOL"]
%w(abe boo cool) # ["abe", "boo", "cool"]

%ds(abe boo cool) # {abe: nil, boo: nil, cool: nil}
%dW(abe boo cool) # {"ABE": nil, "BOO": nil, "COOL": nil}
%dv(abe boo cool) # {'abe': nil, 'boo': nil, 'cool': nil}
