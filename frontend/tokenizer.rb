require './frontend/character_info'
require './frontend/token_types'
require './frontend/scanner'
require 'ostruct'

source = File.open('./hatch/objects.hh')
code   = source.read
source.close
scanner = Scanner.new(code)

scanner.start

tokens = scanner.tokens.map do |token|
  "#{token[:value]} as #{token[:token_type]}"
end

puts tokens
