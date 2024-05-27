require_relative '../source/lexer'
require_relative '../source/lexer/tokens.rb'

source = File.read('language/01.ek').to_s
lexer  = Lexer.new source
tokens = lexer.to_tokens

# tokens = lexer.make_tokens
#
# puts "\n```\n#{lexer.source}\n```\n\n"

puts
puts "TOKENS\n\n"
puts tokens #.reject { |token| token == DelimiterToken }
