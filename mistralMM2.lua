--[[
    MISTRAL ALFA 0.5 — MM2 Script Hub
    Waguri-style · purple neon · lag-fixed · full feature set
    Executor: Delta (PC / Android)
]]

getgenv().MISTRAL_VERSION = "Alfa 0.5"

----------------------------------------------------------------------
-- CONFIG (edit these)
----------------------------------------------------------------------
local TG_LINK = "https://t.me/mistralscripts"  -- <-- твой TG, копируется при старте
-- После загрузки баннера 17924.png на Roblox вставь ID сюда (только цифры):
local BANNER_ASSET_ID = ""  -- например "1234567890"  | пусто = фиолетовый градиент

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local VirtualUser      = game:GetService("VirtualUser")
local HttpService      = game:GetService("HttpService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local StarterGui       = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()
local Camera      = workspace.CurrentCamera

pcall(function() if getgenv().MISTRAL_UNLOAD then getgenv().MISTRAL_UNLOAD() end end)

local Connections, Cleanups = {}, {}
local Flags, UIRegistry = {}, {}
local function track(c) table.insert(Connections, c) return c end
local function onCleanup(fn) table.insert(Cleanups, fn) end
local function clearAll()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for _, f in ipairs(Cleanups) do pcall(f) end
    Connections, Cleanups = {}, {}
end

-- copy TG on start
pcall(function()
    if setclipboard then setclipboard(TG_LINK)
    elseif toclipboard then toclipboard(TG_LINK) end
end)

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function getChar(p) return p and p.Character end
local function getHRP(p) local c = getChar(p) return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum(p) local c = getChar(p) return c and c:FindFirstChildOfClass("Humanoid") end
local function isAlive(p) local h = getHum(p) return h ~= nil and h.Health > 0 end

local function getToolKind(p)
    local function scan(c)
        if not c then return nil end
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") then
                local n = t.Name:lower()
                if n:find("gun") or n:find("pistol") or n:find("revolver") then return "Gun" end
                if n:find("knife") or n:find("blade") or n:find("dagger") then return "Knife" end
            end
        end
    end
    return scan(getChar(p)) or scan(p:FindFirstChild("Backpack"))
end

local function getRole(p)
    local k = getToolKind(p)
    if k == "Knife" then return "Murderer" end
    if k == "Gun" then return "Sheriff" end
    return "Innocent"
end

local cachedRole, cachedRoleT = "Innocent", 0
local function getMyRole()
    if tick() - cachedRoleT < 0.4 then return cachedRole end
    cachedRole = getRole(LocalPlayer)
    cachedRoleT = tick()
    return cachedRole
end

local function getMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRole(p) == "Murderer" then return p end
    end
end

local function getSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRole(p) == "Sheriff" then return p end
    end
end

local function isVisible(p)
    local hrp = getHRP(p)
    if not hrp then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, hrp.Parent }
    return workspace:Raycast(Camera.CFrame.Position, hrp.Position - Camera.CFrame.Position, params) == nil
end

local function getMyTool(kind)
    local patterns = (kind == "Gun") and {"gun","pistol","revolver"} or {"knife","blade","dagger"}
    local function find(c)
        if not c then return nil end
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") then
                local n = t.Name:lower()
                for _, pat in ipairs(patterns) do if n:find(pat) then return t end end
            end
        end
    end
    return find(getChar(LocalPlayer)) or find(LocalPlayer:FindFirstChild("Backpack"))
end

local function equipTool(tool)
    if not tool then return false end
    local ch = getChar(LocalPlayer)
    if not ch then return false end
    if tool.Parent == ch then return true end
    local hum = getHum(LocalPlayer)
    if not hum then return false end
    pcall(function() hum:EquipTool(tool) end)
    for _ = 1, 30 do
        if tool.Parent == ch then return true end
        task.wait(0.04)
    end
    return tool.Parent == ch
end

local function nearestPlayer()
    local my = getHRP(LocalPlayer)
    if not my then return nil end
    local best, bd = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then
            local h = getHRP(p)
            if h then
                local d = (h.Position - my.Position).Magnitude
                if d < bd then bd, best = d, p end
            end
        end
    end
    return best
end

local function tpTo(p)
    if not p or not isAlive(p) then return end
    local hrp, my = getHRP(p), getHRP(LocalPlayer)
    if hrp and my then my.CFrame = hrp.CFrame * CFrame.new(0, 0, 4) end
end

local function predictPos(hrp, t)
    t = t or 0.12
    local vel = hrp.AssemblyLinearVelocity or Vector3.zero
    return hrp.Position + vel * t
end

----------------------------------------------------------------------
-- SOUND
----------------------------------------------------------------------
local SoundEnabled = true
local function playSound(id, vol)
    if not SoundEnabled then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://" .. tostring(id or 6026723916)
        s.Volume = vol or 0.14
        s.Parent = workspace
        s:Play()
        task.delay(2, function() pcall(function() s:Destroy() end) end)
    end)
end

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------
local aimSmooth, flySpeed, farmDelay = 0.25, 80, 0.3
local aimFovRadius = 140
local gunCD, knifeCD = 0, 0
local hitboxOn, hitboxOrig = false, {}
local triggerOn = false
local flyObj, flyOn, flyPending = nil, false, false
local lastSafe = nil
local keys = {}
local lockedTarget = nil
local invisOn = false
local invisConn = nil
local notify = function() end
local espData, coinHLs = {}, {}
local coinCache, coinCacheT = {}, 0
local RoleColors = {
    Murderer = Color3.fromRGB(255, 80, 100),
    Sheriff  = Color3.fromRGB(100, 160, 255),
    Innocent = Color3.fromRGB(120, 255, 160),
}
local profiles = {
    Safe = { ["Player ESP"]=true, ["Chams"]=true, ["Aimbot"]=false, ["Silent Aim"]=false, ["Kill Aura"]=false, ["Auto Shoot"]=false, ["Hitbox"]=false, ["Fly"]=false },
    Agro = { ["Player ESP"]=true, ["Chams"]=true, ["Aimbot"]=true, ["Silent Aim"]=true, ["Kill Aura"]=true, ["Auto Shoot"]=true, ["Hitbox"]=true },
    Farm = { ["Auto Farm"]=true, ["Coin ESP"]=true, ["Player ESP"]=false, ["Aimbot"]=false, ["Kill Aura"]=false },
}

----------------------------------------------------------------------
-- COMBAT
----------------------------------------------------------------------
local function fireGunRemotes(gun, pos)
    for _, d in ipairs(gun:GetDescendants()) do
        if d:IsA("RemoteEvent") then
            pcall(function() d:FireServer(pos) end)
            pcall(function() d:FireServer(pos, pos) end)
            pcall(function() d:FireServer({Origin = Camera.CFrame.Position, Direction = (pos - Camera.CFrame.Position).Unit}) end)
        elseif d:IsA("RemoteFunction") then
            pcall(function() d:InvokeServer(pos) end)
        end
    end
    -- also try common MM2 remote names in ReplicatedStorage
    pcall(function()
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                local n = d.Name:lower()
                if n:find("shoot") or n:find("gun") or n:find("fire") or n:find("bullet") then
                    pcall(function() d:FireServer(pos) end)
                    pcall(function() d:FireServer(LocalPlayer, pos) end)
                end
            end
        end
    end)
end

local function shootMurderer()
    local m = lockedTarget or getMurderer()
    if not m or not isAlive(m) then
        notify("Combat", "No target")
        return false
    end
    local gun = getMyTool("Gun")
    if not gun then
        notify("Combat", "No gun")
        return false
    end
    if not equipTool(gun) then
        notify("Combat", "Equip failed")
        return false
    end
    local hrp = getHRP(m)
    local my = getHRP(LocalPlayer)
    if not hrp or not my then return false end

    local targetPos = Flags["Prediction"] and predictPos(hrp) or hrp.Position
    task.wait(0.05)

    -- aim
    pcall(function()
        my.CFrame = CFrame.new(my.Position, Vector3.new(targetPos.X, my.Position.Y, targetPos.Z))
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    end)

    -- multiple activate attempts (MM2 is picky)
    local ok = false
    for i = 1, 3 do
        pcall(function() gun:Activate() end)
        fireGunRemotes(gun, targetPos)
        if mousemoverel then
            pcall(function()
                local sp, on = Camera:WorldToViewportPoint(targetPos)
                if on then
                    mousemoverel(sp.X - Mouse.X, sp.Y - Mouse.Y)
                    task.wait(0.02)
                    gun:Activate()
                    fireGunRemotes(gun, targetPos)
                end
            end)
        end
        -- VirtualInput click center
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            local vs = Camera.ViewportSize
            vim:SendMouseButtonEvent(vs.X/2, vs.Y/2, 0, true, game, 1)
            task.wait(0.03)
            vim:SendMouseButtonEvent(vs.X/2, vs.Y/2, 0, false, game, 1)
        end)
        task.wait(0.05)
        ok = true
    end

    if ok then
        gunCD = tick() + 1.4
        playSound(3120484875, 0.2)
        notify("Combat", "Shot → " .. m.Name)
        return true
    end
    return false
end

