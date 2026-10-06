local Registries = require("selene.registries")
local Schedules = require("selene.schedules")
local Config = require("selene.config")
local Entities = require("selene.entities")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local ActionManager = require("illarion-script-loader.server.lua.lib.actionManager")

Character.SeleneMethods.startAction = function(user, duration, gfxId, gfxInterval, sfxId, sfxInterval)
    duration = assert(tonumber(duration), "duration must be a number, was " .. tostring(duration))
    gfxId = assert(tonumber(gfxId), "gfxId must be a number, was " .. tostring(gfxId))
    gfxInterval = assert(tonumber(gfxInterval), "gfxInterval must be a number, was " .. tostring(gfxInterval))
    sfxId = assert(tonumber(sfxId), "sfxId must be a number, was " .. tostring(sfxId))
    sfxInterval = assert(tonumber(sfxInterval), "sfxInterval must be a number, was " .. tostring(sfxInterval))
    local entity = user.SeleneEntity
    local gfxHandle = nil
    local sfxHandle = nil
    if gfxId ~= 0 then
        local playGfx = function()
            world:gfx(gfxId, user)
        end
        if gfxInterval > 0 then
            gfxHandle = Schedules.setInterval(gfxInterval * 100, playGfx, { immediate = true })
        else
            playGfx()
        end
    end
    if sfxId ~= 0 then
        local playSfx = function()
            world:makeSound(sfxId, user.pos)
        end
        if sfxInterval > 0 then
            sfxHandle = Schedules.setInterval(sfxInterval * 100, playSfx, { immediate = true })
        else
            playSfx()
        end
    end

    -- Duration is in deciseconds for whatever reason
    local actionHandle = Schedules.setTimeout(duration * 100, function()
        local currentAction = entity:getRuntimeData(DataKeys.CurrentAction)
        if currentAction and type(currentAction.Function) == "function" and currentAction.Args then
            local actionFunction = currentAction.Function
            local actionArgs = currentAction.Args
            ActionManager.ClearAction(user)
            ActionManager.CallActionFunction(actionFunction, actionArgs, Action.success)
        else
            ActionManager.ClearAction(user)
        end
    end)
    local action = entity:getRuntimeData(DataKeys.CurrentAction)
    local lastAction = entity:getRuntimeData(DataKeys.LastAction)
    action.Script = lastAction[DataFields.LastActionScript]
    action.Function = lastAction[DataFields.LastActionFunction]
    action.Args = lastAction[DataFields.LastActionArgs]
    action.ActionHandle = actionHandle
    action.GfxHandle = gfxHandle
    action.SfxHandle = sfxHandle
end

Character.SeleneMethods.disturbAction = function(user, disturber)
    -- TODO checkSource to invalidate target parameter if character logged out or monster died (castOnChar/useMonster)
    -- TODO special handling for crafting dialogs
    local shouldAbort = false
    local entity = user.SeleneEntity
    local currentAction = entity:getRuntimeData(DataKeys.CurrentAction)
    if currentAction and currentAction.Script and type(currentAction.Script.actionDisturbed) == "function" then
        shouldAbort = currentAction.Script.actionDisturbed(user, disturber)
    end

    if shouldAbort then
        user:abortAction()
        return true
    end

    return false
end

Character.SeleneMethods.successAction = function(user)
    -- TODO checkSource to invalidate target parameter if character logged out or monster died (castOnChar/useMonster)
    -- TODO special handling for crafting dialogs
    local entity = user.SeleneEntity
    local currentAction = entity:getRuntimeData(DataKeys.CurrentAction)
    local actionFunction = currentAction and currentAction.Function
    local actionArgs = currentAction and currentAction.Args
    ActionManager.ClearAction(user)
    if type(actionFunction) == "function" and actionArgs then
        ActionManager.CallActionFunction(actionFunction, actionArgs, Action.success)
    end
end

Character.SeleneMethods.abortAction = function(user)
    -- TODO checkSource to invalidate target parameter if character logged out or monster died (castOnChar/useMonster)
    -- TODO special handling for crafting dialogs
    ActionManager.AbortAction(user)
end

Character.SeleneMethods.isActionRunning = function(user)
    local entity = user.SeleneEntity
    local currentAction = entity:getRuntimeData(DataKeys.CurrentAction)
    return currentAction and currentAction.ActionHandle ~= nil
end

