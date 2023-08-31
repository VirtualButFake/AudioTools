local apiHandler = {}

local api = {}
api.__index = api

local net = require("@lune/net")
local process = require("@lune/process")
local task = require("@lune/task")

local logger = require("logger")

local function runCommand(command: string, parameters: { string } | string)
	if typeof(parameters) == "string" then
		parameters = parameters:split(" ")
	end

	return process.spawn(command, parameters :: { string })
end

local function request(requestConfig)
	-- wrapper for net.request that automatically repeats requests on rate limits
	local response

	while not response or response.statusCode == 429 do
		response = net.request(requestConfig)

		if response.statusCode == 429 then
			-- wait 5 seconds and repeat
			task.wait(5)
		end
	end

	return response
end

function apiHandler.new(cookie: string?): apiHandler
	if not cookie then
		error("Failed to get cookie!")
	end

	return setmetatable({ _cookie = cookie }, api) :: apiHandler
end

function api.getToken(self: apiHandler)
	local response = request({
		url = "https://auth.roblox.com",
		method = "POST",
		headers = {
			Cookie = self._cookie,
		},
	})

	if response.statusCode == 403 then
		local token = response.headers["x-csrf-token"]
		self._csrf = token

		return token
	end

	logger.error(`Could not get CSRF token, request error:`)

	return nil
end

function api.getOperationData(self: apiHandler, operationId: string, apiKey: string)
	local function repeatCall()
		return request({
			url = `https://apis.roblox.com/assets/v1/operations/{operationId}`,
			headers = {
				["x-api-key"] = apiKey,
			},
			method = "GET",
		})
	end

	local resp = repeatCall()
	local attempts = 0

	while resp.statusCode ~= 200 or not net.jsonDecode(resp.body).done do
		task.wait(5)
		attempts += 1 

		if attempts > 15 then -- 15 attempts, for rate limits (which are generally 60 seconds, sowe account for a bit more)
			return nil
		end

		resp = repeatCall()
	end

	return net.jsonDecode(resp.body)
end

function api.uploadSound(self: apiHandler, options: assetUploadOptions)
	local params = {
		"assets",
		"create",
		`--description "{options.description}"`,
		`--display-name {options.name}`,
		`--creator-id {options.creator_id}`,
		`--creator-type {options.creator_type}`,
		`--filepath {options.path}`,
		`--api-key {options.api_key}`,
	}

	local newParams = {}

	for i, param in params do
		if param:find("^-%-") then
			-- new param = split on first space
			local flag, value = param:match("^(%S+)%s+(.+)")
			table.insert(newParams, flag)
			table.insert(newParams, value)
			continue
		end

		table.insert(newParams, param)
	end

	local resp = runCommand("rbxcloud", newParams)

	local id = resp.stdout:match("operations/([%w%-]+)")

	if id then
		-- get asset data
		local assetData = self:getOperationData(id, options.api_key)

		if assetData == nil then
			logger.error(`Could not get asset data of {options.path}, skipping asset.`)
			return { success = false }
		end

		local moderationResult = assetData.response.moderationResult

		if moderationResult and moderationResult.moderationState ~= "MODERATION_STATE_APPROVED" then
			logger.error(`Asset {options.path} was not approved. Skipping asset..`)
			return { success = false }
		end

		return {
			success = true,
			response = assetData.response,
		} :: uploadResponse
	end

	return { success = false }
end

function api.authenticateAudio(self: apiHandler, audioAsset: string, experienceIds: { string | number })
	-- {"subjectType":"Universe","subjectId":"' .. tostring(experienceId) .. '","action":"Use"}
	local body = {
		requests = {},
	}

	for _, id in experienceIds do
		table.insert(body.requests, {
			subjectType = "Universe",
			subjectId = id,
			action = "Use",
		})
	end

	local res = request({
		url = `https://apis.roblox.com/asset-permissions-api/v1/assets/{audioAsset}/permissions`,
		method = "PATCH",
		body = net.jsonEncode(body, false),
		headers = {
			Cookie = self._cookie,
			["X-Csrf-Token"] = self._csrf or self:getToken(),
			["Content-Type"] = "application/json-patch+json",
		},
	})

	if res.statusMessage == "OK" and res.ok == true then
		return true
	end

	return false
end

type uploadResponse = {
	success: boolean,
	response: {
		[string]: any,
		assetId: string,
		assetType: string,
		displayName: string,
		creationContext: { creator: { [string]: any } },
		description: string,
	},
}

type assetUploadOptions = {
	name: string,
	path: string,
	asset_type: "audio-mp3" | "audio-ogg" | "decal-png" | "decal-jpeg" | "decal-bmp" | "decal-tga" | "model_fbx",
	creator_id: string,
	creator_type: "group" | "user",
	description: string,
	api_key: string,
}

type apiHandler = typeof(setmetatable({} :: {
	_cookie: string,
	_csrf: string?,
}, api))

return apiHandler
