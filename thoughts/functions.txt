Last night I thought about functions and their syntax. Originally I decided that -> had to be inside the body of a function because I was having a hard time differentiating while parsing between constructs that share {}. But now I'm much more familiar with the entire pipeline and I think I can remove this requirement.

	function { -> }

could become

	function {}

Before I get to that, here are blocks and dictionaries, for comparison, so we can see the reason for the ambiguity.

	Dictionaries
		{ x y z } 			# {"x"=>nil, "y"=>nil, "z"=>nil}
		{ x: 0 y z } 		# {"x"=>0, "y"=>nil, "z"=>nil}
		{ x: 0 y z } 		# {"x"=>0, "y"=>nil, "z"=>nil}
		{ x: 0 y = 1 z } 	# {"x"=>0, "y"=>1, "z"=>nil}

	Blocks/Functions
		named { -> }		# Scope { named: Ref() }
		{ -> }


So obviously this requirement must remain for anonymous blocks, because without -> they look just like dictionaries

	{ -> }
	{    }

But that's okay, it makes them instantly recognizable.

	{    }   # dictionary
	{ -> }   # anon block
	f { .. } # declared/named block

Example usage of each:

	Language {
		info = { version = 0 }				` dictionary
		store_me = { -> info.version }		` called like store_me()
		call_me { info.version }			` called like call_me()
	}

Patterns to notice that I think help understand the syntactical difference:
- ident = { ->    # declaring an anon block
- ident = {       # declaring a dictionary
- ident {	      # declaring a function

You might think that the dictionary and the body of the call_me function are basically the same thing

	{ version = 0 }
	{ info.version }

They are, but the function body is parsed as part of the function declaration `ident {` so that make_*_ast method definitely won't confuse it with a dictionary.