local function silentAim()
    local m = lockedTarget or getMurderer()
    if not m then return end
    local gun = getMyTool("Gun")
    if not gun or not equipTool(gun) then return end
    local hrp = getHRP(m)
    if not hrp then return end
    local pos = Flags["Prediction"] and predictPos(hrp) or hrp.Position
    pcall(function() gun:Activate() end)
    fireGunRemotes(gun, pos)
end

local function throwKnife(target)
    target = target or lockedTarget or getMurderer() or nearestPlayer()
    if not target then return false end
    local knife = getMyTool("Knife")
    if not knife or not equipTool(knife) then return false end
    local hrp, my = getHRP(target), getHRP(LocalPlayer)
    if not (hrp and my) then return false end
    local pos = Flags["Prediction"] and predictPos(hrp) or hrp.Position
    task.wait(0.04)
    pcall(function()
        my.CFrame = CFrame.new(my.Position, Vector3.new(pos.X, my.Position.Y, pos.Z))
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, pos)
        knife:Activate()
        for _, d in ipairs(knife:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                pcall(function() d:FireServer(pos) end)
            end
        end
    end)
    knifeCD = tick() + 0.7
    playSound(2863915039, 0.2)
    notify("Combat", "Knife → " .. target.Name)
    return true
end

local function knifeTouch(p)
    local knife = getMyTool("Knife")
    if not knife or not equipTool(knife) then return false end
    local handle
    for _, d in ipairs(knife:GetDescendants()) do
        if d:IsA("BasePart") then handle = d break end
    end
    if not handle then return false end
    local hrp, my = getHRP(p), getHRP(LocalPlayer)
    if not (hrp and my) then return false end
    pcall(function() my.CFrame = hrp.CFrame * CFrame.new(0, 0, -2) end)
    task.wait(0.04)
    if firetouchinterest then
        local ch = getChar(p)
        if ch then
            for _, part in ipairs(ch:GetChildren()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        firetouchinterest(handle, part, 0)
                        task.wait(0.015)
                        firetouchinterest(handle, part, 1)
                    end)
                end
            end
        end
    else
        pcall(function() knife:Activate() end)
    end
    return true
end

local function killAll()
    if getMyRole() ~= "Murderer" then notify("Combat", "Murderer only") return end
    local c = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then
            if knifeTouch(p) then c += 1 end
            task.wait(0.08)
        end
    end
    notify("Combat", "Killed: " .. c)
end

local function killNearest(r)
    local t = lockedTarget or nearestPlayer()
    if not t then return end
    local my, h = getHRP(LocalPlayer), getHRP(t)
    if my and h and (h.Position - my.Position).Magnitude <= (r or 35) then knifeTouch(t) end
end

local function grabGun()
    local drop = workspace:FindFirstChild("GunDrop", true)
    if not drop then
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                local n = d.Name:lower()
                if n:find("gun") and (n:find("drop") or n:find("pick")) then drop = d break end
            end
        end
    end
    if drop and drop:IsA("BasePart") then
        local hrp = getHRP(LocalPlayer)
        if hrp then
            hrp.CFrame = drop.CFrame + Vector3.new(0, 2, 0)
            if firetouchinterest then
                pcall(function()
                    firetouchinterest(drop, hrp, 0)
                    task.wait(0.03)
                    firetouchinterest(drop, hrp, 1)
                end)
            end
            notify("Combat", "Gun grabbed")
        end
    end
end

local function stealGun()
    local s = getSheriff()
    if not s then notify("Combat", "No Sheriff") return end
    local hrp, my = getHRP(s), getHRP(LocalPlayer)
    if hrp and my then
        my.CFrame = hrp.CFrame
        task.wait(0.05)
        pcall(function() my.AssemblyAngularVelocity = Vector3.new(0, 220, 0) end)
        task.wait(0.12)
        pcall(function() my.AssemblyAngularVelocity = Vector3.zero end)
        grabGun()
    end
end

local function setHitbox(on)
    hitboxOn = on
    if not on then
        for hrp, o in pairs(hitboxOrig) do
            if hrp and hrp.Parent then
                pcall(function() hrp.Size=o.S hrp.Material=o.M hrp.Color=o.C hrp.Transparency=o.T end)
            end
        end
        hitboxOrig = {}
    end
end

----------------------------------------------------------------------
-- INVISIBLE
----------------------------------------------------------------------
local function applyInvis(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            d.LocalTransparencyModifier = 1
            d.Transparency = 1
        elseif d:IsA("Decal") or d:IsA("Texture") then
            d.Transparency = 1
        elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke") then
            d.Enabled = false
        elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
            d.Enabled = false
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.NameDisplayDistance = 0
        hum.HealthDisplayDistance = 0
        pcall(function()
            hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end)
    end
    -- hide name tags
    for _, d in ipairs(char:GetChildren()) do
        if d:IsA("Accessory") then
            for _, p in ipairs(d:GetDescendants()) do
                if p:IsA("BasePart") then p.Transparency = 1 end
            end
        end
    end
end

local function setInvisible(on)
    invisOn = on
    if invisConn then invisConn:Disconnect() invisConn = nil end
    local char = getChar(LocalPlayer)
    if on then
        applyInvis(char)
        -- god-ish: keep health up
        invisConn = RunService.Heartbeat:Connect(function()
            if not invisOn then return end
            local c = getChar(LocalPlayer)
            if c then applyInvis(c) end
            local h = getHum(LocalPlayer)
            if h and h.Health < h.MaxHealth then
                pcall(function() h.Health = h.MaxHealth end)
            end
        end)
        track(invisConn)
        notify("Invis", "ON — local stealth")
    else
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    d.LocalTransparencyModifier = 0
                    if d.Name ~= "Head" then d.Transparency = 0 end
                elseif d:IsA("BasePart") and d.Name == "Head" then
                    d.LocalTransparencyModifier = 0
                    d.Transparency = 0
                end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.NameDisplayDistance = 100
                hum.HealthDisplayDistance = 100
            end
        end
        notify("Invis", "OFF")
    end
end

----------------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------------
local function setFly(on)
    flyOn = on
    flyPending = false
    local hrp = getHRP(LocalPlayer)
    if on then
        if not hrp then flyPending = true return end
        if flyObj then pcall(function() flyObj.bv:Destroy() flyObj.bg:Destroy() end) end
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(4e5,4e5,4e5)
        bv.Velocity = Vector3.zero
        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(4e5,4e5,4e5)
        bg.P = 2e4
        bg.CFrame = hrp.CFrame
        bv.Parent, bg.Parent = hrp, hrp
        flyObj = { bv = bv, bg = bg }
    else
        if flyObj then pcall(function() flyObj.bv:Destroy() flyObj.bg:Destroy() end) flyObj = nil end
    end
end

local function setSpin(on)
    local hrp = getHRP(LocalPlayer)
    if not hrp then return end
    local old = hrp:FindFirstChild("MistralSpin")
    if old then old:Destroy() end
    if on then
        local b = Instance.new("BodyAngularVelocity")
        b.AngularVelocity = Vector3.new(0, 40, 0)
        b.MaxTorque = Vector3.new(0, 4e5, 0)
        b.Name = "MistralSpin"
        b.Parent = hrp
    end
end

local flingConn
local function setFling(on)
    if flingConn then flingConn:Disconnect() flingConn = nil end
    if on then
        flingConn = RunService.Heartbeat:Connect(function()
            local h = getHRP(LocalPlayer)
            if h and isAlive(LocalPlayer) then h.AssemblyAngularVelocity = Vector3.new(0, 250, 0) end
        end)
    else
        local h = getHRP(LocalPlayer)
        if h then pcall(function() h.AssemblyAngularVelocity = Vector3.zero end) end
    end
end

local function say(msg)
    pcall(function()
        local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents", true)
        if ev and ev:FindFirstChild("SayMessageRequest") then ev.SayMessageRequest:FireServer(msg, "All") end
    end)
end

local function rejoin() pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end

local function serverHop()
    local req = http_request or request or (http and http.request)
    if not req then rejoin() return end
    pcall(function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=50"):format(game.PlaceId)
        local res = req({ Url = url, Method = "GET" })
        local data = HttpService:JSONDecode(res.Body)
        for _, s in ipairs(data.data or {}) do
            if s.id ~= game.JobId and (s.playing or 0) < (s.maxPlayers or 0) then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                return
            end
        end
        notify("Server", "No free servers")
    end)
end

local function revealRoles()
    local lines = {}
    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(lines, p.Name .. " — " .. getRole(p))
    end
    notify("Roles", table.concat(lines, "\n"), 7)
end

local function saveConfig()
    if not writefile then notify("Config", "writefile N/A") return end
    local ok = pcall(function() writefile("mistral_a05.json", HttpService:JSONEncode(Flags)) end)
    notify("Config", ok and "Saved" or "Failed")
end

local function loadConfig()
    if not readfile then notify("Config", "readfile N/A") return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile("mistral_a05.json")) end)
    if not ok or type(data) ~= "table" then notify("Config", "Not found") return end
    for n, v in pairs(data) do
        if UIRegistry[n] then pcall(UIRegistry[n], v) end
    end
    notify("Config", "Loaded")
end

local function applyProfile(name)
    local p = profiles[name]
    if not p then return end
    for n, v in pairs(p) do
        if UIRegistry[n] then pcall(UIRegistry[n], v) end
    end
    notify("Profile", name)
end

