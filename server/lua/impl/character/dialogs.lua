local Network = require("selene.network")

local DialogManager = require("illarion-script-loader.server.lua.lib.dialogManager")

Character.SeleneMethods.sendMenu = function(user, menu)
    DialogManager.RequestDialog(user, dialog)
end

Character.SeleneMethods.requestMessageDialog = function(user, dialog)
    DialogManager.RequestDialog(user, dialog)
end

Character.SeleneMethods.requestInputDialog = function(user, dialog)
    DialogManager.RequestDialog(user, dialog)
end

Character.SeleneMethods.requestMerchantDialog = function(user, dialog)
    DialogManager.RequestDialog(user, dialog)
end

Character.SeleneMethods.requestSelectionDialog = function(user, dialog)
    DialogManager.RequestDialog(user, dialog)
end

Character.SeleneMethods.requestCraftingDialog = function(user, dialog)
    DialogManager.RequestDialog(user, dialog)
end

Character.SeleneMethods.sendBook = function(user, bookId)
    Network.sendToEntity(user.SeleneEntity, "illarion:book", {id = bookId})
end