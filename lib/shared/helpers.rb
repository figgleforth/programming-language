module Helpers
	extend self

	def assert condition, message = "Expected condition to be truthy."
		raise "#{message}\n---\n#{condition.inspect}\n---" unless condition
	end

	def constant_identifier? ident
		# ALL UPPER LIKE_THIS
		test = ident&.gsub('_', '')&.gsub('%', '')
		test&.chars&.all? { |c| c.upcase == c }
	end

	def type_identifier? ident
		# Capitalized Like_This or This
		ident[0] && ident[0].upcase == ident[0] && !constant_identifier?(ident)
	end

	def member_identifier? ident
		# lowercased_FIRST_LETTER, lIKE_THIS or thIS or this
		ident[0] && ident[0].downcase == ident[0]
	end

	def type_of_identifier ident
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

	def type_of_number_expr expr
		if expr.to_s.count('.') > 1
			:array_index
		elsif expr.to_s.include? '.'
			:float
		else
			:integer
		end
	end

	def privacy_of_ident ident
		leading_underscores = ident.match(/^_*/)[0].length

		case leading_underscores
		when 0, 2
			:public
		when 1, 3
			:private
		else
			:public # 4+ underscores
		end
	end

	# Rules:
	# _ident   = instance
	# __ident  = static
	# ___ident = static
	# IDENT    = static
	# else       instance
	def binding_of_ident ident
		return :static if type_of_identifier(ident) == :IDENTIFIER

		leading_underscores = ident.match(/^_*/)[0].length

		case leading_underscores
		when 2, 3
			:static
		else
			:instance
		end
	end

	def binding_and_privacy ident
		return binding_of_ident(ident), privacy_of_ident(ident)
	end
end
