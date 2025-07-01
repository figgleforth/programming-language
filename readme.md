### A Programming Language
- **Homoiconic**: The code you write _is_ directly reflected in the structure in memory.
- **Designed for prototyping**: Quick to iterate and experiment with ideas.
- **Minimal reserved keywords**: Avoids unnecessary constraints on naming.
- **Supports composition and inheritance**: Promotes flexible modeling capabilities.
---

#### **Comments**
```plain text
`This is a comment
```
---

#### **Variable Declarations**
```plain text
name := "Cooper"      `Declaration with type inference
name = 'COOPER'
nothing =;            `Shorthand for assigning nil
```
#### **Constants & Enums**
```plain text
PI := 3.14159
GRAVITY := 9.8

MODES {
  DEV := 0 `Dictionary-like structure for constants
  PROD := 1
}
```
---

#### **Types**
```plain text
Vector2 {
  x := 0
  y := 0
}
```
---

#### **Composition**
```plain text
Thing {
  | Vector2 `brings in x and y declarations
  
  update { delta;
    y -= GRAVITY * delta
  }
}

Player | Thing {
  name: String
  
  __to_s: String {;
    "(Player id=`__id`)"    `String interpolation with backticks
  }
}
```
Example usage of these Types:
```plain text
p1 := Player()
p1.name = "Tom"

p2 := Player()
p2.name = "Jerry"

players := [p1, p2]
```
---

#### **Control Flow**

##### Loops
```plain text
players.each {;
  it   `current element
  at   `current index  
  skip `current element
  stop `iteration
}
```
##### Conditional Statements
```plain text
if players.count == 2
  `Lucky!
elif players.count == 1
  `One player lost
else
  `:(
end
```
This design emphasizes readability by explicitly terminating blocks.

---

### **Operator Support**
- Arithmetic: `+`, `-`, `*`, `/`, `%`
- Comparison: `==`, `!=`, `<`, `<=`, `>`, `>=`
- Logical: `and`, `or`, `not`
- Assignment & Compound operators: `+=`, `-=`, `*=`, `/=`, `%=`
  Examples:
```plain text
result := 3 * 5 + 2 / 1 `Follows precedence rules without parentheses
x += 10                 `Compound assignment
flag := not is_ready    `Logical negation
```
---

### **Functions**
```plain text
add: Int {a, b;
  a + b
}

multipliers := [1, 2, 3, 4]
result := map(add(10, it), multipliers)
```
---

### **Advanced Constructs**

#### **Conditionals at the End of a Line**
```plain text
value *= 2 if condition
result /= 2 unless divisor == 0
```
#### **Until Conditional Loops**
```plain text
x := 0
until x >= 10
  x += 1
end
```
#### **Range Operators**

Ranges support flexible initiation:
```plain text
inclusive := 1..10
exclusive := 1><10
float_ranges := 1.5 .< 2.5
```
