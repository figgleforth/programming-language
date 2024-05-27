Object: Island # parsed from ./tests/parse_test.is
  Compositions: Others, Survivors

  Object: Hatch
    Compositions: [Station]
    Constructor:
      Parameters:
        Param:
          Label: nil
          Name: coordinates
          Type: int
        Param:
          Label: nil
          Name: size
          Type: int
    Declaration: entered_numbers -> str? # optional
      Ast_Literal: nil
      Visibility: public
    Declaration: _actual_numbers -> str! # constant
      Ast_Literal: '4815162342'
      Visibility: private
    Method: visit -> nil
      Parameters: []
      Body:
        BuiltinMethodCall: @log
          Arguments:
            IdentifierTok(coordinates)

  Declaration: manual_assignment -> int # required, not optional and not constant
    Visibility: public
    Ast_Literal: IntLiteral(4)

  Declaration: inferred_assignment -> inferred # repurpose this property when inferred then update property in the Typer?
    Visibility: private
    Ast_Literal: IntLiteral(8)

  Method: square_and_some -> float
    Parameters:
      Param:
        Label: nil
        Name: a
        Type: int
    Body:
      BinaryExpression:
        OperatorToken: /
        Left:
          BinaryExpression:
            Operator: *
            Left: Identifier(a)
            Right: Identifier(a)
        Right: FloatLiteral(4.815)

  Method: reminder -> str
    Parameters:
      Param:
        Label: for
        Name: name
        Type: str
      Param:
        Label: on
        Name: day
        Type: str
    Body:
      StringInterpolation:
        Value: "`name`, you must enter the numbers on `day`!"
        Data: {
          name: Identifier(name),
          day: Identifier(day)
        }

  Declaration: message -> inferred
    Visibility: private
    Value:
      MethodCall: reminder
        Arguments:
          Argument:
            Label: for
            Value: StringLiteral('John')
          Argument:
            Label: on
            Value: StringLiteral('Wednesday')

  Assignment: message
    Value:
      MethodCall: reminder
        Arguments:
          Argument:
            Label: for
            Value: StringLiteral('John')
          Argument:
            Label: on
            Value:
              MethodCall: today
                Arguments: nil
