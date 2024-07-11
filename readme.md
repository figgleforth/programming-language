### Goals

- Some syntax that I like, outlined below
- Web server and MVC architecture as part of standard library
   - The ultimate goal is to create web apps without external libraries like how you use Rails with Ruby

### Syntax

Variable without value

```
version =;
```

Variable with value

```
version = 0
```

Anonymous block

```
{
   version = 0
}
```

Function

```
set_version {
   version = 0
}
```

Function with params

```
set_version { v ->
   version = v
}
```

Params with default values

```
set_version { v = 0 ->
   version = v
}
```

Enum

```
ENVIRONMENT {
   DEV,
   PROD
}
```

Class

```
ENVIRONMENT {
   DEV,
   PROD
}

Em {
   environment = ENVIRONMENT.DEV;
   
   set_version { v = 0 ->
      version = v
   }
}
```

Instance

```
ENVIRONMENT {
   DEV,
   PROD
}

Em {
   environment = ENVIRONMENT.DEV;
   
   set_version { v = 0 ->
      version = v
   }
}

lang = Em.new
```

Function call

```
ENVIRONMENT {
   DEV,
   PROD
}

Em {
   environment = ENVIRONMENT.DEV;
   
   set_version { v = 0 ->
      version = v
   }
}

lang = Em.new
lang.set_version 1
```
