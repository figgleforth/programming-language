The goal is to run a web application in as few lines of code as possible. Here's the current vision, using some built-in constructs.

Database records
```
obj User inc Record
   email: string
   posts: [Post] # like Rails has_many
}

obj Post inc Record
   user: User # like Rails belongs_to
}
```

Servers
```
obj Primary_Server inc Server
   port = 3000 # port for this server
   database = 'development' # database for this server  
}
```

Controllers
```
obj Posts_Controller inc Controller
   server = Primary_Server # requests are routed from this server
   
   get 'posts/:id'
      # do what you might do in a Rails controller
   }
   
   put 'posts/:id';
   post 'create';
   delete 'posts/:id';
   options 'whatever';
}
```

`Record`, `Controller`, and `Server` are builtin APIs that any object can inclement to inherit their variables and functions.
```
api Record
   uuid: string = nil
   created_at: Date_Time = nil
   updated_at: Date_Time = nil
   deleted_at: Date_Time = nil
   
   def find id: int -> Record;
   def where -> [Record];
   def delete -> bool;
   def destroy -> bool;
}

api Controller
   server: Server
   params: {string: any}
   
   def get;
   def put;
   def post;
   def patch;
   def delete;
   def options;
}

api Server
   port: int = 3000
   database: string = nil
}
```
