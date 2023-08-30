local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

local function iterateTable(entry, callback, resp)
	for index, value in entry do
		local new = callback(index, value, resp)

		if typeof(value) == "table" then
			iterateTable(value, callback, new)
		end
	end
end

return function(fileMap)
	local AudioParent = roblox.Instance.new("Folder")

	iterateTable(fileMap, function(i, v, resp)
		if typeof(v) == "table" then
			local folder = roblox.Instance.new("Folder")
			folder.Name = i
			folder.Parent = resp
			return folder
		else
			local sound = roblox.Instance.new("Sound")
			sound.SoundId = "rbxassetid://" .. v
			sound.Name = i
			sound.Parent = resp
		end

		return
	end, AudioParent)

    
    fs.writeFile("output.rbxm", roblox.serializeModel({ AudioParent }, false))
end
