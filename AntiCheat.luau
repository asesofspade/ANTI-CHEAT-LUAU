local AntiCheat = {}

local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Folder = script.Parent
local Config      = require(Folder.config)
local PlayerData  = require(Folder.playerData)

local checks = {
	require(Folder.checks.speed),
	require(Folder.checks.fly),
	require(Folder.checks.noclip),
	require(Folder.checks.teleport), 
}

local webhookUrl = game.ServerStorage.WebHook.Value

local function sendToDiscord(player, reason, detail)
    local message = string.format(
        "**%s** , type: %s , details: %s",
        player.Name,
        tostring(reason or "N/A"),
        tostring(detail or "N/A")
    )

    local payload = HttpService:JSONEncode({
        player = player.Name,
        type = tostring(reason or "N/A"),
        details = tostring(detail or "N/A"),
        timestamp = tick(),
        content = message,
        username = "Anti-Cheat"
    })

    local success, result = pcall(function()
        return HttpService:PostAsync(
            webhookUrl,
            payload,
            Enum.HttpContentType.ApplicationJson,
            false
        )
    end)

    if not success then
        warn("Webhook error:", result)
    else
		return
	end

    return success, result
end
local function flag(player, reason, detail)
	local data = PlayerData.get(player)
	if not data then return end

	local now     = tick()
	local elapsed = now - data.lastViolationTick
	local decay   = math.floor(elapsed / Config.VIOLATION_DECAY_TIME)
	data.violations = math.max(0, data.violations - decay)
	data.lastViolationTick = now

	data.violations += 1

	warn(string.format("%-20s , %-35s , %s , %d/%d",
		player.Name, reason, detail or "", data.violations, Config.MAX_VIOLATIONS))

	if data.violations >= Config.MAX_VIOLATIONS then
		player:Kick("Comportamiento sospechoso detectado.")
		sendToDiscord(player, reason, detail)
	end
end

local function monitorCharacter(player, character)
	local data = PlayerData.get(player)
	if not data then return end

	PlayerData.resetCharacter(player)
	character:WaitForChild("HumanoidRootPart")
	character:WaitForChild("Humanoid")

	task.spawn(function()
		while character.Parent and player.Parent do
			task.wait(Config.CHECK_INTERVAL)
			if not character.Parent then break end

			for _, check in checks do
				local ok, err = pcall(check, player, character, data, flag)
				if not ok then
					warn("[AntiCheat] Error en check:", err)
				end
			end
		end
	end)
end

local function onPlayerAdded(player)
	PlayerData.init(player)
	player.CharacterAdded:Connect(function(character)
		monitorCharacter(player, character)
	end)
	if player.Character then
		monitorCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		PlayerData.remove(player)
	end)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

return AntiCheat
