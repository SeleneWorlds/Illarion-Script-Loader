local Registries = require("selene.registries")
local Entities = require("selene.entities")
local Grid = require("selene.grid")
local Pathfinding = require("selene.pathfinding")

local Constants = require("illarion-script-loader.server.lua.lib.constants")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local CharacterManager = require("illarion-script-loader.server.lua.lib.characterManager")
local DirectionUtils = require("illarion-script-loader.server.lua.lib.directionUtils")
local RouteManager = require("illarion-script-loader.server.lua.lib.routeManager")
local CombatManager = require("illarion-script-loader.server.lua.lib.combatManager")

local m = {}

local ACTIVE_RANGE = 60
local RANDOM_MOVE_INTERVAL_TICKS = 20
local VIEW_RANGE = 11
local INITIAL_AGGRO_RANGE = 8
local RETAINED_AGGRO_RANGE = 10
local PATH_SEARCH_RADIUS = 32

local EQUIPMENT_SLOTS = {
    backpack = Character.backpack,
    head = Character.head,
    neck = Character.neck,
    breast = Character.breast,
    hands = Character.hands,
    ["left hand"] = Character.left_tool,
    ["right hand"] = Character.right_tool,
    ["left finger"] = Character.finger_left_hand,
    ["right finger"] = Character.finger_right_hand,
    legs = Character.legs,
    feet = Character.feet,
    coat = Character.coat
}

m.IdCounter = 0
m.NewMonsters = {}
m.UpdateTick = 0

