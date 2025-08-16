### `/intrinsics`

Builtin functions whose implementations are written in Ruby, and declarations written in Air. See [Intrinsic functions](https://en.wikipedia.org/wiki/Intrinsic_function) on Wikipedia.

For simplicity, each `air/intrinsics` declaration should have a corresponding implementation in
`lib/intrinsics`. For instance:

- [`air/intrinsics/assert.air`](/air/intrinsics/assert.air) is the declaration
- [`lib/intrinsics/assert.rb`](/lib/intrinsics/assert.rb) is the implementation
