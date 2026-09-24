--[[
    ═══════════════════════════════════════════════════════
      ALFA 0.7 — MM2 SCRIPT HUB (Mobile Compact + Mega Update)
      Мобильный UI · 15 новых функций · полный багфикс
      Основной executor: Delta (ПК / Android)
    ═══════════════════════════════════════════════════════
]]

-- ═══ 1. CORE ═══
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local TeleportService   = game:GetService("TeleportService")
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()
local Camera      = workspace.CurrentCamera

if game.PlaceId ~= 142823291 then
    warn("[ALFA] Это не Murder Mystery 2 — функции могут не работать")
end

pcall(function() if getgenv().ALFA07_UNLOAD then getgenv().ALFA07_UNLOAD() end end)

local Connections, Cleanups = {}, {}
local function track(c) table.insert(Connections, c) return c end
local function cleanupFn(f) table.insert(Cleanups, f) end
local function clearAll()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for _, f in ipairs(Cleanups) do pcall(f) end
    Connections, Cleanups = {}, {}
end

local Flags, UIRegistry = {}, {}
local notify = function() end

-- ═══ 2. ХЕЛПЕРЫ ═══
local function getChar(plr) return plr.Character end

local function getToolKind(plr)
    local ch = getChar(plr)
    local function scanTool(t)
        if t:IsA("Tool") then
            local n = t.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("revolver") then return "Gun" end
            if n:find("knife") or n:find("blade") or n:find("dagger") then return "Knife" end
        end
        return nil
    end
    local function scanContainer(container)
        if not container then return nil end
        for _, t in ipairs(container:GetChildren()) do
            local k = scanTool(t)
            if k then return k end
        end
        return nil
    end
    return scanContainer(ch) or scanContainer(plr:FindFirstChild("Backpack"))
end

local function getRole(plr)
    local k = getToolKind(plr)
    if k == "Knife" then return "Murderer" end
    if k == "Gun" then return "Sheriff" end
    return "Innocent"
end

local function getMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRole(p) == "Murderer" then return p end
    end
    return nil
end

local function getSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRole(p) == "Sheriff" then return p end
    end
    return nil
end

local function getHRP(plr)
    local ch = getChar(plr)
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function getHum(plr)
    local ch = getChar(plr)
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

local function alive(plr)
    local h = getHum(plr)
    return h ~= nil and h.Health > 0
end

local function isVisible(plr)
    local hrp = getHRP(plr)
    if not hrp then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, hrp.Parent }
    local res = workspace:Raycast(Camera.CFrame.Position, hrp.Position - Camera.CFrame.Position, params)
    return res == nil
end

local function getMyTool(kind)
    local ch = getChar(LocalPlayer)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local patterns = (kind == "Gun") and { "gun", "pistol", "revolver" } or { "knife", "blade", "dagger" }
    local function findTool(container)
        if not container then return nil end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") then
                local n = t.Name:lower()
                for _, p in ipairs(patterns) do
                    if n:find(p) then return t end
                end
            end
        end
        return nil
    end
    return findTool(ch) or findTool(bp)
end

-- ФИКС: правильная проверка экипа
local function equipTool(tool)
    if not tool then return false end
    local ch = getChar(LocalPlayer)
    if not ch then return false end
    if tool.Parent == ch then return true end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return false end
    if tool.Parent ~= bp then return false end
    local h = getHum(LocalPlayer)
    if not h then return false end
    pcall(function() h:EquipTool(tool) end)
    local attempts = 0
    while tool.Parent ~= ch and attempts < 20 do
        task.wait(0.05)
        attempts += 1
    end
    return tool.Parent == ch
end

local function nearestPlayer(excludeRoles)
    local my = getHRP(LocalPlayer)
    if not my then return nil end
    local best, bd = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and alive(p) then
            local ok = true
            if excludeRoles then
                for _, r in ipairs(excludeRoles) do
                    if getRole(p) == r then ok = false break end
                end
            end
            if ok then
                local h = getHRP(p)
                if h then
                    local d = (h.Position - my.Position).Magnitude
                    if d < bd then bd, best = d, p end
                end
            end
        end
    end
    return best
end

local function getPlayerByName(name)
    name = name:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(name) or p.DisplayName:lower():find(name) then return p end
    end
    return nil
end

local function tpToPlayer(p)
    if not p or not alive(p) then notify("TP", "Недоступен") return end
    local hrp = getHRP(p)
    local myHrp = getHRP(LocalPlayer)
    if hrp and myHrp then
        myHrp.CFrame = hrp.CFrame * CFrame.new(0, 0, 4)
        notify("TP", "→ " .. p.Name, 2)
    end
end

-- ═══ 3. SOUND SYSTEM ═══
local SoundEnabled = true
local SOUND_IDS = {
    click = 6026723916, toggle = 6026723916, shoot = 3120484875,
    knife = 2863915039, alert = 3061459262, notify = 6026723916,
    hit = 2863915039,
}
local function playSound(type, vol)
    if not SoundEnabled then return end
    local id = SOUND_IDS[type] or SOUND_IDS.click
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://" .. tostring(id)
        s.Volume = vol or 0.2
        s.Parent = workspace
        s:Play()
        task.delay(3, function() pcall(function() s:Destroy() end) end)
    end)
end

-- ═══ 4. COMBAT (ФИКС) ═══
local aimSmooth, farmDelay, flySpeed = 0.25, 0.15, 80
local gunCooldownEnd = 0
local roundStats = { kills = 0, deaths = 0, wins = 0, rounds = 0 }

local function shootMurderer()
    local m = getMurderer()
    if not m then notify("Combat", "Murderer не найден") return end
    local gun = getMyTool("Gun")
    if not gun then notify("Combat", "Нет пистолета") return end
    local hrp = getHRP(m)
    local myHrp = getHRP(LocalPlayer)
    if not (hrp and myHrp) then return end

    if not equipTool(gun) then notify("Combat", "Экип не удался") return end
    task.wait(0.05)

    pcall(function()
        myHrp.CFrame = CFrame.new(myHrp.Position, Vector3.new(hrp.Position.X, myHrp.Position.Y, hrp.Position.Z))
    end)
    pcall(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, hrp.Position)
        gun:Activate()
    end)
    pcall(function()
        for _, d in ipairs(gun:GetDescendants()) do
            if d:IsA("RemoteEvent") then d:FireServer(hrp.Position) end
        end
    end)
    if mousemoverel then
        pcall(function()
            local sp, on = Camera:WorldToViewportPoint(hrp.Position)
            if on then
                mousemoverel(sp.X - Mouse.X, sp.Y - Mouse.Y)
                task.wait(0.02)
                gun:Activate()
            end
        end)
    end
    gunCooldownEnd = tick() + 1.5
    playSound("shoot")
    notify("Combat", "Выстрел → " .. m.Name, 2)
end

-- НОВАЯ: Silent Aim — без движения камеры
local function silentAim()
    local m = getMurderer()
    if not m then return end
    local gun = getMyTool("Gun")
    if not gun then return end
    if not equipTool(gun) then return end
    local hrp = getHRP(m)
    if not hrp then return end
    pcall(function()
        for _, d in ipairs(gun:GetDescendants()) do
            if d:IsA("RemoteEvent") then d:FireServer(hrp.Position) end
        end
    end)
    pcall(function() gun:Activate() end)
    playSound("shoot")
end

local function throwKnife(target)
    target = target or getMurderer() or nearestPlayer()
    if not target then notify("Combat", "Нет цели") return end
    local knife = getMyTool("Knife")
    if not knife then notify("Combat", "Нет ножа") return end
    local hrp = getHRP(target)
    local myHrp = getHRP(LocalPlayer)
    if not (hrp and myHrp) then return end

    if not equipTool(knife) then notify("Combat", "Экип не удался") return end
    task.wait(0.05)

    pcall(function()
        myHrp.CFrame = CFrame.new(myHrp.Position, Vector3.new(hrp.Position.X, myHrp.Position.Y, hrp.Position.Z))
    end)
    pcall(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, hrp.Position)
        knife:Activate()
    end)
    pcall(function()
        for _, d in ipairs(knife:GetDescendants()) do
            if d:IsA("RemoteEvent") then d:FireServer(hrp.Position) end
        end
    end)
    if mousemoverel then
        pcall(function()
            local sp, on = Camera:WorldToViewportPoint(hrp.Position)
            if on then
                mousemoverel(sp.X - Mouse.X, sp.Y - Mouse.Y)
                task.wait(0.02)
                knife:Activate()
            end
        end)
    end
    playSound("knife")
    notify("Combat", "Нож → " .. target.Name, 2)
end

-- ФИКС: touch с большей задержкой + все parts
local function knifeTouch(p)
    local knife = getMyTool("Knife")
    if not knife then return false end
    if not equipTool(knife) then return false end

    local handle = nil
    for _, d in ipairs(knife:GetDescendants()) do
        if d:IsA("BasePart") then handle = d break end
    end
    if not handle then return false end

    local hrp, my = getHRP(p), getHRP(LocalPlayer)
    if not (hrp and my) then return false end

    pcall(function() my.CFrame = hrp.CFrame * CFrame.new(0, 0, -2) end)
    task.wait(0.05)

    local ch = getChar(p)
    if ch and firetouchinterest then
        for _, part in ipairs(ch:GetChildren()) do
            if part:IsA("BasePart") then
                pcall(function()
                    firetouchinterest(handle, part, 0)
                    task.wait(0.02)
                    firetouchinterest(handle, part, 1)
                end)
            end
        end
    elseif firetouchinterest then
        pcall(function()
            firetouchinterest(handle, hrp, 0)
            task.wait(0.03)
            firetouchinterest(handle, hrp, 1)
        end)
    else
        pcall(function() knife:Activate() end)
    end
    playSound("hit", 0.15)
    roundStats.kills += 1
    return true
end

local function killAll()
    if getRole(LocalPlayer) ~= "Murderer" then
        notify("Combat", "Только за Murderer'а")
        return
    end
    local count = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and alive(p) then
            if knifeTouch(p) then count += 1 end
            task.wait(0.1)
        end
    end
    notify("Combat", "Kill All: " .. count, 2)
end

local function killNearest(radius)
    local t = nearestPlayer()
    if not t then return end
    local my, h = getHRP(LocalPlayer), getHRP(t)
    if my and h and (h.Position - my.Position).Magnitude <= (radius or 40) then
        knifeTouch(t)
    end
end

local function killByRole(role)
    local target = (role == "Sheriff") and getSheriff() or getMurderer()
    if target then
        knifeTouch(target)
        notify("Combat", "Атака: " .. target.Name, 2)
    end
end

local hitboxEnabled = false
local function setHitbox(on)
    hitboxEnabled = on
    if not on then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local hrp = getHRP(p)
                if hrp then
                    pcall(function()
                        hrp.Size = Vector3.new(2, 2, 1)
                        hrp.Material = Enum.Material.Plastic
                        hrp.Transparency = 1
                        hrp.Color = Color3.fromRGB(163, 162, 165)
                    end)
                end
            end
        end
    end
end

-- ═══ 5. VISUALS ═══
local RoleColors = {
    Murderer = Color3.fromRGB(255, 64, 64),
    Sheriff  = Color3.fromRGB(64, 140, 255),
    Innocent = Color3.fromRGB(88, 255, 128),
}
local espData, coinHLs = {}, {}

local savedLighting = {}
local function setFullbright(on)
    if on then
        savedLighting = {
            Bright = Lighting.Brightness, Clock = Lighting.ClockTime,
            Amb = Lighting.OutdoorAmbient, GS = Lighting.GlobalShadows, Fog = Lighting.FogEnd,
        }
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e9
    else
        pcall(function()
            Lighting.Brightness = savedLighting.Bright or 1
            Lighting.ClockTime = savedLighting.Clock or 12
            Lighting.OutdoorAmbient = savedLighting.Amb or Color3.fromRGB(128, 128, 128)
            Lighting.GlobalShadows = savedLighting.GS ~= false
            Lighting.FogEnd = savedLighting.Fog or 100000
        end)
    end
end

local fpsBoostSaved = {}
local function setFPSBoost(on)
    if on then
        fpsBoostSaved = { ql = settings().Rendering.QualityLevel, gs = Lighting.GlobalShadows, parts = {} }
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            Lighting.GlobalShadows = false
            for _, d in ipairs(Lighting:GetDescendants()) do
                if d:IsA("PostEffect") then fpsBoostSaved.parts[d] = d.Enabled d.Enabled = false end
            end
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
                    fpsBoostSaved.parts[d] = d.Enabled
                    d.Enabled = false
                end
            end
        end)
    else
        pcall(function()
            if fpsBoostSaved.ql then settings().Rendering.QualityLevel = fpsBoostSaved.ql end
            if fpsBoostSaved.gs ~= nil then Lighting.GlobalShadows = fpsBoostSaved.gs end
            for d, was in pairs(fpsBoostSaved.parts or {}) do
                if d.Parent then d.Enabled = was end
            end
        end)
        fpsBoostSaved = {}
    end
end

-- НОВЫЕ визуалы
local savedFOV = 70
local function setFOV(v)
    pcall(function()
        if not savedFOV or savedFOV == 70 then savedFOV = Camera.FieldOfView end
        Camera.FieldOfView = v
    end)
end

local savedZoom = nil
local function setZoomOverride(on)
    if on then
        pcall(function()
            savedZoom = LocalPlayer.CameraMaxZoomDistance
            LocalPlayer.CameraMaxZoomDistance = 1000
            LocalPlayer.CameraMinZoomDistance = 0.5
        end)
    else
        pcall(function()
            if savedZoom then
                LocalPlayer.CameraMaxZoomDistance = savedZoom
                LocalPlayer.CameraMinZoomDistance = 0.5
            end
        end)
        savedZoom = nil
    end
end

local function setFirstPerson(on)
    pcall(function()
        if on then
            LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
        else
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
        end
    end)
