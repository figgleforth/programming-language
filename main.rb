source = './language/test.lang'
require './frontend/token.rb'
require './frontend/lexer.rb'

source_code = File.open(source, 'r') do |code|
  Lexer.new(code).start!
end
