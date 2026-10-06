local Network = require("selene.network")
local Registries = require("selene.registries")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DialogManager = require("illarion-script-loader.server.lua.lib.dialogManager")
local ItemLookAt = require("illarion-script-loader.server.lua.lib.itemLookAt")
local InventoryManager = require("illarion-script-loader.server.lua.lib.inventoryManager")
local PayloadValidation = require("illarion-script-loader.server.lua.lib.payloadValidation")

local function dialogId(payload)
    return PayloadValidation.integer(payload.id, 1)
end

Network.handlePayload("illarion:message_dialog", function(player, payload)
    local id = dialogId(payload)
    if not id then return end
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, id)
    if not dialog or dialog.type ~= "MessageDialog" then
        return
    end

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, id)
end)

Network.handlePayload("illarion:input_dialog", function(player, payload)
    local id = dialogId(payload)
    local success = PayloadValidation.boolean(payload.success)
    if not id or success == nil then return end
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, id)
    if not dialog or dialog.type ~= "InputDialog" then
        return
    end

    local input = success and PayloadValidation.string(payload.input, math.max(0, dialog.maxChars or 0)) or ""
    if input == nil then return end
    dialog.success = success
    dialog.input = input

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, id)
end)

Network.handlePayload("illarion:selection_dialog", function(player, payload)
    local id = dialogId(payload)
    local success = PayloadValidation.boolean(payload.success)
    if not id or success == nil then return end
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, id)
    if not dialog or dialog.type ~= "SelectionDialog" then
        return
    end

    local selectedIndex = success and PayloadValidation.integer(payload.selectedIndex, 0) or -1
    if selectedIndex == nil or (success and dialog.options[selectedIndex] == nil) then return end
    dialog.success = success
    dialog.selectedIndex = selectedIndex

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, id)
end)

Network.handlePayload("illarion:menu_struct", function(player, payload)
    local id = dialogId(payload)
    if not id then return end
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, id)
    if not dialog or dialog.type ~= "MenuStruct" then
        return
    end

    local itemId = payload.itemId == nil and nil or PayloadValidation.integer(payload.itemId, 0)
    if payload.itemId ~= nil and not itemId then return end
    local selectedIndex = payload.slotIndex == nil and nil or PayloadValidation.integer(payload.slotIndex, 1)
    if payload.slotIndex ~= nil and not selectedIndex then return end
    if itemId then
        if selectedIndex then
            local entry = dialog.items[selectedIndex]
            if not entry or entry.id ~= itemId then return end
        else
            for index, entry in ipairs(dialog.items) do
                if entry.id == itemId then selectedIndex = index break end
            end
            if not selectedIndex then return end
        end
    end
    dialog.success = itemId ~= nil
    dialog.selectedItemId = itemId or 0
    dialog.selectedItemIndex = selectedIndex or 0

    if dialog.callback then
        dialog.callback(dialog)
    end

    DialogManager.ClearDialog(character, id)
end)

Network.handlePayload("illarion:look_at_menu_item", function(player, payload)
    local id = dialogId(payload)
    local itemId = PayloadValidation.integer(payload.itemId, 0)
    if not id or not itemId then return end
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, id)
    if not dialog or dialog.type ~= "MenuStruct" then
        return
    end

    local slotIndex = PayloadValidation.integer(payload.slotIndex, 1)
    if not slotIndex then
        return
    end

    local entry = dialog.items[slotIndex]
    if not entry or entry.id ~= itemId then
        return
    end

    local itemDef = Registries.findByMetadata("illarion:items", "id", entry.id)
    if not itemDef then
        return
    end

    local item = setmetatable({
        SeleneMenuItem = {
            dialogId = id,
            slotIndex = slotIndex,
            itemId = entry.id
        },
        SeleneItem = {
            def = itemDef,
            count = 1,
            quality = entry.quality or 333,
            wear = 0,
            data = entry.data and entry.data ~= 0 and { data = tostring(entry.data) } or {}
        }
    }, Item.SeleneMetatable)

    local result = ItemLookAt.Get(character, itemDef, item)
    if result then
        Network.sendToPlayer(player, "illarion:look_at_menu_item", {
            id = id,
            slotIndex = slotIndex,
            itemId = entry.id,
            tooltip = result
        })
    end