end

-- Name Hider
local function setNameHider(on)
    pcall(function()
        local ch = getChar(LocalPlayer)
        if not ch then return end
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("BillboardGui") and d.Name:lower():find("name") then
                d.Enabled = not on
            elseif d:IsA("TextLabel") and d.Parent:IsA("BillboardGui") then
                d.Parent.Enabled = not on
            end
        end
    end)
end

-- Camera Shake removal
local function setNoCameraShake(on)
    if on then
        pcall(function()
            LocalPlayer.CameraMode = LocalPlayer.CameraMode
        end)
    end
end

-- ═══ 6. MOVEMENT ═══
local keys = {}
track(UserInputService.InputBegan:Connect(function(i, g) if not g then keys[i.KeyCode] = true end end))
track(UserInputService.InputEnded:Connect(function(i) keys[i.KeyCode] = nil end))

local flyObjects = nil
local flyActive = false
local function setFly(on)
    flyActive = on
    local hrp = getHRP(LocalPlayer)
    if on then
        if not hrp then return end
        if flyObjects then pcall(function() flyObjects.bv:Destroy() flyObjects.bg:Destroy() end) flyObjects = nil end
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(4e5, 4e5, 4e5)
        bv.Velocity = Vector3.zero
        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
        bg.P = 2e4
        bg.CFrame = hrp.CFrame
        bv.Parent, bg.Parent = hrp, hrp
        flyObjects = { bv = bv, bg = bg }
    else
        if flyObjects then pcall(function() flyObjects.bv:Destroy() flyObjects.bg:Destroy() end) flyObjects = nil end
    end
end

local lastSafePos = nil

-- ═══ 7. MISC ═══
local function say(msg)
    pcall(function()
        local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents", true)
        if ev and ev:FindFirstChild("SayMessageRequest") then
            ev.SayMessageRequest:FireServer(msg, "All")
        end
    end)
end

local SPAM = { "gg", "ez", "run", "nice", "ahaha", "clutch" }

local function setSpin(on)
    local hrp = getHRP(LocalPlayer)
    if not hrp then return end
    local old = hrp:FindFirstChild("AlfaSpin")
    if old then old:Destroy() end
    if on then
        local bav = Instance.new("BodyAngularVelocity")
        bav.AngularVelocity = Vector3.new(0, 40, 0)
        bav.MaxTorque = Vector3.new(0, 4e5, 0)
        bav.Name = "AlfaSpin"
        bav.Parent = hrp
        cleanupFn(function() pcall(function() bav:Destroy() end) end)
    end
end

-- ФИКС: Fling через AssemblyAngularVelocity + proper loop
local flingConn = nil
local function setFling(on)
    if flingConn then flingConn:Disconnect() flingConn = nil end
    local hrp = getHRP(LocalPlayer)
    if hrp then pcall(function() hrp.AssemblyAngularVelocity = Vector3.zero end) end
    if on then
        flingConn = RunService.Heartbeat:Connect(function()
            local h = getHRP(LocalPlayer)
            if h and alive(LocalPlayer) then
                h.AssemblyAngularVelocity = Vector3.new(0, 250, 0)
            end
        end)
        cleanupFn(function() if flingConn then flingConn:Disconnect() end end)
    end
end

-- НОВАЯ: Anti-Fling — сбрасывает angular velocity
local antiFlingConn = nil
local function setAntiFling(on)
    if antiFlingConn then antiFlingConn:Disconnect() antiFlingConn = nil end
    if on then
        antiFlingConn = RunService.Heartbeat:Connect(function()
            local h = getHRP(LocalPlayer)
            if h and alive(LocalPlayer) then
                local av = h.AssemblyAngularVelocity
                if av.Magnitude > 50 then
                    h.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end)
        cleanupFn(function() if antiFlingConn then antiFlingConn:Disconnect() end end)
    end
end

local function rejoin() pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end

local function serverHop()
    local req = http_request or request or (http and http.request)
    if not req then notify("Misc", "request API недоступен — Rejoin") rejoin() return end
    pcall(function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
        local res = req({ Url = url, Method = "GET" })
        local data = HttpService:JSONDecode(res.Body)
        for _, s in ipairs(data.data or {}) do
            if s.id ~= game.JobId and (s.playing or 0) < (s.maxPlayers or 0) then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                return
            end
        end
        notify("Misc", "Серверов нет")
    end)
end

local CODES = { "AL3X", "SU3330", "PR13ST", "C01N" }
local function redeemCodes()
    local remote = ReplicatedStorage:FindFirstChild("RedeemCode", true)
    if not remote then
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteEvent") and d.Name:lower():find("redeem") then remote = d break end
        end
    end
    if not remote then notify("Misc", "Remote не найден") return end
    for _, code in ipairs(CODES) do
        pcall(function() remote:FireServer(code) end)
        task.wait(0.3)
    end
    notify("Misc", "Коды: " .. #CODES, 3)
end

local function revealRoles()
    local lines = {}
    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(lines, ("%s — %s"):format(p.Name, getRole(p)))
    end
    notify("Роли", table.concat(lines, "\n"), 8)
end

local function saveConfig()
    local ok = pcall(function() writefile("alfa07_config.json", HttpService:JSONEncode(Flags)) end)
    notify("Config", ok and "Сохранено" or "Недоступно", 3)
end

local function loadConfig()
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile("alfa07_config.json")) end)
    if not ok or typeof(data) ~= "table" then notify("Config", "Не найден", 3) return end
    for name, v in pairs(data) do
        if UIRegistry[name] then pcall(function() UIRegistry[name](v) end) end
    end
    notify("Config", "Загружен", 3)
end

-- НОВАЯ: Quick TP Presets
local function tpToSpawn()
    local myHrp = getHRP(LocalPlayer)
    if myHrp then
        myHrp.CFrame = CFrame.new(0, 50, 0)
        notify("TP", "→ Spawn", 2)
    end
end

local function tpToCenter()
    local myHrp = getHRP(LocalPlayer)
    if myHrp then
        myHrp.CFrame = CFrame.new(0, 10, 0)
        notify("TP", "→ Center", 2)
    end
end

local function tpToNearestPlayer()
    local t = nearestPlayer()
    if t then tpToPlayer(t) end
end

-- ═══ 8. НОВЫЕ ФУНКЦИИ (15 штук) ═══

-- 1. Role-Based Auto Mode
local autoModeEnabled = false
local function checkAutoMode()
    if not autoModeEnabled then return end
    local role = getRole(LocalPlayer)
    if role == "Sheriff" then
        if not Flags["Player ESP"] and UIRegistry["Player ESP"] then pcall(UIRegistry["Player ESP"], true) end
        if Flags["Kill Aura"] and UIRegistry["Kill Aura"] then pcall(UIRegistry["Kill Aura"], false) end
    elseif role == "Murderer" then
        if not Flags["Kill Aura"] and UIRegistry["Kill Aura"] then pcall(UIRegistry["Kill Aura"], true) end
    else
        if not Flags["Player ESP"] and UIRegistry["Player ESP"] then pcall(UIRegistry["Player ESP"], true) end
        if Flags["Kill Aura"] and UIRegistry["Kill Aura"] then pcall(UIRegistry["Kill Aura"], false) end
    end
end

-- 2. Last Seen
local lastSeenData = {}
local lastSeenDrawings = {}

-- 3. Position Predictor
local predictorDrawings = {}

-- 4. Round Timer HUD
local roundTimerLabel = nil
local function findTimerLabel()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextLabel") and d.Visible and d.Text:match("^%d+:%d+$") then
                    return d
                end
            end
        end
    end
    return nil
end

-- 5. Auto Save Sheriff
local sheriffLastPos = nil
local sheriffWasAlive = false

-- 6. Gun Cooldown
-- (gunCooldownEnd from shootMurderer)

-- 7. AFK Detector
local afkTracker = {}
local afkHighlights = {}

-- 8. Group Detector
local groupHighlights = {}

-- 9. Notification Queue
local notifQueue = {}
local notifActiveCount = 0

-- 10. Sound Design (playSound from section 3)

-- 11. Keybind Visualizer
local keybindPanel = nil

-- 12. Safe Mode
local safeModeOn = false
local suspiciousFeatures = { "Aimbot", "Hitbox Expander", "Kill Aura", "Auto Shoot (Sheriff)", "Auto Knife (Murderer)", "Fling All", "Fake Lag", "Silent Aim", "Triggerbot" }
local function setSafeMode(on)
    safeModeOn = on
    if on then
        for _, name in ipairs(suspiciousFeatures) do
            if UIRegistry[name] then pcall(UIRegistry[name], false) end
        end
        notify("Safe Mode", "Агрессивные функции OFF", 3)
    else
        notify("Safe Mode", "OFF", 2)
    end
end

-- 13. Player Action Menu
local actionMenu = nil
local function showActionMenu(plr, xPos, yPos)
    if actionMenu then pcall(function() actionMenu:Destroy() end) end
    actionMenu = Instance.new("Frame")
    actionMenu.Size = UDim2.fromOffset(110, 90)
    actionMenu.Position = UDim2.new(0, xPos, 0, yPos)
    actionMenu.BackgroundColor3 = Color3.fromRGB(30, 28, 42)
    actionMenu.BorderSizePixel = 0
    actionMenu.ZIndex = 20
    pcall(function() actionMenu.Parent = gethui() or game:GetService("CoreGui") end)
    if not actionMenu.Parent then actionMenu.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    local mc = Instance.new("UICorner") mc.CornerRadius = UDim.new(0, 8) mc.Parent = actionMenu
    local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(123, 104, 238) ms.Thickness = 1 ms.Parent = actionMenu
    local ml = Instance.new("UIListLayout") ml.Padding = UDim.new(0, 2) ml.Parent = actionMenu
    local mp = Instance.new("UIPadding") mp.PaddingTop = UDim.new(0, 4) mp.PaddingLeft = UDim.new(0, 4) mp.PaddingRight = UDim.new(0, 4) mp.Parent = actionMenu

    local function makeActionBtn(text, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 22)
        b.BackgroundColor3 = Color3.fromRGB(40, 36, 56)
        b.Text = text
        b.TextColor3 = Color3.fromRGB(232, 228, 240)
        b.TextSize = 10
        b.Font = Enum.Font.Gotham
        b.BorderSizePixel = 0
        b.Parent = actionMenu
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = b
        b.MouseButton1Click:Connect(function()
            pcall(cb)
            pcall(function() actionMenu:Destroy() end)
            actionMenu = nil
        end)
    end

    makeActionBtn("📍 TP", function() tpToPlayer(plr) end)
    makeActionBtn("👁️ Spectate", function() spectateNext(plr) end)
    makeActionBtn("🎯 Track", function()
        local hrp = getHRP(plr)
        if hrp then lastSeenData[plr] = { pos = hrp.Position, time = tick() } end
    end)
end

-- 14. Fake Lag (ФИКС: правильная логика телепорта)
local fakeLagData = { savedPos = nil, timer = 0 }

-- 15. Clone Decoy (ФИКС: удаляем Accessory и Animation)
local function createDecoy()
    local char = getChar(LocalPlayer)
    if not char then notify("Decoy", "Нет персонажа") return end
    pcall(function()
        local clone = char:Clone()
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then d:Destroy() end
            if d:IsA("Accessory") then d:Destroy() end
            if d:IsA("Animation") then d:Destroy() end
            if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end
        end
        local hum = clone:FindFirstChildOfClass("Humanoid")
        if hum then hum:Destroy() end
        clone.Name = "AlfaDecoy"
        clone.Parent = workspace
        notify("Decoy", "Создан (30с)", 2)
        task.delay(30, function() pcall(function() clone:Destroy() end) end)
    end)
end

-- Triggerbot
local triggerbotActive = false

-- Auto Collect Drops
local function autoCollectDrops()
    pcall(function()
        local myHrp = getHRP(LocalPlayer)
        if not myHrp then return end
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                local n = d.Name:lower()
                if (n:find("drop") or n:find("gun") or n:find("knife")) and d ~= getChar(LocalPlayer) then
                    local dist = (d.Position - myHrp.Position).Magnitude
                    if dist < 60 then
                        myHrp.CFrame = CFrame.new(d.Position + Vector3.new(0, 2, 0))
                        if firetouchinterest then
                            firetouchinterest(d, myHrp, 0)
                            task.wait(0.02)
                            firetouchinterest(d, myHrp, 1)
                        end
                        break
                    end
                end
            end
        end
    end)
end

-- Auto Reconnect
local function checkAutoReconnect()
    pcall(function()
        if not LocalPlayer.Parent then
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end)
end

-- Player Trail
local trailData = {}

