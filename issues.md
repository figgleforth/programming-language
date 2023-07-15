Inline if-else does not parse properly
```ruby
blank_func(input_param: float) -> int
  testing: bool = false
  something if whatever
  return 1
end
```

Results in an unknown token for `something`
```
identifier
    blank_func

identifier
    input_param

type
    float

pre_return_type
    ->

type
    int

identifier
    testing

type
    bool

operator
    =

boolean_literal
    false

unknown
    something

key_word
    if

unknown
    whatever

key_word
    return

literal
    1

block_operator
    end
```