local function getRandomDirection()
    local directions = {}
    for _, direction in ipairs(Grid.getDirections()) do
        if DirectionUtils.SeleneToIlla(direction:getName()) ~= nil then
            directions[#directions + 1] = direction
        end
    end

    if #directions == 0 then
        return nil
    end
    return directions[math.random(#directions)]
end

local function randomDefinitionValue(range)
    local minimum = tonumber(range.min) or 0
    local maximum = tonumber(range.max) or minimum
    return math.random(math.min(minimum, maximum), math.max(minimum, maximum))
end

local function initializeAttributes(monster, monsterDef)
    local attributes = monsterDef:getField("attributes")
    if attributes then
        for name, range in pairs(attributes) do
            monster:setAttrib(name, randomDefinitionValue(range))
        end
    end

    monster:setAttrib("hitpoints", tonumber(monsterDef:getField("hitpoints")) or 0)

    local minSize = tonumber(monsterDef:getField("minSize"))
    local maxSize = tonumber(monsterDef:getField("maxSize")) or minSize
    if minSize then
        monster:setAttrib(
            "body_height",
            math.random(math.min(minSize, maxSize), math.max(minSize, maxSize))
        )
    end
end

local function initializeSkills(monster, monsterDef)
    local skills = monsterDef:getField("skills")
    if not skills then
        return
    end
    for skillName, range in pairs(skills) do
        local skillDef = Registries.findByName("illarion:skills", skillName)
        local skillId = skillDef and tonumber(skillDef:getMetadata("id"))
        if skillId then
            monster:setSkill(skillId, randomDefinitionValue(range), 0)
        end
    end
end

local function initializeItems(monster, monsterDef)
    local items = monsterDef:getField("items")
    if not items then
        return
    end
    for slotName, itemData in pairs(items) do
        local slotId = EQUIPMENT_SLOTS[slotName]
        local itemDef = Registries.findByName("illarion:items", itemData.item)
        if slotId ~= nil and itemDef then
            local count = randomDefinitionValue({
                min = itemData.minCount or 1,
                max = itemData.maxCount or itemData.minCount or 1
            })
            monster:createAtPos(slotId, tonumber(itemDef:getMetadata("id")), count)
        end
    end
end

local function keepDirectionInsideSpawn(monster, direction, spawn)
    if not spawn then
        return direction
    end

    local spawnRange = spawn.def:getField("range")
    if spawnRange == nil then
        return direction
    end

    local vector = direction:getVector()
    local offset = {x = vector:getX(), y = vector:getY()}
    local x = monster.pos.x + offset.x
    local y = monster.pos.y + offset.y
    local centerX = spawn.def:getField("x")
    local centerY = spawn.def:getField("y")

    if math.abs(centerX - x) > spawnRange then
        offset = {x = -offset.x, y = offset.y}
    end
    if math.abs(centerY - y) > spawnRange then
        offset = {x = offset.x, y = -offset.y}
    end

    for _, candidate in ipairs(Grid.getDirections()) do
        local candidateVector = candidate:getVector()
        if candidateVector:getX() == offset.x and candidateVector:getY() == offset.y then
            return candidate
        end
    end
    return nil
end

local function makeRandomMove(monster, charData)
    if #world:getPlayersInRangeOf(monster.pos, ACTIVE_RANGE) == 0 then
        return
    end

    local spawn
    local spawnName = charData[DataFields.MonsterSpawn]
    if spawnName then
        local MonsterSpawn = require("illarion-script-loader.server.lua.lib.monsterSpawn")
        spawn = MonsterSpawn.ByName[spawnName]
    end

    local direction = getRandomDirection()
    if direction == nil then
        return
    end
    direction = keepDirectionInsideSpawn(monster, direction, spawn)
    if direction ~= nil then
        monster:move(DirectionUtils.SeleneToIlla(direction:getName()))
    end
end

local function loadMonsterScript(charData)
    local scriptName = charData[DataFields.Script]
    if scriptName == nil or scriptName == "" then
        return nil
    end
    local status, script = xpcall(require, scriptName)
    return status and script or nil
end

local function callMonsterScript(script, entrypoint, ...)
    if script == nil or type(script[entrypoint]) ~= "function" then
        return false
    end
    local status, result = pcall(script[entrypoint], ...)
    return status and result == true
end

local function isValidPlayerTarget(monster, candidate, charData, rangedTargetingRange)
    if candidate:getType() ~= Character.player or CharacterManager.IsDead(candidate) then
        return false
    end
    if monster.SeleneEntity:getDimension() ~= candidate.SeleneEntity:getDimension() then
        return false
    end
    local retained = charData[DataFields.LastMonsterTargetId] == candidate.id
    local range = rangedTargetingRange or (retained and RETAINED_AGGRO_RANGE or INITIAL_AGGRO_RANGE)
    if not monster:isInRange(candidate, range) then
        return false
    end
    if rangedTargetingRange then
        return next(world:LoS(monster.pos, candidate.pos)) == nil
    end
    return true
end

local function getCandidates(monster, range)
    local candidates = {}
    for _, candidate in ipairs(world:getPlayersInRangeOf(monster.pos, range)) do
        if not CharacterManager.IsDead(candidate) then
            candidates[#candidates + 1] = candidate
        end
    end
    for _, candidate in ipairs(world:getMonstersInRangeOf(monster.pos, range)) do
        if candidate.SeleneEntity ~= monster.SeleneEntity and not CharacterManager.IsDead(candidate) then
            candidates[#candidates + 1] = candidate
        end
    end
    return candidates
end

local function selectTarget(monster, candidates, charData, script, rangedTargetingRange)
    if #candidates == 0 then
        return nil
    end
    if script and type(script.setTarget) == "function" then
        local status, index = pcall(script.setTarget, monster, candidates)
        if status then
            index = tonumber(index)
            if index and index >= 1 and index <= #candidates then
                return candidates[index]
            end
            return nil
        end
    end

    local target
    local targetHitpoints
    for index = 1, #candidates do
        local candidate = candidates[index]
        if isValidPlayerTarget(monster, candidate, charData, rangedTargetingRange) then
            local hitpoints = candidate:increaseAttrib("hitpoints", 0)
            if target == nil or hitpoints < targetHitpoints then
                target = candidate
                targetHitpoints = hitpoints
            end
        end
    end
    return target
end

local function getWeaponRanges(monster)
    local attackRange
    local rangedTargetingRange
    for _, slot in ipairs({Character.right_tool, Character.left_tool}) do
        local item = monster:getItemAt(slot)
        local itemDef = item.id ~= 0 and Registries.findByMetadata("illarion:items", "id", item.id) or nil
        local weapon = itemDef and itemDef:getField("weapon") or nil
        local range = weapon and tonumber(weapon.range)
        if range and attackRange == nil then
            attackRange = range
        end
        if range and tonumber(weapon.weaponType) == 7 then
            rangedTargetingRange = math.max(rangedTargetingRange or 0, range)
        end
    end
    return attackRange or 1, rangedTargetingRange
end

local function moveToward(monster, targetPosition)
    local path = Pathfinding.findPath(monster.SeleneEntity, targetPosition, PATH_SEARCH_RADIUS)
    if path and #path > 0 then
        monster.SeleneEntity:move(path[1])
    else
        local direction = getRandomDirection()
        if direction then
            monster:move(DirectionUtils.SeleneToIlla(direction:getName()))
        end
    end
end

local function attackTarget(monster, target, charData, script)
    charData[DataFields.LastMonsterTargetId] = target.id
    charData[DataFields.LastMonsterTargetPosition] = position(target.pos.x, target.pos.y, target.pos.z)

    if callMonsterScript(script, "enemyNear", monster, target) then
        return true
    end

    local combatData = monster.SeleneEntity:getRuntimeData(DataKeys.Combat)
    combatData[DataFields.TargetId] = target.SeleneEntity:getNetworkId()
    if monster.fightpoints >= 0 then
        callMonsterScript(script, "onAttack", monster, target)
        CombatManager.Attack(monster)
    end
    return true
end

local function updateAggro(monster, charData)
    local monsterDef = charData[DataFields.Monster]
    if not monsterDef or monsterDef:getField("canAttack") ~= true then
        return false
    end

    local script = loadMonsterScript(charData)
    local attackRange, rangedTargetingRange = getWeaponRanges(monster)
    local attackTargetCandidate = selectTarget(
        monster, getCandidates(monster, attackRange), charData, script, rangedTargetingRange
    )
    if attackTargetCandidate then
        return attackTarget(monster, attackTargetCandidate, charData, script)
    end

    local visibleTarget = selectTarget(
        monster, getCandidates(monster, VIEW_RANGE), charData, script, rangedTargetingRange
    )
    if visibleTarget then
        charData[DataFields.LastMonsterTargetId] = visibleTarget.id
        charData[DataFields.LastMonsterTargetPosition] = position(
            visibleTarget.pos.x, visibleTarget.pos.y, visibleTarget.pos.z
        )
        if not callMonsterScript(script, "enemyOnSight", monster, visibleTarget) then
            moveToward(monster, visibleTarget.pos)
        end
        return true
    end

    local lastPosition = charData[DataFields.LastMonsterTargetPosition]
    if lastPosition then
        if monster:isInRangeToPosition(lastPosition, 0) then
            charData[DataFields.LastMonsterTargetId] = nil
            charData[DataFields.LastMonsterTargetPosition] = nil
        else
            moveToward(monster, lastPosition)
            return true
        end
    end
    return false
end

function m.Spawn(monsterDef, pos)
    local raceName = monsterDef:getField("race")
    local race = Registries.findByName("illarion:races", raceName)
    if not race then
        error("Unknown monster race " .. raceName)
    end

    local entity = Entities.create(race:getIdentifier():withPrefix("races/"):withSuffix("_0"))
    m.IdCounter = m.IdCounter + 1
    local charData = entity:getRuntimeData(DataKeys.Character)
    charData[DataFields.ID] = Constants.MONSTER_BASE_ID
        + (m.IdCounter % (Constants.NPC_BASE_ID - Constants.MONSTER_BASE_ID))
    charData[DataFields.CharacterType] = Character.monster
    charData[DataFields.Race] = race:getMetadata("id")
    charData[DataFields.Monster] = monsterDef
    charData[DataFields.Script] = monsterDef:getField("script")
    entity:setCoordinate(pos)
    local monster = Character.fromSeleneEntity(entity)
    initializeAttributes(monster, monsterDef)
    initializeSkills(monster, monsterDef)
    initializeItems(monster, monsterDef)
    table.insert(m.NewMonsters, entity)
    return monster
end

function m.Remove(entity)
    local charData = entity:getRuntimeData(DataKeys.Character)
    local spawnName = charData[DataFields.MonsterSpawn]

    if spawnName then
        local MonsterSpawn = require("illarion-script-loader.server.lua.lib.monsterSpawn")
        local spawn = MonsterSpawn.ByName[spawnName]
        local monsterDef = charData[DataFields.Monster]
        if spawn and monsterDef then
            spawn:monsterRemoved(monsterDef)
        end
    end

    entity:remove()
end

function m.RemoveAll()
    local entities = {}
    for _, entity in ipairs(Entities.findAllByTag("illarion:character")) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if charData[DataFields.CharacterType] == Character.monster then
            entities[#entities + 1] = entity
        end
    end
    for _, entity in pairs(m.NewMonsters) do
        entities[#entities + 1] = entity
    end
    for _, entity in ipairs(entities) do
        m.Remove(entity)
    end
    m.NewMonsters = {}
end

function m.Update()
    m.UpdateTick = m.UpdateTick + 1

    for _, entity in pairs(m.NewMonsters) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        charData[DataFields.NextRandomMoveTick] = m.UpdateTick + math.random(1, RANDOM_MOVE_INTERVAL_TICKS)
        CharacterManager.AddEntity(entity)
        entity:spawn()

        local status, script = xpcall(require, charData[DataFields.Script])
        if status and type(script.onSpawn) == "function" then
            script.onSpawn(Character.fromSeleneEntity(entity))
        end
    end
    m.NewMonsters = {}

    for _, entity in ipairs(Entities.findAllByTag("illarion:character")) do
        local charData = entity:getRuntimeData(DataKeys.Character)
        if charData[DataFields.CharacterType] == Character.monster and not charData[DataFields.Dead] then
            local monster = Character.fromSeleneEntity(entity)
            monster.fightpoints = monster.fightpoints + 1
            local routeStatus = RouteManager.Advance(monster)
            if routeStatus == "complete" or routeStatus == "blocked" then
                monster:setOnRoute(false)
                local status, script = xpcall(require, charData[DataFields.Script])
                if status and type(script.abortRoute) == "function" then
                    script.abortRoute(monster)
                end
            end
            local nextRandomMoveTick = charData[DataFields.NextRandomMoveTick] or m.UpdateTick
            local engaged = routeStatus == "idle" and updateAggro(monster, charData)
            if routeStatus == "idle" and not engaged and m.UpdateTick >= nextRandomMoveTick then
                makeRandomMove(monster, charData)
                charData[DataFields.NextRandomMoveTick] = m.UpdateTick + RANDOM_MOVE_INTERVAL_TICKS
            end
        end
    end
end

return m
