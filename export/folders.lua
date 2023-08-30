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

return function(fileMap)
    fs.removeDir("./output")

	iterateTable(fileMap, function(i, v, resp)
		resp = deepCopy(resp) or {}

		table.insert(resp, i)

		if typeof(v) == "table" then
			fs.writeDir(`./output/{table.concat(resp, "/")}`)
		elseif typeof(v) == "string" then
			fs.writeFile(`./output/{table.concat(resp, "/")}.lua`, `return "rbxassetid://{v}"`)
		end

		return resp
	end)
end