Character.SeleneMethods.changeSource = function(user, source)
    local entity = user.SeleneEntity
    local action = entity:getRuntimeData(DataKeys.CurrentAction)

    if source == nil then
        action.Function = nil
        action.Args = nil
        return
    end

    if getmetatable(source) == Character.SeleneMetatable then
        local sourceData = source.SeleneEntity:getRuntimeData(DataKeys.Character)
        local characterType = sourceData and sourceData[DataFields.CharacterType]
        if characterType == Character.player then
            -- The legacy server accepts players as a character source, but an
            -- ACTION_USE has no completion callback for player sources.
            action.Function = nil
            action.Args = nil
            return
        elseif characterType ~= Character.npc and characterType ~= Character.monster then
            return
        end

        local scriptName = sourceData[DataFields.Script]
        if scriptName == nil then
            return
        end
        local status, script = xpcall(require, scriptName)
        if not status then
            return
        end
        local actionFunction = characterType == Character.npc and script.useNPC or script.useMonster
        if type(actionFunction) ~= "function" then
            return
        end

        action.Script = script
        action.Function = actionFunction
        action.Args = { source, user }
        return
    elseif getmetatable(source) == position.SeleneMetatable then
        local script = action.Script
        if type(script) ~= "table" or type(script.useTile) ~= "function" then
            return
        end
        action.Function = script.useTile
        action.Args = { user, source }
        return
    elseif getmetatable(source) == Item.SeleneMetatable then
        local itemId
        if source.SeleneTile then
            itemId = source.SeleneTile:getMetadata("itemId")
        elseif source.SeleneEntity then
            itemId = source.SeleneEntity:getEntityDefinition():getMetadata("itemId")
        end
        if itemId == nil then
            return
        end
        local itemDefinition = Registries.findByMetadata("illarion:items", "id", itemId)
        if itemDefinition == nil then
            return
        end
        local scriptName = itemDefinition:getField("script")
        if scriptName == nil then
            return
        end
        local status, script = xpcall(require, scriptName)
        if not status then
            return
        end
        if type(script.UseItem) ~= "function" then
            return
        end
        action.Script = script
        action.Function = script.UseItem
        if Config.getProperty("useLegacyUseItem") == "true" then
            action.Args = { user, source, Item.fromSeleneEmpty(), 1, 0 }
        else
            action.Args = { user, source }
        end
    else
        return
    end
end

local function isMagicAction(script, actionFunction)
    return type(script) == "table" and (
        actionFunction == script.CastMagic or
        actionFunction == script.CastMagicOnCharacter or
        actionFunction == script.CastMagicOnItem or
        actionFunction == script.CastMagicOnField
    )
end

local function changeActionTarget(user, action, target)
    local script = action.Script or action[DataFields.LastActionScript]
    local actionFunction = action.Function or action[DataFields.LastActionFunction]
    local actionArgs = action.Args or action[DataFields.LastActionArgs]
    if type(script) ~= "table" or type(actionArgs) ~= "table" then
        return
    end

    local newFunction
    local newArgs
    if isMagicAction(script, actionFunction) then
        local counter = actionArgs[#actionArgs - 1] or 1
        local param = actionArgs[#actionArgs] or 0
        if target == nil and type(script.CastMagic) == "function" then
            newFunction = script.CastMagic
            newArgs = { user, counter, param }
        elseif getmetatable(target) == Character.SeleneMetatable and
                type(script.CastMagicOnCharacter) == "function" then
            newFunction = script.CastMagicOnCharacter
            newArgs = { user, target, counter, param }
        elseif getmetatable(target) == Item.SeleneMetatable and
                type(script.CastMagicOnItem) == "function" then
            newFunction = script.CastMagicOnItem
            newArgs = { user, target, counter, param }
        elseif getmetatable(target) == position.SeleneMetatable and
                type(script.CastMagicOnField) == "function" then
            newFunction = script.CastMagicOnField
            newArgs = { user, target, counter, param }
        else
            return
        end
    elseif getmetatable(target) == Item.SeleneMetatable and actionFunction == script.UseItem and
            #actionArgs >= 3 then
        -- Legacy UseItem actions retain their target as the third argument.
        -- Gobaith crafting uses this to continue work on the newly made item.
        newFunction = actionFunction
        newArgs = table.pack(table.unpack(actionArgs, 1, actionArgs.n or #actionArgs))
        newArgs[3] = target
    else
        return
    end

    if action.Function ~= nil or action.Args ~= nil then
        action.Function = newFunction
        action.Args = newArgs
    else
        action[DataFields.LastActionFunction] = newFunction
        action[DataFields.LastActionArgs] = newArgs
    end
end

Character.SeleneMethods.changeTarget = function(user, target)
    local entity = user.SeleneEntity
    local characterData = entity:getRuntimeData(DataKeys.Character)
    if not characterData or characterData[DataFields.CharacterType] ~= Character.player then
        -- These overloads were virtual no-ops for NPCs and monsters.
        return
    end

    -- The legacy LTA object retained its target between callbacks. Update the
    -- action that startAction will copy as well as an already scheduled action.
    local lastAction = entity:getRuntimeData(DataKeys.LastAction)
    changeActionTarget(user, lastAction, target)
    if entity:hasRuntimeData(DataKeys.CurrentAction) then
        changeActionTarget(user, entity:getRuntimeData(DataKeys.CurrentAction), target)
    end
end

Entities.beforeMove:connect(function(entity)
    Character.fromSeleneEntity(entity):abortAction()
end)
Entities.beforeTurn:connect(function(entity)
   Character.fromSeleneEntity(entity):abortAction()
end)
