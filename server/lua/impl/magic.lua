local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getMagicType = function(user)
    return user.SeleneEntity.CustomData[DataKeys.MagicType] or 0
end

Character.SeleneMethods.setMagicType = function(user, magicType)
    user.SeleneEntity.CustomData[DataKeys.MagicType] = magicType
end

Character.SeleneMethods.getMagicFlags = function(user, magicType)
    return user.SeleneEntity.CustomData[DataKeys.MagicFlags .. magicType] or 0
end

local function SetMagicFlags(user, magicType, flags)
    user.SeleneEntity.CustomData[DataKeys.MagicFlags .. magicType] = flags
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
    SetMagicFlags(user, magicType, flags)
end