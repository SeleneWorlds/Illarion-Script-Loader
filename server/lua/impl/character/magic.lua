local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")

Character.SeleneMethods.getMagicType = function(user)
    local charData = user.SeleneEntity:getRuntimeData(DataKeys.Character)
    return charData[DataFields.MagicType] or 0
end

Character.SeleneMethods.setMagicType = function(user, magicType)
    local charData = user.SeleneEntity:getRuntimeData(DataKeys.Character)
    charData[DataFields.MagicType] = magicType
end

Character.SeleneMethods.getMagicFlags = function(user, magicType)
    local magicFlagsData = user.SeleneEntity:getRuntimeData(DataKeys.MagicFlags)
    return magicFlagsData[magicType] or 0
end

Character.SeleneMethods.teachMagic = function(user, magicType, magicFlag)
    local anyFlags = false
    for i = 0, 4 do
        if user:getMagicFlags(i) ~= 0 then
            anyFlags = true
            break
        end
    end

    if not anyFlags then
        user:setMagicType(magicType)
    end

    local flags = user:getMagicFlags(magicType)
    flags = flags | magicFlag
    local magicFlagsData = user.SeleneEntity:getRuntimeData(DataKeys.MagicFlags)
    magicFlagsData[magicType] = flags
end