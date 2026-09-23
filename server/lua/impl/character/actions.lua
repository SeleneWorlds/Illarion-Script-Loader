local Registries = require("selene.registries")
local Schedules = require("selene.schedules")
local Config = require("selene.config")
local Entities = require("selene.entities")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local ActionManager = require("illarion-script-loader.server.lua.lib.actionManager")

Character.SeleneMethods.startAction = function(user, duration, gfxId, gfxInterval, sfxId, sfxInterval)
    local entity = user.SeleneEntity
    local gfxHandle = nil
    local sfxHandle = nil
    if gfxId ~= 0 then
        gfxHandle = Schedules.setInterval(100, function()
            world:gfx(gfxId, user)
        end, { immediate = true })
    end
    if sfxId ~= 0 then
        sfxHandle = Schedules.setInterval(100, function()
            world:makeSound(sfxId, user.pos)
        end, { immediate = true })
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
        local status, script = pcall(require, scriptName)
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
        local status, script = pcall(require, scriptName)
        if not status then
            return
        end
        if type(script.UseItem) ~= "function" then
            return
        end
        action.Script = script
        action.Function = script.UseItem
        if Config.getProperty("useLegacyUseItem") == "true" then
            action.Args = table.pack(user, source, nil, nil, nil)
        else
            action.Args = { user, source }
        end
    else
        return
    end
end

Entities.beforeMove:connect(function(entity)
    Character.fromSeleneEntity(entity):abortAction()
end)
Entities.beforeTurn:connect(function(entity)
   Character.fromSeleneEntity(entity):abortAction()
end)
