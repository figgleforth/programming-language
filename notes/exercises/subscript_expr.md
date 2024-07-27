Subscript_Expr :left, :index_expression
left[index_expression]

```
Binary_Expr 
	operator: .
	left: Binary_Expr 
		operator: .
		left: Identifier_Expr(string: a)
		right: Identifier_Expr(string: b)
	right: Subscript_Expr 
		left: Identifier_Expr(string: c)
		index_expression: Identifier_Expr(string: d)


	right: Binary_Expr
		operator: []
		left: Binary_Expr 
			operator: .
			left: Binary_Expr 
				operator: .
				left: Identifier_Expr(string: a)
				right: Identifier_Expr(string: b)
			right: Identifier_Expr(string: c)
		right: d

Binary_Expr:
  left:
    Binary_Expr:
      left:
        Binary_Expr:
          left:
            Identifier_Expr:
              string: "a"
              is_keyword: false
          operator: "."
          right:
            Identifier_Expr:
              string: "b"
              is_keyword: false
      operator: "."
      right:
        Identifier_Expr:
          string: "c"
          is_keyword: false
  operator: "["
  right:
    Identifier_Expr:
      string: "d"
      is_keyword: false
```

1. left = evaluate x.left 	# a.b
2. evaluate left 		    # whatever .b is
3. 
