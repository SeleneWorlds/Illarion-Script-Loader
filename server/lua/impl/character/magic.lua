local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Character.SeleneMethods.getMagicType = function(user)
    return user.SeleneEntity:getCustomData(DataKeys.MagicType) or 0
end

Character.SeleneMethods.setMagicType = function(user, magicType)
    user.SeleneEntity:setCustomData(DataKeys.MagicType, magicType)
end

Character.SeleneMethods.getMagicFlags = function(user, magicType)
    return user.SeleneEntity:getCustomData(DataKeys.MagicFlags .. magicType) or 0
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
    user.SeleneEntity:setCustomData(DataKeys.MagicFlags .. magicType, flags)
end