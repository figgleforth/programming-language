### Goals
- Write as little fluff code as possible, that means fewer things like `class`, `def`, etc.
- Built in web application in as few lines of code as possible, so it should have server built in, along with database and model constructs, and response rendering.

### Sample

```
STATUS {
   WORKING_ON_IT
   NOT_WORKING_ON_IT
}

Emerald {
   version = 0.0
   bugs = 1_000_000
   status = STATUS.WORKING_ON_IT
   
   info { 
      "Emerald version `version`"
   }
   
   increase_version { to ->
      version = to
   }
   
   change_version { by delta ->
      version += delta
   }
}

em = Emerald.new
em.increase_version 0.1
em.change_bersion by: -0.1
em.info # Emerald version 0.0
```
