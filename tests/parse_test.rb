require_relative './../source/tokenizer'
require_relative './../source/parser'

tokenizer = Tokenizer.new '
1 + 1 new
'

puts "\n- TOKENIZER —————————————————————————————————————"
tokenizer.newlines_become_tokens = false
tokenizer.scan
tokens = tokenizer.tokens
puts "tokens: #{tokens.inspect}"
tokenizer.puts_debug_info

# puts "\n- PARSER ——————————————————————————————————————"
# parser     = Parser.new
# tokens     = parser.to_statements(tokens, stop_at: :eof)
# puts "tokens again: #{tokens.inspect}"
# statements = parser.statements
# puts "statements: #{statements.map(&:inspect).join(",")}"
