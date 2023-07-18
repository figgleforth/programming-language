obj: Example(name: str)

filename: str

new(name: str)
  filename # prints filename
end

obj: InnerExample(favorite_number: int)
  is Runner

  favorite_number: int

  new(favorite_number: int)
    favorite_number = @favorite_number
  end
end

api Runner
  def run
end