-- Spectate
local spectating = false
local spectateTarget = nil
local function spectateNext(specific)
    if specific then
        if alive(specific) then
            spectateTarget = specific
            spectating = true
            local hum = getHum(spectateTarget)
            if hum then Camera.CameraSubject = hum end
            notify("Spectate", "→ " .. spectateTarget.Name, 3)
        end
        return
    end
    local plrs = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and alive(p) then table.insert(plrs, p) end
    end
    if #plrs == 0 then notify("Spectate", "Нет живых", 2) return end
    local idx = 1
    if spectateTarget and table.find(plrs, spectateTarget) then
        idx = (table.find(plrs, spectateTarget) % #plrs) + 1
    end
    spectateTarget = plrs[idx]
    spectating = true
    local hum = getHum(spectateTarget)
    if hum then Camera.CameraSubject = hum end
    notify("Spectate", "→ " .. spectateTarget.Name, 3)
end

local function stopSpectate()
    if not spectating then return end
    spectating = false
    spectateTarget = nil
    local hum = getHum(LocalPlayer)
    if hum then Camera.CameraSubject = hum end
    notify("Spectate", "OFF", 2)
end

local alertRunning = false
local alertOverlay = nil

-- ═══ 9. THEMES ═══
local Themes = {
    Midnight = {
        Accent = Color3.fromRGB(123, 104, 238), Bg = Color3.fromRGB(13, 11, 20),
        Panel = Color3.fromRGB(20, 17, 30), Card = Color3.fromRGB(26, 23, 38),
        Stroke = Color3.fromRGB(45, 39, 64), Text = Color3.fromRGB(232, 228, 240),
        SubText = Color3.fromRGB(150, 145, 165), Hover = Color3.fromRGB(36, 32, 52),
    },
    Cyber = {
        Accent = Color3.fromRGB(0, 255, 170), Bg = Color3.fromRGB(8, 12, 10),
        Panel = Color3.fromRGB(14, 22, 18), Card = Color3.fromRGB(18, 30, 24),
        Stroke = Color3.fromRGB(30, 70, 55), Text = Color3.fromRGB(220, 255, 240),
        SubText = Color3.fromRGB(100, 160, 130), Hover = Color3.fromRGB(26, 44, 34),
    },
    Crimson = {
        Accent = Color3.fromRGB(230, 50, 70), Bg = Color3.fromRGB(18, 8, 10),
        Panel = Color3.fromRGB(28, 14, 17), Card = Color3.fromRGB(38, 20, 24),
        Stroke = Color3.fromRGB(85, 35, 42), Text = Color3.fromRGB(245, 230, 232),
        SubText = Color3.fromRGB(160, 120, 128), Hover = Color3.fromRGB(50, 28, 32),
    },
    Frost = {
        Accent = Color3.fromRGB(100, 180, 255), Bg = Color3.fromRGB(12, 16, 22),
        Panel = Color3.fromRGB(18, 26, 36), Card = Color3.fromRGB(24, 34, 46),
        Stroke = Color3.fromRGB(50, 80, 110), Text = Color3.fromRGB(235, 245, 255),
        SubText = Color3.fromRGB(130, 155, 180), Hover = Color3.fromRGB(34, 48, 62),
    },
    Gold = {
        Accent = Color3.fromRGB(255, 200, 60), Bg = Color3.fromRGB(16, 14, 10),
        Panel = Color3.fromRGB(24, 21, 16), Card = Color3.fromRGB(32, 28, 20),
        Stroke = Color3.fromRGB(70, 60, 35), Text = Color3.fromRGB(248, 240, 225),
        SubText = Color3.fromRGB(160, 148, 120), Hover = Color3.fromRGB(44, 38, 26),
    },
}
local Theme = Themes.Midnight
local currentThemeName = "Midnight"

-- ═══ 10. GUI (МОБИЛЬНЫЙ — 300x380) ═══
local Gui = Instance.new("ScreenGui")
Gui.Name = "Alfa07"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() Gui.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui") end)
if not Gui.Parent then Gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local CardRefs, TextRefs, AccentRefs, StrokeRefs, SubTextRefs = {}, {}, {}, {}, {}

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = inst
end

local function stroke(inst, col, th)
    local s = Instance.new("UIStroke")
    s.Color = col or Theme.Stroke
    s.Thickness = th or 1
    s.Parent = inst
    table.insert(StrokeRefs, s)
    return s
end

local function makeShadow(parent)
    pcall(function()
        local shadow = Instance.new("ImageLabel")
        shadow.Image = "rbxassetid://1316045217"
        shadow.ScaleType = Enum.ScaleType.Slice
        shadow.SliceCenter = Rect.new(10, 10, 118, 118)
        shadow.BackgroundTransparency = 1
        shadow.Size = UDim2.new(1, 30, 1, 30)
        shadow.Position = UDim2.new(0, -15, 0, -15)
        shadow.ImageColor3 = Color3.new(0, 0, 0)
        shadow.ImageTransparency = 0.4
        shadow.ZIndex = 0
        shadow.Parent = parent
    end)
end

-- Alert overlay
alertOverlay = Instance.new("Frame")
alertOverlay.Size = UDim2.new(1, 0, 1, 0)
alertOverlay.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
alertOverlay.BackgroundTransparency = 1
alertOverlay.ZIndex = 2
alertOverlay.Parent = Gui

-- Round Timer HUD
local roundTimerFrame = Instance.new("Frame")
roundTimerFrame.Size = UDim2.fromOffset(70, 24)
roundTimerFrame.Position = UDim2.new(1, -78, 0, 6)
roundTimerFrame.BackgroundColor3 = Color3.fromRGB(20, 17, 30)
roundTimerFrame.BorderSizePixel = 0
roundTimerFrame.Visible = false
roundTimerFrame.ZIndex = 3
roundTimerFrame.Parent = Gui
corner(roundTimerFrame, 6)
local rtStroke = Instance.new("UIStroke") rtStroke.Color = Color3.fromRGB(123, 104, 238) rtStroke.Thickness = 1 rtStroke.Parent = roundTimerFrame
local roundTimerText = Instance.new("TextLabel")
roundTimerText.Size = UDim2.new(1, 0, 1, 0)
roundTimerText.BackgroundTransparency = 1
roundTimerText.Text = "--:--"
roundTimerText.TextColor3 = Color3.fromRGB(232, 228, 240)
roundTimerText.TextSize = 11
roundTimerText.Font = Enum.Font.GothamBold
roundTimerText.Parent = roundTimerFrame

-- Gun Cooldown HUD
local gunCDFrame = Instance.new("Frame")
gunCDFrame.Size = UDim2.fromOffset(100, 22)
gunCDFrame.Position = UDim2.new(0.5, -50, 1, -40)
gunCDFrame.BackgroundColor3 = Color3.fromRGB(20, 17, 30)
gunCDFrame.BorderSizePixel = 0
gunCDFrame.Visible = false
gunCDFrame.ZIndex = 3
gunCDFrame.Parent = Gui
corner(gunCDFrame, 6)
local gcdStroke = Instance.new("UIStroke") gcdStroke.Color = Color3.fromRGB(64, 140, 255) gcdStroke.Thickness = 1 gcdStroke.Parent = gunCDFrame
local gunCDText = Instance.new("TextLabel")
gunCDText.Size = UDim2.new(1, -8, 1, 0)
gunCDText.Position = UDim2.new(0, 4, 0, 0)
gunCDText.BackgroundTransparency = 1
gunCDText.Text = "Gun: Ready"
gunCDText.TextColor3 = Color3.fromRGB(88, 255, 128)
gunCDText.TextSize = 10
gunCDText.Font = Enum.Font.GothamBold
gunCDText.Parent = gunCDFrame
local gunCDFill = Instance.new("Frame")
gunCDFill.Size = UDim2.new(1, 0, 0, 2)
gunCDFill.Position = UDim2.new(0, 0, 1, -2)
gunCDFill.BackgroundColor3 = Color3.fromRGB(64, 140, 255)
gunCDFill.BorderSizePixel = 0
gunCDFill.Parent = gunCDFrame

-- Keybind Visualizer
keybindPanel = Instance.new("Frame")
keybindPanel.Size = UDim2.fromOffset(120, 10)
keybindPanel.Position = UDim2.new(0, 6, 0, 6)
keybindPanel.BackgroundColor3 = Color3.fromRGB(20, 17, 30)
keybindPanel.BackgroundTransparency = 0.1
keybindPanel.BorderSizePixel = 0
keybindPanel.Visible = false
keybindPanel.ZIndex = 3
keybindPanel.AutomaticSize = Enum.AutomaticSize.Y
keybindPanel.Parent = Gui
corner(keybindPanel, 6)
local kbStroke = Instance.new("UIStroke") kbStroke.Color = Color3.fromRGB(45, 39, 64) kbStroke.Thickness = 1 kbStroke.Parent = keybindPanel
local kbList = Instance.new("UIListLayout") kbList.Padding = UDim.new(0, 2) kbList.Parent = keybindPanel
local kbPad = Instance.new("UIPadding") kbPad.PaddingTop = UDim.new(0, 4) kbPad.PaddingLeft = UDim.new(0, 6) kbPad.PaddingRight = UDim.new(0, 6) kbPad.PaddingBottom = UDim.new(0, 4) kbPad.Parent = keybindPanel

-- ═══ Главное окно (300x380 — КОМПАКТНО) ═══
local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(300, 380)
Main.Position = UDim2.new(0.5, -150, 0.5, -190)
Main.BackgroundColor3 = Theme.Bg
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = Gui
corner(Main, 10)
stroke(Main, Theme.Stroke, 1)
makeShadow(Main)

local MainScale = Instance.new("UIScale")
MainScale.Scale = 0.7
MainScale.Parent = Main

-- Header (30px)
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 30)
Header.BackgroundColor3 = Theme.Panel
Header.BorderSizePixel = 0
Header.Parent = Main
corner(Header, 10)

local DragBar = Instance.new("Frame")
DragBar.Size = UDim2.new(1, -80, 1, 0)
DragBar.BackgroundTransparency = 1
DragBar.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 80, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "ALFA 0.7"
Title.TextColor3 = Theme.Accent
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header
table.insert(AccentRefs, Title)

local FPSLabel = Instance.new("TextLabel")
FPSLabel.Size = UDim2.new(0, 45, 1, 0)
FPSLabel.Position = UDim2.new(1, -80, 0, 0)
FPSLabel.BackgroundTransparency = 1
FPSLabel.Text = "FPS: --"
FPSLabel.TextColor3 = Theme.SubText
FPSLabel.TextSize = 9
FPSLabel.Font = Enum.Font.GothamBold
FPSLabel.TextXAlignment = Enum.TextXAlignment.Right
FPSLabel.Parent = Header
table.insert(SubTextRefs, FPSLabel)

local PingLabel = Instance.new("TextLabel")
PingLabel.Size = UDim2.new(0, 45, 1, 0)
PingLabel.Position = UDim2.new(1, -36, 0, 0)
PingLabel.BackgroundTransparency = 1
PingLabel.Text = "Ping: --"
PingLabel.TextColor3 = Theme.SubText
PingLabel.TextSize = 9
PingLabel.Font = Enum.Font.GothamBold
PingLabel.TextXAlignment = Enum.TextXAlignment.Right
PingLabel.Parent = Header
table.insert(SubTextRefs, PingLabel)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.fromOffset(22, 22)
MinBtn.Position = UDim2.new(1, -26, 0.5, -11)
MinBtn.BackgroundColor3 = Theme.Card
MinBtn.Text = "—"
MinBtn.TextColor3 = Theme.Text
MinBtn.TextSize = 12
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header
corner(MinBtn, 5)
table.insert(CardRefs, MinBtn)

-- Sidebar (42px, icon-only)
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 42, 1, -30)
Sidebar.Position = UDim2.new(0, 0, 0, 30)
Sidebar.BackgroundColor3 = Theme.Panel
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local sideList = Instance.new("UIListLayout")
sideList.Padding = UDim.new(0, 3)
sideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideList.Parent = Sidebar

local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 5)
sidePad.Parent = Sidebar

-- Tooltip
local Tooltip = Instance.new("Frame")
Tooltip.Size = UDim2.fromOffset(70, 20)
Tooltip.BackgroundColor3 = Theme.Card
Tooltip.BorderSizePixel = 0
Tooltip.Visible = false
Tooltip.ZIndex = 10
Tooltip.Parent = Gui
corner(Tooltip, 5)
stroke(Tooltip, Theme.Accent, 1)
local TooltipText = Instance.new("TextLabel")
TooltipText.Size = UDim2.new(1, -8, 1, 0)
TooltipText.Position = UDim2.new(0, 8, 0, 0)
TooltipText.BackgroundTransparency = 1
TooltipText.TextColor3 = Theme.Text
TooltipText.TextSize = 10
TooltipText.Font = Enum.Font.GothamBold
TooltipText.TextXAlignment = Enum.TextXAlignment.Left
TooltipText.Parent = Tooltip

-- Content (ФИКС: правильный размер, ClipsDescendants)
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -42, 1, -30)
Content.Position = UDim2.new(0, 42, 0, 30)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent = Main

-- Search (24px)
local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -10, 0, 24)
SearchBox.Position = UDim2.new(0, 5, 0, 5)
SearchBox.BackgroundColor3 = Theme.Card
SearchBox.TextColor3 = Theme.Text
SearchBox.PlaceholderColor3 = Theme.SubText
SearchBox.PlaceholderText = " Поиск..."
SearchBox.Text = ""
SearchBox.TextSize = 10
SearchBox.Font = Enum.Font.Gotham
SearchBox.ClearTextOnFocus = false
SearchBox.BorderSizePixel = 0
SearchBox.Parent = Content
corner(SearchBox, 6)
local searchStroke = stroke(SearchBox, Theme.Stroke, 1)
table.insert(CardRefs, SearchBox)

SearchBox.Focused:Connect(function()
    TweenService:Create(searchStroke, TweenInfo.new(0.2), { Color = Theme.Accent }):Play()
end)
SearchBox.FocusLost:Connect(function()
    TweenService:Create(searchStroke, TweenInfo.new(0.2), { Color = Theme.Stroke }):Play()
end)

-- Pages (ФИКС: правильный размер с учётом search + cmd bar)
local Pages = Instance.new("Frame")
Pages.Size = UDim2.new(1, -10, 1, -60)
Pages.Position = UDim2.new(0, 5, 0, 34)
Pages.BackgroundTransparency = 1
Pages.ClipsDescendants = true
Pages.Parent = Content

-- Command bar (24px)
local CmdBar = Instance.new("TextBox")
CmdBar.Size = UDim2.new(1, -10, 0, 24)
CmdBar.Position = UDim2.new(0, 5, 1, -29)
CmdBar.BackgroundColor3 = Theme.Card
CmdBar.TextColor3 = Theme.Text
CmdBar.PlaceholderColor3 = Theme.SubText
CmdBar.PlaceholderText = " ⌘ Команда... (help)"
CmdBar.Text = ""
CmdBar.TextSize = 10
CmdBar.Font = Enum.Font.Code
CmdBar.ClearTextOnFocus = false
CmdBar.BorderSizePixel = 0
CmdBar.Parent = Content
corner(CmdBar, 6)
local cmdStroke = stroke(CmdBar, Theme.Stroke, 1)
table.insert(CardRefs, CmdBar)

