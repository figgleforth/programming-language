require_relative './../source/lexer'

lexer = Lexer.new '1 + 2 * 3 - 4 / 2'
tokens = lexer.make_tokens

puts "\n`#{lexer.source}` to tokens:\n\n"
puts tokens
