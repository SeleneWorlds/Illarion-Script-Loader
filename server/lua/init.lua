local Registries = require("selene.registries")

local allRaces = Registries.FindAll("illarion:races")
for _, Race in ipairs(allRaces) do
    Character[Race:GetMetadata("name")] = Race:GetMetadata("raceId")
end

local allSkills = Registries.FindAll("illarion:skills")
for _, Skill in ipairs(allSkills) do
    Character[Skill:GetMetadata("name")] = Skill:GetMetadata("skillId")
end
