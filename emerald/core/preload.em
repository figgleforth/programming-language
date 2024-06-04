obj Base_Object
	# convenience for getting an object's type. eg: 'Base_Object'
	fun ? -> string
		@.type
	end

	# instance equality
	fun == other: Base_Object -> bool
		@.id == other.@.id
	end

	fun != other: Base_Object -> bool
		not self == other
	end

	# type equality
	fun === other: Base_Object -> bool
		@.type == other.@.type
	end

	fun !== other: Base_Object -> bool
		not self === other
	end

	fun >== other: Base_Object -> bool
		@.ancestors.include? other
	end

	# eg: 'Base_Object(0x00000001049eec38)
	fun inspect -> string
		"`@.type`(`@.id.to_hash`)"
	end
end

obj Context # represented as @ for every object
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