local function copyJobId()
    local id = tostring(game.JobId)
    pcall(function()
        if setclipboard then setclipboard(id) elseif toclipboard then toclipboard(id) end
    end)
    notify("JobId", id:sub(1, 16) .. "…")
end

local spectating, spectateTarget = false, nil
local function spectateNext()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then table.insert(list, p) end
    end
    if #list == 0 then return end
    local idx = 1
    if spectateTarget and table.find(list, spectateTarget) then
        idx = (table.find(list, spectateTarget) % #list) + 1
    end
    spectateTarget = list[idx]
    spectating = true
    local h = getHum(spectateTarget)
    if h then Camera.CameraSubject = h end
    notify("Spectate", spectateTarget.Name)
end

local function stopSpectate()
    spectating = false
    spectateTarget = nil
    local h = getHum(LocalPlayer)
    if h then Camera.CameraSubject = h end
end

----------------------------------------------------------------------
-- THEME (purple neon default)
----------------------------------------------------------------------
local CFG = {
    Accent = Color3.fromRGB(180, 80, 255),
    BgTransparency = 0.35,
    WindowScale = 1,
    SidebarWidth = 150,
    AnimSpeed = 0.22,
}

local T = {
    Bg = Color3.fromRGB(18, 10, 28),
    Panel = Color3.fromRGB(28, 16, 42),
    Card = Color3.fromRGB(36, 22, 52),
    Stroke = Color3.fromRGB(90, 50, 140),
    Text = Color3.fromRGB(245, 235, 255),
    Sub = Color3.fromRGB(170, 150, 200),
    Hover = Color3.fromRGB(50, 30, 70),
    Select = Color3.fromRGB(55, 30, 85),
}

----------------------------------------------------------------------
-- GUI
----------------------------------------------------------------------
local Gui = Instance.new("ScreenGui")
Gui.Name = "MistralAlfa05"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 999
Gui.Enabled = true

pcall(function()
    if gethui then Gui.Parent = gethui()
    elseif syn and syn.protect_gui then syn.protect_gui(Gui) Gui.Parent = game:GetService("CoreGui")
    else Gui.Parent = game:GetService("CoreGui") end
end)
if not Gui.Parent then pcall(function() Gui.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end) end

-- Notifications TOP-RIGHT (fix)
local ToastHold = Instance.new("Frame")
ToastHold.Size = UDim2.new(0, 250, 0, 400)
ToastHold.Position = UDim2.new(1, -262, 0, 16)  -- right top
ToastHold.BackgroundTransparency = 1
ToastHold.ZIndex = 90
ToastHold.Parent = Gui
local tList = Instance.new("UIListLayout")
tList.Padding = UDim.new(0, 6)
tList.VerticalAlignment = Enum.VerticalAlignment.Top  -- top
tList.HorizontalAlignment = Enum.HorizontalAlignment.Right
tList.SortOrder = Enum.SortOrder.LayoutOrder
tList.Parent = ToastHold

local nQ, nA = {}, 0
local function makeNotif(title, text, dur)
    dur = dur or 3.5
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.BackgroundColor3 = T.Panel
    f.BackgroundTransparency = 0.1
    f.BorderSizePixel = 0
    f.ZIndex = 90
    f.Parent = ToastHold
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = f
    local st = Instance.new("UIStroke") st.Color = CFG.Accent st.Thickness = 1 st.Transparency = 0.4 st.Parent = f
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, -10)
    bar.Position = UDim2.new(0, 5, 0, 5)
    bar.BackgroundColor3 = CFG.Accent
    bar.BorderSizePixel = 0
    bar.Parent = f
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 2) bc.Parent = bar
    local tt = Instance.new("TextLabel")
    tt.Size = UDim2.new(1, -18, 0, 18)
    tt.Position = UDim2.new(0, 14, 0, 6)
    tt.BackgroundTransparency = 1
    tt.Text = title
    tt.TextColor3 = CFG.Accent
    tt.TextSize = 12
    tt.Font = Enum.Font.GothamBold
    tt.TextXAlignment = Enum.TextXAlignment.Left
    tt.ZIndex = 91
    tt.Parent = f
    local tx = Instance.new("TextLabel")
    tx.Size = UDim2.new(1, -18, 0, 0)
    tx.AutomaticSize = Enum.AutomaticSize.Y
    tx.Position = UDim2.new(0, 14, 0, 24)
    tx.BackgroundTransparency = 1
    tx.Text = text
    tx.TextColor3 = T.Text
    tx.TextSize = 11
    tx.Font = Enum.Font.Gotham
    tx.TextWrapped = true
    tx.TextXAlignment = Enum.TextXAlignment.Left
    tx.ZIndex = 91
    tx.Parent = f
    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = f
    f.BackgroundTransparency = 1
    f.Position = UDim2.new(0, 40, 0, 0)
    TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.1, Position = UDim2.new(0, 0, 0, 0)
    }):Play()
    task.delay(dur, function()
        pcall(function()
            TweenService:Create(f, TweenInfo.new(0.2), { BackgroundTransparency = 1, Position = UDim2.new(0, 40, 0, 0) }):Play()
            task.wait(0.2) f:Destroy()
            nA = math.max(0, nA - 1)
        end)
    end)
end

notify = function(title, text, dur)
    table.insert(nQ, { t = title, x = text, d = dur or 3.5 })
end

task.spawn(function()
    while Gui.Parent do
        if #nQ > 0 and nA < 4 then
            local n = table.remove(nQ, 1)
            nA += 1
            makeNotif(n.t, n.x, n.d)
            task.wait(0.08)
        else task.wait(0.1) end
    end
end)

-- Cooldown HUD
local cdFrame = Instance.new("Frame")
cdFrame.Size = UDim2.fromOffset(120, 24)
cdFrame.Position = UDim2.new(0.5, -60, 1, -48)
cdFrame.BackgroundColor3 = T.Panel
cdFrame.BackgroundTransparency = 0.2
cdFrame.BorderSizePixel = 0
cdFrame.Visible = false
cdFrame.ZIndex = 50
cdFrame.Parent = Gui
do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = cdFrame end
local cdText = Instance.new("TextLabel")
cdText.Size = UDim2.new(1, 0, 1, 0)
cdText.BackgroundTransparency = 1
cdText.Text = "Ready"
cdText.TextColor3 = Color3.fromRGB(140, 255, 160)
cdText.TextSize = 12
cdText.Font = Enum.Font.GothamBold
cdText.Parent = cdFrame

-- Role HUD
local roleHud = Instance.new("Frame")
roleHud.Size = UDim2.fromOffset(140, 28)
roleHud.Position = UDim2.new(0.5, -70, 0, 40)
roleHud.BackgroundColor3 = T.Panel
roleHud.BackgroundTransparency = 0.15
roleHud.BorderSizePixel = 0
roleHud.Visible = true
roleHud.ZIndex = 50
roleHud.Parent = Gui
do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = roleHud end
local roleHudText = Instance.new("TextLabel")
roleHudText.Size = UDim2.new(1, 0, 1, 0)
roleHudText.BackgroundTransparency = 1
roleHudText.Text = "Role: —"
roleHudText.TextColor3 = T.Text
roleHudText.TextSize = 13
roleHudText.Font = Enum.Font.GothamBold
roleHudText.Parent = roleHud

-- Watermark
local wm = Instance.new("TextLabel")
wm.Size = UDim2.fromOffset(160, 16)
wm.Position = UDim2.new(0, 10, 0, 8)
wm.BackgroundTransparency = 1
wm.Text = "MISTRAL  Alfa 0.5"
wm.TextColor3 = Color3.fromRGB(180, 120, 255)
wm.TextSize = 11
wm.Font = Enum.Font.GothamBold
wm.TextXAlignment = Enum.TextXAlignment.Left
wm.ZIndex = 60
wm.Parent = Gui

----------------------------------------------------------------------
-- MAIN WINDOW
----------------------------------------------------------------------
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local WIN_W, WIN_H = 540, 420
if isMobile then
    local v = Camera.ViewportSize
    WIN_W = math.min(520, v.X - 20)
    WIN_H = math.min(440, v.Y - 70)
end

local Main = Instance.new("Frame")
Main.Name = "MistralMain"
Main.Size = UDim2.fromOffset(WIN_W, WIN_H)
Main.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Main.BackgroundColor3 = T.Bg
Main.BackgroundTransparency = CFG.BgTransparency
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Active = true
Main.Parent = Gui
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = Main
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = CFG.Accent
mainStroke.Thickness = 1.2
mainStroke.Transparency = 0.35
mainStroke.Parent = Main

-- Banner background
local bgImg = Instance.new("ImageLabel")
bgImg.Size = UDim2.new(1, 0, 1, 0)
bgImg.BackgroundTransparency = 1
bgImg.ImageTransparency = 0.55
bgImg.ScaleType = Enum.ScaleType.Crop
bgImg.ZIndex = 0
bgImg.Parent = Main
if BANNER_ASSET_ID ~= "" then
    bgImg.Image = "rbxassetid://" .. tostring(BANNER_ASSET_ID)
else
    -- purple gradient fallback (no asset)
    bgImg.BackgroundColor3 = Color3.fromRGB(40, 10, 70)
    bgImg.BackgroundTransparency = 0.7
    bgImg.Image = ""
