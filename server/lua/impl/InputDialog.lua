InputDialog.SeleneConstructor = function(title, description, multiline, maxChars, callback)
    return {
        type = "InputDialog",
        title = title,
        description = description,
        multiline = multiline,
        maxChars = maxChars,
        callback = callback
    }
end

InputDialog.SeleneMethods.getInput = function(self)
    return self.input
end

InputDialog.SeleneMethods.getSuccess = function(self)
    return self.success
end
