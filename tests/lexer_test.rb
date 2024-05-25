require_relative './../source/lexer'

source = File.read('examples/03.em').to_s
lexer = Lexer.new source
tokens = lexer.make_tokens

puts "\n```\n#{lexer.source}\n```\n\n"
puts tokens
