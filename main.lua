local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local apiConstructor = require("libs/api")
local logger = require("libs/logger")

local promptCounter = 1
local processArgs = process.args

local function iterateTable(entry, callback, resp)
	for index, value in entry do
		local new = callback(index, value, resp)

		if typeof(value) == "table" then
			iterateTable(value, callback, new)
		end
	end
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

local function iterateDir(path, callback: (path: string, dir: boolean) -> ())
	local files = fs.readDir(path)

	for _, file in files do
		local filePath = `{path}/{file}`

		if fs.isDir(filePath) then
			callback(filePath, true)
			iterateDir(filePath, callback)
		else
			callback(filePath, false)
		end
	end
end

local function createNestedTable(t, indices)
	local current = t

	for i, v in indices do
		if current[v] == nil and i ~= #indices then
			current[v] = {}
		elseif i == #indices then
			break
		end

		current = current[v]
	end

	return current
end

local function traverseTable(t, indices)
	local current = t

	for i, v in indices do
		if current[v] == nil and i ~= #indices then
			current[v] = {}
		end

		current = current[v]
	end

	return current
end

local function prompt(promptMessage, validationFunction)
	local passedArgument = processArgs[promptCounter]
	promptCounter += 1

	local validationResponse, newPrompt
	if passedArgument then
		validationResponse, newPrompt = validationFunction(passedArgument)
		if validationResponse then
			return if newPrompt ~= nil then newPrompt else passedArgument
		end
	end

	local resp = logger.prompt(promptMessage)
	validationResponse, newPrompt = validationFunction(resp)

	while validationResponse ~= true do
		logger.error(validationResponse)
		resp = logger.prompt(promptMessage)
		validationResponse, newPrompt = validationFunction(resp)
	end

	return if newPrompt ~= nil then newPrompt else resp
end

local api = apiConstructor.new(roblox.getAuthCookie(false))

local settings = {}

settings.mode = prompt(
	"Would you like to upload or bulk authenticate audios? Type either 'upload' or 'authenticate'",
	function(resp)
		if resp:lower() ~= "upload" and resp:lower() ~= "authenticate" then
			return "Did not get either 'upload' or 'authenticate'"
		end

		return true, resp:lower()
	end
)

settings.folder = prompt(`What subfolder would you like to {settings.mode:lower()}?`, function(resp)
	local path = `./{resp}`

	if not fs.isDir(path) then
		return `Could not find directory {path}, make sure that this is a valid subdirectory`
	end

	return true, path
end)

if settings.mode == "upload" then
	settings.outputType = prompt(
		"What kind of output do you want? Options are 'rbxm', 'module' and 'folder'",
		function(resp)
			if
				resp:lower() ~= "rbxm"
				and resp:lower() ~= "json"
				and resp:lower() ~= "module"
				and resp:lower() ~= "folder"
			then
				return "Did not get either 'rbxm', 'module' or 'folder'"
			end

			return true, resp:lower()
		end
	)

	settings.creatorType = prompt("Is the creator a 'group' or a 'user'?", function(resp)
		if resp:lower() ~= "group" and resp:lower() ~= "user" then
			return "Did not get either 'group' or 'user'"
		end

		return true, resp:lower()
	end)

	settings.creatorID = prompt(
		"Insert the creator ID here. For a group, this is the group ID, and for a user, this is their user ID.",
		function(resp)
			if tonumber(resp) then
				return true, resp
			end

			return "Did not get a valid ID."
		end
	)

	settings.apiKey = prompt(
		"Insert your ROBLOX API key. You can find this on https://create.roblox.com/dashboard/credentials",
		function(resp)
			return true, resp
		end
	)
end

settings.experienceIDs = prompt(
	settings.mode == "upload"
			and "Do you want to authenticate all newly uploaded sound assets? If so, enter the experience ID(s) under which you want to authenticate the assets, seperated by a comma. Otherwise, type 'none'"
		or "What experiences do you want to add your authenticated assets to? Enter all experience IDs, seperated by comma.",
	function(resp)
		local ids = {}

		if resp == "none" and settings.mode == "upload" then
			return true, false
		end

		if tonumber(resp) then
			return true, { resp }
		end

		for id in string.gmatch(resp, "([^,]+)") do
			table.insert(ids, tonumber(id))
		end

		if #ids == 0 then
			return "Failed to get at least 1 experience ID. Make sure to enter the IDs seperated by comma, for example, '1, 2'"
		end

		return true, ids
	end
)

local fileMap = {}
local succ, oldOutput = pcall(require, settings.folder .. "/data.lua")

if not succ then
	oldOutput = {}
end

iterateDir(settings.folder, function(path, isFolder)
	local pathSplit = path:split("/")
	table.remove(pathSplit, 1)
	table.remove(pathSplit, 1)

	local fileName = pathSplit[#pathSplit]:match("(.+)%..+$")
	local fileExtension = pathSplit[#pathSplit]:match("^.+(%..+)$")

	if fileName and not isFolder and fileExtension ~= ".lua" then
		fileName = tonumber(fileName) or fileName

		local entry = createNestedTable(fileMap, pathSplit)

		if typeof(fileName) == "number" and #entry <= fileName then
			fileName = #entry + 1
		end

		pathSplit[#pathSplit] = fileName

		local oldEntry = traverseTable(oldOutput, pathSplit)

		entry[fileName] = path

		if oldEntry then
			entry[fileName] = oldEntry

			-- auth
			if settings.mode == "authenticate" then
				api:authenticateAudio(oldEntry, settings.experienceIDs)
				logger.success(`Succesfully authenticated audio asset {oldEntry}`)
			end

			return
		end

		-- perform operations
		if settings.mode == "upload" then -- make sure to skip data file
			local audioType = (fileExtension == ".ogg" and "audio-ogg") or (fileExtension == ".mp3" and "audio-mp3")

			if not audioType then
				logger.error(`File extension was not 'ogg' or 'mp3'. Skipping {path}`)
				return
			end

			logger.info(`Now uploading {path}...`)

			local data = api:uploadSound({
				name = table.concat(pathSplit, "_"),
				path = path,
				audioType = fileExtension,
				creator_id = settings.creatorID,
				creator_type = settings.creatorType,
				description = "automatically uploaded",
				api_key = settings.apiKey,
			})

			logger.success(`Uploaded {path} to {data.response.assetId}`)
			if settings.experienceIDs then
				api:authenticateAudio(data.response.assetId, settings.experienceIDs)
				logger.success(
					`Authenticated asset {data.response.assetId} for experiences {table.concat(settings.experienceIDs, ", ")}`
				)
			end

			entry[fileName] = data.response.assetId
		end
	end
end)

-- save new data
fs.writeFile(settings.folder .. "/data.lua", tableToString(fileMap))

-- write to file
if settings.outputType then
	local export = require(`export/{settings.outputType}`)
	export(fileMap)
end
