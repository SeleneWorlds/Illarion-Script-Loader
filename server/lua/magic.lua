local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Interface.Magic.GetMagicType = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.MagicType, 0)
end

Interface.Magic.SetMagicType = function(user, magicType)
    user.SeleneEntity():SetCustomData(DataKeys.MagicType, magicType)
end

Interface.Magic.GetMagicFlags = function(user, magicType)
    return user.SeleneEntity():GetCustomData(DataKeys.MagicFlags .. magicType, 0)
end

Interface.Magic.SetMagicFlags = function(user, magicType, flags)
    user.SeleneEntity():SetCustomData(DataKeys.MagicFlags .. magicType, flags)
end