end
-- dark overlay for readability
local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(12, 5, 20)
overlay.BackgroundTransparency = 0.45
overlay.BorderSizePixel = 0
overlay.ZIndex = 0
overlay.Parent = Main

local MainScale = Instance.new("UIScale")
MainScale.Scale = CFG.WindowScale
MainScale.Parent = Main

-- Top bar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 46)
TopBar.BackgroundColor3 = T.Panel
TopBar.BackgroundTransparency = 0.25
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 2
TopBar.Parent = Main

local Logo = Instance.new("TextLabel")
Logo.Size = UDim2.fromOffset(30, 30)
Logo.Position = UDim2.new(0, 12, 0.5, -15)
Logo.BackgroundColor3 = CFG.Accent
Logo.Text = "M"
Logo.TextColor3 = Color3.new(0, 0, 0)
Logo.TextSize = 15
Logo.Font = Enum.Font.GothamBold
Logo.ZIndex = 3
Logo.Parent = TopBar
local lc = Instance.new("UICorner") lc.CornerRadius = UDim.new(0, 8) lc.Parent = Logo

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(0, 180, 0, 18)
TitleLbl.Position = UDim2.new(0, 50, 0, 6)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "Mistral MM2"
TitleLbl.TextColor3 = T.Text
TitleLbl.TextSize = 15
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.ZIndex = 3
TitleLbl.Parent = TopBar

local SubLbl = Instance.new("TextLabel")
SubLbl.Size = UDim2.new(0, 180, 0, 14)
SubLbl.Position = UDim2.new(0, 50, 0, 26)
SubLbl.BackgroundTransparency = 1
SubLbl.Text = "Scripts · Alfa 0.5"
SubLbl.TextColor3 = T.Sub
SubLbl.TextSize = 11
SubLbl.Font = Enum.Font.Gotham
SubLbl.TextXAlignment = Enum.TextXAlignment.Left
SubLbl.ZIndex = 3
SubLbl.Parent = TopBar

local VerBadge = Instance.new("TextLabel")
VerBadge.Size = UDim2.fromOffset(54, 22)
VerBadge.Position = UDim2.new(0, 210, 0.5, -11)
VerBadge.BackgroundColor3 = CFG.Accent
VerBadge.Text = " 0.5 "
VerBadge.TextColor3 = Color3.new(1, 1, 1)
VerBadge.TextSize = 12
VerBadge.Font = Enum.Font.GothamBold
VerBadge.ZIndex = 3
VerBadge.Parent = TopBar
local vc = Instance.new("UICorner") vc.CornerRadius = UDim.new(0, 6) vc.Parent = VerBadge

local function topBtn(text, xOff, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(28, 28)
    b.Position = UDim2.new(1, xOff, 0.5, -14)
    b.BackgroundColor3 = T.Card
    b.BackgroundTransparency = 0.3
    b.Text = text
    b.TextColor3 = T.Text
    b.TextSize = 14
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.ZIndex = 3
    b.Parent = TopBar
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 7) c.Parent = b
    b.MouseButton1Click:Connect(cb)
    return b
end

-- Drag
local dragging, dStart, pStart
TopBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dStart = i.Position
        pStart = Main.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
track(UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dStart
        Main.Position = UDim2.new(pStart.X.Scale, pStart.X.Offset + d.X, pStart.Y.Scale, pStart.Y.Offset + d.Y)
    end
end))

local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Size = UDim2.new(0, CFG.SidebarWidth, 1, -46)
Sidebar.Position = UDim2.new(0, 0, 0, 46)
Sidebar.BackgroundColor3 = T.Panel
Sidebar.BackgroundTransparency = 0.35
Sidebar.BorderSizePixel = 0
Sidebar.ScrollBarThickness = 2
Sidebar.ScrollBarImageColor3 = CFG.Accent
Sidebar.CanvasSize = UDim2.new()
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.ZIndex = 2
Sidebar.Parent = Main
local sideList = Instance.new("UIListLayout")
sideList.Padding = UDim.new(0, 2)
sideList.Parent = Sidebar
local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 8)
sidePad.PaddingLeft = UDim.new(0, 8)
sidePad.PaddingRight = UDim.new(0, 8)
sidePad.PaddingBottom = UDim.new(0, 8)
sidePad.Parent = Sidebar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -CFG.SidebarWidth, 1, -46)
Content.Position = UDim2.new(0, CFG.SidebarWidth, 0, 46)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.ZIndex = 2
Content.Parent = Main

local Pages = Instance.new("Frame")
Pages.Size = UDim2.new(1, -14, 1, -14)
Pages.Position = UDim2.new(0, 7, 0, 7)
Pages.BackgroundTransparency = 1
Pages.ClipsDescendants = true
Pages.Parent = Content

local tabs, tabButtons, currentTab = {}, {}, nil

local function createPage()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = CFG.Accent
    page.CanvasSize = UDim2.new()
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = Pages
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = page
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = page
    return page
end

local function selectTab(name)
    if currentTab == name then return end
    currentTab = name
    for n, page in pairs(tabs) do
        page.Visible = (n == name)
        if n == name then page.CanvasPosition = Vector2.zero end
    end
    for n, btn in pairs(tabButtons) do
        local active = (n == name)
        TweenService:Create(btn, TweenInfo.new(CFG.AnimSpeed, Enum.EasingStyle.Quint), {
            BackgroundColor3 = active and T.Select or T.Panel,
            BackgroundTransparency = active and 0.15 or 1
        }):Play()
        local lbl = btn:FindFirstChild("TabLabel")
        if lbl then
            TweenService:Create(lbl, TweenInfo.new(CFG.AnimSpeed), {
                TextColor3 = active and CFG.Accent or T.Sub
            }):Play()
        end
        local ic = btn:FindFirstChild("TabIcon")
        if ic then
            TweenService:Create(ic, TweenInfo.new(CFG.AnimSpeed), {
                TextColor3 = active and CFG.Accent or T.Sub
            }):Play()
        end
    end
    playSound(6026723916, 0.05)
end

local function addTab(name, icon)
    local page = createPage()
    tabs[name] = page
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = T.Panel
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = Sidebar
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 8) bc.Parent = btn
    local ic = Instance.new("TextLabel")
    ic.Name = "TabIcon"
    ic.Size = UDim2.fromOffset(24, 24)
    ic.Position = UDim2.new(0, 8, 0.5, -12)
    ic.BackgroundTransparency = 1
    ic.Text = icon
    ic.TextSize = 14
    ic.TextColor3 = T.Sub
    ic.Font = Enum.Font.GothamBold
    ic.Parent = btn
    local lbl = Instance.new("TextLabel")
    lbl.Name = "TabLabel"
    lbl.Size = UDim2.new(1, -40, 1, 0)
    lbl.Position = UDim2.new(0, 36, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = T.Sub
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn
    btn.MouseEnter:Connect(function()
        if currentTab ~= name then
            TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.5, BackgroundColor3 = T.Hover }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if currentTab ~= name then
            TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
        end
    end)
    btn.MouseButton1Click:Connect(function() selectTab(name) end)
    tabButtons[name] = btn
    return page
end

local function sectionTitle(parent, text, icon)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 28)
    f.BackgroundTransparency = 1
    f.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = (icon or "") .. "  " .. text
    l.TextColor3 = CFG.Accent
    l.TextSize = 15
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    return f
end

local function makeAction(parent, title, desc, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 56)
    card.BackgroundColor3 = T.Card
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = card
    local s = Instance.new("UIStroke") s.Color = T.Stroke s.Thickness = 1 s.Transparency = 0.4 s.Parent = card
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, -50, 0, 18)
    tl.Position = UDim2.new(0, 14, 0, 8)
    tl.BackgroundTransparency = 1
    tl.Text = title
    tl.TextColor3 = T.Text
    tl.TextSize = 13
    tl.Font = Enum.Font.GothamMedium
    tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.Parent = card
    local dl = Instance.new("TextLabel")
    dl.Size = UDim2.new(1, -50, 0, 16)
    dl.Position = UDim2.new(0, 14, 0, 28)
    dl.BackgroundTransparency = 1
    dl.Text = desc
    dl.TextColor3 = T.Sub
    dl.TextSize = 11
    dl.Font = Enum.Font.Gotham
    dl.TextXAlignment = Enum.TextXAlignment.Left
    dl.Parent = card
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(32, 32)
    btn.Position = UDim2.new(1, -42, 0.5, -16)
    btn.BackgroundColor3 = CFG.Accent
    btn.BackgroundTransparency = 0.8
    btn.Text = "▶"
    btn.TextColor3 = CFG.Accent
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = card
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 8) bc.Parent = btn
    btn.MouseButton1Click:Connect(function()
        playSound(6026723916, 0.07)
        pcall(callback)
    end)
end