CmdBar.Focused:Connect(function() TweenService:Create(cmdStroke, TweenInfo.new(0.2), { Color = Theme.Accent }):Play() end)
CmdBar.FocusLost:Connect(function() TweenService:Create(cmdStroke, TweenInfo.new(0.2), { Color = Theme.Stroke }):Play() end)

-- Toasts
local ToastHolder = Instance.new("Frame")
ToastHolder.Size = UDim2.new(0, 200, 1, 0)
ToastHolder.Position = UDim2.new(1, -210, 0, 40)
ToastHolder.BackgroundTransparency = 1
ToastHolder.ZIndex = 5
ToastHolder.Parent = Gui
local toastList = Instance.new("UIListLayout")
toastList.Padding = UDim.new(0, 4)
toastList.SortOrder = Enum.SortOrder.LayoutOrder
toastList.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastList.Parent = ToastHolder

local function createNotification(title, text, dur)
    dur = dur or 4
    local t = Instance.new("Frame")
    t.Size = UDim2.new(1, 0, 0, 0)
    t.AutomaticSize = Enum.AutomaticSize.Y
    t.BackgroundColor3 = Theme.Panel
    t.BorderSizePixel = 0
    t.ZIndex = 5
    t.Parent = ToastHolder
    corner(t, 6)
    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(0, 2, 1, -8)
    accentLine.Position = UDim2.new(0, 3, 0, 4)
    accentLine.BackgroundColor3 = Theme.Accent
    accentLine.BorderSizePixel = 0
    accentLine.Parent = t
    corner(accentLine, 1)
    local tt = Instance.new("TextLabel")
    tt.Size = UDim2.new(1, -16, 0, 16)
    tt.Position = UDim2.new(0, 10, 0, 4)
    tt.BackgroundTransparency = 1
    tt.Text = title
    tt.TextColor3 = Theme.Accent
    tt.TextSize = 10
    tt.Font = Enum.Font.GothamBold
    tt.TextXAlignment = Enum.TextXAlignment.Left
    tt.ZIndex = 6
    tt.Parent = t
    local tx = Instance.new("TextLabel")
    tx.Size = UDim2.new(1, -16, 0, 0)
    tx.AutomaticSize = Enum.AutomaticSize.Y
    tx.Position = UDim2.new(0, 10, 0, 20)
    tx.BackgroundTransparency = 1
    tx.Text = text
    tx.TextColor3 = Theme.Text
    tx.TextSize = 9
    tx.Font = Enum.Font.Gotham
    tx.TextWrapped = true
    tx.TextXAlignment = Enum.TextXAlignment.Left
    tx.ZIndex = 6
    tx.Parent = t
    t.BackgroundTransparency = 1
    t.Position = UDim2.new(1, 20, 0, 0)
    TweenService:Create(t, TweenInfo.new(0.2), { BackgroundTransparency = 0, Position = UDim2.new(1, 0, 0, 0) }):Play()
    playSound("notify", 0.1)
    task.delay(dur, function()
        pcall(function()
            TweenService:Create(t, TweenInfo.new(0.25), { BackgroundTransparency = 1, Position = UDim2.new(1, 20, 0, 0) }):Play()
            task.wait(0.25)
            t:Destroy()
            notifActiveCount = math.max(0, notifActiveCount - 1)
        end)
    end)
end

notify = function(title, text, dur)
    table.insert(notifQueue, { title = title, text = text, dur = dur or 4 })
end

task.spawn(function()
    while Gui.Parent do
        if #notifQueue > 0 and notifActiveCount < 3 then
            local n = table.remove(notifQueue, 1)
            notifActiveCount += 1
            createNotification(n.title, n.text, n.dur)
            task.wait(0.15)
        else
            task.wait(0.1)
        end
    end
end)

-- Crosshair
local crosshair = Instance.new("Frame")
crosshair.Size = UDim2.fromOffset(5, 5)
crosshair.Position = UDim2.new(0.5, -2, 0.5, -2)
crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
crosshair.BorderSizePixel = 0
crosshair.Visible = false
crosshair.ZIndex = 4
crosshair.Parent = Gui
corner(crosshair, 2)

-- ═══ 11. UI КОНСТРУКТОРЫ (КОМПАКТНЫЕ) ═══
local tabOrder = {}
local currentPage = "Main"
local selectTab

local TabIcons = {
    Main = "🏠", Combat = "⚔️", Visuals = "👁️", Move = "🏃",
    Players = "👥", Farm = "🪙", Fun = "🎭", Misc = "🛠️", Settings = "⚙️",
}

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(34, 34)
    btn.BackgroundColor3 = Theme.Panel
    btn.Text = TabIcons[name] or "?"
    btn.TextColor3 = Theme.SubText
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = Sidebar
    corner(btn, 8)
    table.insert(CardRefs, btn)
    table.insert(SubTextRefs, btn)

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 2, 0, 0)
    accentBar.Position = UDim2.new(0, -1, 0.5, 0)
    accentBar.BackgroundColor3 = Theme.Accent
    accentBar.BorderSizePixel = 0
    accentBar.Parent = btn
    corner(accentBar, 1)
    table.insert(AccentRefs, accentBar)

    btn.MouseEnter:Connect(function()
        if currentPage ~= name then
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.Hover }):Play()
        end
        TooltipText.Text = name
        Tooltip.Position = UDim2.new(0, btn.AbsolutePosition.X + 40, 0, btn.AbsolutePosition.Y)
        Tooltip.Visible = true
    end)
    btn.MouseLeave:Connect(function()
        if currentPage ~= name then
            TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.Panel }):Play()
        end
        Tooltip.Visible = false
    end)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Theme.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = Pages
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 2)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = page
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 2)
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingRight = UDim.new(0, 2)
    pad.Parent = page

    local tab = { Name = name, Btn = btn, Page = page, AccentBar = accentBar }
    table.insert(tabOrder, tab)
    btn.MouseButton1Click:Connect(function() selectTab(name) end)
    return page
end

selectTab = function(name)
    currentPage = name
    for _, t in ipairs(tabOrder) do
        local isActive = (t.Name == name)
        if isActive then
            t.Page.Visible = true
            t.Page.BackgroundTransparency = 0.3
            TweenService:Create(t.Page, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
        else
            t.Page.Visible = false
        end
        TweenService:Create(t.Btn, TweenInfo.new(0.18), {
            BackgroundColor3 = isActive and Theme.Card or Theme.Panel,
        }):Play()
        TweenService:Create(t.Btn, TweenInfo.new(0.18), {
            TextColor3 = isActive and Theme.Accent or Theme.SubText,
        }):Play()
        TweenService:Create(t.AccentBar, TweenInfo.new(0.2), {
            Size = isActive and UDim2.new(0, 2, 0, 18) or UDim2.new(0, 2, 0, 0),
            Position = isActive and UDim2.new(0, -1, 0.5, -9) or UDim2.new(0, -1, 0.5, 0),
        }):Play()
    end
    playSound("click", 0.08)
end

local function sectionHeader(parent, title)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 20)
    holder.BackgroundTransparency = 1
    holder.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 14)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Theme.Accent
    label.TextSize = 9
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder
    table.insert(AccentRefs, label)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Theme.Stroke
    line.BorderSizePixel = 0
    line.Parent = holder
    return holder
end

local function newCard(parent, height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, height or 28)
    card.BackgroundColor3 = Theme.Card
    card.BorderSizePixel = 0
    card.Parent = parent
    corner(card, 6)
    stroke(card, Theme.Stroke, 1)
    table.insert(CardRefs, card)
    return card
end

-- КОМПАКТНЫЙ ТОГГЛ (28px height)
local function makeToggle(parent, name, default, callback)
    local card = newCard(parent, 28)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Theme.Text
    label.TextSize = 10
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = name
    label.Parent = card
    table.insert(TextRefs, label)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.fromOffset(32, 12)
    bar.Position = UDim2.new(1, -40, 0.5, -6)
    bar.BackgroundColor3 = Theme.Stroke
    bar.BorderSizePixel = 0
    bar.Parent = card
    corner(bar, 6)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(10, 10)
    knob.Position = UDim2.new(0, 1, 0.5, -5)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    corner(knob, 5)

    local glow = Instance.new("UIStroke")
    glow.Color = Theme.Accent
    glow.Thickness = 0
    glow.Transparency = 0.3
    glow.Parent = knob

    local state = default == true
    local function render()
        local tween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if state then
            TweenService:Create(bar, tween, { BackgroundColor3 = Theme.Accent }):Play()
            TweenService:Create(knob, tween, { Position = UDim2.new(1, -11, 0.5, -5) }):Play()
            TweenService:Create(glow, tween, { Thickness = 1.5 }):Play()
        else
            TweenService:Create(bar, tween, { BackgroundColor3 = Theme.Stroke }):Play()
            TweenService:Create(knob, tween, { Position = UDim2.new(0, 1, 0.5, -5) }):Play()
            TweenService:Create(glow, tween, { Thickness = 0 }):Play()
        end
    end
    local function set(v, silent)
        state = v and true or false
        Flags[name] = state
        render()
        if not silent then playSound("toggle", 0.08) end
        if callback then pcall(callback, state) end
    end
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = card
    btn.MouseEnter:Connect(function() TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Hover }):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Card }):Play() end)
    btn.MouseButton1Click:Connect(function() set(not state) end)
    set(state, true)
    UIRegistry[name] = function(v) set(v, true) end
end

-- КОМПАКТНАЯ КНОПКА (28px)
local function makeButton(parent, text, callback)
    local card = newCard(parent, 28)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Theme.Text
    label.TextSize = 10
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = card
    table.insert(TextRefs, label)

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.fromOffset(12, 12)
    arrow.Position = UDim2.new(1, -16, 0.5, -6)
    arrow.BackgroundTransparency = 1
    arrow.Text = "→"
    arrow.TextColor3 = Theme.SubText
    arrow.TextSize = 12
    arrow.Font = Enum.Font.GothamBold
    arrow.Parent = card
    table.insert(SubTextRefs, arrow)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = card
    btn.MouseEnter:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Hover }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.1), { TextColor3 = Theme.Accent }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Card }):Play()
        TweenService:Create(arrow, TweenInfo.new(0.1), { TextColor3 = Theme.SubText }):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.06), { BackgroundColor3 = Theme.Accent }):Play()
        task.wait(0.06)
        TweenService:Create(card, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Card }):Play()
        playSound("click", 0.08)
        pcall(callback)
    end)
end

-- КОМПАКТНЫЙ СЛАЙДЕР (30px)
local function makeSlider(parent, name, min, max, default, cb)
    local card = newCard(parent, 30)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 0, 12)
    label.Position = UDim2.new(0, 8, 0, 2)
    label.BackgroundTransparency = 1
    label.TextColor3 = Theme.Text
    label.TextSize = 10
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = name
    label.Parent = card
    table.insert(TextRefs, label)

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 40, 0, 12)
    valLbl.Position = UDim2.new(1, -8, 0, 2)
    valLbl.BackgroundTransparency = 1
    valLbl.TextColor3 = Theme.Accent
    valLbl.TextSize = 9
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Text = tostring(default)
    valLbl.Parent = card
    table.insert(AccentRefs, valLbl)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -16, 0, 5)
    bar.Position = UDim2.new(0, 8, 0, 20)
    bar.BackgroundColor3 = Theme.Stroke
    bar.BorderSizePixel = 0
    bar.Parent = card
    corner(bar, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0.5, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    corner(fill, 3)
    table.insert(AccentRefs, fill)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(10, 10)
    knob.Position = UDim2.new(0.5, -5, 0.5, -3)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    corner(knob, 5)

    local function set(v, silent)
        v = math.clamp(tonumber(v) or min, min, max)
        Flags[name] = v
        valLbl.Text = tostring(math.floor(v * 100) / 100)
        local alpha = (v - min) / (max - min)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, -5, 0.5, -3)
        if not silent and cb then pcall(cb, v) end
    end
    local draggingS = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingS = true
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingS = false
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if draggingS and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local w = bar.AbsoluteSize.X
            if w > 0 then
                local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / w, 0, 1)
                set(min + (max - min) * alpha)
            end
        end
    end))
    set(default, true)
    UIRegistry[name] = function(v) set(v) end
end

-- КОМПАКТНЫЙ KEYBIND (28px)
local Keybinds = {}
local keybindListeningFor = nil
track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if keybindListeningFor then
        local fn = keybindListeningFor
        keybindListeningFor = nil
        if input.KeyCode ~= Enum.KeyCode.Escape then pcall(fn, input.KeyCode) end
        return
    end
    for _, bind in pairs(Keybinds) do
        if bind.key == input.KeyCode then pcall(bind.callback) end
    end
end))

local function makeKeybind(parent, name, defaultKey, callback)
    local card = newCard(parent, 28)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Theme.Text
    label.TextSize = 10
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = name
    label.Parent = card
    table.insert(TextRefs, label)

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.fromOffset(48, 18)
    keyBtn.Position = UDim2.new(1, -56, 0.5, -9)
    keyBtn.BackgroundColor3 = Theme.Stroke
    keyBtn.Text = defaultKey and defaultKey.Name or "None"
    keyBtn.TextColor3 = Theme.Accent
    keyBtn.TextSize = 9
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.BorderSizePixel = 0
    keyBtn.Parent = card
    corner(keyBtn, 4)

    local currentKey = defaultKey
    local function updateKey(newKey)
        if currentKey and Keybinds[name] then Keybinds[name] = nil end
        currentKey = newKey
        keyBtn.Text = newKey and newKey.Name or "None"
        if newKey then Keybinds[name] = { key = newKey, callback = callback } end
    end
    keyBtn.MouseButton1Click:Connect(function()
        keyBtn.Text = "..."
        TweenService:Create(keyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Accent, TextColor3 = Color3.new(0,0,0) }):Play()
        keybindListeningFor = function(key)
            TweenService:Create(keyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Stroke, TextColor3 = Theme.Accent }):Play()
            updateKey(key)
        end
    end)
    if defaultKey then updateKey(defaultKey) end
