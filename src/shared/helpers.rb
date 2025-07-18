require './src/shared/constants'
require './src/shared/constructs'
require './src/interpreter'
require './src/lexer'
require './src/parser'

def interp_helper code
	expressions  = parse_helper code
	@interpreter = Interpreter.new expressions
	@interpreter.output
end

def parse_helper code
	lexemes = lex_helper code
	@parser = Parser.new lexemes
	@parser.output
end

def lex_helper code
	@lexer = Lexer.new code
	@lexer.output
end

def interp_file file_path
	interp_helper File.read file_path
end

def parse_file file_path
	parse_helper File.read file_path
end

def refute_raises * exceptions
	yield
rescue *exceptions => e
	flunk "Expected no exception, but got #{e.class}: #{e.message}"
end

def assert condition
	raise "Expected condition to be truthy." unless condition
end

def constant_identifier? ident # ALL UPPER LIKE_THIS
	test = ident&.gsub('_', '')&.gsub('%', '')
	test&.chars&.all? { |c| c.upcase == c }
end

def type_identifier? ident # Capitalized Like_This or This
	ident[0] && ident[0].upcase == ident[0] && !constant_identifier?(ident)
end

def member_identifier? ident # lowercased_FIRST_LETTER, lIKE_THIS or thIS or this
	ident[0] && ident[0].downcase == ident[0]
end

def identifier_kind ident
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
