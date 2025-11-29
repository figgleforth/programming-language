module Air
	def self.interp_file filepath, with_std: true
		interp File.read(filepath), with_std: with_std
	end

	def self.interp source_code, with_std: true
		lexemes      = Lexer.new(source_code).output
		expressions  = Parser.new(lexemes).output
		global_scope = with_std ? Air::Global.with_standard_library : Air::Global.new
		interpreter  = Interpreter.new expressions, global_scope

		interpreter.output
	end

	def self.parse_file filepath
		parse File.read(filepath)
	end

	def self.parse source_code
		lexemes = Lexer.new(source_code).output
		Parser.new(lexemes).output
	end

	def self.lex_file filepath
		lex File.read(filepath)
	end

	def self.lex source_code
		Lexer.new(source_code).output
	end

	def self.assert condition, message = "Expected condition to be truthy."
		raise "#{message}\n---\n#{condition.inspect}\n---" unless condition
	end

	def self.constant_identifier? ident
		# ALL UPPER LIKE_THIS
		test = ident&.gsub('_', '')&.gsub('%', '')
		test&.chars&.all? { |c| c.upcase == c }
	end

	def self.type_identifier? ident
		# Capitalized Like_This or This
		ident[0] && ident[0].upcase == ident[0] && !constant_identifier?(ident)
	end

	def self.member_identifier? ident
		# lowercased_FIRST_LETTER, lIKE_THIS or thIS or this
		ident[0] && ident[0].downcase == ident[0]
	end

	def self.type_of_identifier ident
		return :operator if %w(and or not unless return).include? ident

		without_leading__ = ident.gsub(/^_+/, '')

		if constant_identifier? without_leading__
			:IDENTIFIER
		elsif type_identifier? without_leading__
			:Identifier
		elsif member_identifier? without_leading__
			:identifier
		else
			raise "unknown identifier type #{ident.inspect}"
		end
	end

	def self.type_of_number_expr expr
		if expr.to_s.count('.') > 1
			:array_index
		elsif expr.to_s.include? '.'
			:float
		else
			:integer
		end
	end
end
