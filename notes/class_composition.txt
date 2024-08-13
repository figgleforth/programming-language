```
One {
	one = 1
}

Two {
	two = 2
}

Numbers {
	+ One
	+ Two
}
```
```
Stack[
  Global{
    One: Static{
      one: 1 
    }
  
    Two: Static{
      two: 2
    }
    
    Numbers: Static{
    	one: 1
    	two: 2
    }
  }
]
```
- Evaluating Numbers
  - push Static.Numbers scope so its body can be evaluated
- Encounter `+ One` to evaluate
- get One => not found in Static.Numbers but is in Global, so returns Static.One{one} from Global
- copy Static.One's declarations (except @) to curr_scope (which is Static.Numbers)
  - That's how `one: 1` ends up declared
---
What about `> One`?
```
Numbers {
	> One
}
```
- Evaluate Numbers
  - push Static.Numbers
- eval `> One`
  - get One => Static.One
- copy Static.One declarations
- @[types] << Static.One
---
What about `- One`?
```
Numbers {
	> One
	- One
}
```
- Evaluate Numbers
  - push Static.Numbers
- eval `> One`
  - get One => Static.One
- copy Static.One declarations
- @[types] << Static.One
- now I've decided I don't want any of the Static.One declarations
  - eval `- One`
    - gets Static.One so we can see the declarations
    - erase all of these declarations on curr_scope, which is Static.Numbers
- So you end up with Numbers having the One type but not the declarations. Is this useful? Idk, but this is a way you could enforce functions be declared manually  
