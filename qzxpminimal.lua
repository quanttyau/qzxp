-- CREDITS: S14X FOR SPAM AND ANIM FIX
--          LEAKED EAGLE HUB FOR BASICALLY EVERYTHING
--          ANGELI FOR AUTOPARRY AND TRIGGERBOT

-- ============================================================
-- UI PARENT RESOLUTION (CoreGui-preferred, executor-safe)
-- ============================================================
local UI_PARENT, UI_PARENT_KIND

do
    local _env = (getgenv and getgenv()) or _G or {}

    local ok1, hui = pcall(function()
        return _env.gethui and _env.gethui()
    end)
    if ok1 and hui then
        UI_PARENT = hui
        UI_PARENT_KIND = "gethui"
    end

    if not UI_PARENT then
        local ok2, cg = pcall(function()
            return game:GetService("CoreGui")
        end)
        if ok2 and cg then
            local writable = pcall(function()
                local probe = Instance.new("Folder")
                probe.Name = "__ui_probe__"
                probe.Parent = cg
                probe:Destroy()
            end)
            if writable then
                UI_PARENT = cg
                UI_PARENT_KIND = "CoreGui"
            end
        end
    end

    if not UI_PARENT then
        UI_PARENT = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        UI_PARENT_KIND = "PlayerGui"
    end
end

local function GetSafeUIParent()
    return UI_PARENT
end

getgenv().qzxp_UIParent     = UI_PARENT
getgenv().qzxp_UIParentKind = UI_PARENT_KIND

task.spawn(function()

local function PatchCoreGui(str)
    if UI_PARENT_KIND == "CoreGui" then
        return str
    end
    local replacement
    if UI_PARENT_KIND == "gethui" then
        replacement = '(getgenv().qzxp_UIParent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))'
    else
        replacement = 'game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")'
    end
    return (str
        :gsub('game:GetService%("CoreGui"%)', replacement)
        :gsub("game:GetService%('CoreGui'%)", replacement)
        :gsub("game%.CoreGui", replacement)
    )
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

    for _, t in pairs(animator:GetPlayingAnimationTracks()) do
        local n = t.Name:lower()
        if (n:find("block") or n:find("shield") or n:find("defend")) and t.IsPlaying then
            return
        end
    end

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

    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        if track.Name == "GrabParry" or track.Name == "Grab" or track.Name == "SuccessParry" or track.Name == "Success" then
            track.TimePosition = 0
            pcall(function() track:Stop(0.1) end)
        end
    end

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
-- REMOTE FIRE
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
-- DETECTION STATES
-- ============================================================
local InfOn, DSOn, THOn, SFOn = false, false, false, false
local InfDet, DSDet, THDet, SFDet = false, false, false, false

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

local function anyArgIsLocal(...)
    for _, a in ipairs({...}) do
        if isLocalPlayerArg(a) then return true end
    end
    return false
end

pcall(function()
    local rem = ReplicatedStorage.Remotes:FindFirstChild("InfinityBall")
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
                InfOn = state and targetsUs
            else
                InfOn = targetsUs
            end
        end)
    endend)

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

pcall(function()
    local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net

    net["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...)
        if anyArgIsLocal(...) then THOn = true end
    end)
    net["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function(...)
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

end)