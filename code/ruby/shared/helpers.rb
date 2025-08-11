require_relative 'constants'
require_relative 'constructs'
require_relative '../interpreter'
require_relative '../lexer'
require_relative '../parser'

def _interp code, preload_intrinsics = false
	expressions  = _parse code
	@interpreter = Interpreter.new expressions
	@interpreter.preload_intrinsics if preload_intrinsics
	@interpreter.output
end

def _parse code
	lexemes = _lex code
	@parser = Parser.new lexemes
	@parser.output
end

def _lex code
	@lexer = Lexer.new code
	@lexer.output
end

def _lex_file file_path
	_lex File.read file_path
end

def _interp_file file_path, preload_intrinsics = false
	_interp File.read(file_path), preload_intrinsics
end

def _parse_file file_path
	_parse File.read file_path
end

def refute_raises * exceptions
	yield
rescue *exceptions => e
	flunk "Expected no exception, but got #{e.class}: #{e.message}"
end

def _assert condition, message = "Expected condition to be truthy."
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
