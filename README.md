# AntiCheat

Un sistema que detecta y elimina jugadores que usan hacks como fly, speed, noclip y teleport en Roblox.

## Estructura del Proyecto

```
AntiCheat/
├── AntiCheat.lua          # Script principal
├── config.lua             # Configuración
├── playerData.lua         # Datos del jugador
└── checks/                # Módulos de detección
    ├── fly.lua
    ├── speed.lua
    ├── noclip.lua
    └── teleport.lua
```

## Como Funciona

El anticheat tiene un flujo principal simple:

1. Cuando un jugador entra al servidor, se inicializa su data
2. Cuando el jugador respawnea, comienza el monitoreo
3. Cada 0.25 segundos se ejecutan 4 verificaciones diferentes
4. Si hay demasiadas violaciones, el jugador es expulsado
5. Se envía un reporte a Discord

## Script Principal (AntiCheat.lua)

El archivo principal hace lo siguiente:

```lua
local AntiCheat = {}
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Carga todos los checks
local checks = {
    require(Folder.checks.speed),
    require(Folder.checks.fly),
    require(Folder.checks.noclip),
    require(Folder.checks.teleport),
}
```

Cuando un jugador entra:

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

El monitoreo ocurre cada 0.25 segundos:

```lua
local function monitorCharacter(player, character)
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
```

## Sistema de Violaciones

Cada detección suma 1 violación. Las violaciones disminuyen con el tiempo automaticamente.

Código que maneja las violaciones:

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
        player:Kick("Comportamiento sospechoso detectado.")
        sendToDiscord(player, reason, detail)
    end
end
```

Ejemplo: Si pasaron 60 segundos y VIOLATION_DECAY_TIME es 30:
- decay = 60 / 30 = 2
- Si tenía 3 violaciones, ahora tiene 1

Si acumula 3 violaciones sin que decaigan, es expulsado.

## Detección de Fly

El archivo fly.lua detecta el vuelo de 3 formas:

Forma 1: Tiempo en aire
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

Si un jugador está en el aire más de 2 segundos sin tocar el suelo, es sospechoso.

Forma 2: Velocidad vertical
```lua
local vel = hrp.AssemblyLinearVelocity

if vel.Y > Config.MAX_VERTICAL_SPEED + lagTolerance * 10 then
    flag(player, "Fly hack (velocidad vertical)", "VelY=" .. vel.Y)
end
```

Si sube muy rápido (más de 60 studs por segundo), está volando.

Forma 3: Hover (flotación)
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

Si está a más de 5 studs del suelo sin caer y sin subir, está flotando.

## Detección de Speed

El archivo speed.lua detecta velocidad excesiva:

```lua
-- Primero verifica que no haya modificado WalkSpeed
if humanoid.WalkSpeed > Config.MAX_WALKSPEED + 0.5 then
    humanoid.WalkSpeed = Config.MAX_WALKSPEED
    flag(player, "WalkSpeed modificado", "WalkSpeed=" .. humanoid.WalkSpeed)
end

-- Luego verifica la velocidad real de movimiento
local vel = hrp.AssemblyLinearVelocity
local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

if horizSpeed > Config.MAX_REAL_SPEED then
    flag(player, "Speed hack", horizSpeed .. " studs/s")
end
```

Max WalkSpeed es 25 y Max Real Speed es 30.

## Detección de NoClip

El archivo noclip.lua detecta cuando atraviesa paredes:

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
        flag(player, "NoClip detectado", "Overlapping=" .. solidHits)
        data.noclipHits = 0
    end
else
    data.noclipHits = 0
end
```

Usa GetPartBoundsInBox para encontrar partes sólidas que overlappean con el jugador.
Si encuentra demasiadas, es NoClip.

## Detección de Teleport

El archivo teleport.lua detecta saltos imposibles:

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
        flag(player, "Teleport detectado", "Dist=" .. distance)
        data.tpHits = 0
    end
else
    data.tpHits = 0
end

data.lastPosition = currentPos
```

Compara la posición actual con la anterior. Si saltó demasiada distancia en 0.25 segundos, es teleport.

Calcula la distancia máxima permitida con: velocidad máxima * tiempo + margen por lag + tolerancia.

## Configuración (config.lua)

```lua
local Config = {
    MAX_WALKSPEED = 25,              -- Velocidad de caminata máxima
    MAX_REAL_SPEED = 30,             -- Velocidad real máxima
    MAX_AIR_TIME = 2.0,              -- Segundos máximo en el aire
    MAX_VERTICAL_SPEED = 60,         -- Velocidad vertical máxima
    NOCLIP_CHECK_DIST = 3,           -- Distancia para check de noclip
    TP_TOLERANCE = 15,               -- Tolerancia para teleport
    NOCLIP_CONFIRM_TICKS = 3,        -- Frames para confirmar noclip
    CHECK_INTERVAL = 0.25,           -- Cada cuanto revisar (en segundos)
    MAX_VIOLATIONS = 3,              -- Violaciones antes de expulsar
    VIOLATION_DECAY_TIME = 30,       -- Segundos para reducir 1 violación
}
```

## Datos del Jugador (playerData.lua)

Almacena información de cada jugador:

```lua
function PlayerData.init(player)
    store[player.UserId] = {
        violations = 0,           -- Contador de violaciones
        airTime = 0,              -- Tiempo acumulado en el aire
        noclipHits = 0,           -- Detecciones de noclip
        lastViolationTick = tick(), -- Última violación
        lastPosition = nil,       -- Posición anterior
        tpHits = 0,               -- Detecciones de teleport
    }
end
```

## Tolerancia de Lag

El sistema ajusta su sensibilidad según el ping del jugador:

```lua
local ping = player:GetNetworkPing() * 1000

if ping > 400 then
    data.airTime = 0
    data.hoverTime = 0
    return
end

local lagTolerance = ping / 1000 * 2
```

Si el ping es mayor a 400ms, se ignora el check.
Si no, se suma una tolerancia basada en el ping.

Esto evita falsos positivos en jugadores con lag.

## Envío a Discord

Cuando un jugador es expulsado, se envía a Discord:

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

El webhook está guardado en ServerStorage.WebHook.Value

## Instalación

1. Coloca la carpeta AntiCheat en ServerScriptService
2. En ServerStorage crea un StringValue llamado "WebHook"
3. Pega tu URL de webhook de Discord en el valor
4. Listo, el script se ejecuta automáticamente

## Resumen

El anticheat funciona así:

1. Monitorea cada 0.25 segundos
2. Ejecuta 4 checks diferentes
3. Si detecta algo sospechoso, suma 1 violación
4. Las violaciones decaen con el tiempo
5. Si llega a 3 violaciones, expulsa al jugador
6. Reporta a Discord

Es un sistema simple pero efectivo contra hacks básicos.
