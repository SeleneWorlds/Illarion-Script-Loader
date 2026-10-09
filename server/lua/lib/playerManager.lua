local Players = require("selene.players")
local Entities = require("selene.entities")
local Registries = require("selene.registries")
local Network = require("selene.network")
local NameManager = require("illarion-script-loader.server.lua.lib.nameManager")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local AttributeManager = require("illarion-script-loader.server.lua.lib.attributeManager")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local CharacterPersistence = require("illarion-script-loader.server.lua.lib.characterPersistence")
local AdminPersistence = require("illarion-script-loader.server.lua.lib.adminPersistence")

local m = {}

function m.IsAdminUserId(userId)
    return AdminPersistence.isAdmin(userId)
end

function m.IsUserOnline(userId)
    for _, onlinePlayer in ipairs(Players.getOnlinePlayers()) do
        if onlinePlayer:getUserId() == userId then
            return true
        end
    end
    return false
end

function m.IsCharacterOnline(characterId)
    for _, onlinePlayer in ipairs(Players.getOnlinePlayers()) do
        local entity = onlinePlayer:getControlledEntity()
        if entity then
            local charData = entity:getRuntimeData(DataKeys.Character)
            if charData[DataFields.ID] == characterId then
                return true
            end
        end
    end
    return false
end

function m.findRaceEntity(raceId, sex)
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
    return Registries.findByName("entities", "illarion:races/race_0_0")
end

---Builds an in-memory character; negative IDs cannot collide with persisted players or NPCs.
function m.CreateHeadlessCharacter()
    local id = -1
    while CharacterManager.GetCharacterById(id) do
        id = id - 1
    end
    local selected = {
        id = id, name = "Admin", headless = true, race = 26, sex = "male",
        x = -465, y = -465, z = 0,
        facing = 4, age = 18, weight = 0, bodyHeight = 0,
        hitpoints = 10000, mana = 0, foodlevel = 30000, attitude = 0, luck = 0,
        poison = 0, mentalCapacity = 10000, magicType = 0,
        magicFlagsMage = 0, magicFlagsPriest = 0, magicFlagsBard = 0, magicFlagsDruid = 0,
        alive = true, hair = 0, beard = 0, totalOnlineTime = 0,
        hairRed = 255, hairGreen = 255, hairBlue = 255, hairAlpha = 255,
        skinRed = 255, skinGreen = 255, skinBlue = 255, skinAlpha = 255
    }
    for _, name in ipairs({
        "strength", "dexterity", "constitution", "agility",
        "intelligence", "perception", "willpower", "essence"
    }) do
        selected[name] = 10
    end
    return selected
end

function m.Spawn(player, selectedCharacter)
    local entity = Entities.create(m.findRaceEntity(selectedCharacter.race, selectedCharacter.sex))
    local id = selectedCharacter.id
    entity:setName(selectedCharacter.name)
    local charData = entity:getRuntimeData(DataKeys.Character)
    charData[DataFields.ID] = id
    charData[DataFields.Headless] = selectedCharacter.headless == true
    if selectedCharacter.headless then
        entity:makeInvisible()
        entity:setCollisions(false)
        entity:setGravityEnabled(false)
    end
    charData[DataFields.CharacterType] = Character.player
    charData[DataFields.Race] = selectedCharacter.race
    charData[DataFields.Sex] = selectedCharacter.sex
    entity:setCoordinate(selectedCharacter.x, selectedCharacter.y, selectedCharacter.z)
    entity:setFacing(DirectionUtils.IllaToSelene(selectedCharacter.facing) or "south")
    entity:addDynamicComponent("illarion:name", function(entity, forPlayer)
        return {
            type = "visual",
            visual = "illarion:labels/character",
            position = {
                origin = "top",
                offsetY = 20
            },
            overrides = {
                text = NameManager.Get(entity, forPlayer:getControlledEntity(), forPlayer:getLocale())
            }
        }
    end)
    entity:spawn()
    player:setControlledEntity(entity)
    player:setCameraEntity(entity)
    player:setCameraToFollowTarget()

    local character = CharacterManager.AddEntity(entity)
    entity:addDynamicComponent("illarion:visual", function()
        local raceId = character:increaseAttrib("hitpoints", 0) <= 0 and Character.ghost or character:getRace()
        local sex = charData[DataFields.Sex] or "male"
        return {
            type = "visual",
            visual = m.findRaceEntity(raceId, sex):getName(),
            alpha = character.isinvisible and 0.5 or 1
        }
    end)

    local equipment = InventoryManager.GetEquipment(character)
    local belt = InventoryManager.GetBelt(character)
    entity:addDynamicComponent("illarion:light", function()
        local brightness = 0
        for _, slotId in ipairs({ 5, 6, 12, 13, 14, 15, 16, 17 }) do
            local inventory = slotId < 12 and equipment or belt
            local item = inventory:getItem(slotId)
            if item then
                brightness = math.max(brightness, tonumber(item.def:getField("brightness")) or 0)
            end
        end
        if brightness <= 0 then
            return nil
        end
        return {
            type = "light",
            radius = brightness,
            intensity = 1,
            red = 1,
            green = 0.8,
            blue = 0.55
        }
    end)

    equipment:subscribe(function(data)
        local slotId = data.dirtySlot
        if slotId then
            local item = equipment:getItem(slotId)
            Network.sendToEntity(entity, "illarion:update_slot", {
                viewId = "equipment",
                slotId = slotId,
                item = InventoryManager.SerializeItem(item)
            })
            if slotId == 5 or slotId == 6 then
                entity:updateVisuals()
            end
        end
    end)
    belt:subscribe(function(data)
        local slotId = data.dirtySlot
        if slotId then
            local item = belt:getItem(slotId)
            Network.sendToEntity(entity, "illarion:update_slot", {
                viewId = "belt",
                slotId = slotId,
                item = InventoryManager.SerializeItem(item)
            })
            entity:updateVisuals()
        end
    end)

    CharacterPersistence.restoreCollections(character, selectedCharacter)
    entity:updateVisuals()

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
    character:setRace(selectedCharacter.race)

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
