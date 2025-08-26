module Air
	def self.assert condition, message = "Expected condition to be truthy."
		raise "#{message}\n---\n#{condition.inspect}\n---" unless condition
	end
end

require_relative 'shared/constants'
require_relative 'shared/constructs'
require_relative 'shared/errors'
require_relative 'shared/expressions'
require_relative 'shared/helpers'
require_relative 'shared/types'
require_relative 'shared/lexeme'

require_relative 'lexer'
require_relative 'parser'
require_relative 'interpreter'
