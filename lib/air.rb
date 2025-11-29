require_relative 'constants'

# Compile-time (source to AST)
require_relative 'compiler/lexeme'
require_relative 'compiler/expressions'
require_relative 'compiler/lexer'
require_relative 'compiler/parser'

# Runtime (AST to execution)
require_relative 'runtime/errors'
require_relative 'runtime/scope'
require_relative 'runtime/types'
require_relative 'runtime/execution_context'
require_relative 'runtime/helpers'
require_relative 'runtime/interpreter'

require_relative 'pipeline'
