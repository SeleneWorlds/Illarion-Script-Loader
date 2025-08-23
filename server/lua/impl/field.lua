function Field.fromSelenePosition(Dimension, Position)
    return setmetatable({ SeleneDimension = Dimension, SelenePosition = Position }, Field.SeleneMetatable)
end
