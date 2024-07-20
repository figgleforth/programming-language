x = 1;

result = if x == 2 {
  'yes'
else
  'no'
}

boo = 'does interpolation work yet? `result`'
@p boo
@p 'Apparently ' + result

@p 'x before while loop ' + x
while x < 5 {
  x = x + 1
elswhile x < 10 {
  x = x + 2
  @p "This won't print!"
}
@p 'x after ' + x

CONSTANT = 42

get_constant { multiplier = 1 ->
	CONSTANT * multiplier
}

@p get_constant + '!'
@p get_constant(2)

greet_with_arg { name -> 'hello `name`' }
greet_with_label { for name -> 'Mister `name`' }

@p greet_with_arg('Eko')
@p greet_with_label(for: 'Eko')

Some_Class {
  nothing =;

  something = { x y z }

  inspect { ->
    "I am some class"
  }
}

some = Some_Class.new
@p some.something # { x: nil, y: nil, z: nil }
@p some.inspect
