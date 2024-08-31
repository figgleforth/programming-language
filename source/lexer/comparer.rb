class Comparer # maps over the tokens, but in a hashed way
	attr_accessor :tokens


	def initialize tokens
		@tokens = tokens.map do
			if _1.is_a? Word_Token and Token::RESERVED_IDENTIFIERS.include? _1.string
				Key_Identifier_Token.new _1.string
			elsif _1.is_a? Operator_Token and Token::RESERVED_OPERATORS.include? _1.string
				Key_Operator_Token.new _1.string
			else
				_1
			end
		end
	end
end