end)

Network.handlePayload("illarion:merchant_dialog:abort", function(player, payload)
    local id = dialogId(payload)
    if not id then return end
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, id)
    if not dialog or dialog.type ~= "MerchantDialog" then
        return
    end

    dialog.result = MerchantDialog.playerAborts
    dialog.purchaseIndex = 0
    dialog.purchaseAmount = 0
    dialog.saleItem = Item.fromSeleneEmpty()

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, id)
end)

Network.handlePayload("illarion:merchant_dialog:buy", function(player, payload)
    local id = dialogId(payload)
    local index = PayloadValidation.integer(payload.index, 0)
    local amount = PayloadValidation.integer(payload.amount, 1)
    if not id or not index or not amount then return end
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, id)
    if not dialog or dialog.type ~= "MerchantDialog" then
        return
    end

    if not dialog.offers[index + 1] then return end
    dialog.result = MerchantDialog.playerBuys
    dialog.purchaseIndex = index
    dialog.purchaseAmount = amount
    dialog.saleItem = Item.fromSeleneEmpty()

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, id)
end)

Network.handlePayload("illarion:merchant_dialog:sell", function(player, payload)
    local id = dialogId(payload)
    local slotId = PayloadValidation.integer(payload.slotId, 0)
    local amount = PayloadValidation.integer(payload.amount, 1)
    if not id or not slotId or not amount then return end
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, id)
    if not dialog or dialog.type ~= "MerchantDialog" then
        return
    end

    local inventory = InventoryManager.GetInventoryAtView(character, dialog.viewId)
    if not inventory then
        return
    end

    dialog.result = MerchantDialog.playerSells
    dialog.purchaseIndex = 0
    dialog.purchaseAmount = 0

    local sourceItem = inventory:getItem(slotId)
    if not sourceItem then return end
    local item = sourceItem:deepCopy()
    if amount < item.count then
        item.count = amount
    end
    dialog.saleItem = item

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, id)
end)

Network.handlePayload("illarion:merchant_dialog:look_at", function(player, payload)
    local id = dialogId(payload)
    local lookAtList = PayloadValidation.integer(payload.lookAtList, 0, 2)
    local purchaseIndex = PayloadValidation.integer(payload.purchaseIndex, 0)
    if not id or lookAtList == nil or not purchaseIndex then return end
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, id)
    if not dialog or dialog.type ~= "MerchantDialog" then
        return
    end

    local list = lookAtList == MerchantDialog.listSell and dialog.offers
        or (lookAtList == 1 and dialog.primaryRequests or dialog.secondaryRequests)
    if not list[purchaseIndex + 1] then return end
    dialog.result = MerchantDialog.playerLooksAt
    dialog.lookAtList = lookAtList
    dialog.purchaseIndex = purchaseIndex

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, id)
end)

Network.handlePayload("illarion:crafting_dialog:abort", function(player, payload)
    local id = dialogId(payload)
    if not id then return end
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, id)
    if not dialog or dialog.type ~= "CraftingDialog" then
        return
    end

    dialog.result = CraftingDialog.playerAborts

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, id)
end)

Network.handlePayload("illarion:crafting_dialog:craft", function(player, payload)
    local id = dialogId(payload)
    local craftableId = PayloadValidation.integer(payload.craftableId, 0)
    local craftableAmount = PayloadValidation.integer(payload.craftableAmount, 1)
    if not id or not craftableId or not craftableAmount then return end
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, id)
    if not dialog or dialog.type ~= "CraftingDialog" then
        return
    end

    if not dialog.craftables[craftableId] then return end
    dialog.result = CraftingDialog.playerCrafts
    dialog.craftableId = craftableId
    dialog.craftableAmount = craftableAmount

    local craftingPossible = dialog.callback(dialog)
    if craftingPossible then
        character:abortAction()

        local stillToCraft = dialog.craftableAmount
        local craftingTime = dialog.craftableTime
        local sfx = dialog.sfx
        local sfxDuration = dialog.sfxDuration
        CraftingManager.StartCrafting(stillToCraft, craftingTime, sfx, sfxDuration, id)
    end

    DialogManager.ClearDialog(character, id)
end)
