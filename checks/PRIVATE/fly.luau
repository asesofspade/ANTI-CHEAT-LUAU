local Config = require(script.Parent.Parent.config)

local function isAirborne(humanoid)
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Flying
		or state == Enum.HumanoidStateType.PlatformStanding
end

return function(player, character, data, flag)
	local humanoid = character:FindFirstChild("Humanoid")
	local hrp      = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end

	local ping = player:GetNetworkPing() * 1000

	if ping > 400 then
		data.airTime   = 0
		data.hoverTime = 0
		return
	end

	local lagTolerance = ping / 1000 * 2

	local vel = hrp.AssemblyLinearVelocity

	if isAirborne(humanoid) then
		data.airTime = (data.airTime or 0) + Config.CHECK_INTERVAL
	else
		data.airTime = 0
	end

	if data.airTime > Config.MAX_AIR_TIME + lagTolerance then
		flag(player, "Fly hack (air time)", string.format("AirTime=%.1fs Ping=%dms", data.airTime, ping))
		data.airTime = 0
	end

	if vel.Y > Config.MAX_VERTICAL_SPEED + lagTolerance * 10 then
		flag(player, "Fly hack (velocidad vertical)", string.format("VelY=%.1f Ping=%dms", vel.Y, ping))
	end

	local isGrounded = humanoid:GetState() == Enum.HumanoidStateType.Running
		or humanoid:GetState() == Enum.HumanoidStateType.RunningNoPhysics

	if not isGrounded then
		local distToGround = 999
		local result = workspace:Raycast(
			hrp.Position,
			Vector3.new(0, -50, 0),
			RaycastParams.new()
		)
		if result then
			distToGround = (hrp.Position - result.Position).Magnitude
		end

		if distToGround > 5 and math.abs(vel.Y) < 1 and isAirborne(humanoid) then
			data.hoverTime = (data.hoverTime or 0) + Config.CHECK_INTERVAL
			if data.hoverTime > 1.5 + lagTolerance then
				flag(player, "Fly hack (hover)", string.format("Dist=%.1f Ping=%dms", distToGround, ping))
				data.hoverTime = 0
			end
		else
			data.hoverTime = 0
		end
	end
end
