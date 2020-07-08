--// Initialization

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")

local Overture = require(ReplicatedStorage:WaitForChild("Overture"))

local GetDeviceType = Overture:GetRemoteFunction("GA-GetDeviceType")

local API = {}
API.__index = API
API.DefaultData = {}
API.StoredPlayerData = {}

local RobloxVersion, LuaVersion = getfenv().version(), _VERSION
local ValueReplacements = {[true] = "1", [false] = "0"}
local UserAgentMasks = {
	["Mobile"] = "(Linux; Android)",
	["Tablet"] = "(Linux; Android 6.0.1; SHIELD Tablet K1 Build/MRA58K; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/55.0.2883.91"
}

--// Variables

API._Debug = RunService:IsStudio()
API.CollectEndpoint = string.format("http://www.google-analytics.com%s/collect", API._Debug and "/debug" or "")
API.BatchEndpoint = string.format("http://www.google-analytics.com%s/batch", API._Debug and "/debug" or "")

--// Functions

function GetDeviceType.OnServerInvoke()
	--/ Prevents remote queue overflow
end

local function MergeTables(...)
	local NewTable = {}
	
	for _, Table in ipairs({...}) do
		for Index, Value in next, Table do
			NewTable[Index] = Value
		end
	end
	
	return NewTable
end

local function RemovePlayerNames(SubmittedString)
	local RemovedPlayerId, FoundCount = 1, nil
	local NewString = SubmittedString
	
	for _, Player in next, PlayerService:GetPlayers() do
		NewString, FoundCount = string.gsub(NewString, Player.Name, string.format("<Player%i>", RemovedPlayerId))
		
		if FoundCount > 0 then
			RemovedPlayerId += 1
		end
	end
	
	return NewString
end

local function EncodeQuery(Data)
	local DataText = ""
	
	for Key, Value in next, Data do
		DataText = DataText .. string.format("&%s=%s",
			HttpService:UrlEncode(Key),
			HttpService:UrlEncode(ValueReplacements[Value] or Value)
		)
	end
	
	return string.sub(DataText, 2)
end

local function EncodeBatch(BatchData)
	local DataText = ""
	
	for Index, Batch in next, BatchData do
		if Index > 1 then
			DataText = (DataText .. "/n")
		end
		
		DataText = (DataText .. EncodeQuery())
	end
end

local function GetUserId(Player)
	return (typeof(Player) == "Instance" and Player.UserId or Player)
end

local function GetPlayerLocalization(Player)
	local Player = (typeof("Instance") and Player or PlayerService:GetPlayerByUserId(Player))
	local Success, GeoID = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(Player)
	end)
	
	if Player and Success then
		return GeoID
	end
end

local function GetUserAgent(Player)
	local Player = (typeof("Instance") and Player or PlayerService:GetPlayerByUserId(Player))
	local DeviceType = GetDeviceType:InvokeClient(Player)
	
	return UserAgentMasks[DeviceType] or ""
end

function API:GetIdentificationData(Player)
	if not Player then
		return {
			["cid"] = game.JobId,
			["ds"] = "Server",
		}
	end
	
	local UserId = GetUserId(Player)
	local Player = (typeof("Instance") and Player or PlayerService:GetPlayerByUserId(Player))
	local PlayerData = self.StoredPlayerData[UserId]
	
	if PlayerData then
		return PlayerData
	end
	
	PlayerData = {
		["ds"] = "Player",
		["uid"] = UserId,
		["cid"] = string.sub(HttpService:GenerateGUID(), 2, -2),
		["ua"] = string.format("Roblox/%s Lua/%s %s", RobloxVersion, LuaVersion, GetUserAgent(Player)),
		
		["cs"] = Player.FollowUserId > 0 and "Followed" or nil,
		["ul"] = LocalizationService:GetTranslatorForPlayerAsync(Player).LocaleId,
		["geoid"] = GetPlayerLocalization(Player),
	}
	
	self.StoredPlayerData[UserId] = PlayerData
	return PlayerData
end

function API:FlushPlayerData(Player)
	self.StoredPlayerData[GetUserId(Player)] = nil
end

function API:SendRequest(Data)
	return xpcall(
		HttpService.PostAsync, warn, HttpService, API.CollectEndpoint,
		EncodeQuery(MergeTables(self.DefaultData, Data))
	)
end

function API:ReportException(Player, Exception, IsFatal)
	assert(Exception ~= nil, "Event argument \"Exception\" is required.")
	
	return self:SendRequest(MergeTables(self:GetIdentificationData(Player), {
		["t"] = "exception",
		
		["exd"] = RemovePlayerNames(Exception),
		["exf"] = IsFatal or false,
	}))
end

function API:ReportEvent(Player, Category, Action, Label, Value, Overrides)
	assert(Player ~= nil, "Event argument \"Player\" is required.")
	assert(Action ~= nil, "Event argument \"Action\" is required.")
	
	return self:SendRequest(MergeTables(self:GetIdentificationData(Player), {
		["t"] = "event",
		
		["ec"] = Category or "Game",
		["ea"] = Action,
		["el"] = Label,
		["ev"] = Value,
	}, Overrides))
end

function API.new(MeasurementId, Overrides)
	local self = setmetatable({}, API)
	
	self.MeasurementId = MeasurementId
	self.DefaultData = MergeTables({
		["v"] = 1,
		["tid"] = self.MeasurementId,
		["aip"] = true,
		
		["av"] = game.PlaceVersion,
	}, Overrides)
	
	PlayerService.PlayerAdded:Connect(function(Player)
		self:ReportEvent(Player, nil, "Joining", game.PlaceId, nil, {["sc"] = "start"})
	end)
	
	PlayerService.PlayerRemoving:Connect(function(Player)
		self:ReportEvent(Player, nil, "Leaving", game.PlaceId, nil, {["sc"] = "end"})
		self:FlushPlayerData(Player)
	end)
	
	coroutine.wrap(function()
		while wait(30) do
			for _, Player in next, PlayerService:GetPlayers() do
				self:ReportEvent(Player, nil, "Heartbeat")
			end
		end
	end)()
	
	return self
end

return API