local Interface = require("illarion-api.server.lua.interface")

Interface.Magic.GetMagicType = function(user)
    return user.SeleneEntity():GetCustomData("illarion:magicType", 0)
end

Interface.Magic.SetMagicType = function(user, magicType)
    user.SeleneEntity():SetCustomData("illarion:magicType", magicType)
end

Interface.Magic.GetMagicFlags = function(user, magicType)
    return user.SeleneEntity():GetCustomData("illarion:magicFlags:" .. magicType, 0)
end

Interface.Magic.SetMagicFlags = function(user, magicType, flags)
    user.SeleneEntity():SetCustomData("illarion:magicFlags:" .. magicType, flags)
end