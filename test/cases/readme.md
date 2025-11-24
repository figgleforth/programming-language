# Air Test Cases

This directory contains literate test files for the Air programming language. Tests are written as Air code with special comment directives that specify expected outcomes.

## Test Directives

### `=> value`

Assert that the code returns the specified value.

```air
`=> 42
6 * 7

factorial(5)  `=> 120
```

### `error: ErrorType`

Assert that the code raises a specific error.

```air
undefined_var  `error: Undeclared_Identifier

`error: Cannot_Reassign_Constant
CONSTANT = 1
CONSTANT = 2
```

### `skip` or `skip: reason`

Skip this test, optionally with a reason.

```air
`skip: Not implemented yet
experimental_feature()
```

## Comment Placement

Directives can be placed in two ways:

**Above the code** (for multi-line tests):

```air
`=> 120
factorial { n;
    if n == 0 or n == 1
        1
    else
        n * factorial(n - 1)
    end
}
factorial(5)
```

**End of line** (for single-line tests):

```air
1 + 2  `=> 3
Island {}  `=> Air::Type
```

It is preferred for single-line code to use end-of-line comments, while larger blocks use above-the-code comments.

## Regular Comments

Lines starting with backtick that aren't directives are treated as regular comments and ignored:

```air
`This is a comment describing the test
`=> 7
1 + 2 * 3
```

## File Organization

- `arithmetic.air` - Numeric operations, ranges, comparisons
- `functions.air` - Function definitions, calls, scope
- `types.air` - Type declarations, composition, instances
- `errors.air` - Error cases and exceptions

## Running Tests

```bash
# Run all tests (including test/cases)
bundle exec rake test

# Run only test/cases
bundle exec ruby -Ilib:test test/case_test.rb
```

## Writing New Tests

1. Create or edit an `.air` file in `test/cases/`
2. Write Air code with directive comments
3. Run tests to verify

The test runner automatically discovers all `.air` files and generates test methods for each directive.
