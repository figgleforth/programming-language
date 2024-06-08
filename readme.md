### The goal is to run a web application in as few lines of code as possible

Something like using the following built-in constructs.

Database records
```
obj User imp Record
   email: string
   posts: [Post] # like Rails has_many
}

obj Post imp Record
   user: User # like Rails belongs_to
}
```

Servers
```
obj Primary_Server imp Server
   port = 3000 # port for this server
   database = 'development' # database for this server  
}
```

Controllers
```
obj Posts_Controller imp Controller
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
