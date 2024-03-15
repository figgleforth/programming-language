class Token
  attr_accessor :primary_type
  attr_accessor :secondary_type
  attr_accessor :type # :symbol
  attr_accessor :string
  attr_accessor :span

  # any keys and values, comma separated
  def initialize(**options)
    options.each do |key, val|
      instance_variable_set("@#{key}", val) if respond_to?(key)
    end
  end

  def inspect
    "#{string.inspect}(#{type})"
  end

  def debug
    str = string.rjust(PRINT_PADDING) + ' • ' + type.to_s
    "#{string} ( #{type} / #{secondary_type} / #{primary_type} )"
    str
  end

  def ==(other_type)
    type == other_type
  end
end
