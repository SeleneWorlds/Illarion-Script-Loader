local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Interface.Attributes.GetAttribute = function(user, attribute)
    return user.SeleneEntity():GetCustomData(DataKeys.Attributes .. attribute, 0)
end

Interface.Attributes.SetAttribute = function(user, attribute, value)
    user.SeleneEntity():SetCustomData(DataKeys.Attributes .. attribute, value)
end

Interface.Attributes.GetBaseAttribute = function(user, attribute)
    return user.SeleneEntity():GetCustomData(DataKeys.BaseAttributes .. attribute, 0)
end

Interface.Attributes.SetBaseAttribute = function(user, attribute, value)
    user.SeleneEntity():SetCustomData(DataKeys.BaseAttributes .. attribute, value)
end

Interface.Attributes.GetPoisonValue = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.PoisonValue, 0)
end

Interface.Attributes.SetPoisonValue = function(user, value)
    user.SeleneEntity():SetCustomData(DataKeys.PoisonValue, value)
end

Interface.Attributes.GetMentalCapacity = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.MentalCapacity, 0)
end

Interface.Attributes.SetMentalCapacity = function(user, value)
    user.SeleneEntity():SetCustomData(DataKeys.MentalCapacity, value)
end