require_relative 'frontend/constructs'
# require_relative 'frontend/node'
require_relative 'frontend/token'
require_relative 'frontend/tokens'
require_relative 'tokenizer'
require 'ostruct'

class Parser2
  attr_reader :tokens, :current_token

  def initialize(tokens)
    @tokens = tokens
    @current_token = nil
    advance
  end

  def advance
    @current_token = tokens.shift
  end

  def parse
    constructs = []
    while current_token && current_token.type != EOFToken
      constructs << parse_construct
    end
    constructs
  end

  def parse_construct
    case current_token.type
    when CommentToken, BlockCommentToken
      parse_comment
    when KeywordToken
      case current_token.value
      when 'self'
        parse_type_assignment
      when 'obj'
        parse_object_declaration
      when 'def'
        parse_function_definition
      when 'if', 'for', 'while', 'when'
        parse_control_flow
      else
        raise "Unexpected keyword: #{current_token.value}"
      end
    when IdentifierToken
      if peek(1).type == Symbol && peek(1).value == ':'
        parse_variable_declaration
      elsif peek(1).type == Operator && peek(1).value == '='
        parse_assignment
      else
        parse_expression_statement
      end
    else
      raise "Unexpected token: #{current_token.type}"
    end
  end

  def parse_comment
    if current_token.type == CommentToken
      construct = Comment.new(current_token.value)
    else
      construct = MultilineCommentConstruct.new(current_token.value)
    end
    advance
    construct
  end

  def parse_type_assignment
    advance # consume 'self'
    type = parse_expression
    TypeAssignmentConstruct.new(type).tap { advance }
  end

  def parse_object_declaration
    advance # consume 'obj'
    name = advance.value
    body = parse_block
    ObjectDeclarationConstruct.new(name, body)
  end

  def parse_function_definition
    advance # consume 'def'
    name = advance.value
    advance # consume '('
    parameters = parse_parameters
    advance # consume ')'
    body = parse_block
    FunctionDefinitionConstruct.new(name, parameters, body)
  end

  def parse_variable_declaration
    name = advance.value
    advance # consume ':'
    type = parse_expression
    value = if current_token.value == '='
              advance # consume '='
              parse_expression
            else
              nil
            end
    VariableDeclarationConstruct.new(name, type, value)
  end

  def parse_assignment
    lhs = IdentifierConstruct.new(advance.value)
    advance # consume '='
    rhs = parse_expression
    VariableAssignmentConstruct.new(lhs, rhs)
  end

  def parse_control_flow
    case current_token.value
    when 'if'
      parse_if_statement
    when 'for'
      parse_for_statement
    when 'while'
      parse_while_statement
    when 'when'
      parse_when_statement
    else
      raise "Unexpected control flow keyword: #{current_token.value}"
    end
  end

  def parse_if_statement
    advance # consume 'if'
    condition = parse_expression
    body = parse_block
    IfStatementConstruct.new(condition, body)
  end

  def parse_for_statement
    advance # consume 'for'
    iterator = advance.value
    body = parse_block
    ForStatementConstruct.new(iterator, body)
  end

  def parse_while_statement
    advance # consume 'while'
    condition = parse_expression
    body = parse_block
    WhileStatementConstruct.new(condition, body)
  end

  def parse_when_statement
    advance # consume 'when'
    case_expr = parse_expression
    cases = []
    while current_token.value == 'is'
      advance # consume 'is'
      match_expr = parse_expression
      case_body = parse_block
      cases << CaseConstruct.new(match_expr, case_body)
    end
    else_body = if current_token.value == 'else'
                  parse_block
                else
                  nil
                end
    WhenStatementConstruct.new(case_expr, cases, else_body)
  end

  def parse_expression_statement
    expr = parse_expression
    ExpressionStatementConstruct.new(expr).tap { advance }
  end

  def parse_expression(precedence = 0)
    left = parse_primary
    while precedence < get_precedence(peek)
      operator = advance
      right = parse_expression(get_precedence(operator))
      left = BinaryExpressionConstruct.new(left, operator, right)
    end
    left
  end

  def parse_primary
    case current_token.type
    when IdentifierToken
      parse_identifier_or_function_call
    when NumberToken
      NumberLiteralConstruct.new(advance.value)
    when StringToken
      StringLiteralConstruct.new(advance.value)
    when Symbol
      if current_token.value == '('
        advance # consume '('
        expr = parse_expression
        advance # consume ')'
        expr
      else
        raise "Unexpected symbol: #{current_token.value}"
      end
    else
      raise "Unexpected token: #{current_token.type}"
    end
  end

  def parse_identifier_or_function_call
    identifier = IdentifierConstruct.new(advance.value)
    if current_token.value == '('
      advance # consume '('
      args = parse_arguments
      advance # consume ')'
      FunctionCallConstruct.new(identifier, args)
    else
      identifier
    end
  end

  def parse_arguments
    args = []
    until current_token.value == ')'
      args << parse_expression
      advance if current_token.value == ','
    end
    args
  end

  def parse_block
    statements = []
    advance # consume '{' or the beginning of the block
    until current_token.value == 'end'
      statements << parse_construct
    end
    advance # consume 'end'
    BlockConstruct.new(statements)
  end

  def parse_parameters
    params = []
    until current_token.value == ')'
      params << advance.value
      advance if current_token.value == ','
    end
    params
  end

  def peek(n = 1)
    tokens[n]
  end

  def get_precedence(token)
    PRECEDENCE[token.value.to_sym] || 0
  end
end
