source = './language/test.lang'
require './token.rb'
require './lexer.rb'

source_code = File.open(source, 'r') do |code|
  Lexer.new(code).start!
end
