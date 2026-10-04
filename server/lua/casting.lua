local Network = require("selene.network")
local Registries = require("selene.registries")

local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local ActionManager = require("illarion-script-loader.server.lua.lib.actionManager")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")

local function countRunes(spell)
    local count = 0
    for rune = 0, 31 do
        if spell & (1 << rune) ~= 0 then
            count = count + 1
        end
    end
    return count
end

local function resolveCast(character, player, payload, script)
    if payload.kind == nil then
        return script.CastMagic, { character, 1, 0 }
    end
    if payload.kind == "character" then
        local target = PayloadValidation.characterInRange(player, payload.networkId, 14)
        if target and type(script.CastMagicOnCharacter) == "function" then
            return script.CastMagicOnCharacter, { character, target, 1, 0 }
        end
    elseif payload.kind == "field" then
        local x, y, z = PayloadValidation.coordinateInRange(player, payload, nil, 14)
        if x then
            local playerEntity = player:getControlledEntity()
            local tiles = playerEntity:getDimension():getTilesAt(x, y, z, playerEntity:getInteractionViewer())
            if type(script.CastMagicOnItem) == "function" then
                for index = #tiles, 1, -1 do
                    if tiles[index]:getMetadata("itemId") then
                        return script.CastMagicOnItem, { character, Item.fromSeleneTile(tiles[index]), 1, 0 }
                    end
                end
            end
            if type(script.CastMagicOnField) == "function" then
                return script.CastMagicOnField, { character, position(x, y, z), 1, 0 }
            end
        end
    elseif payload.kind == "item" then
        local item
        if payload.networkId ~= nil then
            local entity = PayloadValidation.entityInRange(player, payload.networkId, 14)
            if entity and entity:hasTag("illarion:item") then
                item = Item.fromSeleneEntity(entity)
            end
        else
            local viewId = PayloadValidation.string(payload.viewId, 64)
            local slotId = PayloadValidation.integer(payload.slotId, 0)
            local inventory = viewId and InventoryManager.GetInventoryAtView(character, viewId)
            local inventoryItem = inventory and slotId and inventory:getInventoryItem(slotId)
            if inventoryItem then
                item = Item.fromSeleneInventoryItem(inventoryItem)
            end
        end
        if item and type(script.CastMagicOnItem) == "function" then
            return script.CastMagicOnItem, { character, item, 1, 0 }
        end
    end
    return nil
end

Network.handlePayload("illarion:cast", function(player, payload)
    local spell = PayloadValidation.integer(payload.spell, 1, 0xffffffff)
    if not spell or countRunes(spell) > 5 then
        return
    end

    local character = Character.fromSelenePlayer(player)
    local magicType = character:getMagicType()
    local knownRunes = character:getMagicFlags(magicType)
    if spell & ~knownRunes ~= 0 then
        return
    end

    local spellDefinition = Registries.findByName(
        "illarion:spells",
        "illarion:spell_" .. magicType .. "_" .. spell
    )
    if not spellDefinition then
        character:inform("Diese Runenkombination hat keine Wirkung.", "This rune combination has no effect.")
        return
    end

    local scriptName = spellDefinition:getField("script")
    local loaded, script = pcall(require, scriptName)
    if not loaded then
        return
    end

    local castFunction, castArgs = resolveCast(character, player, payload, script)
    if not castFunction then
        return
    end

    character:abortAction()
    local actionData = character.SeleneEntity:getRuntimeData(DataKeys.LastAction)
    actionData[DataFields.LastActionScript] = script
    actionData[DataFields.LastActionFunction] = castFunction
    actionData[DataFields.LastActionArgs] = castArgs
    ActionManager.CallActionFunction(castFunction, castArgs, Action.none)
end)