end

-- Drag
local function makeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end
makeDraggable(DragBar)

-- M Button (32x32, ФИКС: Scale позиция для мобильных)
local menuOpen = true
local function toggleMenu()
    menuOpen = not menuOpen
    if menuOpen then
        Main.Visible = true
        MainScale.Scale = 0.8
        TweenService:Create(MainScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    else
        TweenService:Create(MainScale, TweenInfo.new(0.15), { Scale = 0.8 }):Play()
        task.wait(0.15)
        Main.Visible = false
    end
end

local MBtn = Instance.new("TextButton")
MBtn.Size = UDim2.fromOffset(32, 32)
MBtn.Position = UDim2.new(1, -38, 1, -38)
MBtn.BackgroundColor3 = Theme.Accent
MBtn.Text = "M"
MBtn.TextColor3 = Color3.new(0, 0, 0)
MBtn.TextSize = 14
MBtn.Font = Enum.Font.GothamBold
MBtn.ZIndex = 6
MBtn.BorderSizePixel = 0
MBtn.Parent = Gui
corner(MBtn, 16)
table.insert(AccentRefs, MBtn)

local mScale = Instance.new("UIScale") mScale.Parent = MBtn
task.spawn(function()
    while Gui.Parent do
        task.wait(2)
        if not menuOpen then
            TweenService:Create(mScale, TweenInfo.new(0.6), { Scale = 1.1 }):Play()
            task.wait(0.6)
            TweenService:Create(mScale, TweenInfo.new(0.6), { Scale = 1.0 }):Play()
        end
    end
end)

local mDrag, mDI, mDS, mSP
MBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        mDrag = true mDS = input.Position mSP = MBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                mDrag = false
                if math.abs((input.Position - mDS).X) + math.abs((input.Position - mDS).Y) < 6 then toggleMenu() end
            end
        end)
    end
end)
MBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then mDI = input end
end)
track(UserInputService.InputChanged:Connect(function(input)
    if mDrag and input == mDI then
        local delta = input.Position - mDS
        MBtn.Position = UDim2.new(mSP.X.Scale, mSP.X.Offset + delta.X, mSP.Y.Scale, mSP.Y.Offset + delta.Y)
    end
end))
MinBtn.MouseButton1Click:Connect(toggleMenu)

-- ФИКС: Pin buttons с Scale позиционированием для мобильных
local function makePin(letter, color, row, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(30, 30)
    b.Position = UDim2.new(1, -38, 1, -80 - row * 36)
    b.BackgroundColor3 = color
    b.Text = letter
    b.TextColor3 = Color3.new(0, 0, 0)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.ZIndex = 3
    b.BorderSizePixel = 0
    b.Parent = Gui
    corner(b, 15)
    local glow = Instance.new("UIStroke") glow.Color = color glow.Thickness = 0 glow.Transparency = 0.4 glow.Parent = b
    b.MouseEnter:Connect(function()
        TweenService:Create(glow, TweenInfo.new(0.12), { Thickness = 2.5 }):Play()
        TweenService:Create(b, TweenInfo.new(0.12), { Size = UDim2.fromOffset(34, 34) }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(glow, TweenInfo.new(0.12), { Thickness = 0 }):Play()
        TweenService:Create(b, TweenInfo.new(0.12), { Size = UDim2.fromOffset(30, 30) }):Play()
    end)
    local pDrag, pDI, pDS, pSP
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pDrag = true pDS = input.Position pSP = b.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    pDrag = false
                    if math.abs((input.Position - pDS).X) + math.abs((input.Position - pDS).Y) < 6 then pcall(cb) end
                end
            end)
        end
    end)
    b.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then pDI = input end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if pDrag and input == pDI then
            local delta = input.Position - pDS
            b.Position = UDim2.new(pSP.X.Scale, pSP.X.Offset + delta.X, pSP.Y.Scale, pSP.Y.Offset + delta.Y)
        end
    end))
    return b
end
makePin("S",  Color3.fromRGB(64, 140, 255), 0, function() shootMurderer() end)
makePin("K",  Color3.fromRGB(255, 64, 64),  1, function() throwKnife() end)
makePin("KA", Theme.Accent, 2, function() killAll() end)

-- ═══ 12. ВКЛАДКИ ═══
local tabMain    = createTab("Main")
local tabCombat  = createTab("Combat")
local tabVisuals = createTab("Visuals")
local tabMove    = createTab("Move")
local tabPlayers = createTab("Players")
local tabFarm    = createTab("Farm")
local tabFun     = createTab("Fun")
local tabMisc    = createTab("Misc")
local tabSet     = createTab("Settings")

-- MAIN
sectionHeader(tabMain, "Quick Actions")
makeButton(tabMain, "🔫 Shoot Murderer", function() shootMurderer() end)
makeButton(tabMain, "🗡️ Throw Knife", function() throwKnife() end)
makeButton(tabMain, "💀 Kill All", function() killAll() end)
makeButton(tabMain, "🔍 Reveal Roles", function() revealRoles() end)

sectionHeader(tabMain, "Keybinds")
makeKeybind(tabMain, "Shoot", Enum.KeyCode.G, function() shootMurderer() end)
makeKeybind(tabMain, "Knife", Enum.KeyCode.V, function() throwKnife() end)
makeKeybind(tabMain, "Spectate", Enum.KeyCode.F2, function() spectateNext() end)
makeKeybind(tabMain, "Stop Spec", Enum.KeyCode.F3, function() stopSpectate() end)
makeKeybind(tabMain, "Decoy", Enum.KeyCode.C, function() createDecoy() end)

-- COMBAT
sectionHeader(tabCombat, "Actions")
makeButton(tabCombat, "🔫 Shoot Murderer", function() shootMurderer() end)
makeButton(tabCombat, "🗡️ Throw Knife", function() throwKnife() end)
makeButton(tabCombat, "💀 Kill All", function() killAll() end)
makeButton(tabCombat, "🎖️ Kill Sheriff", function() killByRole("Sheriff") end)

sectionHeader(tabCombat, "Auto")
makeToggle(tabCombat, "Role Auto Mode", false, function(on) autoModeEnabled = on end)
makeToggle(tabCombat, "Kill Aura", false)
makeToggle(tabCombat, "Auto Shoot", false)
makeToggle(tabCombat, "Auto Knife", false)
makeToggle(tabCombat, "Auto Grab Gun", false)
makeToggle(tabCombat, "Auto Save Sheriff", false)
makeToggle(tabCombat, "Silent Aim", false) -- НОВАЯ 1
makeToggle(tabCombat, "Triggerbot", false, function(on) triggerbotActive = on end) -- НОВАЯ 2
makeToggle(tabCombat, "Auto Collect Drops", false) -- НОВАЯ 3

sectionHeader(tabCombat, "Aiming")
makeToggle(tabCombat, "Aimbot", false)
makeSlider(tabCombat, "Aim Smoothness", 0.05, 1, 0.25, function(v) aimSmooth = v end)
makeToggle(tabCombat, "Hitbox Expander", false, function(on) setHitbox(on) end)

-- VISUALS
sectionHeader(tabVisuals, "ESP")
makeToggle(tabVisuals, "Player ESP", false)
makeToggle(tabVisuals, "Chams", false)
makeToggle(tabVisuals, "Tracers", false)
makeToggle(tabVisuals, "Coin ESP", false)
makeToggle(tabVisuals, "Player Trail", false) -- НОВАЯ 4

sectionHeader(tabVisuals, "World")
makeToggle(tabVisuals, "FOV Circle", false)
makeToggle(tabVisuals, "Crosshair", false, function(on) crosshair.Visible = on end)
makeToggle(tabVisuals, "Fullbright", false, function(on) setFullbright(on) end)
makeToggle(tabVisuals, "No Fog", false)
makeToggle(tabVisuals, "FPS Boost", false, function(on) setFPSBoost(on) end)
makeSlider(tabVisuals, "Camera FOV", 50, 120, 70, function(v) setFOV(v) end) -- НОВАЯ 5
makeToggle(tabVisuals, "Zoom Override", false, function(on) setZoomOverride(on) end) -- НОВАЯ 6
makeToggle(tabVisuals, "No Camera Shake", false) -- НОВАЯ 7

sectionHeader(tabVisuals, "Alerts")
makeToggle(tabVisuals, "Murderer Alert", false, function(on) alertRunning = on if not on then alertOverlay.BackgroundTransparency = 1 end end)
makeSlider(tabVisuals, "Alert Distance", 20, 200, 50, function() end)
makeToggle(tabVisuals, "Hit Sound", false) -- НОВАЯ 8

sectionHeader(tabVisuals, "Tactical")
makeToggle(tabVisuals, "Last Seen Marker", false)
makeToggle(tabVisuals, "Position Predictor", false)
makeToggle(tabVisuals, "AFK Detector", false)
makeToggle(tabVisuals, "Group Detector", false)
makeToggle(tabVisuals, "Round Timer HUD", false, function(on) roundTimerFrame.Visible = on end)
makeToggle(tabVisuals, "Gun Cooldown", false, function(on) gunCDFrame.Visible = on end)
makeToggle(tabVisuals, "Velocity Display", false) -- НОВАЯ 9

-- MOVE
sectionHeader(tabMove, "Movement")
makeSlider(tabMove, "WalkSpeed", 16, 200, 16, function(v) local h = getHum(LocalPlayer) if h then h.WalkSpeed = v end end)
makeSlider(tabMove, "JumpPower", 50, 300, 50, function(v) local h = getHum(LocalPlayer) if h then h.UseJumpPower = true h.JumpPower = v end end)
makeToggle(tabMove, "Infinite Jump", false)

sectionHeader(tabMove, "Advanced")
makeToggle(tabMove, "Fly", false, function(on) setFly(on) end)
makeSlider(tabMove, "Fly Speed", 10, 300, 80, function(v) flySpeed = v end)
makeToggle(tabMove, "Noclip", false)
makeToggle(tabMove, "Click TP", false)
makeToggle(tabMove, "Anti-Void", false)
makeToggle(tabMove, "First Person Lock", false, function(on) setFirstPerson(on) end) -- НОВАЯ 10

sectionHeader(tabMove, "Stealth")
makeToggle(tabMove, "Fake Lag", false) -- НОВАЯ 11
makeToggle(tabMove, "Anti-Fling", false, function(on) setAntiFling(on) end) -- НОВАЯ 12
makeButton(tabMove, "🎭 Clone Decoy", function() createDecoy() end)

sectionHeader(tabMove, "Quick TP") -- НОВАЯ 13
makeButton(tabMove, "📍 TP to Spawn", function() tpToSpawn() end)
makeButton(tabMove, "📍 TP to Center", function() tpToCenter() end)
makeButton(tabMove, "📍 TP to Nearest", function() tpToNearestPlayer() end)

-- PLAYERS (динамический список)

-- FARM
sectionHeader(tabFarm, "Coins")
makeToggle(tabFarm, "Auto Farm Coins", false)
makeSlider(tabFarm, "Farm Delay", 0.05, 1, 0.15, function(v) farmDelay = v end)
makeToggle(tabFarm, "Coin ESP", false)

-- FUN
sectionHeader(tabFun, "Trolling")
makeToggle(tabFun, "Fling All", false, function(on) setFling(on) end)
makeToggle(tabFun, "Spin Bot", false, function(on) setSpin(on) end)
makeToggle(tabFun, "Auto Dance", false)
makeToggle(tabFun, "Chat Spam", false)

sectionHeader(tabFun, "Emotes")
makeButton(tabFun, "😀 dance", function() say("/e dance") end)
makeButton(tabFun, "👋 wave", function() say("/e wave") end)
makeButton(tabFun, "🪑 sit", function() say("/e sit") end)
makeButton(tabFun, "🎉 cheer", function() say("/e cheer") end)

-- MISC
sectionHeader(tabMisc, "Utility")
makeToggle(tabMisc, "Anti-AFK", false)
makeToggle(tabMisc, "Chat Logger", false)
makeToggle(tabMisc, "Auto Reconnect", false) -- НОВАЯ 14
makeToggle(tabMisc, "Name Hider", false, function(on) setNameHider(on) end) -- НОВАЯ 15

sectionHeader(tabMisc, "Server")
makeButton(tabMisc, "🔄 Rejoin", function() rejoin() end)
makeButton(tabMisc, "🌐 Server Hop", function() serverHop() end)
makeButton(tabMisc, "🎟️ Redeem Codes", function() redeemCodes() end)
makeButton(tabMisc, "🔍 Reveal Roles", function() revealRoles() end)

sectionHeader(tabMisc, "Config")
makeButton(tabMisc, "💾 Save Config", function() saveConfig() end)
makeButton(tabMisc, "📂 Load Config", function() loadConfig() end)

-- SETTINGS
sectionHeader(tabSet, "Themes")
local themeButtons = { { "Midnight", "🟣" }, { "Cyber", "🟢" }, { "Crimson", "🔴" }, { "Frost", "🔵" }, { "Gold", "🟡" } }

