class Token
  attr_accessor :primary_type
  attr_accessor :secondary_type
  attr_accessor :type # :symbol
  attr_accessor :word
  attr_accessor :span

  # any keys and values, comma separated
  def initialize(**options)
    options.each do |key, val|
      instance_variable_set("@#{key}", val) if respond_to?(key)
    end
  end

  def inspect
    "#{type}(#{word.to_s})"
  end

  def debug
    str = word.rjust(PRINT_PADDING) + ' • ' + type.to_s
    "#{word} ( #{type} / #{secondary_type} / #{primary_type} )"
    str
  end
end
