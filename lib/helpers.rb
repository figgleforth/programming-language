module Helpers
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
