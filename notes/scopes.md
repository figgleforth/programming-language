Scopes should be literal hashes.
```
topic = 'scopes'
Lang {
  name = 'em'
}
scopes { -> }

GLOBAL_SCOPE = {
  topic = "scopes"
  Lang = Class_Expr
  scopes = Block_Expr
}
```
When I want to call a function, `#evaluate` will receive a `Block_Call_Expr` with a name of the block to call. Use the
name to get the stored Block_Expr and call `#evaluate` with it
```
# scopes() # => Block_Call_Expr(name = scopes)
name = block_call_expr.name # scopes
stored_block = get_from_scope name # returns Block_Expr
evaluate stored_block
```
This should create a scope, evaluate the Block, then pop the scope.

When I want to instantiate a class, `#eval` receives `Binary_Expr` where left is `Class_Expr`, operator is `.`, and
right is `new`.
```
# Lang.new # => Binary_Expr(Lang . new)
stored_class = get_from_scope bin_expr.left # => Class_Expr
evaluate stored_class

```
This will also work smoothly, because `#eval` already knows how to handle `Class_Expr` – which is to create a scope,
evaluate the class, and I think currently it pops the scope. But, I think it needs to return the scope because you need
to be able to store the to whatever variable. For example, `lang = Lang.new`, `Lang.new` will return a scope, and it
will get stored on `lang`. The resulting scope looks like:
```
topic = 'scopes'
Lang {
  name = 'em'
}
scopes { -> }
lang = Lang.new

GLOBAL_SCOPE = {
  topic = "scopes"
  Lang = Class_Expr
  scopes = Block_Expr
  lang = {
	name = "em"
  }
}
```
Say there's a function that changes the name of the lang instance, here's the scope with it.
```
Lang {
  name = 'em'
  update { ->
	name = "test"
  }
}

GLOBAL_SCOPE = {
  topic = "scopes"
  Lang = Class_Expr
  scopes = Block_Expr
  lang = {
	name = "em"
	update = Block_Expr
  }
}
```
Now if we call `lang.update`, I'm gonna detail the process again. It's already detailed above but I want to explain it
twice to make sure I understand. `#eval` is called with the update `Block_Call_Expr`. When `#eval` gets the block, it
uses its name to fetch the stored `Block_Expr` from the current scope. Then it sends that to `#eval`.
```
# lang.update() # => Block_Call_Expr(name = update)
name = block_call_expr.name # update
stored_block = get_from_scope name # returns Block_Expr
evaluate stored_block
```
At the `#eval` branch that handles `Block_Expr`, a scope is pushed, then any declarations from the block happen, and so
now, the thing I'm interested in figuring out is how the `#set_on_scope` will behave for the `name = "test"` expression.

So we pushed a scope, and now we're evaluating `name = "test"`, which is an `Assignment_Expr`. _Side note, this stupid
construct abstraction. I wonder if there even is a need for that?_

Anyway, evaluating `name = "test"`, which means we will set `name` on the current scope with the value "test". But this
is where assignment breaks in the current implementation. It never overwrites the original value, it instead creates a
new `name` on the current scope, which takes hides the original `name`.

So What's the proper way to handle this part? Let's think about that tomorrow

Final thoughts before bed. At every `Assignment_Expr`, we should first look up if the thing being assigned already
exists in any of the scopes. If it's found, we also need to get the index of the scope it is in. That way, we can so
something like `scopes[index_of_existing_member].declarations[existing_member] = evaluate assignment_expr.expression`.
Something along those lines. I should probably also check if not found then to declare it.
