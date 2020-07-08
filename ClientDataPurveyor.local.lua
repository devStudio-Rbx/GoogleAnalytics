--// Initialization

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Overture = require(ReplicatedStorage:WaitForChild("Overture"))

local GetDeviceType = Overture:GetRemoteFunction("GA-GetDeviceType")

--// Functions

function GetDeviceType.OnClientInvoke()
	if GuiService:IsTenFootInterface() then
		return "Console"
	elseif (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
		local DeviceSize = workspace.CurrentCamera.ViewportSize
		
		if DeviceSize.Y > 600 then
			return "Tablet"
		else
			return "Mobile"
		end
	else
		return "Desktop"
	end
end