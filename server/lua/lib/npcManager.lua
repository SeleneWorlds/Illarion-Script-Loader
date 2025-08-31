local Registries = require("selene.registries")
local Entities = require("selene.entities")

local Constants = require("illarion-script-loader.server.lua.lib.constants")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")

local m = {}

m.IdCounter = 0
m.EntitiesByNpcId = {}
m.PendingRemoval = {}

function m.Spawn(npc)
    local race = Registries.FindByName("illarion:races", npc:GetField("race"))
    if race == nil then
        error("Unknown race " .. npc:GetField("race") .. " for NPC " .. npc.Name)
    end
    local entity = Entities.Create(npc:GetField("entity"))
    entity.Name = npc:GetField("name")
    entity:SetCoordinate(npc:GetField("x"), npc:GetField("y"), npc:GetField("z"))
    entity:SetFacing(DirectionUtils.IllaToSelene(npc:GetField("facing")))
    local id = npc:GetMetadata("id") + Constants.NPC_BASE_ID
    entity.CustomData[DataKeys.ID] = id
    entity.CustomData[DataKeys.CharacterType] = Character.npc
    entity.CustomData[DataKeys.NPC] = npc
    entity.CustomData[DataKeys.Script] = npc:GetField("script")
    entity.CustomData[DataKeys.Race] = race
    entity.CustomData[DataKeys.Sex] = npc:GetField("sex") == 1 and "female" or "male"
    entity:Spawn()
    m.EntitiesByNpcId[npc:GetMetadata("id")] = entity
    CharacterManager.AddEntity(entity)
end

function m.SpawnDynamic(name, race, sex, pos, scriptName)
    local raceId = race:GetMetadata("id")
    local typeId = sex == "female" and 1 or 0
    local entityType = "illarion:race_" .. raceId .. "_" .. typeId
    local entity = Entities.Create(entityType)
    entity.Name = name
    entity:SetCoordinate(pos)
    idCounter = idCounter + 1
    entity.CustomData[DataKeys.ID] = idCounter + Constants.DYNAMIC_NPC_BASE_ID
    entity.CustomData[DataKeys.CharacterType] = Character.npc
    entity.CustomData[DataKeys.Script] = scriptName
    entity.CustomData[DataKeys.Race] = race
    entity.CustomData[DataKeys.Sex] = sex
    entity:Spawn()
    CharacterManager.AddEntity(entity)
end

function m.Despawn(entity)
    table.insert(m.PendingRemoval, entity)
end

function m.Update()
    for _, entity in ipairs(m.PendingRemoval) do
        local npc = entity.CustomData[DataKeys.NPC]
        m.EntitiesByNpcId[npc:GetMetadata("id")] = nil
        CharacterManager.RemoveEntity(entity)
        entity:Despawn()
    end

    for _, entity in pairs(m.EntitiesByNpcId) do
        local npc = Character.fromSeleneEntity(entity)
        if not entity.CustomData[DataKeys.Dead] then
            -- TODO run LTE
            -- TODO skip if no player nearby and not on route
            local status, script = pcall(require, entity.CustomData[DataKeys.Script])
            if status and type(script.nextCycle) == "function" then
                script.nextCycle(npc)
            end

            -- TODO make a move if on route
            -- TODO abortRoute if route ended
        else
            npc:increaseAttrib("hitpoints", 10000)
        end
    end
end

return m