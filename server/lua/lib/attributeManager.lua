local Attributes = require("selene.attributes")
local Network = require("selene.network")

local m = {}

function m.GetAttribute(user, attributeName)
    if not user.SeleneEntity then
        print(debug.traceback())
    end
    local attributeKey = "illarion:" .. attributeName
    local attribute = user.SeleneEntity:GetAttribute(attributeKey)
    if attribute == nil then
        attribute = user.SeleneEntity:CreateAttribute(attributeKey, 0)
        if attributeName == "hitpoints" then
            local max = 10000
            attribute:AddModifier("offset", Attributes.MathOpFilter(m.GetAttribute(user, "hitpointsOffset"), "+"))
            attribute:AddModifier("clamp", Attributes.ClampFilter(0, max))
            attribute:AddConstraint("clamp", Attributes.ClampFilter(0, max))
            attribute:AddObserver(function(attribute)
                user:SeleneSetDead(attribute.EffectiveValue <= 0)
                Network.SendToEntity(attribute.Owner, "illarion:health", { value = attribute.EffectiveValue / max })
            end)
        elseif attributeName == "foodlevel" then
            local max = 60000
            attribute:AddModifier("offset", Attributes.MathOpFilter(m.GetAttribute(user, "foodlevelOffset"), "+"))
            attribute:AddModifier("clamp", Attributes.ClampFilter(0, max))
            attribute:AddConstraint("clamp", Attributes.ClampFilter(0, max))
            attribute:AddObserver(function(attribute)
                Network.SendToEntity(attribute.Owner, "illarion:food", { value = attribute.EffectiveValue / max })
            end)
        elseif attributeName == "mana" then
            local max = 10000
            attribute:AddModifier("offset", Attributes.MathOpFilter(m.GetAttribute(user, "manaOffset"), "+"))
            attribute:AddModifier("clamp", Attributes.ClampFilter(0, max))
            attribute:AddConstraint("clamp", Attributes.ClampFilter(0, max))
            attribute:AddObserver(function(attribute)
                Network.SendToEntity(attribute.Owner, "illarion:mana", { value = attribute.EffectiveValue / max })
            end)
        elseif attributeName == "strength" or attributeName == "dexterity" or attributeName == "constitution" or attributeName == "agility" or attributeName == "intelligence" or attributeName == "essence" or attributeName == "perception" or attributeName == "willpower" then
            attribute:AddModifier("offset", Attributes.MathOpFilter(m.GetAttribute(user, attributeName .. "Offset"), "+"))
            attribute:AddModifier("clamp", Attributes.ClampFilter(0, 255))
            attribute:AddConstraint("clamp", Attributes.ClampFilter(0, 255))
        elseif attributeName == "actionpoints" then
            attribute:AddConstraint("clamp", Attributes.ClampFilter(0, 21))
        elseif attributeName == "fightpoints" then
            attribute:AddConstraint("clamp", Attributes.ClampFilter(0, 0))
        end
    end
    return attribute
end

return m