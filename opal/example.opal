struct: Example(name: str)

filename: str

new: Example(name: str)

end

class: InnerExample(favorite_number: int)
  favorite_number: int

  new(favorite_number: int)
    favorite_number = @favorite_number
  end
end


