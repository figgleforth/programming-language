```
Hatch {
   Computer {
      numbers = 4815162342
   }
   computer = Computer.new
   open { -> }
}

Island {
   something_nil
   survivors = []
   hatch = Hatch.new
}
```
The simplest data structure to represent this code, that an interpreter could understand, is probably the dictionary.
```
Hatch = {
   Computer: {
      numbers: 4815162342
   }
   computer: {
      numbers: 4815162342
   }
   open: [Exprs that make up the body of the function]
}

Island = {
   something_nil: nil
   survivors: []
   hatch: {
      Computer: {
         numbers: 4815162342
      }
      computer: {
         numbers: 4815162342
      }
      open: [Exprs that make up the body of the function]
   }
}
```
The obvious flaw is repetition. So let's make a separate dictionary for storing references to things like functions and classes.
```
references = {
   Computer: {
      numbers: 4815162342
   }
   Hatch = {
      Computer: references[Computer]
      computer: {
         numbers: 4815162342
      }
      open: [Exprs that make up the body of the function]
   }
   Island = {
      something_nil: nil
      survivors: []
      hatch: {
         Computer: references[Computer]
         computer: {
            numbers: 4815162342
         }
         open: references[Hatch.open]
      } 
   }
}

Hatch = {
   Computer: references[Computer]
   computer: {
      numbers: 4815162342
   }
   open: references[Hatch.open]
}

Island = {
   something_nil: nil
   survivors: []
   hatch: {
      Computer: references[Computer]
      computer: {
         numbers: 4815162342
      }
      open: references[Hatch.open]
   }
}
``` 
Good enough. Takeaways:
- classes and functions are basically reusable blueprints to be stored in `references`
- instances are basically duplicates of the blueprint dictionary 
- functions are basically runtime interpretations of its Exprs stored in its reference
- the dictionary containing `references`, `Hatch`, and `Island` is basically the global scope
