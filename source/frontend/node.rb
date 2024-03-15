class Node
   attr_accessor :tokens

   def initialize tokens
      @tokens = tokens
      # parse if identified?
   end

   def identified?
      raise '#identified? is not implemented by this subclass of Node'
   end

   def inspect
      ivars = instance_variables
      ivars.delete(:@tokens) # remove @tokens from list of instance variables

      # str = "#<#{self.class}:#{'0x%08x' % (object_id << 1)}"
      str = "#{self.class}(::"

      ivars.each do |ivar|
         str += " #{ivar.to_s.gsub('@','')}=#{instance_variable_get(ivar).inspect}"
      end
      str + " ::)"
   end

   def parse
      raise '#parse is not implemented by this subclass of Node'
   end

   def next_token
      tokens[0]
   end

   def eat times = 1
      tokens.shift times
   end

   def eat_until & block
      eat tokens.slice_before(&block).to_a.first.count
   end

   def eat_past & block
      eat tokens.slice_after(&block).to_a.first.count
   end

   def peek ahead = 1
      tokens.dup.shift ahead
   end

   def peek_until & block
      tokens.dup.slice_before(&block).to_a.first
   end

   def assert token, type, msg = nil
      msg ||= "Expected #{token.inspect} to be #{type}"
      raise msg if token.type != type
   end

   def assert_not token, type, msg = nil
      msg ||= "Expected #{token.inspect} not to be #{type}"
      raise msg if token.type == type
   end

   def reached_end? tokens
      tokens.empty? || tokens[0].type == :eof
   end
end
