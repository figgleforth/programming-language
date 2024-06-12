### Goals
- Write as little fluff code as possible, that means fewer things like `class`, `def`, etc.
- Built in web application in as few lines of code as possible, so it should have server built in, along with database and model constructs, and response rendering.

### Sample

```
STATUS_ENUM {
   CAN_BE_UNINITIALIZED
   MUST_BE_CAPITALIZED = 0
   CAN_BE, COMMA_SEPARATED,
   OR_NESTED {
      NICE = 42
   }
   NICE = 420
}

Classes_Are_Capitalized {
   member_vars_are_lowercase = 0
   or_uninitialized;
   version = 0.0
   bugs = 1_000_000
   status = STATUS_ENUM.NICE
   
   member_functions_are_lowercase { 
      "Emerald version `version`"
   }
   
   functions_with_params { a_param -> 
      "This param `a_param`"
   }
   
   and_with_labels { by delta ->
      version += delta
   }
}

em = Emerald.new
em.increase_version 0.1
em.change_version by: -0.1
em.info # Emerald version 0.0
```
