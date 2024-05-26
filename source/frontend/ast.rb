class Ast
   attr_accessor :token


   def initialize token = nil
      @token = token
   end


   def to_s
      "#{self.class}(#{debug})"
   end


   def debug
      ""
   end


   def inspect
      to_s
   end
end

class Statement < Ast
   def debug
      token
   end
end

class NumberExpr < Ast
   def decimal?
      token.value.include? '.'
   end


   def value
      decimal? ? @number.to_f : @number.to_i
   end
end

class BinaryExpr < Ast
   attr_accessor :left, :operator, :right


   def initialize left, operator, right
      @left     = left
      @operator = operator
      @right    = right
   end


   def debug
      "#{left} #{operator.value} #{right}"
   end
end

class Comment < Ast
   def to_s
      "# #{token.value}"
   end
end

class Assignment < Ast
   attr_accessor :keypath, :value, :type


   def debug
      if type
         "#{keypath} as #{type.value} = #{value ? value : value.inspect}"
      else
         if keypath?
            "#{keypath.map(&:to_s).join('.')} as keypath = #{value ? value : value.inspect}"
         else
            "#{keypath} = #{value ? value : value.inspect}"
         end
      end
   end


   def keypath?
      keypath.is_a? Array
   end
end

class MethodDefinition < Ast
   attr_accessor :identifier, :body, :return_type


   def debug
      "#{identifier}, body: #{body}"
   end


   def return_statement
      body.last
   end
end

class MemberAccess < Ast
   attr_accessor :object, :member


   def debug
      "object: #{object}, member: #{member}"
   end
end

class Literal < Ast
   def debug
      token
   end
end

class NumberLiteral < Ast
end

class StringLiteral < Ast
end

