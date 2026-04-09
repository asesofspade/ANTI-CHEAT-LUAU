# AntiCheat

A system that detects and removes players using hacks like fly, speed, noclip, and teleport in Roblox.

## Project Structure
AntiCheat/
├── AntiCheat.lua          # Main script
├── config.lua             # Configuration
├── playerData.lua         # Player data
└── checks/                # Detection modules
├── fly.lua
├── speed.lua
├── noclip.lua
└── teleport.lua

## How It Works

The anticheat has a simple main flow:

1. When a player joins the server, their data is initialized
2. When the player respawns, monitoring begins
3. Every 0.25 seconds, 4 different checks are run
4. If there are too many violations, the player is kicked
5. A report is sent to Discord

## Main Script (AntiCheat.lua)

The main file does the following:

```lua
local AntiCheat = {}
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Load all checks
local checks = {
    require(Folder.checks.speed),
    require(Folder.checks.fly),
    require(Folder.checks.noclip),
    require(Folder.checks.teleport),
}
```

When a player joins:

```lua
local function onPlayerAdded(player)
    PlayerData.init(player)
    player.CharacterAdded:Connect(function(character)
        monitorCharacter(player, character)
    end)
    if player.Character then
        monitorCharacter(player, player.Character)
    end
end
```

Monitoring occurs every 0.25 seconds:

```lua
local function monitorCharacter(player, character)
    task.spawn(function()
        while character.Parent and player.Parent do
            task.wait(Config.CHECK_INTERVAL)
            if not character.Parent then break end
            
            for _, check in checks do
                local ok, err = pcall(check, player, character, data, flag)
                if not ok then
                    warn("[AntiCheat] Error in check:", err)
                end
            end
        end
    end)
end
```

## Violation System

Each detection adds 1 violation. Violations decrease over time automatically.

Code that handles violations:

```lua
local function flag(player, reason, detail)
    local data = PlayerData.get(player)
    if not data then return end
    
    local now = tick()
    local elapsed = now - data.lastViolationTick
    local decay = math.floor(elapsed / Config.VIOLATION_DECAY_TIME)
    data.violations = math.max(0, data.violations - decay)
    data.lastViolationTick = now
    
    data.violations += 1
    
    if data.violations >= Config.MAX_VIOLATIONS then
        player:Kick("Suspicious behavior detected.")
        sendToDiscord(player, reason, detail)
    end
end
```

Example: If 60 seconds have passed and VIOLATION_DECAY_TIME is 30:
- decay = 60 / 30 = 2
- If they had 3 violations, they now have 1

If they accumulate 3 violations before they decay, they are kicked.

## Fly Detection

The fly.lua file detects flying in 3 ways:

Method 1: Airborne time
```lua
if isAirborne(humanoid) then
    data.airTime = (data.airTime or 0) + Config.CHECK_INTERVAL
else
    data.airTime = 0
end

if data.airTime > Config.MAX_AIR_TIME + lagTolerance then
    flag(player, "Fly hack (air time)", "AirTime=" .. data.airTime)
end
```

If a player is in the air for more than 2 seconds without touching the ground, it's suspicious.

Method 2: Vertical speed
```lua
local vel = hrp.AssemblyLinearVelocity

if vel.Y > Config.MAX_VERTICAL_SPEED + lagTolerance * 10 then
    flag(player, "Fly hack (vertical speed)", "VelY=" .. vel.Y)
end
```

If they move upward too fast (more than 60 studs per second), they are flying.

Method 3: Hover (floating)
```lua
local distToGround = 999
local result = workspace:Raycast(hrp.Position, Vector3.new(0, -50, 0))
if result then
    distToGround = (hrp.Position - result.Position).Magnitude
end

if distToGround > 5 and math.abs(vel.Y) < 1 and isAirborne(humanoid) then
    data.hoverTime = (data.hoverTime or 0) + Config.CHECK_INTERVAL
    if data.hoverTime > 1.5 + lagTolerance then
        flag(player, "Fly hack (hover)", "Dist=" .. distToGround)
    end
end
```

If they are more than 5 studs above the ground without falling or rising, they are hovering.

## Speed Detection

The speed.lua file detects excessive speed:

```lua
-- First checks if WalkSpeed was modified
if humanoid.WalkSpeed > Config.MAX_WALKSPEED + 0.5 then
    humanoid.WalkSpeed = Config.MAX_WALKSPEED
    flag(player, "WalkSpeed modified", "WalkSpeed=" .. humanoid.WalkSpeed)
end

-- Then checks the actual movement speed
local vel = hrp.AssemblyLinearVelocity
local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

if horizSpeed > Config.MAX_REAL_SPEED then
    flag(player, "Speed hack", horizSpeed .. " studs/s")
end
```

Max WalkSpeed is 25 and Max Real Speed is 30.

## NoClip Detection

The noclip.lua file detects when a player phases through walls:

```lua
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = {character}

local overlapping = workspace:GetPartBoundsInBox(
    hrp.CFrame,
    size * 0.9
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
        flag(player, "NoClip detected", "Overlapping=" .. solidHits)
        data.noclipHits = 0
    end
else
    data.noclipHits = 0
end
```

Uses GetPartBoundsInBox to find solid parts overlapping with the player. If too many are found, it's NoClip.

## Teleport Detection

The teleport.lua file detects impossible jumps:

```lua
local currentPos = hrp.Position

if not data.lastPosition then
    data.lastPosition = currentPos
    return
end

local distance = (currentPos - data.lastPosition).Magnitude

local maxSpeed = Config.MAX_REAL_SPEED
local timeElapsed = Config.CHECK_INTERVAL
local lagMargin = math.clamp(ping / 1000 * maxSpeed, 0, 20)
local maxAllowed = (maxSpeed * timeElapsed) + lagMargin + Config.TP_TOLERANCE

if distance > maxAllowed then
    data.tpHits = (data.tpHits or 0) + 1
    
    if data.tpHits >= 2 then
        flag(player, "Teleport detected", "Dist=" .. distance)
        data.tpHits = 0
    end
else
    data.tpHits = 0
end

data.lastPosition = currentPos
```

Compares the current position to the previous one. If they jumped too far in 0.25 seconds, it's a teleport.

Calculates the maximum allowed distance with: max speed × time + lag margin + tolerance.

## Configuration (config.lua)

```lua
local Config = {
    MAX_WALKSPEED = 25,             
    MAX_REAL_SPEED = 30,            
    MAX_AIR_TIME = 2.0,           
    MAX_VERTICAL_SPEED = 60,       
    NOCLIP_CHECK_DIST = 3,        
    TP_TOLERANCE = 15,            
    NOCLIP_CONFIRM_TICKS = 3,     
    CHECK_INTERVAL = 0.25,           
    MAX_VIOLATIONS = 3,             
    VIOLATION_DECAY_TIME = 30,      
}
```

## Player Data (playerData.lua)

Stores information for each player:

```lua
function PlayerData.init(player)
    store[player.UserId] = {
        violations = 0,          
        airTime = 0,             
        noclipHits = 0,         
        lastViolationTick = tick(),
        lastPosition = nil,     
        tpHits = 0,            
    }
end
```

## Lag Tolerance

The system adjusts its sensitivity based on the player's ping:

```lua
local ping = player:GetNetworkPing() * 1000

if ping > 400 then
    data.airTime = 0
    data.hoverTime = 0
    return
end

local lagTolerance = ping / 1000 * 2
```

If ping is greater than 400ms, the check is skipped. Otherwise, a tolerance based on ping is added. This avoids false positives for players with high latency.

## Discord Reporting

When a player is kicked, a report is sent to Discord:

```lua
local function sendToDiscord(player, reason, detail)
    local payload = HttpService:JSONEncode({
        player = player.Name,
        type = tostring(reason or "N/A"),
        details = tostring(detail or "N/A"),
        timestamp = tick(),
        content = message,
        username = "Anti-Cheat"
    })
    
    local success = HttpService:PostAsync(
        webhookUrl,
        payload,
        Enum.HttpContentType.ApplicationJson,
        false
    )
end
```

The webhook URL is stored in ServerStorage.WebHook.Value

## Installation

1. Place the AntiCheat folder in ServerScriptService
2. In ServerStorage, create a StringValue named "WebHook"
3. Paste your Discord webhook URL into the value
4. Done — the script runs automatically

## Summary

The anticheat works as follows:

1. Monitors every 0.25 seconds
2. Runs 4 different checks
3. If something suspicious is detected, adds 1 violation
4. Violations decay over time
5. If 3 violations are reached, the player is kicked
6. Reports to Discord
