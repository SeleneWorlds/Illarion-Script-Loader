local Network = require("selene.network")

local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local m = {}

m.IdCounter = 0

function m.RequestDialog(user, dialog)
    m.IdCounter = m.IdCounter + 1
    local id = m.IdCounter
    local dialogs = user.SeleneEntity:getRuntimeData(DataKeys.Dialogs)
    dialogs[id] = dialog
    if dialog.type == "MessageDialog" then
        Network.sendToEntity(user.SeleneEntity, "illarion:message_dialog", {
            id = id,
            title = dialog.title,
            message = dialog.message
        })
    elseif dialog.type == "InputDialog" then
        Network.sendToEntity(user.SeleneEntity, "illarion:input_dialog", {
            id = id,
            title = dialog.title,
            description = dialog.description,
            multiline = dialog.multiline,
            maxChars = dialog.maxChars
        })
    elseif dialog.type == "MerchantDialog" then
        Network.sendToEntity(user.SeleneEntity, "illarion:merchant_dialog", {
            id = id,
            title = title
        })
    elseif dialog.type == "SelectionDialog" then
        Network.sendToEntity(user.SeleneEntity, "illarion:selection_dialog", {
            id = id,
            title = title,
            message = message
        })
    elseif dialog.type == "CraftingDialog" then
        Network.sendToEntity(user.SeleneEntity, "illarion:crafting_dialog", {
            id = id,
            title = title
        })
    end
end

function m.GetDialog(character, id)
    local dialogs = character.SeleneEntity:getRuntimeData(DataKeys.Dialogs)
    local dialog = dialogs[id]
    if dialog then
        if dialog.type == "MessageDialog" then
            setmetatable(dialog, MessageDialog.SeleneMetatable)
        elseif dialog.type == "InputDialog" then
            setmetatable(dialog, InputDialog.SeleneMetatable)
        elseif dialog.type == "MerchantDialog" then
            setmetatable(dialog, MerchantDialog.SeleneMetatable)
        elseif dialog.type == "SelectionDialog" then
            setmetatable(dialog, SelectionDialog.SeleneMetatable)
        elseif dialog.type == "CraftingDialog" then
            setmetatable(dialog, CraftingDialog.SeleneMetatable)
        end
    end
    return dialog
end

function m.ClearDialog(character, id)
    local dialogs = character.SeleneEntity:getRuntimeData(DataKeys.Dialogs)
    dialogs[id] = nil
end

return m