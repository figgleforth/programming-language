1 + 1 == 2
1 - 1 == 0
1 * 2 == 2
4 / 2 == 2
10 % 3 == 1

1 + 2 * 3 == 7
(1 + 2) * 3 == 9
2 * 3 + 4 == 10
2 * (3 + 4) == 14

`raise "" unless 3 < 4 == true
4 > 3 == true
4 >= 4 == true
3 <= 4 == true
4 <= 3 == false

1 == 1 == true
1 != 2 == true



true && false == false
true || false == true
`!(true) == false ` fix because this doesn't work. it thinks ! is an identifier

5 & 3 == 1
5 | 3 == 7
5 ^ 3 == 6

(1 + 2) * (3 + 4) == 21
1 + 2 * 3 < 10 == true
4 * 8 < 10 == false
10 / (2 + 3) == 2

1 + 2 - 3 * 4 / 5 == 1
(1 + 2 - 3) * (4 / 5) == 0

1 + 2 < 3 * 4 == true
(1 + 2) < (3 * 4) == true

` this evaluates to true in Ruby, false here. Check the operator precedence
true || false && false == true

` these two evaluate to true in Ruby, false here
`5 & 3 | 2 == 3
`5 | 3 & 2 == 5

`(1 == 1) && (2 != 3) == true
`(1 == 1) || (2 == 3) == true
