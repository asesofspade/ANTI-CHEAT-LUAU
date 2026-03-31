local Config = require(script.Parent.Parent.config)

return function(player, character, data, flag)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not hrp or not humanoid then return end
	if humanoid.Health <= 0 then return end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	local origin = hrp.Position
	local size = hrp.Size

	local overlapping = workspace:GetPartBoundsInBox(
		hrp.CFrame,
		size * 0.9, 
		OverlapParams.new()
	)

	local solidHits = 0
	for _, part in overlapping do
		if part.CanCollide and not character:IsAncestorOf(part) then
			solidHits += 1
		end
	end

	if solidHits > 0 then
		data.noclipHits = (data.noclipHits or 0) + 1
		if data.noclipHits >= Config.NOCLIP_CONFIRM_TICKS then
			flag(player, "NoClip detectado", string.format("Overlapping=%d Pos=%s", solidHits, tostring(origin)))
			data.noclipHits = 0
		end
	else
		data.noclipHits = 0
	end
end
