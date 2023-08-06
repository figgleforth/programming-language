self: obj Account('accounts') < Model

@@primary_key = 'id'
@@table = 'accounts'

udx email: str # cannot be nil
col name: str? # can be nil
col value: float = 1.0 # cannot be nil with optional default value to use when instantiating
col description: txt?

has company: Company?
has rewards: [Reward]

# has_many through
has identities: [AccountIdentities.identity] # Model.relationship, equivalent of has_many :identities, through: :account_identities. optional to define has_many account_identities

# join table
obj AccountIdentities < Model
  has account: Account
  has identity: Identity
end





