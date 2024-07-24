Rules for scopes:
- Every program starts with a `global` scope
- Named functions push a `block` scope onto the stack at evaluation
- Anon functions push a `block` scope onto the stack at evaluation
- Anon functions declared in a variable push a `block` scope onto the stack at evaluation
- Instances push a `local` scope onto the stack at evaluation
- All `block` scopes can see `global` scope, and up the scope stack to the nearest `local` scope
---
Every scope has this format
```ruby
{
  '@': {
    id:   0,
    kind: :global # local (inside an instance), block (any function, named, stored, or anon)
  },
  # any additional keys are members on this scope, like vars, funcs, constants, and classes
}
```
An example scope
```em
Dog {
	name = 'Doggy'
	bark { -> 'woof' }
}
floof = Dog.new
floof.name = 'Cooper'

Emerald {
	version { -> 0.0 } 
}
```
```ruby
{
  '@':     {
    id:   0,
    kind: :global
  },

  Dog:     Class_Expr,

  floof:   {
    '@':  { id: 1, kind: :local },
    name: 'Cooper'
  },

  Emerald: Class_Expr
}
```
---
Say we want to evaluate `floof = Dog.new`. The `Class_Expr` stored in `Dog` tells the interpreter what declarations to
put into the `local` scope created for the instance. So #evaluate Class_Expr(Dog) produces
```ruby
{
  '@':  { id: 1, kind: :local },
  name: 'Cooper',
  bark: Block_Expr
}
```
which gets declared as the `floof` variable in the enclosing scope
```ruby
{
  # the enclosing scope
  floof: {
    '@':  { id: 1, kind: :local },
    name: 'Cooper',
    bark: Block_Expr
  }
}
```
Just like `Class_Expr`, when `floof.bark` is evaluated, the stored `Block_Expr` tells the interpreter what to put into
its `block` scope. So the #bark func would produce this scope
```ruby
{
  '@': { id: 2, kind: :block },
}
```
Had the #bark function any declarations, like
```em
bark { times ->
	woof = 'w' + ('o' * times) + 'f'  
}
```
The scope created when evaluating `floof.bark(3)` would produce
```ruby
{
  '@':   { id: 2, kind: :block },
  times: 3,
  woof:  'wooof'
}
```
And finally, an anon block `{ -> }` would produce
```ruby
{
  '@': { id: 4, kind: :block },
}
```
Whenever a block exits, the scope pushed for it is popped, effectively being destroyed.

---
So a quick exercise with comments at each scope, to get a clearer picture on how this works
```em
NAME = 'Cooper'

Dog {
	# this class can access NAME from global
	name = NAME;
	
	bark { at ->
		# this function can access global, and anything in Dog
		bark_style { ->
			# this function can access global, and anything in bark, and anything in Dog
			'woof'
		}
		'`at`, `bark_style()`'
	}
	
	play {
		# this function can access global, and anything in Dog
		fetch { -> # this function can access global, and anything in play, and anything in Dog
		}
		
		{ -> # this anon block can access global, and play, and Dog
			fetch()
		}
		
		{ -> # this anon block can access global, and play, and Dog
			{ -> # this anon block can access global, and the previous anon block, and play, and Dog
				fetch()
				bark()
			}
		}
		
		anon_block = { ->
			fetch()
			bark()
		}
		
		anon_block() # at evaluation, a scope gets pushed on top of the function scope, so this block has access to fetch() and bark()
	}
}
```
