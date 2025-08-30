local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

m.EntitiesById = {}
m.CharactersById = {}

function m.AddEntity(entity)
    local id = entity.CustomData[DataKeys.ID]
    if id == nil then
        error("Tried to add an entity without an ID to character manager")
    end
    m.EntitiesById[id] = entity
    local character = Character.fromSeleneEntity(entity)
    m.CharactersById[id] = character
    return character
end

function m.RemoveEntity(entity)
    m.EntitiesById[entity.CustomData[DataKeys.ID]] = nil
end

return m