require_relative '../source/lexer/lexer'

source = File.read('language/01.e').to_s
lexer  = Lexer.new source
tokens = lexer.tokenize

# tokens = lexer.make_tokens
#
# puts "\n```\n#{lexer.source}\n```\n\n"

puts
puts "TOKENS\n\n"
puts tokens #.reject { |token| token == DelimiterToken }
