local Registries = require("selene.registries")
local Interface = require("illarion-api.server.lua.interface")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

Interface.Attributes.GetAttributeOffset = function(user, attribute)
    return user.SeleneEntity():GetCustomData(DataKeys.AttributeOffsets .. attribute, 0)
end

Interface.Attributes.SetAttributeOffset = function(user, attribute, value)
    user.SeleneEntity():SetCustomData(DataKeys.AttributeOffsets .. attribute, value)
end

Interface.Attributes.GetBaseAttribute = function(user, attribute)
    return user.SeleneEntity():GetCustomData(DataKeys.BaseAttributes .. attribute, 0)
end

Interface.Attributes.SetBaseAttribute = function(user, attribute, value)
    user.SeleneEntity():SetCustomData(DataKeys.BaseAttributes .. attribute, value)
end

Interface.Attributes.GetTransientBaseAttribute = function(user, attribute)
    return user.SeleneEntity():GetCustomData(DataKeys.TransientBaseAttributes .. attribute, 0)
end

Interface.Attributes.SetTransientBaseAttribute = function(user, attribute, value)
    user.SeleneEntity():SetCustomData(DataKeys.TransientBaseAttributes .. attribute, value)
end

Interface.Attributes.ClampAttribute = function(user, attribute, value)
    local max = 0
    if attribute == "hitpoints" or attribute == "mana" then
        max = 10000
    elseif attribute == "food" then
        max = 60000
    elseif attribute == "strength" or attribute == "dexterity" or attribute == "constitution" or attribute == "agility" or attribute == "intelligence" or attribute == "essence" or attribute == "perception" or attribute == "willpower" then
        max = 255
    end
    return max ~= 0 and math.clamp(value, 0, max) or math.max(value, 0)
end

Character.SeleneMethods.isBaseAttributeValid = function(user, attribute, value)
    local raceId = user:getRace()
    local race = Registries.FindByMetadata("illarion:races", "id", raceId)
    if not race then
        return false
    end

    local titlecaseAttribute = attribute:gsub("^%l", string.upper, 1)
    local minValue = race:GetField("min" .. titlecaseAttribute)
    local maxValue = race:GetField("max" .. titlecaseAttribute)
    if not minValue or not maxValue then
        return false
    end

    return value >= minValue and value <= maxValue
end

Character.SeleneMethods.getMaxAttributePoints = function(user)
    local raceId = user:getRace()
    local race = Registries.FindByMetadata("illarion:races", "id", raceId)
    if not race then
        return 0
    end

    return race:GetField("maxAttributePoints")
end

Character.SeleneMethods.getPoisonValue = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.PoisonValue, 0)
end

Character.SeleneMethods.setPoisonValue = function(user, value)
    user.SeleneEntity():SetCustomData(DataKeys.PoisonValue, value)
end

Character.SeleneMethods.increasePoisonValue = function(user, amount)
    user.SeleneEntity():SetCustomData(DataKeys.PoisonValue, user.SeleneEntity():GetCustomData(DataKeys.PoisonValue, 0) + amount)
end

Character.SeleneMethods.getMentalCapacity = function(user)
    return user.SeleneEntity():GetCustomData(DataKeys.MentalCapacity, 0)
end

Character.SeleneMethods.setMentalCapacity = function(user, value)
    user.SeleneEntity():SetCustomData(DataKeys.MentalCapacity, value)
end

Character.SeleneMethods.increaseMentalCapacity = function(user, amount)
    user.SeleneEntity():SetCustomData(DataKeys.MentalCapacity, user.SeleneEntity():GetCustomData(DataKeys.MentalCapacity, 0) + amount)
end

Character.SeleneMethods.increaseAttrib = function(user, attribute, value)
    if attribute == "sex" then
        error("sex is not yet implemented 😏")
    end

    local baseValue = Interface.Attributes.GetTransientBaseAttribute(user, attribute)
    local offset = Interface.Attributes.GetAttributeOffset(user, attribute)
    local prev = Interface.Attributes.ClampAttribute(user, attribute, baseValue + offset)
    local new = Interface.Attributes.ClampAttribute(user, attribute, prev + value)
    if prev ~= new then
        if baseValue == 0 then
            Interface.Attributes.SetBaseAttribute(user, attribute, new)
            Interface.Attributes.SetAttributeOffset(user, attribute, 0)
        else
            Interface.Attributes.SetAttributeOffset(user, attribute, new - baseValue)
        end
        Interface.Attributes.HandleAttributeChange(user, attribute)
    end
    return new
end

