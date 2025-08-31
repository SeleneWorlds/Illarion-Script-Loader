local Attributes = require("selene.attributes")
local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")

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
    return AttributeManager.GetAttribute(user, "poisonvalue").EffectiveValue
end

Character.SeleneMethods.setPoisonValue = function(user, value)
    AttributeManager.GetAttribute(user, "poisonvalue").Value = value
end

Character.SeleneMethods.increasePoisonValue = function(user, amount)
    local attribute = AttributeManager.GetAttribute(user, "poisonvalue")
    attribute.Value = attribute.Value + amount
end

Character.SeleneMethods.getMentalCapacity = function(user)
    return AttributeManager.GetAttribute(user, "mentalcapacity").EffectiveValue
end

Character.SeleneMethods.setMentalCapacity = function(user, value)
    AttributeManager.GetAttribute(user, "mentalcapacity").Value = value
end

Character.SeleneMethods.increaseMentalCapacity = function(user, amount)
    local attribute = AttributeManager.GetAttribute(user, "mentalcapacity")
    attribute.Value = attribute.Value + amount
end

Character.SeleneMethods.increaseAttrib = function(user, attributeName, value)
    if attributeName == "sex" then
        local sex = user.SeleneEntity.CustomData[DataKeys.Sex]
        if sex == "female" then
            return Character.female
        else
            return Character.male
        end
    elseif attributeName == "poisonvalue" or attributeName == "attitude" or attributeName == "luck" or attributeName == "age" or attributeName == "body_height" then
        local attribute = AttributeManager.GetAttribute(user, attributeName)
        attribute.Value = attribute.Value + value
        return attribute.EffectiveValue
    end

    local attribute = AttributeManager.GetAttribute(user, attributeName)
    if value == 0 then
        return attribute.EffectiveValue
    end

    if attribute.Value == 0 then
        attribute.Value = value
        return attribute.EffectiveValue
    else
        local offsetAttribute = AttributeManager.GetAttribute(user, attributeName .. "Offset")
        offsetAttribute.Value = offsetAttribute.Value + value
        attribute:Refresh()
        return attribute.EffectiveValue
    end
end

Character.SeleneMethods.setAttrib = function(user, attributeName, value)
    if attributeName == "sex" then
        user.SeleneEntity.CustomData[DataKeys.Sex] = value == Character.female and "female" or "male"
        return
    elseif attributeName == "poisonvalue" or attributeName == "attitude" or attributeName == "luck" or attributeName == "age" or attributeName == "body_height" then
        AttributeManager.GetAttribute(user, attributeName).Value = value
        return
    end

    local attribute = AttributeManager.GetAttribute(user, attributeName)
    if attribute.Value == 0 then
        attribute.Value = value
        return
    end

    local offsetAttribute = AttributeManager.GetAttribute(user, attributeName .. "Offset")
    local offset = value - attribute.Value
    offsetAttribute.Value = offset
    attribute:Refresh()
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
        -- TODO load base attributes to reset changes
        return false
    end

    -- TODO save base attributes
    return true
end

Character.SeleneMethods.setBaseAttribute = function(user, attributeName, value)
    if user:isBaseAttributeValid(attributeName, value) then
        local attribute = AttributeManager.GetAttribute(user, attributeName)
        attribute.Value = value
        return true
    end
    return false
end

Character.SeleneMethods.increaseBaseAttribute = function(user, attributeName, amount)
    local attribute = AttributeManager.GetAttribute(user, attributeName)
    local prev = attribute.Value
    local new = prev + amount
    if user:isBaseAttributeValid(attributeName, new) then
        attribute.Value = new
        return true
    end
    return false
end