local function applyTheme(themeName)
    currentThemeName = themeName
    Theme = Themes[themeName]
    Main.BackgroundColor3 = Theme.Bg
    Header.BackgroundColor3 = Theme.Panel
    Sidebar.BackgroundColor3 = Theme.Panel
    CmdBar.BackgroundColor3 = Theme.Card
    SearchBox.BackgroundColor3 = Theme.Card
    for _, f in ipairs(CardRefs) do f.BackgroundColor3 = Theme.Card end
    for _, t in ipairs(TextRefs) do t.TextColor3 = Theme.Text end
    for _, t in ipairs(SubTextRefs) do t.TextColor3 = Theme.SubText end
    for _, f in ipairs(AccentRefs) do
        if f:IsA("TextLabel") then f.TextColor3 = Theme.Accent
        elseif f:IsA("Frame") then f.BackgroundColor3 = Theme.Accent end
    end
    for _, s in ipairs(StrokeRefs) do
        if s:IsA("UIStroke") then s.Color = Theme.Stroke end
    end
    for _, t in ipairs(tabOrder) do
        local isActive = (t.Name == currentPage)
        t.Btn.BackgroundColor3 = isActive and Theme.Card or Theme.Panel
        t.Btn.TextColor3 = isActive and Theme.Accent or Theme.SubText
        t.AccentBar.BackgroundColor3 = Theme.Accent
    end
    Title.TextColor3 = Theme.Accent
    Tooltip.BackgroundColor3 = Theme.Card
    TooltipText.TextColor3 = Theme.Text
    MinBtn.BackgroundColor3 = Theme.Card
    MinBtn.TextColor3 = Theme.Text
    notify("Theme", themeName, 2)
end

for _, t in ipairs(themeButtons) do
    makeButton(tabSet, t[2] .. " " .. t[1], function() applyTheme(t[1]) end)
end

sectionHeader(tabSet, "Audio")
makeToggle(tabSet, "Sound Effects", true, function(on) SoundEnabled = on end)
makeToggle(tabSet, "Keybind Visualizer", false, function(on) keybindPanel.Visible = on end)

sectionHeader(tabSet, "Safety")
makeToggle(tabSet, "Safe Mode", false, function(on) setSafeMode(on) end)

sectionHeader(tabSet, "Keybinds")
makeKeybind(tabSet, "Shoot", nil, function() shootMurderer() end)
makeKeybind(tabSet, "Knife", nil, function() throwKnife() end)
makeKeybind(tabSet, "Kill All", nil, function() killAll() end)
makeKeybind(tabSet, "Toggle Fly", nil, function() local c = Flags["Fly"] or false if UIRegistry["Fly"] then UIRegistry["Fly"](not c) end end)
makeKeybind(tabSet, "Toggle Noclip", nil, function() local c = Flags["Noclip"] or false if UIRegistry["Noclip"] then UIRegistry["Noclip"](not c) end end)
makeKeybind(tabSet, "Toggle ESP", nil, function() local c = Flags["Player ESP"] or false if UIRegistry["Player ESP"] then UIRegistry["Player ESP"](not c) end end)

sectionHeader(tabSet, "Danger")
makeButton(tabSet, "🚨 PANIC", function()
    for name in pairs(Flags) do
        if Flags[name] == true and UIRegistry[name] then pcall(function() UIRegistry[name](false) end) end
    end
    setFullbright(false) setFPSBoost(false) setHitbox(false)
    alertRunning = false alertOverlay.BackgroundTransparency = 1
    autoModeEnabled = false safeModeOn = false stopSpectate()
    notify("PANIC", "Всё OFF", 3)
end)
makeButton(tabSet, "❌ Unload", function()
    clearAll()
    pcall(function() Gui:Destroy() end)
    getgenv().ALFA07_UNLOAD = nil
end)

getgenv().ALFA07_UNLOAD = function()
    clearAll()
    pcall(function() Gui:Destroy() end)
    getgenv().ALFA07_UNLOAD = nil
end

-- ФИКС: поиск по ВСЕМ вкладкам
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local q = SearchBox.Text:lower()
    for _, tab in ipairs(tabOrder) do
        for _, child in ipairs(tab.Page:GetChildren()) do
            if child:IsA("Frame") then
                local lbl = child:FindFirstChildWhichIsA("TextLabel")
                if lbl then
                    child.Visible = (q == "") or (lbl.Text:lower():find(q, 1, true) ~= nil)
                end
            end
        end
    end
end)

-- ═══ 13. COMMAND BAR ═══
local Commands = {
    ["shoot"] = function() shootMurderer() end,
    ["knife"] = function(a) if a[1] then local t = getPlayerByName(a[1]) if t then throwKnife(t) else notify("Cmd", "Не найден") end else throwKnife() end end,
    ["killall"] = function() killAll() end,
    ["killsheriff"] = function() killByRole("Sheriff") end,
    ["tp"] = function(a) if a[1] then local t = getPlayerByName(a[1]) if t then tpToPlayer(t) else notify("Cmd", "Не найден") end else notify("Cmd", "Укажи имя") end end,
    ["spawn"] = function() tpToSpawn() end,
    ["center"] = function() tpToCenter() end,
    ["spectate"] = function() spectateNext() end,
    ["stopspec"] = function() stopSpectate() end,
    ["decoy"] = function() createDecoy() end,
    ["fly"] = function() local c = Flags["Fly"] or false if UIRegistry["Fly"] then UIRegistry["Fly"](not c) end end,
    ["noclip"] = function() local c = Flags["Noclip"] or false if UIRegistry["Noclip"] then UIRegistry["Noclip"](not c) end end,
    ["esp"] = function() local c = Flags["Player ESP"] or false if UIRegistry["Player ESP"] then UIRegistry["Player ESP"](not c) end end,
    ["chams"] = function() local c = Flags["Chams"] or false if UIRegistry["Chams"] then UIRegistry["Chams"](not c) end end,
    ["fullbright"] = function() local c = Flags["Fullbright"] or false if UIRegistry["Fullbright"] then UIRegistry["Fullbright"](not c) end end,
    ["speed"] = function(a) if a[1] then local v = tonumber(a[1]) if v and UIRegistry["WalkSpeed"] then UIRegistry["WalkSpeed"](v) end end end,
    ["jump"] = function(a) if a[1] then local v = tonumber(a[1]) if v and UIRegistry["JumpPower"] then UIRegistry["JumpPower"](v) end end end,
    ["rejoin"] = function() rejoin() end,
    ["hop"] = function() serverHop() end,
    ["reveal"] = function() revealRoles() end,
    ["codes"] = function() redeemCodes() end,
    ["safe"] = function() setSafeMode(not safeModeOn) end,
    ["panic"] = function()
        for name in pairs(Flags) do
            if Flags[name] == true and UIRegistry[name] then pcall(function() UIRegistry[name](false) end) end
        end
        setFullbright(false) setFPSBoost(false) setHitbox(false) alertRunning = false
        alertOverlay.BackgroundTransparency = 1 autoModeEnabled = false safeModeOn = false stopSpectate()
        notify("PANIC", "Всё OFF", 3)
    end,
    ["theme"] = function(a) if a[1] then local n = a[1]:gsub("^%l", string.upper) if Themes[n] then applyTheme(n) else notify("Cmd", "Midnight, Cyber, Crimson, Frost, Gold", 4) end end end,
    ["help"] = function() notify("Команды", "shoot, knife [name], killall, tp [name], spawn, center, spectate, stopspec, decoy, fly, noclip, esp, chams, fullbright, speed [n], jump [n], rejoin, hop, reveal, codes, safe, panic, theme [name], unload", 8) end,
    ["unload"] = function() clearAll() pcall(function() Gui:Destroy() end) getgenv().ALFA07_UNLOAD = nil end,
}
CmdBar.FocusLost:Connect(function(enter)
    if enter then
        local text = CmdBar.Text
        CmdBar.Text = ""
        if text == "" then return end
        local args = {}
        for word in text:gmatch("%S+") do table.insert(args, word) end
        local cmd = table.remove(args, 1):lower()
        if Commands[cmd] then pcall(Commands[cmd], args) else notify("Cmd", "Неизвестная: " .. cmd, 3) end
    end
end)

-- ═══ 14. LOOPS ═══
local frames = 0
track(RunService.RenderStepped:Connect(function() frames += 1 end))
task.spawn(function()
    while Gui.Parent do
        task.wait(1)
        FPSLabel.Text = ("FPS: %d"):format(frames)
        frames = 0
        local okP, ping = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
        PingLabel.Text = okP and ("Ping: %dms"):format(math.floor(ping)) or "Ping: —"
    end
end)

-- FOV Circle
local fovCircle
if Drawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5
    fovCircle.NumSides = 60
    fovCircle.Radius = 130
    fovCircle.Filled = false
    fovCircle.Visible = false
    cleanupFn(function() pcall(function() fovCircle:Remove() end) end)
end

-- RenderStepped main
track(RunService.RenderStepped:Connect(function()
    if Flags["Aimbot"] then
        local m = getMurderer()
        if m and isVisible(m) then
            local hrp = getHRP(m)
            if hrp then
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, hrp.Position), aimSmooth)
            end
        end
    end
    if Flags["Silent Aim"] then
        silentAim()
    end
    if triggerbotActive then
        local m = getMurderer()
        if m and alive(m) then
            local hrp = getHRP(m)
            if hrp then
                local sp, on = Camera:WorldToViewportPoint(hrp.Position)
                if on then
                    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    if (Vector2.new(sp.X, sp.Y) - center).Magnitude < 50 then
                        shootMurderer()
                        triggerbotActive = false
                        task.delay(1.5, function() if Flags["Triggerbot"] then triggerbotActive = true end end)
                    end
                end
            end
        end
    end
    if flyActive and Flags["Fly"] then
        local hum, hrp = getHum(LocalPlayer), getHRP(LocalPlayer)
        if hum and hrp then
            if flyObjects and flyObjects.bv.Parent then
                local v = hum.MoveDirection * flySpeed
                if keys[Enum.KeyCode.Space] then v += Vector3.new(0, flySpeed, 0) end
                if keys[Enum.KeyCode.LeftControl] then v -= Vector3.new(0, flySpeed, 0) end
                flyObjects.bv.Velocity = v
                flyObjects.bg.CFrame = CFrame.new(hrp.Position, hrp.Position + Camera.CFrame.LookVector)
            else
                setFly(true)
            end
        end
    end
    -- Tracers
    if Flags["Tracers"] and Drawing then
        for plr, d in pairs(espData) do
            if d.line then
                local hrp = getHRP(plr)
                if hrp then
                    local pos, on = Camera:WorldToViewportPoint(hrp.Position)
                    if on then
                        d.line.Visible = true
                        d.line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        d.line.To = Vector2.new(pos.X, pos.Y)
                    else
                        d.line.Visible = false
                    end
                else
                    d.line.Visible = false
                end
            end
        end
    end
    -- Last Seen
    if Flags["Last Seen Marker"] and Drawing then
        for plr, data in pairs(lastSeenData) do
            if plr and plr.Parent then
                if isVisible(plr) then
                    local hrp = getHRP(plr)
                    if hrp then lastSeenData[plr] = { pos = hrp.Position, time = tick() } end
                    if lastSeenDrawings[plr] then
                        pcall(function() lastSeenDrawings[plr].circle:Remove() lastSeenDrawings[plr].text:Remove() end)
                        lastSeenDrawings[plr] = nil
                    end
                else
                    local age = tick() - data.time
                    if age < 15 then
                        local pos, on = Camera:WorldToViewportPoint(data.pos)
                        if on then
                            if not lastSeenDrawings[plr] then
                                local circle = Drawing.new("Circle")
                                circle.Thickness = 2 circle.NumSides = 30 circle.Radius = 8 circle.Filled = false
                                circle.Color = Color3.fromRGB(255, 200, 50)
                                local text = Drawing.new("Text")
                                text.Size = 13 text.Font = 2 text.Color = Color3.fromRGB(255, 200, 50) text.Center = true
                                lastSeenDrawings[plr] = { circle = circle, text = text }
                            end
                            local alpha = 1 - (age / 15)
                            lastSeenDrawings[plr].circle.Position = Vector2.new(pos.X, pos.Y)
                            lastSeenDrawings[plr].circle.Visible = true
                            lastSeenDrawings[plr].circle.Transparency = 1 - alpha
                            lastSeenDrawings[plr].text.Position = Vector2.new(pos.X, pos.Y - 22)
                            lastSeenDrawings[plr].text.Text = plr.Name .. " (" .. math.floor(age) .. "s)"
                            lastSeenDrawings[plr].text.Visible = true
                            lastSeenDrawings[plr].text.Transparency = 1 - alpha
                        end
                    else
                        if lastSeenDrawings[plr] then
                            pcall(function() lastSeenDrawings[plr].circle:Remove() lastSeenDrawings[plr].text:Remove() end)
                            lastSeenDrawings[plr] = nil
                        end
                    end
                end
            end
        end
    elseif lastSeenDrawings then
        for plr, d in pairs(lastSeenDrawings) do
            pcall(function() d.circle:Remove() d.text:Remove() end)
        end
        lastSeenDrawings = {}
    end
    -- Position Predictor
    if Flags["Position Predictor"] and Drawing then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and alive(plr) then
                local hrp = getHRP(plr)
                if hrp and isVisible(plr) then
                    local vel = hrp.AssemblyLinearVelocity or Vector3.zero
                    if vel.Magnitude > 1 then
                        local futurePos = hrp.Position + vel * 0.5
                        local pos1, on1 = Camera:WorldToViewportPoint(hrp.Position)
                        local pos2, on2 = Camera:WorldToViewportPoint(futurePos)
                        if on1 and on2 then
                            if not predictorDrawings[plr] then
                                local line = Drawing.new("Line")
                                line.Thickness = 2 line.Color = Color3.fromRGB(255, 255, 100)
                                predictorDrawings[plr] = line
                            end
                            predictorDrawings[plr].From = Vector2.new(pos1.X, pos1.Y)
                            predictorDrawings[plr].To = Vector2.new(pos2.X, pos2.Y)
                            predictorDrawings[plr].Visible = true
                        end
                    end
                end
            end
        end
        for plr, line in pairs(predictorDrawings) do
            if not (plr and plr.Parent and alive(plr)) then
                pcall(function() line:Remove() end)
                predictorDrawings[plr] = nil
            end
        end
    else
        for plr, line in pairs(predictorDrawings) do pcall(function() line:Remove() end) end
        predictorDrawings = {}
    end
    -- FOV Circle
    if fovCircle then
        fovCircle.Visible = Flags["FOV Circle"] == true
        if fovCircle.Visible then
            fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            fovCircle.Color = Theme.Accent
        end
    end
    -- Gun Cooldown
    if gunCDFrame.Visible then
        local remaining = gunCooldownEnd - tick()
        if remaining > 0 then
            gunCDText.Text = ("Gun: %.1fs"):format(remaining)
            gunCDText.TextColor3 = Color3.fromRGB(64, 140, 255)
            gunCDFill.Size = UDim2.new(1 - (remaining / 1.5), 0, 0, 2)
            gunCDFill.BackgroundColor3 = Color3.fromRGB(64, 140, 255)
        else
            gunCDText.Text = "Gun: Ready"
            gunCDText.TextColor3 = Color3.fromRGB(88, 255, 128)
            gunCDFill.Size = UDim2.new(1, 0, 0, 2)
            gunCDFill.BackgroundColor3 = Color3.fromRGB(88, 255, 128)
        end
    end
    -- Player Trail
    if Flags["Player Trail"] and Drawing then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and alive(plr) then
                local hrp = getHRP(plr)
                if hrp then
                    if not trailData[plr] then trailData[plr] = { points = {}, lastUpdate = 0 } end
                    local data = trailData[plr]
                    if tick() - data.lastUpdate > 0.1 then
                        table.insert(data.points, hrp.Position)
                        if #data.points > 20 then table.remove(data.points, 1) end
                        data.lastUpdate = tick()
                    end
                    if not data.drawings then data.drawings = {} end
                    -- Clean old
                    for _, d in ipairs(data.drawings) do pcall(function() d:Remove() end) end
                    data.drawings = {}
                    -- Draw lines
                    for i = 1, #data.points - 1 do
                        local p1, on1 = Camera:WorldToViewportPoint(data.points[i])
                        local p2, on2 = Camera:WorldToViewportPoint(data.points[i + 1])
                        if on1 and on2 then
                            local line = Drawing.new("Line")
                            line.Thickness = 1
                            line.Color = RoleColors[getRole(plr)]
                            line.Transparency = 1 - (i / #data.points)
                            line.From = Vector2.new(p1.X, p1.Y)
                            line.To = Vector2.new(p2.X, p2.Y)
                            line.Visible = true
                            table.insert(data.drawings, line)
                        end
                    end
                end
            end
        end
    else
        for plr, data in pairs(trailData) do
            if data.drawings then
                for _, d in ipairs(data.drawings) do pcall(function() d:Remove() end) end
            end
        end
        trailData = {}
    end
end))

