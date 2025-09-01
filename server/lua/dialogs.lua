local Network = require("selene.network")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")
local DialogManager = require("illarion-script-loader.server.lua.lib.dialogManager")

Network.HandlePayload("illarion:message_dialog", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, payload.id)
    if not dialog or dialog.type ~= "MessageDialog" then
        return
    end

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, payload.id)
end)

Network.HandlePayload("illarion:input_dialog", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, payload.id)
    if not dialog or dialog.type ~= "InputDialog" then
        return
    end

    dialog.success = payload.success
    dialog.input = payload.success and payload.input or ""

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, payload.id)
end)

Network.HandlePayload("illarion:selection_dialog", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, payload.id)
    if not dialog or dialog.type ~= "SelectionDialog" then
        return
    end

    dialog.success = payload.success
    dialog.selectedIndex = payload.success and payload.selectedIndex or -1

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, payload.id)
end)

Network.HandlePayload("illarion:merchant_dialog:abort", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, payload.id)
    if not dialog or dialog.type ~= "MerchantDialog" then
        return
    end

    dialog.result = MerchantDialog.playerAborts
    dialog.purchaseIndex = 0
    dialog.purchaseAmount = 0
    dialog.saleItem = Item.fromSeleneEmpty()

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, payload.id)
end)

Network.HandlePayload("illarion:merchant_dialog:buy", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, payload.id)
    if not dialog or dialog.type ~= "MerchantDialog" then
        return
    end

    dialog.result = MerchantDialog.playerBuys
    dialog.purchaseIndex = payload.index
    dialog.purchaseAmount = payload.amount
    dialog.saleItem = Item.fromSeleneEmpty()

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, payload.id)
end)

Network.HandlePayload("illarion:merchant_dialog:sell", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, payload.id)
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

    local item = inventory:GetItem(payload.slotId):DeepCopy()
    if payload.amount < item.count then
        item.count = payload.amount
    end
    dialog.saleItem = item

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, payload.id)
end)

Network.HandlePayload("illarion:merchant_dialog:look_at", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, payload.id)
    if not dialog or dialog.type ~= "MerchantDialog" then
        return
    end

    dialog.result = MerchantDialog.playerLooksAt
    dialog.lookAtList = payload.lookAtList
    dialog.purchaseIndex = payload.purchaseIndex

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, payload.id)
end)

Network.HandlePayload("illarion:crafting_dialog:abort", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, payload.id)
    if not dialog or dialog.type ~= "CraftingDialog" then
        return
    end

    dialog.result = CraftingDialog.playerAborts

    dialog.callback(dialog)
    DialogManager.ClearDialog(character, payload.id)
end)

Network.HandlePayload("illarion:crafting_dialog:craft", function(player, payload)
    local character = Character.fromSelenePlayer(player)
    local dialog = DialogManager.GetDialog(character, payload.id)
    if not dialog or dialog.type ~= "CraftingDialog" then
        return
    end

    dialog.result = CraftingDialog.playerCrafts
    dialog.craftableId = payload.craftableId
    dialog.craftableAmount = payload.craftableAmount

    local craftingPossible = dialog.callback(dialog)
    if craftingPossible then
        character:abortAction()

        local stillToCraft = dialog.craftableAmount
        local craftingTime = dialog.craftableTime
        local sfx = dialog.sfx
        local sfxDuration = dialog.sfxDuration
        CraftingManager.StartCrafting(stillToCraft, craftingTime, sfx, sfxDuration, payload.id)
    end

    DialogManager.ClearDialog(character, payload.id)
end)
