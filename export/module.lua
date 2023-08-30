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

local function tableToString(t)
	-- i know, i know, bad way of doing this but the important part is that it works
	-- only supports tables & strings
	-- there's not much context we have, so we can only work with extremely basic things
	local returnString = "return {"
	local inTable = false
	local openAmount, closeAmount = 0, 0

	iterateTable(t, function(i, v, resp)
		if inTable and resp ~= inTable then 
			closeAmount += 1
			returnString ..= "},"
			inTable = false
		end

		if typeof(v) == "table" then 
			openAmount += 1
			returnString ..= `{i}=` .. "{" -- luau lsp doesnt like it when i escaped a curly bracket
			inTable = v
			return v
		elseif typeof(v) == "string" then  
			if typeof(i) == "number" then 
				returnString ..= `\"{v}\",`
			else 
				returnString ..= `{i}=\"{v}\",`
			end

			return inTable
		end

		return
	end)


	returnString ..= ("}"):rep(openAmount - closeAmount + 1)

	return returnString
end


return function(fileMap)
    iterateTable(fileMap, function(i, v, resp)
        if typeof(v) == "string" then
            resp[i] = "rbxassetid://" .. v
            return
        end

        return v
    end, fileMap)

    fs.writeFile("./output.lua", tableToString(fileMap))
end