# def eat tokens, times = 1
#     tokens.shift times
#   end
#
# def var_declaration tokens
#    valid = tokens[0] == :identifier
#
#    # obj Identifier
#    name = eat(tokens, 2).last
#
# end
#
# class IamDeclaration < Node
#    attr_accessor :name, :compositions
#
#    def identified?
#       tokens[0].type == :keyword_iam && tokens[1].type == :identifier
#    end
#
#    def parse
#       # iam Identifier ## + Identifier, Identifier, ...
#       # 0   1          ## 2 3 todo) do these later
#       @name = eat(2).last
#       @compositions = make_compositions_object
#    end
# end
#
# class SelfDeclaration < Node
#    attr_accessor :name, :compositions
#
#    def identified?
#       tokens[0].type == :self_keyword && tokens[1].type == :colon && tokens[2].type == :identifier
#    end
#
#    def parse
#       # self :  Identifier  +  Identifier, Identifier, ...
#       # 0    1  2           3  4
#       @name = eat(3).last
#
#       # puts "tokens: #{tokens.inspect}"
#
#       if tokens[0].type == :binary_operator && tokens[0].string == '+'
#          assert next_token, :binary_operator, 'Expected +'
#          eat
#
#          assert_not next_token, :newline, 'Expected identifier for compositions'
#          assert next_token, :identifier
#
#          compositions = []
#          # eat all the compositions, ignore commas and newlines
#          compositions = eat_past { |token| token.type == :newline }.reject { |token| token.type == :comma || token.type == :newline }
#
#          raise "Compositions must be identifiers" unless compositions.all? { |token| token.type == :identifier }
#
#          compositions.map! do |token|
#             # todo) make them into nodes?
#             # Composition.new token.word
#             # token.word
#             Literal.new token
#          end.to_a
#
#          @compositions = compositions
#       end
#    end
# end
#
#
# class ObjectDeclaration < Node
#    attr_accessor :name, :filename, :statements, :variables, :functions, :objects, :name, :explicitly_declared, :compositions
#
#    # infers the name of the program from the filename. ex: file_name.rb => File_Name, the reason for the underscore is to prevent naming collisions and to not hog identifiers for automated things like this.
#    def initialize(tokens = [])
#       @name = 'Unnamed Object'
#       @statements = []
#       @variables = []
#       @functions = []
#       @objects = []
#       @compositions = []
#       @name = name
#       @explicitly_declared = true
#       super tokens
#    end
#
#    def identified?
#       # puts "tokens: #{tokens.inspect}"
#       tokens[0].type == :identifier &&
#         tokens[1].type == :colon &&
#         (tokens[2].type == :identifier || tokens[2].type == :builtin_type)
#    end
#
#    def parse
#       identifier = eat(2).last # obj, identifier
#       node = ObjectDeclaration.new
#       node.name = identifier.string
#       compositions = make_compositions_object
#       node.compositions = compositions
#
#       @objects << node
#       @statements << node
#
#       # todo) since @statements, etc is shared within this parser, I have to instantiate a new one here. I could refactor it so that I also pass @statements to the parser, but that's more work than I feel like doing right now
#       parser = ParserOld.new
#       tokens = parser.make_statements(t, :end_keyword)
#       node.statements = parser.statements
#
#       eat tokens # end keyword
#
#       tokens
#    end
#
#    def make_compositions_object
#       compositions = []
#
#       if tokens[0].type == :binary_operator && tokens[0].string == '+'
#          eat tokens
#          # eat all the compositions, ignore commas and newlines
#          compositions = eat_past do |token|
#             token.type == :newline
#          end
#
#          compositions = compositions.reject do |token|
#             token.type == :comma || token.type == :newline
#          end
#
#          raise "Compositions must be identifiers" unless compositions.all? do |token|
#             token.type == :identifier
#          end
#
#          compositions.map! do |token|
#             # todo) make them into nodes?
#             # token.word
#             Literal.new token
#          end.to_a
#       end
#
#       compositions
#    end
#
#    def filename=(fn)
#       @filename = fn
#       convert_file_name_to_name_of_object!
#    end
#
#    def convert_file_name_to_name_of_object!
#       return unless @filename
#       @explicitly_declared = false
#       @name = @filename.split('/').last.split('.').first.gsub(/(?:^|_)([a-z])/) { |match| match.upcase } # eg) file_name to File_Name
#    end
# end
#
#
# class MethodDeclaration < Node
#    attr_accessor :token, :keyword # def, new
#    attr_accessor :parameters, :statements, :returns
#
#    def initialize(token, keyword = :def, parameters = [])
#       @token = token
#       @keyword = keyword
#       @parameters = parameters
#    end
#
#    def inspect
#       "Method{#{token.inspect} ;; returns(#{returns&.inspect}) ;; params[#{parameters.map(&:inspect).join(',')}] ;; statements[#{statements.map(&:inspect).join(" ;; ")}]}"
#    end
# end
#
#
# class VariableDeclaration < Node
#    attr_accessor :token, :type, :value
#    attr_accessor :visibility
#
#    def self.from? tokens
#       inferred_assignment?(tokens) || explicit_assignment?(tokens)
#    end
#
#    def self.inferred_assignment? tokens
#       tokens[0].type == :identifier &&
#         tokens[1].type == :inferred_assignment_operator
#    end
#
#    def self.explicit_assignment? tokens
#       tokens[0].type == :identifier &&
#         tokens[1].type == :colon &&
#         (tokens[2].type == :identifier || tokens[2].type == :builtin_type)
#    end
#
#    def initialize(token, type = nil, value = nil, visibility = :public)
#       @token = token
#       @type = type
#       @value = value
#       @visibility = visibility
#    end
#
#    def inspect
#       "#{self.class}(#{token.string}: #{type || '???'} = #{value.inspect})"
#    end
#
#    def inferred?
#       value.nil?
#    end
# end
#
#
# class VariableReference < Node
#    attr_accessor :token
#
#    def initialize(token)
#       @token = token
#    end
#
#    def inspect
#       "VariableRef::(#{token.inspect})"
#    end
# end
#
#
# class BinaryExpression < Node
#    attr_accessor :binary_operator, :left, :right
#
#    def initialize(operator, left, right)
#       @binary_operator = operator
#       @left = left
#       @right = right
#    end
#
#    def inspect
#       "BinExpr(#{left.inspect} #{binary_operator} #{right.inspect})"
#    end
# end
#
#
# class Literal < Node
#    attr_accessor :token, :type # :variable, :method
#
#    def initialize(token, type = :variable)
#       @token = token
#       @type = type
#    end
#
#    def inspect
#       if type == :variable
#          "Literal(#{token.string})"
#       else
#          "MethodLiteral(#{token.string})"
#       end
#    end
# end
#
#
# class Param < Node
#    attr_accessor :name_token, :type, :label, :default_value
#
#    def initialize(name_token: nil, type: nil, label: nil)
#       @name_token = name_token
#       @type = type
#       @label = label
#    end
#
#    def inspect
#       prefix = label.nil? ? '' : "#{label.string}"
#       "Param{label(#{prefix}), name(#{name_token.string}), type(#{type.string}), default(#{default_value&.inspect})}"
#    end
# end
#
#
# class Argument < Node
#    attr_accessor :value, :label
#
#    def initialize(value: nil, label: nil)
#       @value = value
#       @label = label
#    end
#
#    def inspect
#       label_ = label ? "#{label.inspect}: " : ''
#       "#{label_}#{value.inspect}"
#    end
# end
#
#
# class Composition < Node
#    attr_accessor :name
#
#    def initialize(name)
#       @name = name
#    end
#
#    def inspect
#       "Comp(#{name})"
#    end
# end
#
#
# class Call < Node
#    attr_accessor :name, :parameters
#
#    def initialize(name, parameters = [])
#       @name = name
#       @parameters = parameters
#    end
#
#    def inspect
#       prefix = "Call{#{name.inspect}"
#       params = parameters.map(&:inspect).join(', ')
#       prefix += " with Parameters[#{params}]" unless params.empty?
#       "#{prefix}}"
#    end
# end
#
