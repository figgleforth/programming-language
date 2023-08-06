class Program
   attr_accessor :filename, :children

   def initialize(filename, children = [])
      @filename = filename
      @children = children
   end
end

class SelfDeclaration
   attr_accessor :name, :compositions

   def initialize(name, compositions = [])
      @name                    = name
      @compositions = compositions
   end
end

# Program.new(20,30)

class Node
   attr_accessor :type, :name, :value, :child_nodes, :tokens, :compositions

   # any keys and values, comma separated
   def initialize(**options)
      options.each do |key, val|
         instance_variable_set("@#{key}", val) if respond_to?(key)
      end
   end

   def inspect
      str = "#{type} -> #{name}"
      str += "\n\t" + child_nodes.map(&:inspect).join("\n") if child_nodes
      str += "\n\tCompositions:\n\t\t#{compositions.map(&:inspect).join("\n\t\t")}" if compositions
      str
   end
end
