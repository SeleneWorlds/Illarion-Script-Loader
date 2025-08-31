local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")

Character.SeleneMethods.getSkinColour = function(user)
    return AttributeManager.GetAttribute(user, "skinColor").EffectiveValue
end

Character.SeleneMethods.setSkinColour = function(user, skinColor)
    AttributeManager.GetAttribute(user, "skinColor").Value = skinColor
end

Character.SeleneMethods.getHairColour = function(user)
    return AttributeManager.GetAttribute(user, "hairColor").EffectiveValue
end

Character.SeleneMethods.setHairColour = function(user, hairColor)
    AttributeManager.GetAttribute(user, "hairColor").Value = hairColor
end

Character.SeleneMethods.getHair = function(user)
    return AttributeManager.GetAttribute(user, "hair").EffectiveValue
end

Character.SeleneMethods.setHair = function(user, hairId)
    AttributeManager.GetAttribute(user, "hair").Value = hairId
end

Character.SeleneMethods.getBeard = function(user)
    return AttributeManager.GetAttribute(user, "beard").EffectiveValue
end

Character.SeleneMethods.setBeard = function(user, beardId)
    AttributeManager.GetAttribute(user, "beard").Value = beardId
end