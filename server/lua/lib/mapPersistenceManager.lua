local m = {}

function m.getLayerFor(pos)
    if world:isPersistentAt(pos) then
        return "persisted"
    end
    return "transient"
end

return m
