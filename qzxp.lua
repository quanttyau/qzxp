-- CREDITS: S14X FOR SPAM AND ANIM FIX
--          LEAKED EAGLE HUB FOR BASICALLY EVERYTHING
--          ANGELI FOR AUTOPARRY AND TRIGGERBOT

local function GetSafeUIParent()
    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

-- [[ VFX HOOK CLEANUP — prevent duplication on reload ]]
pcall(function()
    if getgenv().qzxp_VFXConns then
        for _, conn in ipairs(getgenv().qzxp_VFXConns) do
            pcall(function() conn:Disconnect() end)
        end
    end
    if getgenv().qzxp_VFXDisabled then
        for _, conn in ipairs(getgenv().qzxp_VFXDisabled) do
            pcall(function() conn:Enable() end)
        end
    end
end)
getgenv().qzxp_VFXConns = {}
getgenv().qzxp_VFXHooked = {}
getgenv().qzxp_VFXDisabled = {}

task.spawn(function()

local function PatchCoreGui(str)
    return str
        :gsub('game:GetService("CoreGui")', 'game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")')
        :gsub("game:GetService('CoreGui')", "game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')")
        :gsub('game.CoreGui', 'game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")')
end

local Fluent = loadstring(PatchCoreGui(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/Beta.lua")))()
local SaveManager = loadstring(PatchCoreGui(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua")))()
local InterfaceManager = loadstring(PatchCoreGui(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua")))()

local Window = Fluent:CreateWindow({
    Title = "qzxp",
    TabWidth = 130,
    Size = UDim2.fromOffset(750, 530),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main      = Window:AddTab({Title = "Parry", Icon = "sword"}),
    Detection = Window:AddTab({Title = "Detect", Icon = "eye"}),
    Spam      = Window:AddTab({Title = "Spam", Icon = "zap"}),
    Trigger   = Window:AddTab({Title = "Trigger", Icon = "target"}),
    Skins     = Window:AddTab({Title = "Skins", Icon = "palette"}),
    Lock      = Window:AddTab({Title = "Lock", Icon = "lock"}),
    Visuals   = Window:AddTab({Title = "Visuals", Icon = "monitor"}),
    Settings  = Window:AddTab({Title = "Config", Icon = "sliders"})
}
local Options = Fluent.Options

-- Services
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats             = game:GetService("Stats")
local Workspace         = game:GetService("Workspace")
local CoreGui           = GetSafeUIParent()
local ContentProvider   = game:GetService("ContentProvider")
local HttpService       = game:GetService("HttpService")
local Debris            = game:GetService("Debris")

pcall(function()
    if hookfunction then
        hookfunction(ContentProvider.PreloadAsync, function() return end)
        hookfunction(ContentProvider.Preload, function() return end)
        hookfunction(ContentProvider.GetAssetFetchStatus, function() return Enum.AssetFetchStatus.Success end)
    end
end)

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local suppressNotifies = false
local function notify(cfg)
    if suppressNotifies then return end
    task.defer(function() pcall(function() Fluent:Notify(cfg) end) end)
end

-- ============================================================
-- ANTICHEAT BYPASS
-- ============================================================
local _token, _tokenFound = nil, false

task.defer(function()
    pcall(function()
        for _, fn in getgc(true) do
            if type(fn) == 'function' and debug.info(fn, 's'):find('PRY', 1, true) then
                for _, v in debug.getupvalues(fn) do
                    if type(v) == 'function' then _token = v; _tokenFound = true; break end
                end
            end
            if _tokenFound then break end
        end
    end)
    notify({Title = "AC", Content = _tokenFound and "Bypassed" or "Failed", Duration = 4})
end)

local function _tokenize(uid)
    local t = tostring(math.floor(Workspace:GetServerTimeNow() * 100))
    local k = _token(uid, 'TIME')
    local c = table.create(#t)
    for i = 1, #t do
        c[i] = string.char(bit32.bxor((string.byte(t, i) + i) % 256, string.byte(k, (i - 1) % #k + 1)))
    end
    return table.concat(c)
end

-- ============================================================
-- REMOTE HOOKER
-- ============================================================
local _remote, _args = nil, nil
pcall(function()
    local mt = getrawmetatable(game)
    local old = mt.__index
    local oldnew = mt.__newindex or function(s, k, v) rawset(s, k, v) end
    setreadonly(mt, false)
    mt.__index = newcclosure(function(self, key)
        if key == 'FireServer' and self:IsA('RemoteEvent') then
            return function(_, ...)
                local a = {...}
                if #a >= 8 and not _remote then
                    _remote = self; _args = a
                    notify({Title = "Hook", Content = self.Name, Duration = 3})
                end
                return old(self, key)(_, unpack(a))
            end
        end
        return old(self, key)
    end)
    mt.__newindex = newcclosure(function(self, key, value)
        if typeof(self) == "Instance" and self:IsA("LayerCollector") and (key == "ZIndexBehavior" or key == "ZIndex") then return end
        return oldnew(self, key, value)
    end)
    setreadonly(mt, true)
end)

-- ============================================================
-- SWORD REGISTRY
-- ============================================================
local SwordAPI = ReplicatedStorage:WaitForChild("Shared", 9e9):WaitForChild("SwordAPI", 9e9)
local swordModuleInstance = ReplicatedStorage:WaitForChild("Shared", 9e9):WaitForChild("ReplicatedInstances", 9e9):WaitForChild("Swords", 9e9)
local swordModule = require(swordModuleInstance)

local SwordRegistry = {}
local SwordList = {}

local function norm(s)
    return s and tostring(s):lower():gsub("[%s_%-%p]+", "") or ""
end

local function buildRegistry()
    local seen = {}
    SwordRegistry = {}
    SwordList = {}

    local function reg(name)
        if not name or name == "" or seen[name] then return end
        seen[name] = true
        SwordRegistry[norm(name)] = name
        table.insert(SwordList, name)
    end

    pcall(function()
        if type(swordModule) == "table" then
            for k, v in pairs(swordModule) do
                if type(k) == "string" and k ~= "GetSword" and k ~= "EquipSwordTo" and k ~= "new" and k ~= "__index" then
                    reg(k)
                end
                if type(v) == "table" then
                    if v.Name then reg(v.Name) end
                    if v.SwordName then reg(v.SwordName) end
                end
            end
            if swordModule.Swords and type(swordModule.Swords) == "table" then
                for k2, v2 in pairs(swordModule.Swords) do
                    if type(k2) == "string" then reg(k2) end
                    if type(v2) == "table" and v2.Name then reg(v2.Name) end
                end
            end
        end
    end)

    pcall(function()
        local folder = ReplicatedStorage.Shared.ReplicatedInstances.Swords
        for _, item in ipairs(folder:GetChildren()) do
            reg(item.Name)
        end
    end)

    pcall(function()
        if SwordAPI and SwordAPI:FindFirstChild("Collection") then
            for _, item in ipairs(SwordAPI.Collection:GetChildren()) do
                reg(item.Name)
            end
        end
    end)

    table.sort(SwordList, function(a, b) return a:lower() < b:lower() end)
    if #SwordList == 0 then table.insert(SwordList, "Default") end
end
buildRegistry()

local function resolve(input)
    if not input or input == "" then return "" end
    local n = norm(input)
    if SwordRegistry[n] then return SwordRegistry[n] end
    for nk, actual in pairs(SwordRegistry) do
        if nk:find(n, 1, true) then return actual end
    end
    return input
end

-- ============================================================
-- ANIMATION FIX
-- ============================================================
local AnimFix_AP = true
local AnimFix_TB = true
local AnimFix_Spam = true

local AnimCache = {}
local TrackCache = {}
local LastAnimTime = 0
local SuccessFlag = false

local function PlayParryAnim()
    local now = os.clock()
    if not SuccessFlag and (now - LastAnimTime) < 0.2 then return end
    LastAnimTime = now
    SuccessFlag = false

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    -- Block check
    for _, t in pairs(animator:GetPlayingAnimationTracks()) do
        local n = t.Name:lower()
        if (n:find("block") or n:find("shield") or n:find("defend")) and t.IsPlaying then
            return
        end
    end

    -- Resolve animation
    local swordName = char:GetAttribute("CurrentlyEquippedSword") or ""
    if getgenv().skinChanger and getgenv().swordAnimations ~= "" then
        swordName = getgenv().swordAnimations
    end

    local default = SwordAPI.Collection.Default:FindFirstChild("GrabParry") or SwordAPI.Collection.Default:FindFirstChild("Grab")
    if not swordName or swordName == "" then return end

    local resolved = resolve(swordName)
    local anim = AnimCache[resolved]
    if not anim then
        anim = default
        local animType
        pcall(function()
            local data = swordModule:GetSword(resolved)
            if data and type(data) == "table" then animType = data.AnimationType end
        end)
        if not animType then
            pcall(function()
                local data = ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(resolved)
                if data and type(data) == "table" then animType = data.AnimationType end
            end)
        end

        if animType and SwordAPI.Collection:FindFirstChild(animType) then
            local f = SwordAPI.Collection[animType]
            local a = f:FindFirstChild("GrabParry") or f:FindFirstChild("Grab")
            if a then anim = a end
        end

        if not animType and SwordAPI.Collection:FindFirstChild(resolved) then
            local f = SwordAPI.Collection[resolved]
            local a = f:FindFirstChild("GrabParry") or f:FindFirstChild("Grab")
            if a then anim = a end
        end

        AnimCache[resolved] = anim
    end
    if not anim then return end

    -- Stop existing parry tracks
    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        if track.Name == "GrabParry" or track.Name == "Grab" or track.Name == "SuccessParry" or track.Name == "Success" then
            track.TimePosition = 0
            pcall(function() track:Stop(0.1) end)
        end
    end

    -- Play
    local track = TrackCache[anim]
    if not track or not track.Parent then
        local ok, t = pcall(function() return animator:LoadAnimation(anim) end)
        if not ok or not t then return end
        track = t
        track.Looped = false
        TrackCache[anim] = track
    end

    pcall(function() track:Play(0, 1, 1) end)
end

local function StopGrabAnimations()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then return end
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            if track.Name == "GrabParry" or track.Name == "Grab" then
                pcall(function() track:Stop(0.1) end)
            end
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    TrackCache = {}
    AnimCache = {}
end)

pcall(function()
    ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function()
        SuccessFlag = true
        StopGrabAnimations()
    end)
end)

pcall(function()
    ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
        StopGrabAnimations()
    end)
end)

-- ============================================================
-- BALL SYSTEM
-- ============================================================
local function getBall()
    local b = Workspace:FindFirstChild('Balls')
    if not b then return nil end
    for _, ball in pairs(b:GetChildren()) do
        if ball:GetAttribute('realBall') then ball.CanCollide = false; return ball end
    end
end

local function getAllBalls()
    local t = {}
    local b = Workspace:FindFirstChild('Balls')
    if not b then return t end
    for _, ball in pairs(b:GetChildren()) do
        if ball:GetAttribute('realBall') then ball.CanCollide = false; table.insert(t, ball) end
    end
    return t
end

local _ping, _pingTime = 0, 0
local function getPing()
    local n = tick()
    if (n - _pingTime) > 0.1 then
        _pingTime = n
        pcall(function() _ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    end
    return _ping or 50
end

-- ============================================================
-- CURVE DETECTION
-- ============================================================
local CurveProps = {__last_warping=tick(), __lerp_radians=0, __curving=tick(), __previous_velocity={}, __tornado_time=tick()}
local lastTornadoCheck, tornadoActive = 0, false

local function checkTornadoActive()
    local now = os.clock()
    if now - lastTornadoCheck < 0.1 then return tornadoActive end
    lastTornadoCheck = now

    local Runtime = Workspace:FindFirstChild('Runtime')
    if Runtime and Runtime:FindFirstChild('Tornado') then
        if (tick() - (CurveProps.__tornado_time or 0)) < ((Runtime.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159) then
            tornadoActive = true
            return true
        end
    end
    tornadoActive = false
    return false
end

local function isCurved()
    local ball = getBall()
    if not ball then return false end
    local z = ball:FindFirstChild("zoomies")
    if not z then return false end
    local vel = z.VectorVelocity
    local spd = vel.Magnitude
    if spd < 1 then return false end
    local bdir = vel.Unit
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return false end
    local pos = char.PrimaryPart.Position
    local bpos = ball.Position
    local dir = (pos - bpos).Unit
    local dot = dir:Dot(bdir)
    local ping = getPing() / 1000
    local dist = (pos - bpos).Magnitude
    local rt = dist / spd - ping
    local st = math.min(spd / 100, 40)
    local bdt = 15 - math.min(dist / 1000, 15) + st

    table.insert(CurveProps.__previous_velocity, vel)
    if #CurveProps.__previous_velocity > 4 then table.remove(CurveProps.__previous_velocity, 1) end

    if ball:FindFirstChild('AeroDynamicSlashVFX') then CurveProps.__tornado_time = tick() end
    if checkTornadoActive() then return true end

    if spd > 160 and rt > (getPing() / 10) then
        if spd < 300 then bdt = math.max(bdt - 15, 15)
        elseif spd < 600 then bdt = math.max(bdt - 16, 16)
        elseif spd < 1000 then bdt = math.max(bdt - 17, 17)
        elseif spd < 1500 then bdt = math.max(bdt - 19, 19)
        else bdt = math.max(bdt - 20, 20) end
    end

    if dist < bdt then return false end

    if spd < 300 then
        if (tick() - (CurveProps.__curving or 0)) < (rt / 1.2) then return true end
    elseif spd < 450 then
        if (tick() - (CurveProps.__curving or 0)) < (rt / 1.21) then return true end
    elseif spd < 600 then
        if (tick() - (CurveProps.__curving or 0)) < (rt / 1.335) then return true end
    else
        if (tick() - (CurveProps.__curving or 0)) < (rt / 1.5) then return true end
    end

    local dthr = 0.5 - ping
    local cd = math.clamp(dot, -1, 1)
    local rad = math.deg(math.asin(cd))
    CurveProps.__lerp_radians = (CurveProps.__lerp_radians or 0) + (rad - (CurveProps.__lerp_radians or 0)) * 0.8

    if spd < 300 then
        if CurveProps.__lerp_radians < 0.02 then CurveProps.__last_warping = tick() end
        if (tick() - (CurveProps.__last_warping or 0)) < (rt / 1.19) then return true end
    else
        if CurveProps.__lerp_radians < 0.018 then CurveProps.__last_warping = tick() end
        if (tick() - (CurveProps.__last_warping or 0)) < (rt / 1.5) then return true end
    end

    if #CurveProps.__previous_velocity == 4 then
        local d1 = (bdir - CurveProps.__previous_velocity[1].Unit).Unit
        local d2 = (bdir - CurveProps.__previous_velocity[2].Unit).Unit
        if (dot - dir:Dot(d1)) < dthr or (dot - dir:Dot(d2)) < dthr then return true end
    end

    local hz = Vector3.new(pos.X - bpos.X, 0, pos.Z - bpos.Z)
    if hz.Magnitude > 0 then hz = hz.Unit end
    local away = -hz
    local hbd = Vector3.new(bdir.X, 0, bdir.Z)
    if hbd.Magnitude > 0 then
        hbd = hbd.Unit
        if math.deg(math.acos(math.clamp(away:Dot(hbd), -1, 1))) < 85 then return true end
    end

    return dot < (dthr - 0.25)
end

-- ============================================================
-- TARGET TRACKING
-- ============================================================
local Sender = {last = nil, ball = nil, conn = nil, prev = nil}
local function trackBall(ball)
    if ball == Sender.ball then return end
    if Sender.conn then pcall(function() Sender.conn:Disconnect() end) end
    Sender.ball = ball; Sender.last = nil; Sender.prev = nil
    if ball then
        Sender.prev = ball:GetAttribute("target")
        Sender.conn = ball:GetAttributeChangedSignal('target'):Connect(function()
            local nt = ball:GetAttribute("target")
            if nt == LocalPlayer.Name and Sender.prev and Sender.prev ~= LocalPlayer.Name then
                Sender.last = Sender.prev
            end
            Sender.prev = nt
        end)
    end
end

local function findPart(name)
    if not name or name == "" or name == LocalPlayer.Name then return nil end
    local af = Workspace:FindFirstChild("Alive")
    if af then local c = af:FindFirstChild(name); if c then return c.PrimaryPart or c:FindFirstChild("HumanoidRootPart") end end
    local p = Players:FindFirstChild(name)
    if p and p.Character then return p.Character.PrimaryPart end
end

-- Lock state
local LockEnabled = false
local LockTarget = "None"

-- Highlight
local HLEnabled = false
local HLColor = Color3.fromRGB(255, 60, 60)
local hlInst = nil
local function clearHL() if hlInst then pcall(function() hlInst:Destroy() end); hlInst = nil end end
local function refreshHL()
    clearHL()
    if not HLEnabled or LockTarget == "None" then return end
    local p = findPart(LockTarget)
    if p and p.Parent then
        local h = Instance.new("Highlight"); h.Name = "PL_HL"; h.FillColor = HLColor; h.OutlineColor = HLColor; h.FillTransparency = 0.6; h.OutlineTransparency = 0; h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.Adornee = p.Parent; h.Parent = p.Parent
        hlInst = h
    end
end
task.spawn(function() while task.wait(0.5) do if HLEnabled then if not hlInst or not hlInst.Parent then refreshHL() end else clearHL() end end end)

local function closestToCursor()
    local ml; pcall(function() ml = UserInputService:GetMouseLocation() end)
    local c = ml or Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bp = math.huge, nil
    local af = Workspace:FindFirstChild("Alive")
    if af then for _, v in pairs(af:GetChildren()) do if v ~= LocalPlayer.Character and v.PrimaryPart then local sp, on = Camera:WorldToScreenPoint(v.PrimaryPart.Position); if on then local d = (Vector2.new(sp.X, sp.Y) - c).Magnitude; if d < best then best = d; bp = v.Name end end end end end
    return bp
end

local pLookup = {}
local function playerList()
    local l = {"None"}; pLookup = {["None"] = "None"}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local d = p.DisplayName ~= p.Name and (p.Name .. " (" .. p.DisplayName .. ")") or p.Name
            table.insert(l, d); pLookup[d] = p.Name
        end
    end
    table.sort(l, function(a, b) return a:lower() < b:lower() end)
    return l
end

local function syncLockDD()
    if not Options or not Options.LockTarget then return end
    task.defer(function() pcall(function()
        Options.LockTarget:SetValues(playerList())
        local ds = "None"
        if LockTarget ~= "None" then for d, n in pairs(pLookup) do if n == LockTarget then ds = d; break end end end
        Options.LockTarget:SetValue(ds)
    end) end)
end

-- ============================================================
-- CURVE CFRAME
-- ============================================================
local CURVES = {"Camera", "Dot", "Nearest", "Random", "Accel", "Backwards", "Slow", "High", "Normal", "Speed", "Down", "Left", "Right"}
local CurveMode = "Camera"

local lastCFCalcFrame, cachedCF, frameCount = 0, nil, 0
RunService.Heartbeat:Connect(function() frameCount += 1 end)

local function getCurveCF()
    if cachedCF and frameCount == lastCFCalcFrame then return cachedCF end
    lastCFCalcFrame = frameCount

    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local rp = root and root.Position or Camera.CFrame.Position
    local tp, ball = nil, getBall()
    if ball then trackBall(ball) end

    if LockEnabled and LockTarget ~= "None" then tp = findPart(LockTarget) end
    if not tp and Sender.last then tp = findPart(Sender.last) end

    if not tp then
        local ml; pcall(function() ml = UserInputService:GetMouseLocation() end)
        local c = ml or Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local bs, bw = math.huge, math.huge
        local st2, wt = nil, nil
        local af = Workspace:FindFirstChild("Alive")
        local function chk(m)
            if m == LocalPlayer.Character or not m.PrimaryPart then return end
            local p = m.PrimaryPart.Position
            local sp, on = Camera:WorldToScreenPoint(p)
            if on then local d = (Vector2.new(sp.X, sp.Y) - c).Magnitude; if d < bs then bs = d; st2 = m.PrimaryPart end end
            local wd = (p - rp).Magnitude; if wd < bw then bw = wd; wt = m.PrimaryPart end
        end
        if af then for _, v in pairs(af:GetChildren()) do chk(v) end end
        for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer and p.Character then chk(p.Character) end end
        tp = st2 or wt
    end

    local tpos = tp and tp.Position or (rp + Camera.CFrame.LookVector * 100)
    if LockEnabled and tp then
        cachedCF = CFrame.new(rp, tpos)
        return cachedCF
    end

    local m = (Options and Options.CurveMode and Options.CurveMode.Value) or CurveMode
    local resCF = Camera.CFrame
    if m == "Camera" then resCF = Camera.CFrame
    elseif m == "Dot" then
        if ball then local z = ball:FindFirstChild("zoomies"); local v = z and z.VectorVelocity or Vector3.zero; local d = v.Magnitude > 1 and -v.Unit or (tpos - rp).Unit; resCF = CFrame.new(rp, rp + d * 100)
        else resCF = CFrame.new(rp, tpos) end
    elseif m == "Nearest" then resCF = CFrame.new(rp, tpos)
    elseif m == "Random" then resCF = CFrame.new(rp, tpos + Vector3.new(math.random(-4000,4000), math.random(-4000,4000), math.random(-4000,4000)))
    elseif m == "Accel" then resCF = CFrame.new(rp, tpos + Vector3.new(0, 5, 0))
    elseif m == "Backwards" then resCF = CFrame.new(Camera.CFrame.Position, rp + (rp - tpos).Unit * 10000 + Vector3.new(0, 1000, 0))
    elseif m == "Slow" then resCF = CFrame.new(rp, tpos + Vector3.new(0, -9e18, 0))
    elseif m == "High" then resCF = CFrame.new(rp, tpos + Vector3.new(0, 9e18, 0))
    elseif m == "Normal" then resCF = CFrame.new(rp, rp + (root and root.CFrame.LookVector or Camera.CFrame.LookVector))
    elseif m == "Speed" then resCF = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Camera.CFrame.UpVector * 5)
    elseif m == "Down" then resCF = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position - Vector3.new(0, 9e9, 0))
    elseif m == "Left" then resCF = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position - Camera.CFrame.RightVector * 9e9)
    elseif m == "Right" then resCF = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Camera.CFrame.RightVector * 9e9)
    end
    cachedCF = resCF
    return cachedCF
end

-- ============================================================
-- REMOTE FIRE (no rate limiter — RenderStepped accumulator handles pacing)
-- ============================================================
local parryLockouts = {}

local function fireRemote(ball)
    if not _remote or not _args or not _tokenFound then return end

    local rcf = getCurveCF()
    local ed = {}
    local af = Workspace:FindFirstChild("Alive")
    if af then for _, e in pairs(af:GetChildren()) do if e.PrimaryPart then local ok, sp = pcall(Camera.WorldToScreenPoint, Camera, e.PrimaryPart.Position); if ok then ed[e.Name] = sp end end end end

    local vp = Camera.ViewportSize
    local mp = Vector2.new(vp.X / 2, vp.Y / 2)
    if LockEnabled and LockTarget ~= "None" then
        local lp = findPart(LockTarget)
        if lp then local sp = Camera:WorldToScreenPoint(lp.Position); mp = Vector2.new(sp.X, sp.Y) end
    else
        local ok, loc = pcall(UserInputService.GetMouseLocation, UserInputService)
        if ok and loc then mp = loc end
    end

    _remote:FireServer(_args[1], _args[2], _tokenize(_args[2]), 0.5, rcf, ed, {math.floor(mp.X), math.floor(mp.Y)}, false)

    if ball then
        parryLockouts[ball] = os.clock()
        local changedConn
        changedConn = ball:GetAttributeChangedSignal("target"):Connect(function()
            if ball:GetAttribute("target") ~= LocalPlayer.Name then
                parryLockouts[ball] = nil
                changedConn:Disconnect()
            end
        end)
    end
end

local function doParry(ball, source)
    local animOn = (source == "AP" and AnimFix_AP) or (source == "TB" and AnimFix_TB)
    if animOn then PlayParryAnim() end
    fireRemote(ball)
end

-- ============================================================
-- AUTOPARRY
-- ============================================================
local AP_On, AP_Acc, AP_Div = false, 50, 1.1
local RandAcc = false
local AutoAbility = false

local function updDiv() AP_Div = 0.7 + (AP_Acc - 1) * (0.9 / 99) end
updDiv()

task.spawn(function()
    while task.wait(1) do
        if RandAcc then
            local p = getPing()
            if p >= 90 then AP_Acc = 4
            elseif p <= 50 then AP_Acc = math.random(70, 100) end
            updDiv()
            if Options and Options.Accuracy then pcall(function() Options.Accuracy:SetValue(AP_Acc) end) end
        end
    end
end)

-- ============================================================
-- DETECTION STATES (FIXED)
-- ============================================================
local InfOn, DSOn, THOn, SFOn = false, false, false, false
local InfDet, DSDet, THDet, SFDet = false, false, false, false

-- Track which detection is actually ON the local player
-- Each detection gets its own verified state

local function isLocalPlayerArg(a)
    if a == nil then return false end
    if typeof(a) == "Instance" then
        return a == LocalPlayer or a == LocalPlayer.Character
    end
    if type(a) == "string" then
        return a == LocalPlayer.Name or a == LocalPlayer.DisplayName
    end
    return false
end

-- Helper: scan all args for local player reference
local function anyArgIsLocal(...)
    for _, a in ipairs({...}) do
        if isLocalPlayerArg(a) then return true end
    end
    return false
end

-- Infinity Ball
pcall(function()
    local rem = ReplicatedStorage.Remotes:FindFirstChild("InfinityBall")
    if rem then
        rem.OnClientEvent:Connect(function(...)
            local args = {...}
            -- Try to determine if this event targets us
            local targetsUs = false
            for _, a in ipairs(args) do
                if isLocalPlayerArg(a) then targetsUs = true; break end
            end
            -- If the first bool arg is the state, use it; otherwise toggle
            local state = nil
            for _, a in ipairs(args) do
                if type(a) == "boolean" then state = a; break end
            end
            if state ~= nil then
                InfOn = state and targetsUs
            else
                InfOn = targetsUs
            end
        end)
    end
end)

-- Death Slash
pcall(function()
    local rem = ReplicatedStorage.Remotes:FindFirstChild("DeathBall")
    if rem then
        rem.OnClientEvent:Connect(function(...)
            local args = {...}
            local targetsUs = false
            for _, a in ipairs(args) do
                if isLocalPlayerArg(a) then targetsUs = true; break end
            end
            local state = nil
            for _, a in ipairs(args) do
                if type(a) == "boolean" then state = a; break end
            end
            if state ~= nil then
                DSOn = state and targetsUs
            else
                DSOn = targetsUs
            end
        end)
    end
end)

-- Time Hole / Slashes of Fury via net
pcall(function()
    local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net

    net["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...)
        if anyArgIsLocal(...) then THOn = true end
    end)
    net["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function(...)
        -- Only clear if we were the target, or if no args (global off)
        local args = {...}
        if #args == 0 or anyArgIsLocal(...) then THOn = false end
    end)

    net["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...)
        if anyArgIsLocal(...) then SFOn = true end
    end)
    net["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function(...)
        local args = {...}
        if #args == 0 or anyArgIsLocal(...) then SFOn = false end
    end)
end)

-- Reset detection state on respawn to avoid stuck flags
LocalPlayer.CharacterAdded:Connect(function()
    InfOn, DSOn, THOn, SFOn = false, false, false, false
end)

-- ============================================================
-- TRIGGERBOT
-- ============================================================
local TB_On, TB_Delay = false, 50

local _tbLastFire = 0
RunService.Heartbeat:Connect(function()
    if not TB_On then return end
    local now = os.clock()
    if now - _tbLastFire < 0.02 then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or root:FindFirstChild('SingularityCape') then return end

    local balls = getAllBalls()
    for _, ball in pairs(balls) do
        if not ball then continue end
        if parryLockouts[ball] and (os.clock() - (parryLockouts[ball] or 0)) < 0.35 then
            continue
        end

        local tgt = ball:GetAttribute('target')
        if tgt ~= LocalPlayer.Name then continue end

        if ball:FindFirstChild('AeroDynamicSlashVFX') then ball.AeroDynamicSlashVFX:Destroy() end
        if ball:FindFirstChild('ComboCounter') then continue end
        if InfDet and InfOn then continue end
        if DSDet and DSOn then continue end
        if THDet and THOn then continue end
        if SFDet and SFOn then continue end

        if (TB_Delay or 0) > 0 then
            local delayMs = TB_Delay
            task.delay(delayMs / 1000, function()
                if not ball or not ball.Parent or ball:GetAttribute('target') ~= LocalPlayer.Name then return end
                doParry(ball, "TB")
            end)
        else
            doParry(ball, "TB")
        end
        break
    end
end)

-- ============================================================
-- SPAM ENGINE
-- ============================================================
local Spam_On = false
local SpamRPS = 100
local SpamInt = 0.01
local SpamDetect = true

local function spamOk()
    if not SpamDetect then return true end
    if InfDet and InfOn then return false end
    if DSDet and DSOn then return false end
    if THDet and THOn then return false end
    if SFDet and SFOn then return false end
    return true
end

-- RenderStepped + time accumulator. At 1000 RPS the old task.wait
-- loop could only fire once per frame (~60Hz), so the CPS target
-- was unreachable. This schedules on the render tick and fires
-- floor(acc / interval) times, so the rate stays exact regardless
-- of framerate.
local timeAccumulator = 0

RunService.RenderStepped:Connect(function(dt)
    if not Spam_On then timeAccumulator = 0 return end

    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart or char.PrimaryPart:FindFirstChild('SingularityCape') then
        timeAccumulator = 0
        return
    end

    if not spamOk() then timeAccumulator = 0 return end

    local interval = (SpamInt and SpamInt > 0) and SpamInt or 0.01
    timeAccumulator += dt
    if timeAccumulator >= interval then
        local fires = math.floor(timeAccumulator / interval)
        timeAccumulator -= fires * interval
        if timeAccumulator > interval * 2 then timeAccumulator = 0 end
        if fires > 200 then fires = 200 end
        for _ = 1, fires do
            local ball = getBall()
            if ball then
                if AnimFix_Spam then PlayParryAnim() end
                fireRemote(ball)
            end
        end
    end
end)

-- ============================================================
-- SWORD CHANGER CORE INTERFACES
-- ============================================================
local SKIN_KEY = "Skin.LastEquippedSword"
local CFG_FILE = "qzxp/auto_config.json"

local function readCfg()
    local d = {}
    pcall(function() if isfile and isfile(CFG_FILE) then d = HttpService:JSONDecode(readfile(CFG_FILE)) end end)
    return type(d) == "table" and d or {}
end
local function writeCfg(d) pcall(function() if isfolder and makefolder and not isfolder("qzxp") then makefolder("qzxp") end; if writefile then writefile(CFG_FILE, HttpService:JSONEncode(d or {})) end end) end
local function loadSaved() local d = readCfg(); local s = d[SKIN_KEY]; return type(s) == "string" and s or "" end

getgenv().saveLastEquippedSword = function(n) if type(n) ~= "string" or n == "" then return end; local d = readCfg(); d[SKIN_KEY] = n; writeCfg(d) end

do
    local s = loadSaved()
    getgenv().skinChanger = getgenv().skinChanger or s ~= ""
    getgenv().swordModel = type(getgenv().swordModel) == "string" and getgenv().swordModel ~= "" and getgenv().swordModel or s
    getgenv().swordAnimations = type(getgenv().swordAnimations) == "string" and getgenv().swordAnimations ~= "" and getgenv().swordAnimations or s
    getgenv().swordFX = type(getgenv().swordFX) == "string" and getgenv().swordFX ~= "" and getgenv().swordFX or s
end

local realSword = ""
local function trackReal()
    local c = LocalPlayer.Character; if not c then return end
    realSword = c:GetAttribute("CurrentlyEquippedSword") or ""
    c:GetAttributeChangedSignal("CurrentlyEquippedSword"):Connect(function()
        if not getgenv().skinChanger then realSword = c:GetAttribute("CurrentlyEquippedSword") or "" end
    end)
end
LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); trackReal() end)
if LocalPlayer.Character then trackReal() end

local rs = ReplicatedStorage
local sc -- swords controller

task.spawn(function()
    while task.wait(0.5) and not sc do
        local ok, cn = pcall(getconnections, rs.Remotes.FireSwordInfo.OnClientEvent)
        if ok and cn then for _, v in ipairs(cn) do
            if v.Function and islclosure and islclosure(v.Function) then
                local ok2, up = pcall(getupvalues, v.Function)
                if ok2 and #up == 1 and type(up[1]) == "table" then sc = up[1]; break end
            end
        end end
    end
end)

local function slashName(n)
    local e = resolve(n)
    local ok, d = pcall(function() return swordModule:GetSword(e) end)
    return (ok and d and d.SlashName) or "SlashEffect"
end

local function refreshSlash()
    local fx = getgenv().swordFX ~= "" and getgenv().swordFX or getgenv().swordModel
    getgenv().slashName = fx ~= "" and slashName(fx) or "SlashEffect"
end
refreshSlash()

local function equip(name)
    if not LocalPlayer.Character then return end
    local exact = resolve(name)
    pcall(function()
        local f = rawget(swordModule, "EquipSwordTo")
        if type(f) == "function" then
            local ups = getupvalues(f)
            for i = 1, #ups do
                if type(ups[i]) == "boolean" then
                    setupvalue(f, i, false)
                    break
                end
            end
        end
    end)
    pcall(function() swordModule:EquipSwordTo(LocalPlayer.Character, exact) end)
    task.spawn(function()
        local att = 0
        while not sc and att < 20 do task.wait(0.5); att += 1 end
        if not sc then return end
        pcall(function() if sc.SetSword then sc:SetSword(exact) end end)
        pcall(function()
            if rs.Remotes:FindFirstChild("FireSwordInfo") then rs.Remotes.FireSwordInfo:FireServer(exact) end
            if sc.currentSword ~= nil then pcall(function() sc.currentSword = exact end) end
            if sc.SwordFX ~= nil then pcall(function() sc.SwordFX = exact end) end
        end)
    end)
end

getgenv().updateSword = function()
    refreshSlash()
    AnimCache = {}
    if getgenv().skinChanger and getgenv().swordModel ~= "" then
        getgenv().saveLastEquippedSword(getgenv().swordModel)
        equip(getgenv().swordModel)
    end
end

getgenv().revertSword = function()
    if realSword ~= "" then equip(realSword) end
    AnimCache = {}
end

-- VFX hooker (with duplication prevention via global tracking)
local hooked = getgenv().qzxp_VFXHooked
local vfxConns = getgenv().qzxp_VFXConns
local vfxDisabled = getgenv().qzxp_VFXDisabled

-- Rate limiters to prevent buzzing/static sounds from overlapping during clashes
local lastPlaySoundTime = 0

task.spawn(function()
    local remotes = {"ParrySuccessAll", "ParryAttempt", "ParrySuccess", "PlaySound", "PlayVisuals"}
    while task.wait(5) do
        for _, rn in ipairs(remotes) do
            local rem = rs.Remotes:FindFirstChild(rn)
            if rem and rem:IsA("RemoteEvent") then
                local ok, cn = pcall(getconnections, rem.OnClientEvent)
                if ok and type(cn) == "table" then
                    for _, v in ipairs(cn) do
                        local fn = v.Function
                        if fn and not hooked[fn] then
                            hooked[fn] = true; v:Disable()
                            table.insert(vfxDisabled, v)
                            local target = fn
                            local ours = function(...)
                                local args = {...}
                                
                                -- Prevent audio buzzing/static by rate limiting PlaySound
                                if rn == "PlaySound" then
                                    local now = os.clock()
                                    if (now - lastPlaySoundTime) < 0.15 then return end
                                    lastPlaySoundTime = now
                                end
                                
                                local isMe = false
                                for _, a in ipairs(args) do if tostring(a) == LocalPlayer.Name or (typeof(a) == "Instance" and (a == LocalPlayer.Character or a == LocalPlayer)) then isMe = true; break end end
                                if isMe and getgenv().skinChanger then
                                    local fx = getgenv().swordFX ~= "" and getgenv().swordFX or getgenv().swordModel
                                    refreshSlash()
                                    local sf, slF = false, false
                                    for i, a in ipairs(args) do
                                        if type(a) == "string" then
                                            if fx ~= "" and not slF and (a:match("Slash") or a == "Default" or a:match("Effect")) then args[i] = getgenv().slashName; slF = true
                                            elseif fx ~= "" and not sf then
                                                local isSw = false
                                                pcall(function() if rs.Shared.ReplicatedInstances.Swords:FindFirstChild(resolve(a)) or SwordRegistry[norm(a)] then isSw = true end end)
                                                if isSw or a == LocalPlayer:GetAttribute("CurrentlyEquippedSword") then args[i] = fx; sf = true end
                                            end
                                        end
                                    end
                                    if fx ~= "" and not slF and type(args[1]) == "string" then args[1] = getgenv().slashName end
                                    if fx ~= "" and not sf and type(args[3]) == "string" then args[3] = fx end
                                end
                                if setthreadidentity then pcall(setthreadidentity, 2) end
                                pcall(target, unpack(args))
                            end
                            hooked[ours] = true
                            local conn = rem.OnClientEvent:Connect(ours)
                            table.insert(vfxConns, conn)
                        end
                    end
                end
            end
        end
    end
end)

-- Enforcement loop
task.spawn(function()
    while task.wait(3) do
        if getgenv().skinChanger and getgenv().swordModel ~= "" then
            local char = LocalPlayer.Character
            if char then
                local exact = resolve(getgenv().swordModel)
                if exact and exact ~= "" then
                    if LocalPlayer:GetAttribute("CurrentlyEquippedSword") ~= exact then equip(exact) end
                    if not char:FindFirstChild(exact) then equip(exact) end
                    for _, v in pairs(char:GetChildren()) do
                        if v:IsA("Model") and v.Name ~= exact and SwordRegistry[norm(v.Name)] then
                            pcall(function() v:Destroy() end)
                        end
                    end
                end
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if getgenv().skinChanger then
        getgenv().skinChanger = false
        if getgenv().setSkinUI then getgenv().setSkinUI(false) end
        task.wait(2)
        getgenv().skinChanger = true
        if getgenv().setSkinUI then getgenv().setSkinUI(true) end
        task.wait(0.5)
        pcall(getgenv().updateSword)
    end
end)

-- ============================================================
-- HEADLESS / KORBLOX
-- ============================================================
local Headless, Korblox = false, false
local headBak, kBuilt, legBak, kMode = nil, {}, {}, nil

local function rigType(c) if not c then return "R6" end; local h = c:FindFirstChildOfClass("Humanoid"); if h and h.RigType == Enum.HumanoidRigType.R15 then return "R15" end; if c:FindFirstChild("RightUpperLeg") then return "R15" end; return "R6" end

local function doHeadless()
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChild("Head"); if not h then return end
    if headBak then local b = headBak; headBak = nil; if b.p and b.p.Parent then pcall(function() b.p.Transparency = b.t end) end; for _, e in ipairs(b.d) do if e.i and e.i.Parent then pcall(function() e.i.Transparency = e.t end) end end end
    headBak = {p = h, t = h.Transparency, d = {}}
    pcall(function() h.Transparency = 1; h.LocalTransparencyModifier = 1 end)
    for _, d in ipairs(h:GetChildren()) do if d:IsA("Decal") or d:IsA("Texture") then table.insert(headBak.d, {i=d, t=d.Transparency}); pcall(function() d.Transparency = 1 end) end end
    for _, a in ipairs(c:GetChildren()) do if a:IsA("Accessory") then local hdl = a:FindFirstChild("Handle"); if hdl and (hdl:FindFirstChild("FaceFrontAttachment") or hdl:FindFirstChild("FaceCenterAttachment")) then table.insert(headBak.d, {i=hdl, t=hdl.Transparency}); pcall(function() hdl.Transparency = 1 end); for _, d in ipairs(hdl:GetDescendants()) do if d:IsA("Decal") or d:IsA("Texture") then table.insert(headBak.d, {i=d, t=d.Transparency}); pcall(function() d.Transparency = 1 end) end end end end end
end

local function undoHeadless() if not headBak then return end; local b = headBak; headBak = nil; if b.p and b.p.Parent then pcall(function() b.p.Transparency = b.t; b.p.LocalTransparencyModifier = 0 end) end; for _, e in ipairs(b.d) do if e.i and e.i.Parent then pcall(function() e.i.Transparency = e.t end) end end end

local function clearK() for _, e in ipairs(kBuilt) do if typeof(e) == "Instance" then pcall(function() e:Destroy() end) end end; kBuilt = {} end
local function restoreLegs() for _, e in ipairs(legBak) do if e.p and e.p.Parent then pcall(function() e.p.Transparency = e.t; e.p.LocalTransparencyModifier = 0 end) end end; legBak = {} end
local function cleanK(c) if not c then return end; for _, d in ipairs(c:GetDescendants()) do if d.Name == "KorbloxRightLeg" or d.Name == "KorbloxWeld" or (d:IsA("BasePart") and d:GetAttribute("IceKorblox")) then pcall(function() d:Destroy() end) end end end

local function doKorblox()
    local c = LocalPlayer.Character; if not c then return end
    clearK(); restoreLegs(); cleanK(c)
    local rig = rigType(c)
    local parts, anchor, ty, w
    if rig == "R15" then
        local u, l, f = c:FindFirstChild("RightUpperLeg"), c:FindFirstChild("RightLowerLeg"), c:FindFirstChild("RightFoot")
        if not (u and l and f) then return end
        parts = {u, l, f}; anchor = u; ty = u.Size.Y + l.Size.Y + f.Size.Y; w = u.Size.X
    else
        local leg = c:FindFirstChild("Right Leg"); if not leg then return end
        parts = {leg}; anchor = leg; ty = leg.Size.Y; w = leg.Size.X
    end
    local fake = Instance.new("Part"); fake.Name = "KorbloxRightLeg"; fake.Size = Vector3.new(1, 2, 1); fake.CanCollide = false; fake.CanQuery = false; fake.CanTouch = false; fake.Massless = true
    local ys = ty / 2; local xzs = w * (1 + (ys - 1) * 0.5)
    local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.FileMesh; m.MeshId = "rbxassetid://101851696"; m.TextureId = "rbxassetid://101851254"; m.Scale = Vector3.new(xzs, ys, xzs); m.Parent = fake
    fake.Parent = c; pcall(function() fake:SetAttribute("IceKorblox", true) end)
    local weld = Instance.new("Weld"); weld.Name = "KorbloxWeld"; weld.Part0 = anchor; weld.Part1 = fake; weld.C0 = CFrame.new(0, anchor.Size.Y / 2 - ty / 2, 0); weld.Parent = fake
    for _, p in ipairs(parts) do table.insert(legBak, {p=p, t=p.Transparency}); pcall(function() p.Transparency = 1; p.LocalTransparencyModifier = 1 end) end
    table.insert(kBuilt, fake); kMode = "STANDIN"
end

local function undoKorblox() clearK(); restoreLegs(); cleanK(LocalPlayer.Character); kMode = nil end

LocalPlayer.CharacterAdded:Connect(function()
    headBak = nil; kBuilt, legBak = {}, {}; kMode = nil
    task.wait(1)
    if Korblox then doKorblox() end
    if Headless then doHeadless() end
end)

task.spawn(function()
    while task.wait(0.5) do
        local c = LocalPlayer.Character
        if c then
            if Headless and not headBak then doHeadless() end
            if Korblox and kMode ~= "STANDIN" then doKorblox() end
        end
    end
end)

-- ============================================================
-- ESP
-- ============================================================
local ESP_On = false
local espC = {}

local function updateESP()
    if not ESP_On then for _, d in pairs(espC) do if d then pcall(function() d:Destroy() end) end end; espC = {}; return end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
            if not espC[p] or espC[p].Adornee ~= p.Character.Head then
                if espC[p] then pcall(function() espC[p]:Destroy() end) end
                local bb = Instance.new("BillboardGui"); bb.Name = "qESP"; bb.Adornee = p.Character.Head; bb.Size = UDim2.new(0, 200, 0, 40); bb.StudsOffset = Vector3.new(0, 3, 2); bb.AlwaysOnTop = true; bb.Parent = p.Character.Head
                local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.new(1,1,1); lbl.TextStrokeTransparency = 0.5; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 14; lbl.Parent = bb
                espC[p] = bb
            end
            local lbl = espC[p] and espC[p]:FindFirstChildOfClass("TextLabel")
            if lbl then local ab = p:GetAttribute("EquippedAbility"); lbl.Text = ab and (p.DisplayName .. " [" .. ab .. "]") or p.DisplayName end
        end
    end
end

task.spawn(function() while task.wait(0.25) do if ESP_On then updateESP() end end end)

-- ============================================================
-- KEYBIND LIST & BALL STATS GUI
-- ============================================================
local function MakeDrag(handle, frame)
    local drag, di, ds, sp = false, nil, nil, nil
    handle.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = true; ds = i.Position; sp = frame.Position; i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drag = false end end) end end)
    handle.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then di = i end end)
    UserInputService.InputChanged:Connect(function(i) if i == di and drag and ds then local d = i.Position - ds; frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end end)
end

local KBShow = false
local kbGui = Instance.new("ScreenGui"); kbGui.Name = "q_KB"; kbGui.ResetOnSpawn = false; kbGui.IgnoreGuiInset = true; kbGui.DisplayOrder = 100; kbGui.Parent = CoreGui
local kbF = Instance.new("Frame"); kbF.Size = UDim2.new(0, 220, 0, 200); kbF.Position = UDim2.new(1, -235, 0.5, -100); kbF.BackgroundColor3 = Color3.fromRGB(25, 25, 25); kbF.BackgroundTransparency = 0.15; kbF.Visible = false; kbF.Parent = kbGui
Instance.new("UICorner", kbF).CornerRadius = UDim.new(0, 6)
local kbS = Instance.new("UIStroke"); kbS.Color = Color3.fromRGB(60, 60, 60); kbS.Thickness = 1; kbS.Parent = kbF
local kbT = Instance.new("TextLabel"); kbT.Size = UDim2.new(1, 0, 0, 28); kbT.BackgroundColor3 = Color3.fromRGB(30, 30, 30); kbT.BackgroundTransparency = 0.2; kbT.Font = Enum.Font.GothamBold; kbT.TextSize = 13; kbT.TextColor3 = Color3.fromRGB(200, 200, 200); kbT.Text = "  Keys"; kbT.TextXAlignment = Enum.TextXAlignment.Left; kbT.Parent = kbF
Instance.new("UICorner", kbT).CornerRadius = UDim.new(0, 6)
local kbC = Instance.new("Frame"); kbC.Size = UDim2.new(1, -10, 1, -34); kbC.Position = UDim2.new(0, 5, 0, 31); kbC.BackgroundTransparency = 1; kbC.Parent = kbF
Instance.new("UIListLayout", kbC).Padding = UDim.new(0, 4)
MakeDrag(kbT, kbF)

local function keyStr(o) if not o then return "?" end; local v = o.Value; return typeof(v) == "EnumItem" and v.Name or tostring(v) end

local kbItems = {
    {n = "AP", k = function() return keyStr(Options and Options.APKey) end, s = function() return AP_On end},
    {n = "Spam", k = function() return keyStr(Options and Options.SpamKey) end, s = function() return Spam_On end},
    {n = "TB", k = function() return keyStr(Options and Options.TBKey) end, s = function() return TB_On end},
    {n = "Lock", k = function() return keyStr(Options and Options.LockKey) end, s = function() return LockEnabled end},
}

local kbL = {}
for i, it in ipairs(kbItems) do
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1, 0, 0, 20); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextColor3 = Color3.fromRGB(200, 200, 200); l.LayoutOrder = i; l.Parent = kbC; kbL[i] = l
end

-- Ball Stats
local BS_On = false
local bsGui = Instance.new("ScreenGui"); bsGui.Name = "q_BS"; bsGui.ResetOnSpawn = false; bsGui.IgnoreGuiInset = true; bsGui.DisplayOrder = 100; bsGui.Parent = CoreGui
local bsF = Instance.new("Frame"); bsF.Size = UDim2.new(0, 220, 0, 120); bsF.Position = UDim2.new(1, -470, 0.5, -60); bsF.BackgroundColor3 = Color3.fromRGB(25, 25, 25); bsF.BackgroundTransparency = 0.15; bsF.Visible = false; bsF.Parent = bsGui
Instance.new("UICorner", bsF).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", bsF).Color = Color3.fromRGB(60, 60, 60)
local bsT = Instance.new("TextLabel"); bsT.Size = UDim2.new(1, 0, 0, 28); bsT.BackgroundColor3 = Color3.fromRGB(30, 30, 30); bsT.BackgroundTransparency = 0.2; bsT.Font = Enum.Font.GothamBold; bsT.TextSize = 13; bsT.TextColor3 = Color3.fromRGB(200, 200, 200); bsT.Text = "  Ball"; bsT.TextXAlignment = Enum.TextXAlignment.Left; bsT.Parent = bsF
Instance.new("UICorner", bsT).CornerRadius = UDim.new(0, 6)
local bsC = Instance.new("Frame"); bsC.Size = UDim2.new(1, -10, 1, -34); bsC.Position = UDim2.new(0, 5, 0, 31); bsC.BackgroundTransparency = 1; bsC.Parent = bsF
Instance.new("UIListLayout", bsC).Padding = UDim.new(0, 3)
MakeDrag(bsT, bsF)

local function bsLabel(o) local l = Instance.new("TextLabel"); l.Size = UDim2.new(1, 0, 0, 18); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextColor3 = Color3.fromRGB(200, 200, 200); l.LayoutOrder = o; l.Text = "N/A"; l.Parent = bsC; return l end
local bsSp, bsDi, bsTg, bsCu = bsLabel(1), bsLabel(2), bsLabel(3), bsLabel(4)

-- No Render
local NR_On = false
local NR_Conn = nil

-- UI Update Loop
RunService.RenderStepped:Connect(function()
    kbF.Visible = KBShow
    if KBShow then
        for i, it in ipairs(kbItems) do
            local s = it.s(); local k = it.k()
            local sc = s and "<font color='#4cd964'>ON</font>" or "<font color='#ff3b30'>OFF</font>"
            kbL[i].RichText = true; kbL[i].Text = string.format("[%s] %s %s", k, it.n, sc)
        end
    end

    bsF.Visible = BS_On
    if BS_On then
        local ball = getBall()
        if ball and ball.Parent then
            local z = ball:FindFirstChild('zoomies')
            local sp = z and math.round(z.VectorVelocity.Magnitude) or 0
            local tg = ball:GetAttribute('target') or "None"
            local c = LocalPlayer.Character; local r = c and c:FindFirstChild("HumanoidRootPart")
            local di = r and math.round((r.Position - ball.Position).Magnitude) or 0
            bsSp.Text = "Spd: " .. sp; bsDi.Text = "Dist: " .. di; bsTg.Text = "Tgt: " .. tg; bsCu.Text = "Curve: " .. (isCurved() and "Y" or "N")
        else
            bsSp.Text = "Spd: -"; bsDi.Text = "Dist: -"; bsTg.Text = "Tgt: -"; bsCu.Text = "Curve: -"
        end
    end
end)

-- ============================================================
-- UI LAYOUT
-- ============================================================

-- PARRY TAB
local s1 = Tabs.Main:AddSection("Autoparry")
s1:AddToggle("APToggle", { Title = "Enabled", Default = false, Callback = function(v) AP_On = v; notify({Title = "AP", Content = v and "On" or "Off", Duration = 2}) end })
s1:AddSlider("Accuracy", { Title = "Accuracy", Default = 50, Min = 1, Max = 100, Rounding = 1, Callback = function(v) AP_Acc = v; updDiv() end })
s1:AddToggle("RandAccToggle", { Title = "Randomize Acc", Default = false, Callback = function(v) RandAcc = v end })
s1:AddDropdown("CurveMode", { Title = "Curve", Values = CURVES, Default = "Camera", Multi = false, Callback = function(v) CurveMode = v end })
s1:AddToggle("AbilityToggle", { Title = "Auto Ability", Default = false, Callback = function(v) AutoAbility = v end })
s1:AddToggle("AnimFixAP", { Title = "Anim Fix", Default = true, Callback = function(v) AnimFix_AP = v end })
s1:AddKeybind("APKey", { Title = "Keybind", Default = "P", Callback = function() if Options.APToggle then Options.APToggle:SetValue(not AP_On) end end, ChangedCallback = function() end })

-- DETECTION TAB
local s2 = Tabs.Detection:AddSection("Detections")
s2:AddToggle("InfDet", { Title = "Infinity", Default = false, Callback = function(v) InfDet = v end })
s2:AddToggle("DSDet", { Title = "Death Slash", Default = false, Callback = function(v) DSDet = v end })
s2:AddToggle("THDet", { Title = "Time Hole", Default = false, Callback = function(v) THDet = v end })
s2:AddToggle("SFDet", { Title = "Slashes of Fury", Default = false, Callback = function(v) SFDet = v end })

-- SPAM TAB
local s3 = Tabs.Spam:AddSection("Spam")
s3:AddToggle("SpamToggle", { Title = "Enabled", Default = false, Callback = function(v) Spam_On = v; notify({Title = "Spam", Content = v and "On" or "Off", Duration = 2}) end })
s3:AddSlider("SpamRPS", { Title = "RPS", Default = 100, Min = 1, Max = 1000, Rounding = 0, Callback = function(v) SpamRPS = v; SpamInt = 1 / v end })
s3:AddToggle("SpamDet", { Title = "Respect Detections", Default = true, Callback = function(v) SpamDetect = v end })
s3:AddToggle("AnimFixSpam", { Title = "Anim Fix", Default = true, Callback = function(v) AnimFix_Spam = v end })
s3:AddKeybind("SpamKey", { Title = "Keybind", Default = "E", Callback = function() if Options.SpamToggle then Options.SpamToggle:SetValue(not Spam_On) else Spam_On = not Spam_On end end, ChangedCallback = function() end })

-- TRIGGER TAB
local s4 = Tabs.Trigger:AddSection("Triggerbot")
s4:AddToggle("TBToggle", { Title = "Enabled", Default = false, Callback = function(v) TB_On = v; notify({Title = "TB", Content = v and "On" or "Off", Duration = 2}) end })
s4:AddSlider("TBDelay", { Title = "Delay (ms)", Default = 50, Min = 0, Max = 500, Rounding = 0, Callback = function(v) TB_Delay = v end })
s4:AddToggle("AnimFixTB", { Title = "Anim Fix", Default = true, Callback = function(v) AnimFix_TB = v end })
s4:AddKeybind("TBKey", { Title = "Keybind", Default = "R", Callback = function() if Options.TBToggle then Options.TBToggle:SetValue(not TB_On) end end, ChangedCallback = function() end })

-- SKINS TAB
local s5 = Tabs.Skins:AddSection("Sword Changer")
local skinRef = s5:AddToggle("SkinToggle", { Title = "Enabled", Default = false, Callback = function(v)
    getgenv().skinChanger = v; getgenv().skinChangerEnabled = v
    if v and getgenv().swordModel ~= "" then pcall(getgenv().updateSword)
    elseif not v then pcall(getgenv().revertSword) end
end })
getgenv().setSkinUI = function(v) if skinRef and skinRef.Value ~= v then skinRef:SetValue(v); getgenv().skinChanger = v; getgenv().skinChangerEnabled = v end end

s5:AddInput("ManualSword", { Title = "Sword Name", Default = "", Placeholder = "type sword name...", Callback = function(v)
    local n = v and v:match("^%s*(.-)%s*$") or ""
    local e = resolve(n)
    if getgenv().skinChanger then pcall(getgenv().revertSword) end
    getgenv().swordModel = e; getgenv().swordAnimations = e; getgenv().swordFX = e
    if getgenv().skinChanger and e ~= "" then pcall(getgenv().updateSword) end
    pcall(getgenv().saveLastEquippedSword, e)
end })

-- LOCK TAB
local s6 = Tabs.Lock:AddSection("Parry Lock")
s6:AddToggle("LockToggle", { Title = "Enabled", Default = false, Callback = function(v) LockEnabled = v; notify({Title = "Lock", Content = v and "On" or "Off", Duration = 2}) end })
s6:AddDropdown("LockTarget", { Title = "Target", Values = playerList(), Default = "None", Multi = false, Callback = function(v) LockTarget = pLookup[v] or "None"; refreshHL() end })
s6:AddKeybind("CursorKey", { Title = "Cursor Lock", Default = "T", Callback = function() local t = closestToCursor(); if t then LockTarget = t; syncLockDD(); notify({Title = "Lock", Content = t, Duration = 2}) end end, ChangedCallback = function() end })
s6:AddKeybind("LockKey", { Title = "Toggle Key", Default = "L", Callback = function() if Options.LockToggle then Options.LockToggle:SetValue(not LockEnabled) end end, ChangedCallback = function() end })
s6:AddButton({ Title = "Refresh List", Callback = function() syncLockDD() end })

local s6h = Tabs.Lock:AddSection("Highlight")
s6h:AddToggle("HLToggle", { Title = "Enabled", Default = false, Callback = function(v) HLEnabled = v; refreshHL() end })
local hr, hg, hb = 255, 60, 60
local function updHL() HLColor = Color3.fromRGB(hr, hg, hb); refreshHL() end
s6h:AddSlider("HLR", { Title = "R", Default = 255, Min = 0, Max = 255, Rounding = 0, Callback = function(v) hr = v; updHL() end })
s6h:AddSlider("HLG", { Title = "G", Default = 60, Min = 0, Max = 255, Rounding = 0, Callback = function(v) hg = v; updHL() end })
s6h:AddSlider("HLB", { Title = "B", Default = 60, Min = 0, Max = 255, Rounding = 0, Callback = function(v) hb = v; updHL() end })

-- VISUALS TAB
local s7 = Tabs.Visuals:AddSection("ESP")
s7:AddToggle("ESPToggle", { Title = "Ability ESP", Default = false, Callback = function(v) ESP_On = v; updateESP() end })

local s7b = Tabs.Visuals:AddSection("Ball Stats")
s7b:AddToggle("BSToggle", { Title = "Ball Info", Default = false, Callback = function(v) BS_On = v end })

local s7c = Tabs.Visuals:AddSection("Character")
s7c:AddToggle("HeadlessT", { Title = "Headless", Default = false, Callback = function(v) Headless = v; if v then doHeadless() else undoHeadless() end end })
s7c:AddToggle("KorbloxT", { Title = "Korblox Leg", Default = false, Callback = function(v) Korblox = v; if v then doKorblox() else undoKorblox() end end })

local s7d = Tabs.Visuals:AddSection("Performance")
s7d:AddToggle("NRToggle", {
    Title = "No Slash VFX",
    Default = false,
    Callback = function(state)
        NR_On = state
        if state then
            NR_Conn = Workspace.Runtime.ChildAdded:Connect(function(child)
                if NR_On and child.Name:find("Slash") then
                    task.defer(function() pcall(function() child:Destroy() end) end)
                end
            end)
        else
            if NR_Conn then NR_Conn:Disconnect(); NR_Conn = nil end
        end
    end
})

-- SETTINGS TAB
local s8 = Tabs.Settings:AddSection("Engine")
s8:AddToggle("KBToggle", { Title = "Keybind List", Default = false, Callback = function(v) KBShow = v; kbF.Visible = v end })

Players.PlayerAdded:Connect(function() task.wait(1); syncLockDD() end)
Players.PlayerRemoving:Connect(function(p) if LockTarget == p.Name then LockTarget = "None"; refreshHL(); notify({Title = "Lock", Content = "Target left", Duration = 3}) end; task.wait(0.1); syncLockDD() end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("qzxp")
SaveManager:SetFolder("qzxp/configs")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)

suppressNotifies = true
pcall(function() SaveManager:LoadAutoloadConfig() end)
task.delay(1, function() suppressNotifies = false; Fluent:Notify({Title = "qzxp", Content = "Loaded", Duration = 4}) end)

getgenv().qzxp_Cleanup = function()
    pcall(function()
        -- Disconnect our VFX hook connections
        if getgenv().qzxp_VFXConns then
            for _, conn in ipairs(getgenv().qzxp_VFXConns) do
                pcall(function() conn:Disconnect() end)
            end
        end
        -- Re-enable the original remote connections we disabled
        if getgenv().qzxp_VFXDisabled then
            for _, conn in ipairs(getgenv().qzxp_VFXDisabled) do
                pcall(function() conn:Enable() end)
            end
        end
        getgenv().qzxp_VFXConns = nil
        getgenv().qzxp_VFXHooked = nil
        getgenv().qzxp_VFXDisabled = nil

        local cg = GetSafeUIParent()
        for _, o in ipairs(cg:GetChildren()) do if o:IsA("ScreenGui") and (o.Name:lower():find("qzxp") or o.Name:lower():find("q_")) then o:Destroy() end end
        getgenv().skinChanger = nil; getgenv().skinChangerEnabled = nil
        getgenv().swordModel = nil; getgenv().swordAnimations = nil; getgenv().swordFX = nil
        getgenv().slashName = nil; getgenv().updateSword = nil; getgenv().revertSword = nil
        getgenv().saveLastEquippedSword = nil; getgenv().setSkinUI = nil; getgenv().qzxp_Cleanup = nil
        if NR_Conn then NR_Conn:Disconnect() end
    end)
end

end)