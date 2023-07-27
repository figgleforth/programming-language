class CharacterInfo
  class Position
    attr_accessor :col, :row
  end

  attr_accessor :next_chars, :value, :position

  def initialize
    @value = nil
    @next_chars = []
    @position = Position.new
    position.col = 0
    position.row = 0
  end
end
