local Network = require("selene.network")
local Config = require("selene.config")

local DialogManager = require("illarion-script-loader.server.lua.lib.dialogManager")
local ActionManager = require("illarion-script-loader.server.lua.lib.actionManager")
local DataFields = require("illarion-script-loader.server.lua.lib.dataFields")
local DataKeys = require("illarion-script-loader.server.lua.lib.datakeys")

local useLegacyMenuCallbacks = Config.getProperty("useLegacyMenuCallbacks") == "true"

Character.SeleneMethods.sendMenu = function(user, menu)
    if useLegacyMenuCallbacks and menu.callback == nil then
        menu.callback = function(dialog)
            if not dialog.success then
                return
            end

            local lastAction = user.SeleneEntity:getRuntimeData(DataKeys.LastAction)
            local actionFunction = lastAction[DataFields.LastActionFunction]
            local actionArgs = lastAction[DataFields.LastActionArgs]
            if type(actionFunction) ~= "function" or not actionArgs or #actionArgs < 5 then
                return
            end

            local resumedArgs = table.pack(table.unpack(actionArgs, 1, actionArgs.n or #actionArgs))
            resumedArgs[5] = dialog.selectedItemId
            lastAction[DataFields.LastActionArgs] = resumedArgs
            ActionManager.CallActionFunction(actionFunction, resumedArgs, Action.none)
        end
    end
    DialogManager.RequestDialog(user, menu)
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
