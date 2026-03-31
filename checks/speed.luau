local Config = require(script.Parent.Parent.config)

return function(player, character, data, flag)
	local humanoid = character:FindFirstChild("Humanoid")
	local hrp      = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end

	if humanoid.WalkSpeed > Config.MAX_WALKSPEED + 0.5 then
		humanoid.WalkSpeed = Config.MAX_WALKSPEED
		flag(player, "WalkSpeed modificado", string.format("WalkSpeed=%.1f", humanoid.WalkSpeed))
	end

	local vel        = hrp.AssemblyLinearVelocity
	local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

	if horizSpeed > Config.MAX_REAL_SPEED then
		flag(player, "Speed hack", string.format("%.1f studs/s", horizSpeed))
	end
end
