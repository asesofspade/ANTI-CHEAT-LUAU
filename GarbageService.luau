local GarbageService = {}
local rs = game:GetService("RunService")
local remoteEvent

local array_types = {
	localscripts = {
		action = "kick",
		message = "You have been kicked for exploiting."
	},
	humanoidproperties = {
		action = "warning",
		message = "Do not modify ur character properties."
	},
	partpropertymodify = {
		action = "warning",
		message = "Do not modify game parts."
	},
}
if rs:IsClient() then
	local playerGui = game.Players.LocalPlayer.PlayerGui
	local warningsGui = playerGui:WaitForChild("Warnings")
	local container = warningsGui:WaitForChild("container")
	local warn_title = container:WaitForChild("title")
	local warn_reason = container:WaitForChild("reasson")
	local player = game.Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	
	remoteEvent = game.ReplicatedStorage:WaitForChild("GarbageRemote")
	
	local function showWarning(action, message)
		warn_title.Text = action:upper()
		warn_reason.Text = message
		container.Visible = true
		task.wait(3)
		container.Visible = false
	end

	local playerScripts = player:WaitForChild("PlayerScripts")
	for _, sibling in ipairs(playerScripts:GetChildren()) do
		if sibling.Name ~= "Watcher" then
			sibling.AncestryChanged:Connect(function(_, newParent)
				if newParent == nil then
					local config = array_types["localscripts"]
					showWarning(config.action, config.message)
					remoteEvent:FireServer("localscripts", sibling.Name)
				end
			end)
		end
	end

	local savedProperties = {
		WalkSpeed  = humanoid.WalkSpeed,
		JumpPower  = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight,
		MaxHealth  = humanoid.MaxHealth,
	}
	for property, value in pairs(savedProperties) do
		humanoid:GetPropertyChangedSignal(property):Connect(function()
			humanoid[property] = value
			local config = array_types["humanoidproperties"]
			showWarning(config.action, config.message)
			remoteEvent:FireServer("humanoidproperties", property)
		end)
	end

	local savedParts = {}
	local characterModel = player.Character or player.CharacterAdded:Wait()
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and not part:IsA("Terrain") and not part:IsDescendantOf(characterModel) then
			savedParts[part] = {
				CFrame       = part.CFrame,
				Size         = part.Size,
				Color        = part.Color,
				Material     = part.Material,
				Transparency = part.Transparency,
				Reflectance  = part.Reflectance,
				CanCollide   = part.CanCollide,
				CanTouch     = part.CanTouch,
				CanQuery     = part.CanQuery,
				Anchored     = part.Anchored,
				Massless     = part.Massless,
				CastShadow   = part.CastShadow,
				BrickColor   = part.BrickColor,
			}
		end
	end

	local warned = false
	game.RunService.Heartbeat:Connect(function()
		for part, properties in pairs(savedParts) do
			for property, value in pairs(properties) do
				if part[property] ~= value then
					part[property] = value
					if not warned then
						warned = true
						local config = array_types["partpropertymodify"]
						remoteEvent:FireServer("partpropertymodify", property)
						showWarning(config.action, config.message)
						task.wait(3)
						warned = false
					end
				end
			end
		end
	end)

else
	remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = "GarbageRemote"
	remoteEvent.Parent = game.ReplicatedStorage
	
	game.Players.PlayerAdded:Connect(function(player)
		remoteEvent.OnServerEvent:Connect(function(plr, typeDetected, detail)
			if plr == player then
				local config = array_types[typeDetected]
				if not config then return end
				if config.action == "kick" then
					player:Kick(config.message)
				elseif config.action == "warning" then
					return
				end
			end
		end)
	end)
end
return GarbageService
