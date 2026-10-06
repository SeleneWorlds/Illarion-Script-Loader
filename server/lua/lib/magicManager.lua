local Network = require("selene.network")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

function m.SendMagicState(character)
    local magicType = character:getMagicType()
    Network.sendToEntity(character.SeleneEntity, "illarion:magic", {
        type = magicType,
        flags = character:getMagicFlags(magicType)
    })
end

function m.ForgetAllMagic(character, magicType)
    magicType = assert(tonumber(magicType), "magicType must be a number, was " .. tostring(magicType))
    local magicFlagsData = character.SeleneEntity:getRuntimeData(DataKeys.MagicFlags)
    magicFlagsData[magicType] = 0
    m.SendMagicState(character)
end

return m
