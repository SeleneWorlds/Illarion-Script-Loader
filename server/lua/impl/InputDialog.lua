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