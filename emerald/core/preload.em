Base_Object {
	== { other ->
		self.id == other.id
	}

	!= { other ->
		self.id != other.id
	}

	=== { other ->
		self.type == other.type
	}

	!== { other ->
		self.type == other.type
	}

	>== { other ->
		self.ancestors.include? other
	}

	? { self.type }

	inspect {
		"`self.type`(`self.id.to_hash`)"
	}
}

obj Context # represents self for every object
	id: int
	type: string
	type_raw: any
	scopes: [Scope]
	args: []
end

obj Database
	host: string
	name: string
	username: string
	password: string
end

obj Server
	port: int = 5000
	database: Database
end

obj Controller
	server: Server
end
