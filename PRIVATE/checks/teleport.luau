local Config = require(script.Parent.Parent.config)

return function(player, character, data, flag)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local currentPos = hrp.Position

	if not data.lastPosition then
		data.lastPosition = currentPos
		return
	end

	local ping = player:GetNetworkPing() * 1000

	if ping > 400 then
		data.lastPosition = currentPos
		return
	end

	local distance = (currentPos - data.lastPosition).Magnitude

	local maxSpeed    = Config.MAX_REAL_SPEED
	local timeElapsed = Config.CHECK_INTERVAL
	local lagMargin   = math.clamp(ping / 1000 * maxSpeed, 0, 20)
	local maxAllowed  = (maxSpeed * timeElapsed) + lagMargin + Config.TP_TOLERANCE

	if distance > maxAllowed then
		data.tpHits = (data.tpHits or 0) + 1

		if data.tpHits >= 2 then
			flag(player, "Teleport detectado", string.format(
				"Dist=%.1f Max=%.1f Ping=%dms Pos=%s",
				distance, maxAllowed, ping, tostring(currentPos)
			))
			data.tpHits = 0
		end
	else
		data.tpHits = 0
	end

	data.lastPosition = currentPos
end