Character.SeleneMethods.setAttrib = function(user, attribute, value)
   local baseValue = Interface.Attributes.GetTransientBaseAttribute(user, attribute)
   local offset = Interface.Attributes.GetAttributeOffset(user, attribute)
   local prev = Interface.Attributes.ClampAttribute(user, attribute, baseValue + offset)
   local new = Interface.Attributes.ClampAttribute(user, attribute, value)
   if prev ~= new then
       if baseValue == 0 then
           Interface.Attributes.SetBaseAttribute(user, attribute, new)
           Interface.Attributes.SetAttributeOffset(user, attribute, 0)
       else
           Interface.Attributes.SetAttributeOffset(user, attribute, new - baseValue)
       end
       Interface.Attributes.HandleAttributeChange(user, attribute)
   end
end

Character.SeleneMethods.getBaseAttributeSum = function(user)
    return Interface.Attributes.GetTransientBaseAttribute(user, "agility") + Interface.Attributes.GetTransientBaseAttribute(user, "constitution") +
           Interface.Attributes.GetTransientBaseAttribute(user, "dexterity") + Interface.Attributes.GetTransientBaseAttribute(user, "essence") +
           Interface.Attributes.GetTransientBaseAttribute(user, "intelligence") + Interface.Attributes.GetTransientBaseAttribute(user, "perception") +
           Interface.Attributes.GetTransientBaseAttribute(user, "strength") + Interface.Attributes.GetTransientBaseAttribute(user, "willpower")
end

Character.SeleneMethods.saveBaseAttributes = function(user)
    -- This behaviour is insane and should not exist
    if getMaxAttributePoints(user) ~= getBaseAttributeSum(user) then
        Interface.Attributes.SetTransientBaseAttribute(user, "agility", Interface.Attributes.GetBaseAttribute(user, "agility"))
        Interface.Attributes.SetTransientBaseAttribute(user, "constitution", Interface.Attributes.GetBaseAttribute(user, "constitution"))
        Interface.Attributes.SetTransientBaseAttribute(user, "dexterity", Interface.Attributes.GetBaseAttribute(user, "dexterity"))
        Interface.Attributes.SetTransientBaseAttribute(user, "essence", Interface.Attributes.GetBaseAttribute(user, "essence"))
        Interface.Attributes.SetTransientBaseAttribute(user, "intelligence", Interface.Attributes.GetBaseAttribute(user, "intelligence"))
        Interface.Attributes.SetTransientBaseAttribute(user, "perception", Interface.Attributes.GetBaseAttribute(user, "perception"))
        Interface.Attributes.SetTransientBaseAttribute(user, "strength", Interface.Attributes.GetBaseAttribute(user, "strength"))
        Interface.Attributes.SetTransientBaseAttribute(user, "willpower", Interface.Attributes.GetBaseAttribute(user, "willpower"))
        return false
    end

    Interface.Attributes.SetBaseAttribute(user, "agility", Interface.Attributes.GetTransientBaseAttribute(user, "agility"))
    Interface.Attributes.SetBaseAttribute(user, "constitution", Interface.Attributes.GetTransientBaseAttribute(user, "constitution"))
    Interface.Attributes.SetBaseAttribute(user, "dexterity", Interface.Attributes.GetTransientBaseAttribute(user, "dexterity"))
    Interface.Attributes.SetBaseAttribute(user, "essence", Interface.Attributes.GetTransientBaseAttribute(user, "essence"))
    Interface.Attributes.SetBaseAttribute(user, "intelligence", Interface.Attributes.GetTransientBaseAttribute(user, "intelligence"))
    Interface.Attributes.SetBaseAttribute(user, "perception", Interface.Attributes.GetTransientBaseAttribute(user, "perception"))
    Interface.Attributes.SetBaseAttribute(user, "strength", Interface.Attributes.GetTransientBaseAttribute(user, "strength"))
    Interface.Attributes.SetBaseAttribute(user, "willpower", Interface.Attributes.GetTransientBaseAttribute(user, "willpower"))
    return true
end

Character.SeleneMethods.setBaseAttribute = function(user, attribute, value)
    if Interface.Attributes.isBaseAttributeValid(user, attribute, value) then
        local prev = Interface.Attributes.GetTransientBaseAttribute(user, attribute)
        local new = Interface.Attributes.ClampAttribute(user, attribute, value)
        if prev ~= new then
            Interface.Attributes.SetBaseAttribute(user, attribute, new)
            Interface.Attributes.HandleAttributeChange(user, attribute)
        end
        return true
    end
    return false
end

Character.SeleneMethods.increaseBaseAttribute = function(user, attribute, amount)
    local prev = Interface.Attributes.GetTransientBaseAttribute(user, attribute)
    local new = prev + amount
    if Interface.Attributes.isBaseAttributeValid(user, attribute, new) then
        new = Interface.Attributes.ClampAttribute(user, attribute, new)
        if prev ~= new then
            Interface.Attributes.SetBaseAttribute(user, attribute, new)
            Interface.Attributes.HandleAttributeChange(user, attribute)
        end
        return true
    end
    return false
end