-- Noclip
track(RunService.Stepped:Connect(function()
    if Flags["Noclip"] and getChar(LocalPlayer) then
        for _, p in ipairs(getChar(LocalPlayer):GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
    -- No Camera Shake
    if Flags["No Camera Shake"] then
        pcall(function()
            local ch = getChar(LocalPlayer)
            if ch then
                local hrp = getHRP(LocalPlayer)
                if hrp then
                    for _, d in ipairs(ch:GetDescendants()) do
                        if d:IsA("Humanoid") then
                            d.CameraOffset = Vector3.new(0, 0, 0)
                        end
                    end
                end
            end
        end)
    end
end))

-- Infinite Jump
track(UserInputService.JumpRequest:Connect(function()
    if Flags["Infinite Jump"] then
        local h = getHum(LocalPlayer)
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

-- Click TP
track(Mouse.Button1Down:Connect(function()
    if Flags["Click TP"] and Mouse.Target then
        local hrp = getHRP(LocalPlayer)
        if hrp then hrp.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 4, 0)) end
    end
end))

-- Respawn
track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    pcall(function()
        local h = getHum(LocalPlayer)
        if h then
            if Flags["WalkSpeed"] then h.WalkSpeed = Flags["WalkSpeed"] end
            if Flags["JumpPower"] then h.UseJumpPower = true h.JumpPower = Flags["JumpPower"] end
        end
        if Flags["Fly"] then task.wait(0.3) setFly(true) end
    end)
    if spectating then stopSpectate() end
end))

-- Combat daemon
task.spawn(function()
    while Gui.Parent do
        task.wait(0.45)
        pcall(function()
            if autoModeEnabled then checkAutoMode() end
            if Flags["Kill Aura"] and getRole(LocalPlayer) == "Murderer" then
                local knife = getMyTool("Knife")
                if knife and equipTool(knife) then killNearest(30) end
            end
            if Flags["Auto Shoot"] and getRole(LocalPlayer) == "Sheriff" then
                local m = getMurderer()
                if m and isVisible(m) then shootMurderer() end
            end
            if Flags["Auto Knife"] and getRole(LocalPlayer) == "Murderer" then
                local t = nearestPlayer()
                if t and isVisible(t) then throwKnife(t) end
            end
            if Flags["Auto Grab Gun"] or Flags["Auto Collect Drops"] then
                local drop = workspace:FindFirstChild("GunDrop", true)
                if not drop then
                    for _, d in ipairs(workspace:GetDescendants()) do
                        if d:IsA("BasePart") and d.Name:lower():find("gun") and d.Name:lower():find("drop") then drop = d break end
                    end
                end
                if drop and drop:IsA("BasePart") then
                    local hrp = getHRP(LocalPlayer)
                    if hrp then
                        hrp.CFrame = drop.CFrame + Vector3.new(0, 2, 0)
                        if firetouchinterest then
                            pcall(function() firetouchinterest(drop, hrp, 0) task.wait(0.03) firetouchinterest(drop, hrp, 1) end)
                        end
                    end
                end
            end
            if Flags["Auto Collect Drops"] then
                autoCollectDrops()
            end
            -- Auto Save Sheriff
            if Flags["Auto Save Sheriff"] then
                local sheriff = getSheriff()
                if sheriff and alive(sheriff) then
                    local hrp = getHRP(sheriff)
                    if hrp then sheriffLastPos = hrp.Position end
                    sheriffWasAlive = true
                elseif sheriffWasAlive and sheriffLastPos then
                    local myHrp = getHRP(LocalPlayer)
                    if myHrp then
                        myHrp.CFrame = CFrame.new(sheriffLastPos + Vector3.new(0, 3, 0))
                        notify("Auto Save", "→ Sheriff death", 3)
                        playSound("alert")
                    end
                    sheriffLastPos = nil
                    sheriffWasAlive = false
                end
            end
            if Flags["Anti-Void"] then
                local hrp = getHRP(LocalPlayer)
                if hrp then
                    if hrp.Position.Y > 0 then lastSafePos = hrp.Position end
                    if hrp.Position.Y < -60 and lastSafePos then hrp.CFrame = CFrame.new(lastSafePos + Vector3.new(0, 6, 0)) end
                end
            end
            if Flags["No Fog"] then
                Lighting.FogEnd = 1e9
                for _, a in ipairs(Lighting:GetChildren()) do
                    if a:IsA("Atmosphere") then a.Density = 0 end
                end
            end
            if Flags["Auto Reconnect"] then
                checkAutoReconnect()
            end
        end)
    end
end)

-- Hitbox re-apply
task.spawn(function()
    while Gui.Parent do
        task.wait(2)
        if hitboxEnabled then
            pcall(function()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and alive(p) then
                        local hrp = getHRP(p)
                        if hrp and hrp.Size.X < 14 then
                            hrp.Size = Vector3.new(14, 14, 14)
                            hrp.Material = Enum.Material.ForceField
                            hrp.Color = Color3.fromRGB(255, 60, 60)
                            hrp.Transparency = 0.6
                        end
                    end
                end
            end)
        end
    end
end)

-- Coin farm
task.spawn(function()
    while Gui.Parent do
        task.wait(farmDelay)
        if Flags["Auto Farm Coins"] then
            pcall(function()
                local hrp = getHRP(LocalPlayer)
                if not hrp then return end
                local best, bd = nil, math.huge
                local coinNames = { "coin", "pickup", "collect", "money", "cash", "gem" }
                for _, d in ipairs(workspace:GetDescendants()) do
                    if d:IsA("BasePart") then
                        local n = d.Name:lower()
                        local isCoin = false
                        for _, cn in ipairs(coinNames) do
                            if n:find(cn) then isCoin = true break end
                        end
                        if isCoin then
                            local dist = (d.Position - hrp.Position).Magnitude
                            if dist < bd then bd, best = dist, d end
                        end
                    end
                end
                if best then
                    hrp.CFrame = CFrame.new(best.Position + Vector3.new(0, 2.5, 0))
                    if firetouchinterest then
                        pcall(function() firetouchinterest(best, hrp, 0) task.wait(0.02) firetouchinterest(best, hrp, 1) end)
                    end
                end
            end)
        end
    end
end)

