local Interface = require("illarion-api.server.lua.interface")

Interface.Attributes.GetAttribute = function(user, attribute)
    return user.SeleneEntity():GetCustomData("illarion:attributes:" .. attribute, 0)
end

Interface.Attributes.SetAttribute = function(user, attribute, value)
    user.SeleneEntity():SetCustomData("illarion:attributes:" .. attribute, value)
end

Interface.Attributes.GetBaseAttribute = function(user, attribute)
    return user.SeleneEntity():GetCustomData("illarion:baseAttributes:" .. attribute, 0)
end

Interface.Attributes.SetBaseAttribute = function(user, attribute, value)
    user.SeleneEntity():SetCustomData("illarion:baseAttributes:" .. attribute, value)
end

Interface.Attributes.GetPoisonValue = function(user)
    return user.SeleneEntity():GetCustomData("illarion:poisonValue", 0)
end

Interface.Attributes.SetPoisonValue = function(user, value)
    user.SeleneEntity():SetCustomData("illarion:poisonValue", value)
end

Interface.Attributes.GetMentalCapacity = function(user)
    return user.SeleneEntity():GetCustomData("illarion:mentalCapacity", 0)
end

Interface.Attributes.SetMentalCapacity = function(user, value)
    user.SeleneEntity():SetCustomData("illarion:mentalCapacity", value)
end