local function makeToggle(parent, title, desc, flagName, default, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, desc and 56 or 44)
    card.BackgroundColor3 = T.Card
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = card
    local s = Instance.new("UIStroke") s.Color = T.Stroke s.Thickness = 1 s.Transparency = 0.4 s.Parent = card
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, -70, 0, 18)
    tl.Position = UDim2.new(0, 14, 0, desc and 8 or 13)
    tl.BackgroundTransparency = 1
    tl.Text = title
    tl.TextColor3 = T.Text
    tl.TextSize = 13
    tl.Font = Enum.Font.GothamMedium
    tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.Parent = card
    if desc then
        local dl = Instance.new("TextLabel")
        dl.Size = UDim2.new(1, -70, 0, 16)
        dl.Position = UDim2.new(0, 14, 0, 28)
        dl.BackgroundTransparency = 1
        dl.Text = desc
        dl.TextColor3 = T.Sub
        dl.TextSize = 11
        dl.Font = Enum.Font.Gotham
        dl.TextXAlignment = Enum.TextXAlignment.Left
        dl.Parent = card
    end
    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(42, 24)
    track.Position = UDim2.new(1, -56, 0.5, -12)
    track.BackgroundColor3 = T.Stroke
    track.BorderSizePixel = 0
    track.Parent = card
    local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(1, 0) tc.Parent = track
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(20, 20)
    knob.Position = UDim2.new(0, 2, 0.5, -10)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1, 0) kc.Parent = knob
    local state = default == true
    local function render(anim)
        local tw = TweenInfo.new(anim and CFG.AnimSpeed or 0, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        if state then
            TweenService:Create(track, tw, { BackgroundColor3 = CFG.Accent }):Play()
            TweenService:Create(knob, tw, { Position = UDim2.new(1, -22, 0.5, -10) }):Play()
        else
            TweenService:Create(track, tw, { BackgroundColor3 = T.Stroke }):Play()
            TweenService:Create(knob, tw, { Position = UDim2.new(0, 2, 0.5, -10) }):Play()
        end
    end
    local function set(v, silent)
        state = v and true or false
        Flags[flagName] = state
        render(not silent)
        if not silent then playSound(6026723916, 0.06) end
        if callback then pcall(callback, state) end
    end
    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Parent = card
    hit.MouseButton1Click:Connect(function() set(not state) end)
    set(state, true)
    UIRegistry[flagName] = function(v) set(v, true) end
end

local function makeSlider(parent, title, flagName, min, max, default, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 52)
    card.BackgroundColor3 = T.Card
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = card
    local s = Instance.new("UIStroke") s.Color = T.Stroke s.Thickness = 1 s.Transparency = 0.4 s.Parent = card
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, -60, 0, 16)
    tl.Position = UDim2.new(0, 14, 0, 6)
    tl.BackgroundTransparency = 1
    tl.Text = title
    tl.TextColor3 = T.Text
    tl.TextSize = 12
    tl.Font = Enum.Font.GothamMedium
    tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.Parent = card
    local vl = Instance.new("TextLabel")
    vl.Size = UDim2.new(0, 48, 0, 16)
    vl.Position = UDim2.new(1, -56, 0, 6)
    vl.BackgroundTransparency = 1
    vl.Text = tostring(default)
    vl.TextColor3 = CFG.Accent
    vl.TextSize = 12
    vl.Font = Enum.Font.GothamBold
    vl.TextXAlignment = Enum.TextXAlignment.Right
    vl.Parent = card
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -28, 0, 6)
    bar.Position = UDim2.new(0, 14, 0, 32)
    bar.BackgroundColor3 = T.Stroke
    bar.BorderSizePixel = 0
    bar.Parent = card
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = bar
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0.5, 0, 1, 0)
    fill.BackgroundColor3 = CFG.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = fill
    local function set(v, silent)
        v = math.clamp(tonumber(v) or min, min, max)
        Flags[flagName] = v
        vl.Text = tostring(math.floor(v * 100) / 100)
        local a = (v - min) / (max - min)
        fill.Size = UDim2.new(a, 0, 1, 0)
        if not silent and callback then pcall(callback, v) end
    end
    local drag = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true end
    end)
    bar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
    end)
    track(UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local w = bar.AbsoluteSize.X
            if w > 0 then set(min + (max - min) * math.clamp((i.Position.X - bar.AbsolutePosition.X) / w, 0, 1)) end
        end
    end))
    set(default, true)
    UIRegistry[flagName] = function(v) set(v) end
end

-- TABS
local pHome = addTab("Home", "🏠")
local pCombat = addTab("Combat", "⚔️")
local pTeleport = addTab("Teleport", "📍")
local pVisuals = addTab("Visuals", "👁")
local pFarm = addTab("Auto Farm", "⭐")
local pLocal = addTab("Local", "👤")
local pTroll = addTab("Troll", "😈")
local pPlayers = addTab("Players", "👥")
local pMisc = addTab("Misc", "🔧")
local pConfig = addTab("Config", "📁")

-- HOME dashboard
sectionTitle(pHome, "Status", "📊")
local dashCard = Instance.new("Frame")
dashCard.Size = UDim2.new(1, 0, 0, 90)
dashCard.BackgroundColor3 = T.Card
dashCard.BackgroundTransparency = 0.15
dashCard.BorderSizePixel = 0
dashCard.Parent = pHome
do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = dashCard end
local dashRole = Instance.new("TextLabel")
dashRole.Size = UDim2.new(1, -20, 0, 22)
dashRole.Position = UDim2.new(0, 14, 0, 10)
dashRole.BackgroundTransparency = 1
dashRole.Text = "Role: —"
dashRole.TextColor3 = T.Text
dashRole.TextSize = 14
dashRole.Font = Enum.Font.GothamBold
dashRole.TextXAlignment = Enum.TextXAlignment.Left
dashRole.Parent = dashCard
local dashMur = Instance.new("TextLabel")
dashMur.Size = UDim2.new(1, -20, 0, 18)
dashMur.Position = UDim2.new(0, 14, 0, 36)
dashMur.BackgroundTransparency = 1
dashMur.Text = "Murderer: —"
dashMur.TextColor3 = RoleColors.Murderer
dashMur.TextSize = 12
dashMur.Font = Enum.Font.Gotham
dashMur.TextXAlignment = Enum.TextXAlignment.Left
dashMur.Parent = dashCard
local dashSher = Instance.new("TextLabel")
dashSher.Size = UDim2.new(1, -20, 0, 18)
dashSher.Position = UDim2.new(0, 14, 0, 56)
dashSher.BackgroundTransparency = 1
dashSher.Text = "Sheriff: —"
dashSher.TextColor3 = RoleColors.Sheriff
dashSher.TextSize = 12
dashSher.Font = Enum.Font.Gotham
dashSher.TextXAlignment = Enum.TextXAlignment.Left
dashSher.Parent = dashCard

sectionTitle(pHome, "Quick", "⚡")
makeAction(pHome, "Shoot Murderer", "Aim + fire at murderer", function() shootMurderer() end)
makeAction(pHome, "Throw Knife", "Knife nearest / murderer", function() throwKnife() end)
makeAction(pHome, "Kill All", "Murderer only", function() killAll() end)
makeAction(pHome, "Reveal Roles", "Show all roles", function() revealRoles() end)
sectionTitle(pHome, "Profiles", "💾")
makeAction(pHome, "Profile: Safe", "ESP only, no combat cheats", function() applyProfile("Safe") end)
makeAction(pHome, "Profile: Agro", "Aim + aura + hitbox", function() applyProfile("Agro") end)
makeAction(pHome, "Profile: Farm", "Coin farm focus", function() applyProfile("Farm") end)

-- COMBAT
sectionTitle(pCombat, "Combat", "⚔️")
makeAction(pCombat, "Steal Gun", "Fling sheriff + grab gun", function() stealGun() end)
makeAction(pCombat, "Grab Gun", "TP gun drop to you", function() grabGun() end)
makeToggle(pCombat, "Auto Grab Gun", "Continuously grab gun drop", "Auto Grab Gun", false)
makeToggle(pCombat, "Auto Knife Throw", "Auto knife nearby", "Auto Knife", false)
makeToggle(pCombat, "Kill Aura", "Auto knife as Murderer", "Kill Aura", false)
makeToggle(pCombat, "Auto Shoot", "Auto shoot as Sheriff", "Auto Shoot", false)
makeToggle(pCombat, "Silent Aim", "Silent aim murderer", "Silent Aim", false)
makeToggle(pCombat, "Aimbot", "Smooth aimbot", "Aimbot", false)
makeToggle(pCombat, "Prediction", "Lead moving targets", "Prediction", false)
makeToggle(pCombat, "FOV Circle", "Show aim FOV", "FOV Circle", false)
makeSlider(pCombat, "FOV Radius", "FOVRad", 40, 300, 140, function(v) aimFovRadius = v end)
makeSlider(pCombat, "Aim Smoothness", "AimSmooth", 0.05, 1, 0.25, function(v) aimSmooth = v end)
makeToggle(pCombat, "Hitbox Expander", "Bigger hitboxes", "Hitbox", false, function(on) setHitbox(on) end)
makeToggle(pCombat, "Triggerbot", "Shoot when on target", "Triggerbot", false, function(on) triggerOn = on end)
makeToggle(pCombat, "Cooldown HUD", "Show gun/knife CD", "Cooldown HUD", true, function(on) cdFrame.Visible = on end)

