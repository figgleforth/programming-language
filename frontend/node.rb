  # use the index to determine the distance to the token. 0 is the current token, 1 is the next token, -1 is the previous token, so really just the index in the positive (forward) or negative (backward) direction
  attr_accessor :tokens_ahead
  attr_accessor :tokens_behind

    # hint) it's best to assume any of the following properties could be nil, because they may not be set yet


  attr_accessor :next_word
  attr_accessor :previous_word


  def initialize
    @tokens_ahead  = []
    @tokens_behind = []
  end

