require 'forwardable'

module Lang
  class Token
    extend Forwardable

    attr_reader :type, :lexeme, :literal, :location

    def_delegators :@location, :line, :col, :length

    def initialize(type, lexeme, literal, location)
      @type = type
      @lexeme = lexeme
      @literal = literal
      @location = location
    end
    # ...
  end
end
