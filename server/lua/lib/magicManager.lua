local Network = require("selene.network")

local m = {}

function m.SendMagicState(character)
    local magicType = character:getMagicType()
    Network.sendToEntity(character.SeleneEntity, "illarion:magic", {
        type = magicType,
        flags = character:getMagicFlags(magicType)
    })
end

return m
