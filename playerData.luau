local PlayerData = {}
local store = {}

function PlayerData.init(player)
	store[player.UserId] = {
		violations        = 0,
		airTime           = 0,
		noclipHits        = 0,
		lastViolationTick = tick(),
		lastPosition      = nil,  
		tpHits            = 0,   
	}
end

function PlayerData.get(player)
	return store[player.UserId]
end

function PlayerData.remove(player)
	store[player.UserId] = nil
end

function PlayerData.resetCharacter(player)
	local data = store[player.UserId]
	if not data then return end
	data.airTime    = 0
	data.noclipHits = 0
end

return PlayerData
