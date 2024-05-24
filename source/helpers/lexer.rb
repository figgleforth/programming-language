def whitespace? input
   [' ', "\t"].include? input
end

def newline? input
   ["\n"].include? input
end

def numeric? input
   !!(input =~ /\A[0-9]+\z/)
end

def alpha? input
   !!(input =~ /\A[a-zA-Z]+\z/)
end

def alphanumeric? input
   !!(input =~ /\A[a-zA-Z0-9]+\z/)
end

def symbol? input
   !!(input =~ /\A[^a-zA-Z0-9\s]+\z/)
end

def identifier? input
   alphanumeric?(input) || input == '_'
end

# https://stackoverflow.com/a/18533211/1426880
def string_to_float input
   Float(input)
   i, f = input.to_i, input.to_f
   i == f ? i : f
rescue ArgumentError
   self
end

# todo; will be useful for numbers like .1, 1. and 1.1
def type_of_number
   if self[0] == '.'
      :float_decimal_beg
   elsif self[-1] == '.'
      :float_decimal_end
   elsif self.include?('.')
      :float_decimal_mid
   else
      :integer
   end
end
