local Registries = require("selene.registries")
local Interface = require("illarion-api.server.lua.interface")

Interface.Skills.GetSkillName = function(id)
    local skill = Registries.FindByMetadata("illarion:skills", "id", id)
    return skill:GetMetadata("name")
end