-- TELEPORT
sectionTitle(pTeleport, "Teleport", "📍")
makeAction(pTeleport, "TP Nearest", "To nearest player", function() local t=nearestPlayer() if t then tpTo(t) end end)
makeAction(pTeleport, "TP Murderer", "To murderer", function() local m=getMurderer() if m then tpTo(m) else notify("TP","No murderer") end end)
makeAction(pTeleport, "TP Sheriff", "To sheriff", function() local s=getSheriff() if s then tpTo(s) else notify("TP","No sheriff") end end)
makeAction(pTeleport, "TP Spawn", "Map center", function() local h=getHRP(LocalPlayer) if h then h.CFrame=CFrame.new(0,50,0) end end)
makeToggle(pTeleport, "Click TP", "Click to teleport", "Click TP", false)

-- VISUALS
sectionTitle(pVisuals, "ESP", "👁")
makeToggle(pVisuals, "Player ESP", "Names + role + distance", "Player ESP", false)
makeToggle(pVisuals, "Chams", "Role highlights", "Chams", false)
makeToggle(pVisuals, "Tracers", "Lines to players", "Tracers", false)
makeToggle(pVisuals, "Coin ESP", "Highlight coins", "Coin ESP", false)
makeToggle(pVisuals, "Role HUD", "Role at top center", "Role HUD", true, function(on) roleHud.Visible = on end)
sectionTitle(pVisuals, "World", "🌍")
makeToggle(pVisuals, "Fullbright", "Bright map", "Fullbright", false, function(on)
    if on then Lighting.Brightness=3 Lighting.ClockTime=14 Lighting.GlobalShadows=false Lighting.FogEnd=1e9
    else Lighting.Brightness=1 Lighting.ClockTime=12 Lighting.GlobalShadows=true end
end)
makeToggle(pVisuals, "No Fog", "Remove fog", "No Fog", false)
makeToggle(pVisuals, "FPS Boost", "Lower quality", "FPS Boost", false, function(on)
    pcall(function()
        settings().Rendering.QualityLevel = on and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
        Lighting.GlobalShadows = not on
    end)
end)
makeSlider(pVisuals, "Camera FOV", "CamFOV", 50, 120, 70, function(v) pcall(function() Camera.FieldOfView=v end) end)
makeToggle(pVisuals, "Murderer Alert", "Sound when close", "Murderer Alert", false)
makeSlider(pVisuals, "Alert Distance", "AlertDist", 20, 150, 50)

-- FARM
sectionTitle(pFarm, "Coins", "🪙")
makeToggle(pFarm, "Auto Farm Coins", "TP to coins", "Auto Farm", false)
makeSlider(pFarm, "Farm Delay", "FarmDelay", 0.15, 1, 0.3, function(v) farmDelay = v end)

-- LOCAL
sectionTitle(pLocal, "Movement", "🏃")
makeSlider(pLocal, "WalkSpeed", "WalkSpeed", 16, 150, 16, function(v) local h=getHum(LocalPlayer) if h then h.WalkSpeed=v end end)
makeSlider(pLocal, "JumpPower", "JumpPower", 50, 200, 50, function(v) local h=getHum(LocalPlayer) if h then h.UseJumpPower=true h.JumpPower=v end end)
makeToggle(pLocal, "Infinite Jump", "Jump in air", "InfJump", false)
makeToggle(pLocal, "Bunny Hop", "Auto jump", "Bhop", false)
makeToggle(pLocal, "Fly", "Fly mode", "Fly", false, function(on) setFly(on) end)
makeSlider(pLocal, "Fly Speed", "FlySpeed", 20, 200, 80, function(v) flySpeed = v end)
makeToggle(pLocal, "Noclip", "Through walls", "Noclip", false)
makeToggle(pLocal, "Anti-Void", "Save from fall", "AntiVoid", false)
makeToggle(pLocal, "Anti-AFK", "Prevent kick", "AntiAFK", false)
sectionTitle(pLocal, "Stealth", "👻")
makeToggle(pLocal, "Invisible", "Local invis + health lock", "Invisible", false, function(on) setInvisible(on) end)

-- TROLL
sectionTitle(pTroll, "Troll", "😈")
makeToggle(pTroll, "Fling All", "Fling nearby", "Fling", false, function(on) setFling(on) end)
makeToggle(pTroll, "Spin Bot", "Spin", "Spin", false, function(on) setSpin(on) end)
makeToggle(pTroll, "Chat Spam", "Spam chat", "ChatSpam", false)
makeAction(pTroll, "Spectate Next", "Cycle players", function() spectateNext() end)
makeAction(pTroll, "Stop Spectate", "Back to self", function() stopSpectate() end)

-- PLAYERS list
sectionTitle(pPlayers, "Players", "👥")
local playerListHost = Instance.new("Frame")
playerListHost.Size = UDim2.new(1, 0, 0, 10)
playerListHost.BackgroundTransparency = 1
playerListHost.Parent = pPlayers
local playerListLayout = Instance.new("UIListLayout")
playerListLayout.Padding = UDim.new(0, 4)
playerListLayout.Parent = playerListHost

-- MISC
sectionTitle(pMisc, "Server", "🌐")
makeAction(pMisc, "Rejoin", "Rejoin server", function() rejoin() end)
makeAction(pMisc, "Server Hop", "Other server", function() serverHop() end)
makeAction(pMisc, "Copy JobId", "To clipboard", function() copyJobId() end)
makeAction(pMisc, "Copy TG Link", "Telegram channel", function()
    pcall(function()
        if setclipboard then setclipboard(TG_LINK) elseif toclipboard then toclipboard(TG_LINK) end
    end)
    notify("TG", TG_LINK)
end)
makeAction(pMisc, "Reveal Roles", "All roles", function() revealRoles() end)
sectionTitle(pMisc, "Config File", "💾")
makeAction(pMisc, "Save Config", "Write file", function() saveConfig() end)
makeAction(pMisc, "Load Config", "Read file", function() loadConfig() end)

-- CONFIG
sectionTitle(pConfig, "Appearance", "🎨")
makeSlider(pConfig, "UI Transparency", "UIAlpha", 0.1, 0.7, 0.35, function(v)
    CFG.BgTransparency = v
    Main.BackgroundTransparency = v
end)
makeSlider(pConfig, "Window Scale", "UIScale", 0.75, 1.25, 1, function(v)
    CFG.WindowScale = v
    MainScale.Scale = v
end)
makeSlider(pConfig, "Accent R", "AccR", 0, 255, 180, function(v)
    CFG.Accent = Color3.fromRGB(v, CFG.Accent.G*255, CFG.Accent.B*255)
    mainStroke.Color = CFG.Accent
    Logo.BackgroundColor3 = CFG.Accent
    VerBadge.BackgroundColor3 = CFG.Accent
end)
makeSlider(pConfig, "Accent G", "AccG", 0, 255, 80, function(v)
    CFG.Accent = Color3.fromRGB(CFG.Accent.R*255, v, CFG.Accent.B*255)
    mainStroke.Color = CFG.Accent
    Logo.BackgroundColor3 = CFG.Accent
end)
makeSlider(pConfig, "Accent B", "AccB", 0, 255, 255, function(v)
    CFG.Accent = Color3.fromRGB(CFG.Accent.R*255, CFG.Accent.G*255, v)
    mainStroke.Color = CFG.Accent
    Logo.BackgroundColor3 = CFG.Accent
end)
sectionTitle(pConfig, "Audio", "🔊")
makeToggle(pConfig, "Sound Effects", "UI sounds", "Sounds", true, function(on) SoundEnabled = on end)
sectionTitle(pConfig, "Banner", "🖼")
makeAction(pConfig, "How to set banner", "Upload 17924.png → put ID in BANNER_ASSET_ID", function()
    notify("Banner", "Upload PNG to Roblox, paste ID at top of script")
end)
sectionTitle(pConfig, "Danger", "⚠️")
makeAction(pConfig, "PANIC", "Disable all features", function()
    for n, v in pairs(Flags) do
        if v == true and UIRegistry[n] then pcall(UIRegistry[n], false) end
    end
    setFly(false) setFling(false) setSpin(false) setHitbox(false) setInvisible(false)
    triggerOn = false
    stopSpectate()
    notify("PANIC", "All off")
end)
makeAction(pConfig, "Unload", "Destroy script", function()
    clearAll()
    pcall(function() Gui:Destroy() end)
    getgenv().MISTRAL_UNLOAD = nil
end)

-- Window controls
local menuOpen = true
topBtn("—", -100, function()
    menuOpen = not menuOpen
    if menuOpen then
        Main.Visible = true
        MainScale.Scale = 0.88
        TweenService:Create(MainScale, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = CFG.WindowScale }):Play()
    else
        TweenService:Create(MainScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.88 }):Play()
        task.delay(0.16, function() Main.Visible = false end)
    end
end)
topBtn("□", -66, function()
    local v = Camera.ViewportSize
    if Main.Size.X.Offset > WIN_W + 20 then
        TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {
            Size = UDim2.fromOffset(WIN_W, WIN_H), Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
        }):Play()
    else
        local nw, nh = math.min(v.X-40, 720), math.min(v.Y-60, 540)
        TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {
            Size = UDim2.fromOffset(nw, nh), Position = UDim2.new(0.5, -nw/2, 0.5, -nh/2)
        }):Play()
    end
end)
topBtn("✕", -32, function()
    clearAll()
    pcall(function() Gui:Destroy() end)
    getgenv().MISTRAL_UNLOAD = nil
end)

