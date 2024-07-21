Boo {
    scary = 1234
}

moo { boo ->
	boo.scary
}
@@ moo(Boo.new) == 1234

moo_with_comp { &boo_param ->
    scary * 2
}
@@ moo_with_comp(Boo.new) == 2468

x = 1;

result = if x == 2 {
  'yes'
else
  'no'
}

boo = 'does interpolation work yet? `result`'
@@ boo + ' .. apparently not'

@@ 'x before while loop ' + x
while x < 5 {
  x = x + 1
  @@ 'x became ' + x
elswhile x < 10 {
  x = x + 2
  @@ "This won't print!"
}
@@ 'x after while loop ' + x

CONSTANT = 42

get_constant { multiplier = 1.6 ->
	multiplier ** multiplier * CONSTANT
}

@@ 1.6 ** 1.6 * 42
@@ 'constant: ' + get_constant
@@ get_constant(2)

greet_with_arg { name -> 'hello `name`' }
greet_with_label { for name -> 'Mister `name`' }

@@ greet_with_arg('Eko')
@@ greet_with_label(for: 'Eko')

Some_Class {
  nothing =;

  something = { x y z }

  inspect { ->
    "I am some class"
  }
}

some = Some_Class.new
@@ some.something # { x: nil, y: nil, z: nil }
@@ some.inspect