-- Fling
task.spawn(function()
    while Gui.Parent do
        task.wait(0.2)
        if Flags["Fling All"] then
            pcall(function()
                local myHrp = getHRP(LocalPlayer)
                if myHrp then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and alive(p) then
                            local th = getHRP(p)
                            if th and (th.Position - myHrp.Position).Magnitude < 80 then
                                myHrp.CFrame = th.CFrame * CFrame.new(0, 0, 0)
                                task.wait(0.05)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- Fake Lag (ФИКС: правильная логика)
task.spawn(function()
    while Gui.Parent do
        task.wait(0.1)
        if Flags["Fake Lag"] then
            pcall(function()
                local hrp = getHRP(LocalPlayer)
                if hrp then
                    fakeLagData.timer += 0.1
                    if fakeLagData.timer >= 1.0 then
                        fakeLagData.timer = 0
                        if not fakeLagData.savedPos then
                            fakeLagData.savedPos = hrp.Position
                        else
                            hrp.CFrame = CFrame.new(fakeLagData.savedPos)
                            fakeLagData.savedPos = nil
                        end
                    end
                end
            end)
        else
            fakeLagData.savedPos = nil
            fakeLagData.timer = 0
        end
    end
end)

-- Dance / Spam
local danceT, spamT = 0, 0
task.spawn(function()
    while Gui.Parent do
        task.wait(0.5)
        danceT += 0.5
        spamT += 0.5
        pcall(function()
            if Flags["Auto Dance"] and danceT >= 6 then danceT = 0 say("/e dance") end
            if Flags["Chat Spam"] and spamT >= 2.5 then spamT = 0 say(SPAM[math.random(#SPAM)]) end
        end)
    end
end)

-- ESP
task.spawn(function()
    while Gui.Parent do
        task.wait(0.25)
        pcall(function()
            local wantBB = Flags["Player ESP"]
            local wantHL = Flags["Chams"]
            local wantVel = Flags["Velocity Display"]
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local d = espData[plr]
                    local ch = getChar(plr)
                    if not (ch and alive(plr)) then
                        if d then
                            pcall(function() if d.bb then d.bb:Destroy() end end)
                            pcall(function() if d.hl then d.hl:Destroy() end end)
                            pcall(function() if d.line then d.line:Remove() end end)
                            espData[plr] = nil
                        end
                    else
                        d = d or {}
                        local role = getRole(plr)
                        local col = RoleColors[role]
                        if wantBB then
                            local head = ch:FindFirstChild("Head") or getHRP(plr)
                            if head and (not d.bb or not d.bb.Parent or d.bb.Adornee ~= head) then
                                pcall(function() if d.bb then d.bb:Destroy() end end)
                                local bb = Instance.new("BillboardGui")
                                bb.Size = UDim2.fromOffset(130, 24)
                                bb.StudsOffset = Vector3.new(0, 3, 0)
                                bb.AlwaysOnTop = true
                                bb.MaxDistance = 800
                                bb.Adornee = head
                                local lbl = Instance.new("TextLabel")
                                lbl.Size = UDim2.new(1, 0, 1, 0)
                                lbl.BackgroundTransparency = 1
                                lbl.Font = Enum.Font.GothamBold
                                lbl.TextSize = 10
                                lbl.TextStrokeTransparency = 0.35
                                lbl.Parent = bb
                                bb.Parent = Gui
                                d.bb, d.lbl = bb, lbl
                            end
                            if d.bb and d.lbl then
                                local h = getHRP(plr)
                                local dist = h and math.floor((h.Position - Camera.CFrame.Position).Magnitude + 0.5) or 0
                                local txt = ("%s · %s · %dm"):format(plr.Name, role, dist)
                                if wantVel and h then
                                    local vel = h.AssemblyLinearVelocity or Vector3.zero
                                    local speed = math.floor(vel.Magnitude)
                                    txt = txt .. " · " .. speed .. "sps"
                                end
                                d.lbl.Text = txt
                                d.lbl.TextColor3 = col
                            end
                        elseif d.bb then
                            pcall(function() d.bb:Destroy() end)
                            d.bb, d.lbl = nil, nil
                        end
                        if wantHL then
                            if not d.hl or not d.hl.Parent or d.hl.Adornee ~= ch then
                                pcall(function() if d.hl then d.hl:Destroy() end end)
                                local hl = Instance.new("Highlight")
                                hl.FillTransparency = 0.65
                                hl.OutlineTransparency = 0
                                hl.Adornee = ch
                                hl.Parent = ch
                                d.hl = hl
                            end
                            if d.hl then
                                d.hl.FillColor = col
                                d.hl.OutlineColor = col
                            end
                        elseif d.hl then
                            pcall(function() d.hl:Destroy() end)
                            d.hl = nil
                        end
                        if Flags["Tracers"] and Drawing then
                            if not d.line then
                                local line = Drawing.new("Line")
                                line.Thickness = 1.5
                                line.Visible = true
                                d.line = line
                            end
                        elseif d.line then
                            pcall(function() d.line:Remove() end)
                            d.line = nil
                        end
                        if d.line then d.line.Color = col end
                        espData[plr] = d
                    end
                end
            end
            -- Coin ESP
            if Flags["Coin ESP"] then
                for _, h in ipairs(coinHLs) do pcall(function() h:Destroy() end) end
                coinHLs = {}
                local coinNames = { "coin", "pickup", "collect", "money", "gem" }
                for _, dsc in ipairs(workspace:GetDescendants()) do
                    if dsc:IsA("BasePart") then
                        local n = dsc.Name:lower()
                        local isCoin = false
                        for _, cn in ipairs(coinNames) do
                            if n:find(cn) then isCoin = true break end
                        end
                        if isCoin then
                            local hl = Instance.new("Highlight")
                            hl.FillColor = Color3.fromRGB(255, 220, 60)
                            hl.OutlineColor = Color3.fromRGB(255, 220, 60)
                            hl.FillTransparency = 0.7
                            hl.Adornee = dsc
                            hl.Parent = workspace
                            table.insert(coinHLs, hl)
                        end
                    end
                end
            elseif #coinHLs > 0 then
                for _, h in ipairs(coinHLs) do pcall(function() h:Destroy() end) end
                coinHLs = {}
            end
        end)
    end
end)

-- Murderer Alert
task.spawn(function()
    while Gui.Parent do
        task.wait(0.4)
        if alertRunning then
            pcall(function()
                local m = getMurderer()
                if m and alive(m) then
                    local myHrp = getHRP(LocalPlayer)
                    local mHrp = getHRP(m)
                    if myHrp and mHrp then
                        local dist = (mHrp.Position - myHrp.Position).Magnitude
                        local alertDist = Flags["Alert Distance"] or 50
                        if dist < alertDist then
                            TweenService:Create(alertOverlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.85 }):Play()
                            task.wait(0.2)
                            TweenService:Create(alertOverlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
                            playSound("alert")
                        end
                    end
                end
            end)
        end
    end
end)

-- AFK Detector
task.spawn(function()
    while Gui.Parent do
        task.wait(2)
        if Flags["AFK Detector"] then
            pcall(function()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and alive(plr) then
                        local hrp = getHRP(plr)
                        if hrp then
                            if not afkTracker[plr] then afkTracker[plr] = { pos = hrp.Position, time = tick(), afk = false } end
                            local data = afkTracker[plr]
                            if (hrp.Position - data.pos).Magnitude > 2 then
                                data.pos = hrp.Position
                                data.time = tick()
                                data.afk = false
                            elseif tick() - data.time > 10 then
                                data.afk = true
                            end
                            if data.afk and not afkHighlights[plr] then
                                local hl = Instance.new("Highlight")
                                hl.FillColor = Color3.fromRGB(255, 200, 50)
                                hl.OutlineColor = Color3.fromRGB(255, 200, 50)
                                hl.FillTransparency = 0.5
                                hl.Adornee = getChar(plr)
                                hl.Parent = getChar(plr)
                                afkHighlights[plr] = hl
                            elseif not data.afk and afkHighlights[plr] then
                                pcall(function() afkHighlights[plr]:Destroy() end)
                                afkHighlights[plr] = nil
                            end
                        end
                    end
                end
                for plr, hl in pairs(afkHighlights) do
                    if not (plr and plr.Parent and alive(plr)) then
                        pcall(function() hl:Destroy() end)
                        afkHighlights[plr] = nil
                    end
                end
            end)
        else
            for plr, hl in pairs(afkHighlights) do pcall(function() hl:Destroy() end) end
            afkHighlights = {}
        end
    end
end)

-- Group Detector
task.spawn(function()
    while Gui.Parent do
        task.wait(1)
        if Flags["Group Detector"] then
            pcall(function()
                for _, hl in pairs(groupHighlights) do pcall(function() hl:Destroy() end) end
                groupHighlights = {}
                local plrs = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and alive(p) then table.insert(plrs, p) end
                end
                for i = 1, #plrs do
                    for j = i + 1, #plrs do
                        local h1, h2 = getHRP(plrs[i]), getHRP(plrs[j])
                        if h1 and h2 then
                            local dist = (h1.Position - h2.Position).Magnitude
                            if dist < 15 then
                                for _, p in ipairs({plrs[i], plrs[j]}) do
                                    if not groupHighlights[p] then
                                        local ch = getChar(p)
                                        local hl = Instance.new("Highlight")
                                        hl.FillColor = Color3.fromRGB(255, 100, 255)
                                        hl.OutlineColor = Color3.fromRGB(255, 100, 255)
                                        hl.FillTransparency = 0.6
                                        hl.Adornee = ch
                                        hl.Parent = ch
                                        groupHighlights[p] = hl
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        else
            for _, hl in pairs(groupHighlights) do pcall(function() hl:Destroy() end) end
            groupHighlights = {}
        end
    end
end)

-- Round Timer HUD
task.spawn(function()
    while Gui.Parent do
        task.wait(0.5)
        if roundTimerFrame.Visible then
            pcall(function()
                if not roundTimerLabel or not roundTimerLabel.Parent then
                    roundTimerLabel = findTimerLabel()
                end
                if roundTimerLabel then
                    roundTimerText.Text = roundTimerLabel.Text
                    if roundTimerLabel.Text:match("0:0") then
                        roundTimerText.TextColor3 = Color3.fromRGB(255, 64, 64)
                    else
                        roundTimerText.TextColor3 = Theme.Text
                    end
                else
                    roundTimerText.Text = "--:--"
                end
            end)
        end
    end
end)

-- Spectate check
task.spawn(function()
    while Gui.Parent do
        task.wait(1)
        if spectating and spectateTarget then
            if not alive(spectateTarget) then stopSpectate() end
        end
    end
end)

-- Keybind Visualizer
task.spawn(function()
    while Gui.Parent do
        task.wait(1)
        if keybindPanel.Visible then
            pcall(function()
                for _, child in ipairs(keybindPanel:GetChildren()) do
                    if child:IsA("TextLabel") then pcall(function() child:Destroy() end) end
                end
                local hasBinds = false
                for name, bind in pairs(Keybinds) do
                    if bind.key then
                        hasBinds = true
                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, 0, 0, 14)
                        lbl.BackgroundTransparency = 1
                        lbl.Text = ("[%s] %s"):format(bind.key.Name, name)
                        lbl.TextColor3 = Theme.Text
                        lbl.TextSize = 9
                        lbl.Font = Enum.Font.Gotham
                        lbl.TextXAlignment = Enum.TextXAlignment.Left
                        lbl.Parent = keybindPanel
                    end
                end
                if not hasBinds then
                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, 0, 0, 14)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = "No keybinds"
                    lbl.TextColor3 = Theme.SubText
                    lbl.TextSize = 9
                    lbl.Font = Enum.Font.Gotham
                    lbl.TextXAlignment = Enum.TextXAlignment.Left
                    lbl.Parent = keybindPanel
                end
            end)
        end
    end
end)

-- Player list
local playerListEntries = {}
task.spawn(function()
    while Gui.Parent do
        task.wait(3)
        pcall(function()
            for _, entry in ipairs(playerListEntries) do pcall(function() entry:Destroy() end) end
            playerListEntries = {}

            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local entry = newCard(tabPlayers, 30)

                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Size = UDim2.new(0, 90, 1, 0)
                    nameLabel.Position = UDim2.new(0, 6, 0, 0)
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.TextColor3 = Theme.Text
                    nameLabel.TextSize = 9
                    nameLabel.Font = Enum.Font.Gotham
                    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                    nameLabel.Text = p.Name:sub(1, 12)
                    nameLabel.Parent = entry

                    local role = getRole(p)
                    local roleLabel = Instance.new("TextLabel")
                    roleLabel.Size = UDim2.new(0, 50, 1, 0)
                    roleLabel.Position = UDim2.new(0, 100, 0, 0)
                    roleLabel.BackgroundTransparency = 1
                    roleLabel.TextColor3 = RoleColors[role]
                    roleLabel.TextSize = 8
                    roleLabel.Font = Enum.Font.GothamBold
                    roleLabel.TextXAlignment = Enum.TextXAlignment.Left
                    roleLabel.Text = role:sub(1, 3)
                    roleLabel.Parent = entry

                    local distLabel = Instance.new("TextLabel")
                    distLabel.Size = UDim2.new(0, 35, 1, 0)
                    distLabel.Position = UDim2.new(1, -80, 0, 0)
                    distLabel.BackgroundTransparency = 1
                    distLabel.TextColor3 = Theme.SubText
                    distLabel.TextSize = 8
                    distLabel.Font = Enum.Font.Gotham
                    distLabel.TextXAlignment = Enum.TextXAlignment.Right
                    local hrp = getHRP(p)
                    local myHrp = getHRP(LocalPlayer)
                    if hrp and myHrp then
                        distLabel.Text = math.floor((hrp.Position - myHrp.Position).Magnitude + 0.5) .. "m"
                    else
                        distLabel.Text = "--"
                    end
                    distLabel.Parent = entry

                    local tpBtn = Instance.new("TextButton")
                    tpBtn.Size = UDim2.fromOffset(34, 18)
                    tpBtn.Position = UDim2.new(1, -40, 0.5, -9)
                    tpBtn.BackgroundColor3 = Theme.Accent
                    tpBtn.Text = "TP"
                    tpBtn.TextColor3 = Color3.new(0, 0, 0)
                    tpBtn.TextSize = 9
                    tpBtn.Font = Enum.Font.GothamBold
                    tpBtn.BorderSizePixel = 0
                    tpBtn.Parent = entry
                    corner(tpBtn, 4)

                    local menuBtn = Instance.new("TextButton")
                    menuBtn.Size = UDim2.fromOffset(18, 18)
                    menuBtn.Position = UDim2.new(1, -18, 0.5, -9)
                    menuBtn.BackgroundColor3 = Theme.Stroke
                    menuBtn.Text = "⋯"
                    menuBtn.TextColor3 = Theme.Text
                    menuBtn.TextSize = 12
                    menuBtn.Font = Enum.Font.GothamBold
                    menuBtn.BorderSizePixel = 0
                    menuBtn.Parent = entry
                    corner(menuBtn, 4)

                    tpBtn.MouseButton1Click:Connect(function() tpToPlayer(p) end)
                    menuBtn.MouseButton1Click:Connect(function()
                        local pos = menuBtn.AbsolutePosition
                        showActionMenu(p, pos.X - 90, pos.Y)
                    end)

                    table.insert(playerListEntries, entry)
                end
            end
        end)
    end
end)

-- Cleanup
track(Players.PlayerRemoving:Connect(function(plr)
    if espData[plr] then
        pcall(function()
            if espData[plr].bb then espData[plr].bb:Destroy() end
            if espData[plr].hl then espData[plr].hl:Destroy() end
            if espData[plr].line then espData[plr].line:Remove() end
        end)
        espData[plr] = nil
    end
    if lastSeenData[plr] then lastSeenData[plr] = nil end
    if lastSeenDrawings[plr] then
        pcall(function() lastSeenDrawings[plr].circle:Remove() lastSeenDrawings[plr].text:Remove() end)
        lastSeenDrawings[plr] = nil
    end
    if predictorDrawings[plr] then
        pcall(function() predictorDrawings[plr]:Remove() end)
        predictorDrawings[plr] = nil
    end
    if afkTracker[plr] then afkTracker[plr] = nil end
    if afkHighlights[plr] then pcall(function() afkHighlights[plr]:Destroy() end) afkHighlights[plr] = nil end
    if groupHighlights[plr] then pcall(function() groupHighlights[plr]:Destroy() end) groupHighlights[plr] = nil end
    if trailData[plr] then
        if trailData[plr].drawings then
            for _, d in ipairs(trailData[plr].drawings) do pcall(function() d:Remove() end) end
        end
        trailData[plr] = nil
    end
    if spectateTarget == plr then stopSpectate() end
end))

-- Chat logger
local function hookChat(plr)
    track(plr.Chatted:Connect(function(msg)
        if Flags["Chat Logger"] then print(("[ALFA] %s: %s"):format(plr.Name, msg)) end
    end))
end
for _, p in ipairs(Players:GetPlayers()) do hookChat(p) end
track(Players.PlayerAdded:Connect(hookChat))

-- Anti-AFK
track(LocalPlayer.Idled:Connect(function()
    if Flags["Anti-AFK"] then
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
        end)
    end
end))

cleanupFn(function()
    for _, h in ipairs(coinHLs) do pcall(function() h:Destroy() end) end
    for _, d in pairs(espData) do
        pcall(function() if d.bb then d.bb:Destroy() end end)
        pcall(function() if d.hl then d.hl:Destroy() end end)
        pcall(function() if d.line then d.line:Remove() end end)
    end
    if flyObjects then pcall(function() flyObjects.bv:Destroy() flyObjects.bg:Destroy() end) end
    if flingConn then flingConn:Disconnect() end
    if antiFlingConn then antiFlingConn:Disconnect() end
    for _, d in pairs(lastSeenDrawings) do pcall(function() d.circle:Remove() d.text:Remove() end) end
    for _, l in pairs(predictorDrawings) do pcall(function() l:Remove() end) end
    for _, hl in pairs(afkHighlights) do pcall(function() hl:Destroy() end) end
    for _, hl in pairs(groupHighlights) do pcall(function() hl:Destroy() end) end
    for plr, data in pairs(trailData) do
        if data.drawings then
            for _, d in ipairs(data.drawings) do pcall(function() d:Remove() end) end
        end
    end
end)

-- ═══ 15. START ═══
selectTab("Main")
Main.Visible = true
TweenService:Create(MainScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
notify("ALFA 0.7", "Mobile UI + 15 new features! M — menu, help — cmds", 6)
print("═══ ALFA 0.7 MM2 Hub (Mobile Compact + Mega Update) loaded ═══")