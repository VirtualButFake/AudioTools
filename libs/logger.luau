local logger = {}

local stdio = require("@lune/stdio")

local function writeOut(textTable: { { string } })
	for _, textEntry in textTable do
		local text = textEntry[1]
		local color = textEntry[2]

		stdio.write(`{stdio.color(color)}{text}`)
	end

	stdio.write("\n")
end

function logger.error(msg: string)
    writeOut({
        { "[", "black" },
        { "ERROR", "red" },
        { "] ", "black" },
        { msg, "reset" },
    })
end

function logger.success(msg: string)
    writeOut({
        { "[", "black" },
        { "SUCCESS", "green" },
        { "] ", "black" },
        { msg, "reset" },
    })
end

function logger.info(msg: string)
    writeOut({
        { "[", "black" },
        { "INFO", "white" },
        { "] ", "black" },
        { msg, "reset" },
    })
end

function logger.prompt(msg: string)
    writeOut({
        { "[", "black" },
        { "PROMPT", "yellow" },
        { "] ", "black" },
        { msg, "reset" },
    })

    return stdio.prompt()
end

return logger