local Registries = require("selene.registries")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local function GetAttributeOffset(user, attribute)
    return user.SeleneEntity():GetCustomData(DataKeys.AttributeOffsets .. attribute, 0)
end

local function SetAttributeOffset(user, attribute, value)
    user.SeleneEntity():SetCustomData(DataKeys.AttributeOffsets .. attribute, value)
end

local function GetSavedBaseAttribute(user, attribute)
    return user.SeleneEntity():GetCustomData(DataKeys.BaseAttributes .. attribute, 0)
end

local function SetSavedBaseAttribute(user, attribute, value)
    user.SeleneEntity():SetCustomData(DataKeys.BaseAttributes .. attribute, value)
end

local function GetTransientBaseAttribute(user, attribute)
    return user.SeleneEntity():GetCustomData(DataKeys.TransientBaseAttributes .. attribute, 0)
end

local function SetTransientBaseAttribute(user, attribute, value)
    user.SeleneEntity():SetCustomData(DataKeys.TransientBaseAttributes .. attribute, value)
end

local function ClampAttribute(user, attribute, value)
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

local function HandleAttributeChange(user)
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

    local baseValue = GetTransientBaseAttribute(user, attribute)
    local offset = GetAttributeOffset(user, attribute)
    local prev = ClampAttribute(user, attribute, baseValue + offset)
    local new = ClampAttribute(user, attribute, prev + value)
    if prev ~= new then
        if baseValue == 0 then
            user:setBaseAttribute(attribute, new)
            SetAttributeOffset(user, attribute, 0)
        else
            SetAttributeOffset(user, attribute, new - baseValue)
        end
        HandleAttributeChange(user, attribute)
    end
    return new
end

Character.SeleneMethods.setAttrib = function(user, attribute, value)
   local baseValue = GetTransientBaseAttribute(user, attribute)
   local offset = GetAttributeOffset(user, attribute)
   local prev = ClampAttribute(user, attribute, baseValue + offset)
   local new = ClampAttribute(user, attribute, value)
   if prev ~= new then
       if baseValue == 0 then
           user:setBaseAttribute(attribute, new)
           SetAttributeOffset(user, attribute, 0)
       else
           SetAttributeOffset(user, attribute, new - baseValue)
       end
       HandleAttributeChange(user, attribute)
   end
end

Character.SeleneMethods.getBaseAttributeSum = function(user)
    return user:getBaseAttribute("agility") + user:getBaseAttribute("constitution") +
           user:getBaseAttribute("dexterity") + user:getBaseAttribute("essence") +
           user:getBaseAttribute("intelligence") + user:getBaseAttribute("perception") +
           user:getBaseAttribute("strength") + user:getBaseAttribute("willpower")
end

Character.SeleneMethods.saveBaseAttributes = function(user)
    -- This behaviour is insane and should not exist
    if user:getMaxAttributePoints(use) ~= user:getBaseAttributeSum() then
        SetTransientBaseAttribute(user, "agility", GetSavedBaseAttribute(user, "agility"))
        SetTransientBaseAttribute(user, "constitution", GetSavedBaseAttribute(user, "constitution"))
        SetTransientBaseAttribute(user, "dexterity", GetSavedBaseAttribute(user, "dexterity"))
        SetTransientBaseAttribute(user, "essence", GetSavedBaseAttribute(user, "essence"))
        SetTransientBaseAttribute(user, "intelligence", GetSavedBaseAttribute(user, "intelligence"))
        SetTransientBaseAttribute(user, "perception", GetSavedBaseAttribute(user, "perception"))
        SetTransientBaseAttribute(user, "strength", GetSavedBaseAttribute(user, "strength"))
        SetTransientBaseAttribute(user, "willpower", GetSavedBaseAttribute(user, "willpower"))
        return false
    end

    SetSavedBaseAttribute(user, "agility", GetTransientBaseAttribute(user, "agility"))
    SetSavedBaseAttribute(user, "constitution", GetTransientBaseAttribute(user, "constitution"))
    SetSavedBaseAttribute(user, "dexterity", GetTransientBaseAttribute(user, "dexterity"))
    SetSavedBaseAttribute(user, "essence", GetTransientBaseAttribute(user, "essence"))
    SetSavedBaseAttribute(user, "intelligence", GetTransientBaseAttribute(user, "intelligence"))
    SetSavedBaseAttribute(user, "perception", GetTransientBaseAttribute(user, "perception"))
    SetSavedBaseAttribute(user, "strength", GetTransientBaseAttribute(user, "strength"))
    SetSavedBaseAttribute(user, "willpower", GetTransientBaseAttribute(user, "willpower"))
    return true
end

Character.SeleneMethods.setBaseAttribute = function(user, attribute, value)
    if user:isBaseAttributeValid(attribute, value) then
        local prev = GetTransientBaseAttribute(user, attribute)
        local new = ClampAttribute(user, attribute, value)
        if prev ~= new then
            SetTransientBaseAttribute(user, attribute, new)
            HandleAttributeChange(user, attribute)
        end
        return true
    end
    return false
end

Character.SeleneMethods.increaseBaseAttribute = function(user, attribute, amount)
    local prev = GetTransientBaseAttribute(user, attribute)
    local new = prev + amount
    if user:isBaseAttributeValid(attribute, new) then
        new = ClampAttribute(user, attribute, new)
        if prev ~= new then
            SetTransientBaseAttribute(user, attribute, new)
            HandleAttributeChange(user, attribute)
        end
        return true
    end
    return false
end