local Registries = require("selene.registries")

SelectionDialog.SeleneConstructor = function(title, callback)
    return {
        type = "SelectionDialog",
        title = title,
        message = message,
        callback = callback,
        options = {}
    }
end

SelectionDialog.SeleneMethods.addOption = function(self, id, name)
    self.options[id] = name
end

SelectionDialog.SeleneMethods.setCloseOnMove = function(self)
    self.closeOnMove = true
end

SelectionDialog.SeleneMethods.getSuccess = function(self)
    return self.success
end

SelectionDialog.SeleneMethods.getSelectedIndex = function(self)
    return self.selectedIndex
end
