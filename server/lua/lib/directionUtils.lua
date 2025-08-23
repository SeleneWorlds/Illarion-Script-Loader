local m = {}

function m.IllaToSelene(direction)
    if direction == Character.north then
        return "north"
    elseif direction == Character.south then
        return "south"
    elseif direction == Character.east then
        return "east"
    elseif direction == Character.west then
        return "west"
    elseif direction == Character.northeast then
        return "northeast"
    elseif direction == Character.northwest then
        return "northwest"
    elseif direction == Character.southeast then
        return "southeast"
    elseif direction == Character.southwest then
        return "southwest"
    end
end

function m.SeleneToIlla(direction)
    if direction == "north" then
        return Character.north
    elseif direction == "south" then
        return Character.south
    elseif direction == "east" then
        return Character.east
    elseif direction == "west" then
        return Character.west
    elseif direction == "northeast" then
        return Character.northeast
    elseif direction == "northwest" then
        return Character.northwest
    elseif direction == "southeast" then
        return Character.southeast
    elseif direction == "southwest" then
        return Character.southwest
    end
end

return m