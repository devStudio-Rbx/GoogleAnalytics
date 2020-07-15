--// Initialization

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Overture = require(ReplicatedStorage:WaitForChild("Overture"))

local GetDeviceType = Overture:GetRemoteFunction("GA-GetDeviceType")
local GetViewportSize = Overture:GetRemoteFunction("GA-GetViewportSize")

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

function GetViewportSize.OnClientInvoke()
	local Viewport = workspace.CurrentCamera.ViewportSize
	
	return string.format("%ix%i", Viewport.X, Viewport.Y)
end
