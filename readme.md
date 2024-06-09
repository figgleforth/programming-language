### Goals
- Write as little fluff code as possible, that means fewer things like `class`, `def`, etc.
- Built in web application in as few lines of code as possible

---

Models
```
User :> Record
   email: string
   posts: [Post] # like Rails has_many
   
   authenticate? :: email: string, password: string :: bool
   }
}

Post >: Record
   user: User # like Rails belongs_to
}
```

Controllers
```
Posts_Controller :> Controller
   server = Primary_Server # requests are routed from this server
   
   get_single_post :: 'posts/:id' :: Post
      # do what you might do in a Rails controller
   }
   
   put_post :: 'posts/:id'
   }
}
```

Servers
```
Primary_Server :> Server
   port = 3000 # port for this server
   database = 'development' # database for this server  
}
```

Controller syntax is still to be determined, but the point is that all it takes is a Server object and a Controller object to run a web app.
