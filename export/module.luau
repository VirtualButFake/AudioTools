local fs = require("@lune/fs")

local function iterateTable(entry, callback, resp)
	for index, value in entry do
		local new = callback(index, value, resp)

		if typeof(value) == "table" then
			iterateTable(value, callback, new)
		end
	end
end

local function deepCopy(original)
	if not original then
		return
	end

	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

local stringToTable = require("../libs/stringToTable").encode

return function(fileMap)
    iterateTable(fileMap, function(i, v, resp)
        if typeof(v) == "string" then
            resp[i] = "rbxassetid://" .. v
            return
        end

        return v
    end, fileMap)

    fs.writeFile("./output.lua", "return " .. stringToTable(fileMap))
end