-- M button
local MBtn = Instance.new("TextButton")
MBtn.Size = UDim2.fromOffset(46, 46)
MBtn.Position = UDim2.new(1, -58, 1, -58)
MBtn.BackgroundColor3 = CFG.Accent
MBtn.Text = "M"
MBtn.TextColor3 = Color3.new(0, 0, 0)
MBtn.TextSize = 18
MBtn.Font = Enum.Font.GothamBold
MBtn.ZIndex = 100
MBtn.BorderSizePixel = 0
MBtn.Parent = Gui
do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = MBtn end
MBtn.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    Main.Visible = menuOpen
    if menuOpen then
        MainScale.Scale = 0.88
        TweenService:Create(MainScale, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = CFG.WindowScale }):Play()
    end
end)

-- FOV circle
local fovCircle = nil
if Drawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.5
    fovCircle.NumSides = 48
    fovCircle.Filled = false
    fovCircle.Visible = false
    onCleanup(function() pcall(function() fovCircle:Remove() end) end)
end

----------------------------------------------------------------------
-- LOOPS
----------------------------------------------------------------------
track(UserInputService.InputBegan:Connect(function(i, g)
    if not g then keys[i.KeyCode] = true end
end))
track(UserInputService.InputEnded:Connect(function(i) keys[i.KeyCode] = nil end))

track(UserInputService.JumpRequest:Connect(function()
    if Flags["InfJump"] or Flags["Bhop"] then
        local h = getHum(LocalPlayer)
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

pcall(function()
    if Mouse then
        track(Mouse.Button1Down:Connect(function()
            if Flags["Click TP"] and Mouse.Target then
                local hrp = getHRP(LocalPlayer)
                if hrp then hrp.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 4, 0)) end
            end
        end))
    end
end)

track(RunService.RenderStepped:Connect(function()
    pcall(function()
        local target = lockedTarget or getMurderer()
        if Flags["Aimbot"] and target and isVisible(target) then
            local hrp = getHRP(target)
            if hrp then
                local tp = Flags["Prediction"] and predictPos(hrp) or hrp.Position
                local sp, on = Camera:WorldToViewportPoint(tp)
                if on then
                    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                    if (Vector2.new(sp.X, sp.Y) - center).Magnitude <= aimFovRadius then
                        Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, tp), aimSmooth)
                    end
                end
            end
        end
        if Flags["Silent Aim"] then silentAim() end
        if triggerOn then
            local m = lockedTarget or getMurderer()
            if m and isAlive(m) then
                local hrp = getHRP(m)
                if hrp then
                    local sp, on = Camera:WorldToViewportPoint(hrp.Position)
                    if on then
                        local c = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                        if (Vector2.new(sp.X, sp.Y) - c).Magnitude < 55 then
                            triggerOn = false
                            task.spawn(shootMurderer)
                            task.delay(1.4, function() if Flags["Triggerbot"] then triggerOn = true end end)
                        end
                    end
                end
            end
        end
        if flyOn and Flags["Fly"] then
            local hum, hrp = getHum(LocalPlayer), getHRP(LocalPlayer)
            if hum and hrp and flyObj and flyObj.bv and flyObj.bv.Parent then
                local v = hum.MoveDirection * flySpeed
                if keys[Enum.KeyCode.Space] then v += Vector3.new(0, flySpeed, 0) end
                if keys[Enum.KeyCode.LeftControl] then v -= Vector3.new(0, flySpeed, 0) end
                flyObj.bv.Velocity = v
                flyObj.bg.CFrame = CFrame.new(hrp.Position, hrp.Position + Camera.CFrame.LookVector)
            elseif Flags["Fly"] and not flyPending then
                flyPending = true
                task.delay(0.2, function() if Flags["Fly"] then setFly(true) end flyPending = false end)
            end
        end
        if fovCircle then
            fovCircle.Visible = Flags["FOV Circle"] == true
            if fovCircle.Visible then
                fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                fovCircle.Radius = aimFovRadius
                fovCircle.Color = CFG.Accent
            end
        end
        -- HUD
        local r = getMyRole()
        roleHudText.Text = "Role: " .. r
        roleHudText.TextColor3 = RoleColors[r] or T.Text
        dashRole.Text = "Role: " .. r
        dashRole.TextColor3 = RoleColors[r] or T.Text
        local mur = getMurderer()
        dashMur.Text = "Murderer: " .. (mur and mur.Name or "—")
        local sher = getSheriff()
        dashSher.Text = "Sheriff: " .. (sher and sher.Name or "—")
        if Flags["Cooldown HUD"] then
            cdFrame.Visible = true
            local gr = gunCD - tick()
            local kr = knifeCD - tick()
            if gr > 0 then
                cdText.Text = ("Gun %.1fs"):format(gr)
                cdText.TextColor3 = Color3.fromRGB(120, 170, 255)
            elseif kr > 0 then
                cdText.Text = ("Knife %.1fs"):format(kr)
                cdText.TextColor3 = Color3.fromRGB(255, 130, 130)
            else
                cdText.Text = "Ready"
                cdText.TextColor3 = Color3.fromRGB(140, 255, 160)
            end
        end
    end)
end))

track(RunService.Stepped:Connect(function()
    if Flags["Noclip"] then
        local ch = getChar(LocalPlayer)
        if ch then
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end
end))

track(LocalPlayer.CharacterAdded:Connect(function()
    cachedRoleT = 0
    task.wait(0.5)
    pcall(function()
        local h = getHum(LocalPlayer)
        if h then
            if Flags["WalkSpeed"] then h.WalkSpeed = Flags["WalkSpeed"] end
            if Flags["JumpPower"] then h.UseJumpPower = true h.JumpPower = Flags["JumpPower"] end
        end
        if Flags["Fly"] then task.wait(0.3) setFly(true) end
        if invisOn then task.wait(0.2) applyInvis(getChar(LocalPlayer)) end
    end)
    if spectating then stopSpectate() end
end))

track(LocalPlayer.CharacterRemoving:Connect(function()
    if flyObj then pcall(function() flyObj.bv:Destroy() flyObj.bg:Destroy() end) flyObj = nil end
end))

-- combat daemon
task.spawn(function()
    while Gui.Parent do
        task.wait(0.45)
        pcall(function()
            if Flags["Kill Aura"] and getMyRole() == "Murderer" then
                local k = getMyTool("Knife")
                if k and equipTool(k) then killNearest(30) end
            end
            if Flags["Auto Shoot"] and getMyRole() == "Sheriff" and tick() >= gunCD then
                local m = lockedTarget or getMurderer()
                if m and isVisible(m) then task.spawn(shootMurderer) end
            end
            if Flags["Auto Knife"] and getMyRole() == "Murderer" then
                local t = lockedTarget or nearestPlayer()
                if t then task.spawn(function() throwKnife(t) end) end
            end
            if Flags["Auto Grab Gun"] then grabGun() end
            if Flags["AntiVoid"] then
                local hrp = getHRP(LocalPlayer)
                local hum = getHum(LocalPlayer)
                if hrp then
                    if hrp.Position.Y > 5 and hum and hum.FloorMaterial ~= Enum.Material.Air then
                        lastSafe = hrp.Position
                    end
                    if hrp.Position.Y < -50 and lastSafe then
                        hrp.CFrame = CFrame.new(lastSafe + Vector3.new(0, 6, 0))
                    end
                end
            end
            if Flags["No Fog"] then Lighting.FogEnd = 1e9 end
            if Flags["Murderer Alert"] then
                local m = getMurderer()
                if m then
                    local my, mh = getHRP(LocalPlayer), getHRP(m)
                    if my and mh and (mh.Position - my.Position).Magnitude < (Flags["AlertDist"] or 50) then
                        playSound(3061459262, 0.12)
                    end
                end
            end
        end)
    end
end)

