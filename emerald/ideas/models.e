self: Account < Record # database record corresponding to a specific table, like in Rails but built into the language

# these are optional, by default they're inferred from the obj like in Rails
@.primary_key = 'id'
@.table = 'accounts'

udx email: string # unique index, can't be nil
clm name: string? # column, can be nil
clm value: float = 1.0 # non nillable with default
clm description: string? = 'nice' # nillable with default

has company: Company? # single object is a singular relationship
has rewards: [Reward] # collection is a many relationship

# has_many through
has identities: [Account_Identity.identity] # Model.relationship, equivalent of has_many :identities, through: :account_identities. optional to define has_many account_identities

# join table
obj Account_Identity < Record
  has account: Account
  has identity: Identity
}
