local Players = require("selene.players")
local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Network = require("selene.network")
local I18n = require("selene.i18n")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local CharacterPersistence = require("illarion-script-loader.server.lua.lib.characterPersistence")

local m = {}

local function findRaceEntity(raceId, sex)
    local preferredTypeId = sex == "female" and 1 or 0
    local fallback = nil

    for _, entityDefinition in pairs(Registries.findAll("entities")) do
        if entityDefinition:getMetadata("raceId") == raceId then
            fallback = fallback or entityDefinition
            if entityDefinition:getMetadata("typeId") == preferredTypeId then
                return entityDefinition
            end
        end
    end

    if fallback then
        return fallback
    end
    error("No entity definition found for race " .. raceId)
end

function m.Spawn(player, selectedCharacter)
    local entity = Entities.create(findRaceEntity(selectedCharacter.race, selectedCharacter.sex))
    local id = selectedCharacter.id
    entity:setName(selectedCharacter.name)
    local charData = entity:getRuntimeData(DataKeys.Character)
    charData[DataFields.ID] = id
    charData[DataFields.CharacterType] = Character.player
    charData[DataFields.Race] = selectedCharacter.race
    charData[DataFields.Sex] = selectedCharacter.sex
    entity:setCoordinate(selectedCharacter.x, selectedCharacter.y, selectedCharacter.z)
    entity:setFacing(DirectionUtils.IllaToSelene(selectedCharacter.facing) or "south")
    entity:addDynamicComponent("illarion:name", function(entity, forPlayer)
        local targetCharData = entity:getRuntimeData(DataKeys.Character)
        local isControlled = forPlayer:getControlledEntity() == entity
        local introductionData = forPlayer:getControlledEntity() and forPlayer:getControlledEntity():getRuntimeData(DataKeys.Introductions) or nil
        local relationship = introductionData and introductionData[targetCharData[DataFields.ID]]
        local isIntroduced = relationship and relationship.introduced
        local effectiveName = entity:getName()
        if not isIntroduced and not isControlled then
            local raceId = targetCharData[DataFields.Race]
            local race = Registries.findByMetadata("illarion:races", "id", raceId)
            if race then
                local sex = targetCharData[DataFields.Sex] or "male"
                local key = "nameTag." .. stringx.substringAfter(race:getName(), "illarion:") .. "." .. sex
                effectiveName = I18n.get(key, forPlayer:getLocale()) or key
            else
                effectiveName = tostring(targetCharData[DataFields.Race])
            end
        end
        return {
            type = "visual",
            visual = "illarion:labels/character",
            position = {
                origin = "top",
                offsetY = 20
            },
            overrides = {
                text = effectiveName
            }
        }
    end)
    entity:spawn()
    player:setControlledEntity(entity)
    player:setCameraEntity(entity)
    player:setCameraToFollowTarget()

    local character = CharacterManager.AddEntity(entity)

    local equipment = InventoryManager.GetEquipment(character)
    equipment:subscribe(function(data)
        local slotId = data.dirtySlot
        if slotId then
            local item = equipment:getItem(slotId)
            Network.sendToEntity(entity, "illarion:update_slot", {
                viewId = "equipment",
                slotId = slotId,
                item = InventoryManager.SerializeItem(item)
            })
        end
    end)
    local belt = InventoryManager.GetBelt(character)
    belt:subscribe(function(data)
        local slotId = data.dirtySlot
        if slotId then
            local item = belt:getItem(slotId)
            Network.sendToEntity(entity, "illarion:update_slot", {
                viewId = "belt",
                slotId = slotId,
                item = InventoryManager.SerializeItem(item)
            })
        end
    end)

    CharacterPersistence.restoreCollections(character, selectedCharacter)

    local scalarAttributes = {
        age = selectedCharacter.age,
        weight = selectedCharacter.weight,
        body_height = selectedCharacter.bodyHeight,
        hitpoints = selectedCharacter.hitpoints,
        mana = selectedCharacter.mana,
        foodlevel = selectedCharacter.foodlevel,
        attitude = selectedCharacter.attitude,
        luck = selectedCharacter.luck,
        poisonvalue = selectedCharacter.poison
    }
    for name, value in pairs(scalarAttributes) do
        AttributeManager.GetAttribute(character, name):setValue(value)
    end

    local persistedAttributes = entity:getRuntimeData(DataKeys.PersistedAttributes)
    for _, name in ipairs({
        "strength", "dexterity", "constitution", "agility",
        "intelligence", "perception", "willpower", "essence"
    }) do
        local value = selectedCharacter[name]
        AttributeManager.GetAttribute(character, name):setValue(value)
        persistedAttributes[name] = value
    end

    character:setMentalCapacity(selectedCharacter.mentalCapacity)
    character:setMagicType(selectedCharacter.magicType)
    local magicFlags = entity:getRuntimeData(DataKeys.MagicFlags)
    magicFlags[Character.mage] = selectedCharacter.magicFlagsMage
    magicFlags[Character.priest] = selectedCharacter.magicFlagsPriest
    magicFlags[Character.bard] = selectedCharacter.magicFlagsBard
    magicFlags[Character.druid] = selectedCharacter.magicFlagsDruid
    charData[DataFields.Dead] = selectedCharacter.alive == false or selectedCharacter.alive == 0
    character:setHair(selectedCharacter.hair)
    character:setBeard(selectedCharacter.beard)
    character:setHairColour(colour(
        selectedCharacter.hairRed,
        selectedCharacter.hairGreen,
        selectedCharacter.hairBlue,
        selectedCharacter.hairAlpha
    ))
    character:setSkinColour(colour(
        selectedCharacter.skinRed,
        selectedCharacter.skinGreen,
        selectedCharacter.skinBlue,
        selectedCharacter.skinAlpha
    ))

    local playerData = player:getRuntimeData(DataKeys.Player)
    playerData[DataFields.TotalOnlineTime] = selectedCharacter.totalOnlineTime
    playerData[DataFields.CurrentLoginTimestamp] = os.time()

    return character
end

function m.Despawn(player)
    if player:getControlledEntity() then
        player:getControlledEntity():remove()
    end

    local playerData = player:getRuntimeData(DataKeys.Player)
    local loginTimestamp = playerData[DataFields.CurrentLoginTimestamp] or 0
    local logoutTimestamp = os.time()
    local sessionOnlineTime = logoutTimestamp - loginTimestamp
    local totalOnlineTime = playerData[DataFields.TotalOnlineTime] or 0
    playerData[DataFields.TotalOnlineTime] = totalOnlineTime + sessionOnlineTime
end

function m.getPlayerByCharacterName(name)
    for _, player in ipairs(Players.getOnlinePlayers()) do
        if player:getControlledEntity() and player:getControlledEntity():getName() == name then
            return player
        end
    end
    return nil
end

return m