task.spawn(function()
    while Gui.Parent do
        task.wait(2)
        if hitboxOn then
            pcall(function()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and isAlive(p) then
                        local hrp = getHRP(p)
                        if hrp and hrp.Size.X < 12 then
                            if not hitboxOrig[hrp] then
                                hitboxOrig[hrp] = { S=hrp.Size, M=hrp.Material, C=hrp.Color, T=hrp.Transparency }
                            end
                            hrp.Size = Vector3.new(14,14,14)
                            hrp.Material = Enum.Material.ForceField
                            hrp.Color = Color3.fromRGB(255, 60, 80)
                            hrp.Transparency = 0.55
                        end
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while Gui.Parent do
        task.wait(math.max(farmDelay, 0.2))
        if Flags["Auto Farm"] then
            pcall(function()
                local hrp = getHRP(LocalPlayer)
                if not hrp then return end
                if tick() - coinCacheT > 2 then
                    coinCache = {}
                    for _, d in ipairs(workspace:GetDescendants()) do
                        if d:IsA("BasePart") then
                            local n = d.Name:lower()
                            if n:find("coin") or n:find("pickup") or n:find("collect") then
                                table.insert(coinCache, d)
                            end
                        end
                    end
                    coinCacheT = tick()
                end
                local best, bd = nil, math.huge
                for _, d in ipairs(coinCache) do
                    if d.Parent then
                        local dist = (d.Position - hrp.Position).Magnitude
                        if dist < bd then bd, best = dist, d end
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

task.spawn(function()
    while Gui.Parent do
        task.wait(0.3)
        if Flags["Fling"] then
            pcall(function()
                local my = getHRP(LocalPlayer)
                if not my then return end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and isAlive(p) then
                        local th = getHRP(p)
                        if th and (th.Position - my.Position).Magnitude < 60 then
                            my.CFrame = th.CFrame
                            task.wait(0.04)
                        end
                    end
                end
            end)
        end
    end
end)

local spamT = 0
task.spawn(function()
    while Gui.Parent do
        task.wait(1)
        spamT += 1
        if Flags["ChatSpam"] and spamT >= 3 then
            spamT = 0
            say(({"gg","ez","nice"})[math.random(3)])
        end
    end
end)

-- ESP
task.spawn(function()
    while Gui.Parent do
        task.wait(0.4)
        pcall(function()
            local wantBB = Flags["Player ESP"]
            local wantHL = Flags["Chams"]
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local d = espData[plr]
                    local ch = getChar(plr)
                    if not (ch and isAlive(plr)) then
                        if d then
                            pcall(function()
                                if d.bb then d.bb:Destroy() end
                                if d.hl then d.hl:Destroy() end
                                if d.line then d.line:Remove() end
                            end)
                            espData[plr] = nil
                        end
                    else
                        d = d or {}
                        local role = getRole(plr)
                        local col = RoleColors[role]
                        if wantBB then
                            local head = ch:FindFirstChild("Head") or getHRP(plr)
                            if head and (not d.bb or not d.bb.Parent) then
                                pcall(function() if d.bb then d.bb:Destroy() end end)
                                local bb = Instance.new("BillboardGui")
                                bb.Size = UDim2.fromOffset(130, 22)
                                bb.StudsOffset = Vector3.new(0, 3, 0)
                                bb.AlwaysOnTop = true
                                bb.Adornee = head
                                local lbl = Instance.new("TextLabel")
                                lbl.Size = UDim2.new(1, 0, 1, 0)
                                lbl.BackgroundTransparency = 1
                                lbl.Font = Enum.Font.GothamBold
                                lbl.TextSize = 11
                                lbl.TextStrokeTransparency = 0.4
                                lbl.Parent = bb
                                bb.Parent = Gui
                                d.bb, d.lbl = bb, lbl
                            end
                            if d.bb and d.lbl then
                                local h = getHRP(plr)
                                local dist = h and math.floor((h.Position - Camera.CFrame.Position).Magnitude) or 0
                                d.lbl.Text = plr.Name .. " · " .. role .. " · " .. dist .. "m"
                                d.lbl.TextColor3 = col
                            end
                        elseif d.bb then
                            pcall(function() d.bb:Destroy() end)
                            d.bb, d.lbl = nil, nil
                        end
                        if wantHL then
                            if not d.hl or not d.hl.Parent then
                                pcall(function() if d.hl then d.hl:Destroy() end end)
                                local hl = Instance.new("Highlight")
                                hl.FillTransparency = 0.6
                                hl.OutlineTransparency = 0
                                hl.Adornee = ch
                                hl.Parent = ch
                                d.hl = hl
                            end
                            if d.hl then d.hl.FillColor = col d.hl.OutlineColor = col end
                        elseif d.hl then
                            pcall(function() d.hl:Destroy() end)
                            d.hl = nil
                        end
                        if Flags["Tracers"] and Drawing then
                            if not d.line then
                                local l = Drawing.new("Line")
                                l.Thickness = 1.2
                                d.line = l
                            end
                            if d.line then
                                d.line.Color = col
                                local hrp = getHRP(plr)
                                if hrp then
                                    local pos, on = Camera:WorldToViewportPoint(hrp.Position)
                                    if on then
                                        d.line.Visible = true
                                        d.line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                                        d.line.To = Vector2.new(pos.X, pos.Y)
                                    else d.line.Visible = false end
                                end
                            end
                        elseif d.line then
                            pcall(function() d.line:Remove() end)
                            d.line = nil
                        end
                        espData[plr] = d
                    end
                end
            end
        end)
    end
end)

task.spawn(function()
    while Gui.Parent do
        task.wait(1.5)
        pcall(function()
            for _, h in ipairs(coinHLs) do pcall(function() h:Destroy() end) end
            coinHLs = {}
            if Flags["Coin ESP"] then
                for _, d in ipairs(workspace:GetDescendants()) do
                    if d:IsA("BasePart") and d.Name:lower():find("coin") then
                        local hl = Instance.new("Highlight")
                        hl.FillColor = Color3.fromRGB(255, 220, 50)
                        hl.OutlineColor = Color3.fromRGB(255, 220, 50)
                        hl.FillTransparency = 0.7
                        hl.Adornee = d
                        hl.Parent = workspace
                        table.insert(coinHLs, hl)
                    end
                end
            end
        end)
    end
end)

-- Player list rebuild
task.spawn(function()
    while Gui.Parent do
        task.wait(2.5)
        pcall(function()
            for _, ch in ipairs(playerListHost:GetChildren()) do
                if ch:IsA("Frame") then ch:Destroy() end
            end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local card = Instance.new("Frame")
                    card.Size = UDim2.new(1, 0, 0, 40)
                    card.BackgroundColor3 = T.Card
                    card.BackgroundTransparency = 0.15
                    card.BorderSizePixel = 0
                    card.Parent = playerListHost
                    local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 8) cc.Parent = card
                    local role = getRole(p)
                    local nl = Instance.new("TextLabel")
                    nl.Size = UDim2.new(0, 110, 1, 0)
                    nl.Position = UDim2.new(0, 10, 0, 0)
                    nl.BackgroundTransparency = 1
                    nl.Text = p.Name:sub(1, 14)
                    nl.TextColor3 = T.Text
                    nl.TextSize = 12
                    nl.Font = Enum.Font.Gotham
                    nl.TextXAlignment = Enum.TextXAlignment.Left
                    nl.Parent = card
                    local rl = Instance.new("TextLabel")
                    rl.Size = UDim2.new(0, 50, 1, 0)
                    rl.Position = UDim2.new(0, 120, 0, 0)
                    rl.BackgroundTransparency = 1
                    rl.Text = role:sub(1, 3)
                    rl.TextColor3 = RoleColors[role]
                    rl.TextSize = 11
                    rl.Font = Enum.Font.GothamBold
                    rl.Parent = card
                    local function smallBtn(txt, x, cb)
                        local b = Instance.new("TextButton")
                        b.Size = UDim2.fromOffset(32, 24)
                        b.Position = UDim2.new(1, x, 0.5, -12)
                        b.BackgroundColor3 = CFG.Accent
                        b.BackgroundTransparency = 0.7
                        b.Text = txt
                        b.TextColor3 = CFG.Accent
                        b.TextSize = 10
                        b.Font = Enum.Font.GothamBold
                        b.BorderSizePixel = 0
                        b.Parent = card
                        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 5) bc.Parent = b
                        b.MouseButton1Click:Connect(cb)
                    end
                    smallBtn("TP", -78, function() tpTo(p) end)
                    smallBtn("👁", -42, function()
                        lockedTarget = p
                        notify("Lock", p.Name)
                    end)
                end
            end
            playerListHost.Size = UDim2.new(1, 0, 0, math.max(10, #Players:GetPlayers() * 44))
        end)
    end
end)

track(Players.PlayerRemoving:Connect(function(plr)
    if espData[plr] then
        pcall(function()
            if espData[plr].bb then espData[plr].bb:Destroy() end
            if espData[plr].hl then espData[plr].hl:Destroy() end
            if espData[plr].line then espData[plr].line:Remove() end
        end)
        espData[plr] = nil
    end
    if lockedTarget == plr then lockedTarget = nil end
    if spectateTarget == plr then stopSpectate() end
end))

track(LocalPlayer.Idled:Connect(function()
    if Flags["AntiAFK"] then
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0,0), Camera.CFrame)
            task.wait(0.5)
            VirtualUser:Button2Up(Vector2.new(0,0), Camera.CFrame)
        end)
    end
end))

onCleanup(function()
    for _, h in ipairs(coinHLs) do pcall(function() h:Destroy() end) end
    for _, d in pairs(espData) do
        pcall(function()
            if d.bb then d.bb:Destroy() end
            if d.hl then d.hl:Destroy() end
            if d.line then d.line:Remove() end
        end)
    end
    if flyObj then pcall(function() flyObj.bv:Destroy() flyObj.bg:Destroy() end) end
    if flingConn then flingConn:Disconnect() end
    if invisConn then invisConn:Disconnect() end
    setHitbox(false)
end)

getgenv().MISTRAL_UNLOAD = function()
    clearAll()
    pcall(function() Gui:Destroy() end)
    getgenv().MISTRAL_UNLOAD = nil
end

-- START
selectTab("Home")
MainScale.Scale = 0.85
Main.BackgroundTransparency = 0.55
TweenService:Create(MainScale, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = CFG.WindowScale }):Play()
TweenService:Create(Main, TweenInfo.new(0.35), { BackgroundTransparency = CFG.BgTransparency }):Play()

notify("Mistral Alfa 0.5", "TG copied · purple neon · all features")
notify("TG", TG_LINK, 5)
print("═══ Mistral Alfa 0.5 loaded ═══")
print("[Mistral] TG:", TG_LINK)
print("[Mistral] Banner ID:", BANNER_ASSET_ID == "" and "(gradient fallback)" or BANNER_ASSET_ID)