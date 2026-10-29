-- CREDITS: S14X (spam, anim, fflags), EAGLE HUB, ANGELI (triggerbot), OXY (autoparry)

local function GetSafeUIParent()
    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

-- VFX hooks — detach/restore on reload
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

local _threads = {}
local function spawnTracked(fn, ...)
    local t = task.spawn(fn, ...)
    table.insert(_threads, t)
    return t
end
getgenv().qzxp_Threads = _threads

local _renderHandlers = {}
local _renderConn = nil
local function addRenderHandler(fn, order)
    table.insert(_renderHandlers, {fn = fn, order = order or 0})
    table.sort(_renderHandlers, function(a, b) return a.order < b.order end)
    if _renderHandlers[#_renderHandlers] ~= nil and not _renderConn then
        _renderConn = game:GetService("RunService").RenderStepped:Connect(function(dt)
            for i = 1, #_renderHandlers do
                local h = _renderHandlers[i]
                local ok, err = pcall(h.fn, dt)
                if not ok then warn("[qzxp] render handler: " .. tostring(err)) end
            end
        end)
    end
end
local _postSimHandlers = {}
local _postSimConn = nil
local function addPostSimHandler(fn, order)
    table.insert(_postSimHandlers, {fn = fn, order = order or 0})
    table.sort(_postSimHandlers, function(a, b) return a.order < b.order end)
    if _postSimHandlers[#_postSimHandlers] ~= nil and not _postSimConn then
        _postSimConn = game:GetService("RunService").PostSimulation:Connect(function(dt)
            for i = 1, #_postSimHandlers do
                local h = _postSimHandlers[i]
                local ok, err = pcall(h.fn, dt)
                if not ok then warn("[qzxp] postsim handler: " .. tostring(err)) end
            end
        end)
    end
end
local _heartbeatHandlers = {}
local _heartbeatConn = nil
local function addHeartbeatHandler(fn, order)
    table.insert(_heartbeatHandlers, {fn = fn, order = order or 0})
    table.sort(_heartbeatHandlers, function(a, b) return a.order < b.order end)
    if _heartbeatHandlers[#_heartbeatHandlers] ~= nil and not _heartbeatConn then
        _heartbeatConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
            for i = 1, #_heartbeatHandlers do
                local h = _heartbeatHandlers[i]
                local ok, err = pcall(h.fn, dt)
                if not ok then warn("[qzxp] heartbeat handler: " .. tostring(err)) end
            end
        end)
    end
end
getgenv().qzxp_StopRender = function()
    if _renderConn then pcall(function() _renderConn:Disconnect() end); _renderConn = nil end
    _renderHandlers = {}
    if _postSimConn then pcall(function() _postSimConn:Disconnect() end); _postSimConn = nil end
    _postSimHandlers = {}
    if _heartbeatConn then pcall(function() _heartbeatConn:Disconnect() end); _heartbeatConn = nil end
    _heartbeatHandlers = {}
end

task.spawn(function()

-- ============================================================
-- UI LIBRARY
-- ============================================================
local _UIS = game:GetService("UserInputService")
local _HS  = game:GetService("HttpService")
local _TS  = game:GetService("TweenService")

local UITheme = {
    Bg = Color3.fromRGB(15, 15, 15),
    Sidebar = Color3.fromRGB(11, 11, 11),
    Panel = Color3.fromRGB(15, 15, 15),
    Row = Color3.fromRGB(15, 15, 15),
    Border = Color3.fromRGB(55, 55, 55),
    BorderDim = Color3.fromRGB(35, 35, 35),
    Text = Color3.fromRGB(242, 242, 242),
    TextDim = Color3.fromRGB(182, 182, 182),
    TextMute = Color3.fromRGB(126, 126, 126),
    White = Color3.fromRGB(255, 255, 255),
    Black = Color3.fromRGB(0, 0, 0),
    Off = Color3.fromRGB(52, 52, 52),
    Hover = Color3.fromRGB(28, 28, 28),
    GradTop = Color3.fromRGB(15, 15, 15),
    GradBot = Color3.fromRGB(15, 15, 15),
    RowTop = Color3.fromRGB(15, 15, 15),
    RowBot = Color3.fromRGB(15, 15, 15),
    BtnTop = Color3.fromRGB(15, 15, 15),
    BtnBot = Color3.fromRGB(15, 15, 15),
    KnobTop = Color3.fromRGB(255, 255, 255),
    KnobBot = Color3.fromRGB(255, 255, 255),
    OffTop = Color3.fromRGB(52, 52, 52),
    OffBot = Color3.fromRGB(52, 52, 52),
}
local FONT  = Enum.Font.GothamMedium
local FONTB = Enum.Font.GothamBold
local FONTM = Enum.Font.RobotoMono
local TI_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TI_MED  = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local function tween(o, ti, p) _TS:Create(o, ti, p):Play() end

local function mk(c, p, par)
    local o = Instance.new(c)
    if p then for k, v in next, p do o[k] = v end end
    if par then o.Parent = par end
    return o
end
local function addStroke(par, color, thick, trans)
    return mk("UIStroke", {Color = color or UITheme.Border, Thickness = thick or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = trans or 0}, par)
end
local function addCorner(par, r) return mk("UICorner", {CornerRadius = UDim.new(0, r or 0)}, par) end
local function addGrad(par, top, bottom, rot)
end
local function toKey(v)
    if typeof(v) == "EnumItem" then return v end
    if type(v) == "string" then
        local ok, kc = pcall(function() return Enum.KeyCode[v] end)
        if ok then return kc end
    end
    return Enum.KeyCode.Unknown
end
local KEY_SYMBOLS = {
    LeftBracket = "[", RightBracket = "]",
    Semicolon = ";", Quote = "'",
    Comma = ",", Period = ".",
    Slash = "/", BackSlash = "\\",
    Minus = "-", Equals = "=",
    Backquote = "`",
    KeypadDivide = "/", KeypadMultiply = "*",
    KeypadMinus = "-", KeypadPlus = "+",
    KeypadPeriod = ".", KeypadEquals = "=",
}
local function keyDisplay(kc)
    if not kc or kc == Enum.KeyCode.Unknown then return "?" end
    local n = kc.Name
    return KEY_SYMBOLS[n] or n
end

local Fluent = {Options = {}, Window = nil}
local Options = Fluent.Options

local _nGui, _nHolder, _nCount = nil, nil, 0
local function ensureNotify()
    if _nGui and _nGui.Parent then return end
    _nGui = mk("ScreenGui", {Name = "qzxp_Notify", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 300}, GetSafeUIParent())
    _nHolder = mk("Frame", {Size = UDim2.new(0, 300, 1, -24), Position = UDim2.new(1, -312, 0, 12), BackgroundTransparency = 1}, _nGui)
    mk("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top}, _nHolder)
end
function Fluent:Notify(opts)
    if not opts then return end
    ensureNotify()
    _nCount += 1
    local title = tostring(opts.Title or "Notice")
    local content = tostring(opts.Content or "")
    local dur = tonumber(opts.Duration) or 4
    local card = mk("Frame", {Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = UITheme.Panel,
        BorderSizePixel = 0, LayoutOrder = _nCount, ClipsDescendants = true}, _nHolder)
    addCorner(card, 10); addStroke(card, UITheme.Border, 1, 0.45); addGrad(card, UITheme.RowTop, UITheme.RowBot, 90)
    mk("Frame", {Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = UITheme.White, BorderSizePixel = 0}, card)
    mk("TextLabel", {Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 16, 0, 8),
        BackgroundTransparency = 1, Font = FONTB, TextSize = 13, TextColor3 = UITheme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = title}, card)
    mk("TextLabel", {Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 16, 0, 28),
        BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = UITheme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = content}, card)
    task.delay(dur, function() if card and card.Parent then pcall(function() card:Destroy() end) end end)
end

local Tab, Section, Window, _openDropdown
local function closeDropdown()
    if _openDropdown then pcall(function() _openDropdown:Destroy() end); _openDropdown = nil end
end

Section = {}; Section.__index = Section
function Section:_row(h)
    self._rowN += 1
    local row = mk("Frame", {Size = UDim2.new(1, 0, 0, h or 36), BackgroundColor3 = UITheme.Row,
        BorderSizePixel = 0, LayoutOrder = self._rowN}, self._wrap)
    mk("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UITheme.Border, BackgroundTransparency = 0.4, BorderSizePixel = 0}, row)
    return row
end
function Section:_label(row, text)
    return mk("TextLabel", {Size = UDim2.new(0.5, -16, 1, 0), Position = UDim2.new(0, 16, 0, 0),
        BackgroundTransparency = 1, Font = FONT, TextSize = 13, TextColor3 = UITheme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(text or "")}, row)
end
function Section:AddToggle(id, opts)
    local row = self:_row(38); self:_label(row, opts.Title or id)
    local switch = mk("Frame", {Size = UDim2.new(0, 40, 0, 22), Position = UDim2.new(1, -56, 0.5, -11),
        BackgroundColor3 = UITheme.Off, BorderSizePixel = 0, ClipsDescendants = true}, row)
    addCorner(switch, 11); addStroke(switch, UITheme.Border, 1, 0.35)
    local knob = mk("Frame", {Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(0, 2, 0.5, -9),
        BackgroundColor3 = UITheme.White, BorderSizePixel = 0}, switch)
    addCorner(knob, 9)
    addStroke(knob, UITheme.Border, 1, 0.45)
    local click = mk("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = ""}, switch)
    local obj = {Value = not not opts.Default}
    local function apply(on, animate)
        local knobPos = on and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        switch.BackgroundColor3 = on and UITheme.White or UITheme.Off
        if animate then tween(knob, TI_MED, {Position = knobPos}) else knob.Position = knobPos end
    end
    local function set(v, animate)
        v = not not v; if obj.Value == v then return end
        obj.Value = v; apply(v, animate ~= false)
        if opts.Callback then pcall(opts.Callback, v) end
    end
    obj.SetValue = function(_, v) set(v, false) end
    click.MouseButton1Click:Connect(function() set(not obj.Value, true) end)
    apply(obj.Value, false); Options[id] = obj; return obj
end
function Section:AddSlider(id, opts)
    local row = self:_row(50)
    mk("TextLabel", {Size = UDim2.new(0.6, -16, 0, 16), Position = UDim2.new(0, 16, 0, 9),
        BackgroundTransparency = 1, Font = FONT, TextSize = 13, TextColor3 = UITheme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(opts.Title or id)}, row)
    local valLbl = mk("TextLabel", {Size = UDim2.new(0.4, -16, 0, 16), Position = UDim2.new(0.6, 0, 0, 9),
        BackgroundTransparency = 1, Font = FONTM, TextSize = 12, TextColor3 = UITheme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Right, Text = "0"}, row)
    local bar = mk("Frame", {Size = UDim2.new(1, -32, 0, 6), Position = UDim2.new(0, 16, 0, 34),
        BackgroundColor3 = UITheme.Off, BorderSizePixel = 0, ClipsDescendants = false}, row)
    addCorner(bar, 3); addStroke(bar, UITheme.Border, 1, 0.55); addGrad(bar, UITheme.OffTop, UITheme.OffBot, 90)
    local fill = mk("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = UITheme.White, BorderSizePixel = 0}, bar)
    addCorner(fill, 3); addGrad(fill, UITheme.White, Color3.fromRGB(200, 200, 210), 0)
    local knob = mk("Frame", {Size = UDim2.new(0, 16, 0, 16), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = UITheme.White, BorderSizePixel = 0, ZIndex = 2}, bar)
    addCorner(knob, 8); addGrad(knob, UITheme.KnobTop, UITheme.KnobBot, 90); addStroke(knob, UITheme.Border, 1, 0.3)
    local minV, maxV = opts.Min or 0, opts.Max or 100
    local round = opts.Rounding or 0
    local obj = {Value = opts.Default or minV}
    local function rv(v)
        if round <= 0 then return math.floor(v + 0.5) end
        local m = 10 ^ round; return math.floor(v * m + 0.5) / m
    end
    local function update()
        local a = math.clamp((obj.Value - minV) / (maxV - minV), 0, 1)
        fill.Size = UDim2.new(a, 0, 1, 0); knob.Position = UDim2.new(a, 0, 0.5, 0); valLbl.Text = tostring(obj.Value)
    end
    local function set(v)
        v = rv(math.clamp(v, minV, maxV))
        if obj.Value == v then return end
        obj.Value = v; update(); if opts.Callback then pcall(opts.Callback, v) end
    end
    obj.SetValue = function(_, v) set(v) end
    local dragging = false
    local function posToVal(x)
        local rel = (x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
        set(minV + math.clamp(rel, 0, 1) * (maxV - minV))
    end
    local dragArea = mk("TextButton", {Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0.5, -11),
        BackgroundTransparency = 1, Text = ""}, bar)
    dragArea.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; posToVal(i.Position.X)
        end
    end)
    _UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            posToVal(i.Position.X)
        end
    end)
    _UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    update(); Options[id] = obj; return obj
end
function Section:AddDropdown(id, opts)
    local row = self:_row(40); self:_label(row, opts.Title or id)
    local btn = mk("TextButton", {Size = UDim2.new(0.5, -16, 0, 28), Position = UDim2.new(0.5, 0, 0.5, -14),
        BackgroundColor3 = UITheme.Panel, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ClipsDescendants = true}, row)
    addCorner(btn, 8); addStroke(btn, UITheme.Border, 1, 0.3); addGrad(btn, UITheme.BtnTop, UITheme.BtnBot, 90)
    local lbl = mk("TextLabel", {Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = UITheme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = ""}, btn)
    mk("TextLabel", {Size = UDim2.new(0, 16, 1, 0), Position = UDim2.new(1, -20, 0, 0),
        BackgroundTransparency = 1, Font = FONT, TextSize = 10, TextColor3 = UITheme.TextDim, Text = "v"}, btn)
    btn.MouseEnter:Connect(function() tween(btn, TI_FAST, {BackgroundColor3 = UITheme.Hover}) end)
    btn.MouseLeave:Connect(function() tween(btn, TI_FAST, {BackgroundColor3 = UITheme.Panel}) end)
    local values = opts.Values or {}
    local multi = opts.Multi or false
    local sel = {}
    local obj = {Value = opts.Default}
    if multi and type(opts.Default) == "table" then for _, v in ipairs(opts.Default) do sel[v] = true end end
    local function display()
        if multi then
            local parts = {}
            for v, _ in pairs(sel) do parts[#parts+1] = tostring(v) end
            return #parts > 0 and table.concat(parts, ", ") or "(none)"
        end
        return tostring(obj.Value or "")
    end
    local function refresh() lbl.Text = display() end
    btn.MouseButton1Click:Connect(function()
        if _openDropdown then closeDropdown() end
        local abs = btn.AbsolutePosition; local sz = btn.AbsoluteSize
        local h = math.min(#values * 26 + 6, 190)
        local panel = mk("ScrollingFrame", {Position = UDim2.fromOffset(abs.X, abs.Y + sz.Y + 4),
            Size = UDim2.fromOffset(sz.X, h), BackgroundColor3 = UITheme.Panel, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = UITheme.Off,
            CanvasSize = UDim2.new(0, 0, 0, #values * 26), ZIndex = 250, ClipsDescendants = true}, self._tab._window._gui)
        addCorner(panel, 9); addStroke(panel, UITheme.Border, 1, 0.3); addGrad(panel, UITheme.BtnTop, UITheme.BtnBot, 90)
        mk("UIListLayout", {Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, panel)
        mk("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3)}, panel)
        _openDropdown = panel
        for i, v in ipairs(values) do
            local item = mk("TextButton", {Size = UDim2.new(1, -6, 0, 24), BackgroundColor3 = UITheme.Panel,
                BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
                LayoutOrder = i, ZIndex = 251}, panel)
            addCorner(item, 6)
            mk("TextLabel", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = UITheme.Text,
                TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(v), ZIndex = 252}, item)
            item.MouseEnter:Connect(function() item.BackgroundTransparency = 0; item.BackgroundColor3 = UITheme.Hover end)
            item.MouseLeave:Connect(function() item.BackgroundTransparency = 1 end)
            item.MouseButton1Click:Connect(function()
                if multi then
                    if sel[v] then sel[v] = nil else sel[v] = true end
                    refresh(); if opts.Callback then pcall(opts.Callback, v) end
                else
                    obj.Value = v; refresh(); closeDropdown(); if opts.Callback then pcall(opts.Callback, v) end
                end
            end)
        end
    end)
    refresh()
    obj.SetValue = function(_, v) obj.Value = v; refresh(); if opts.Callback then pcall(opts.Callback, v) end end
    obj.SetValues = function(_, v) values = v or {}; if _openDropdown then closeDropdown() end end
    Options[id] = obj; return obj
end
function Section:AddKeybind(id, opts)
    local row = self:_row(38); self:_label(row, opts.Title or id)
    local btn = mk("TextButton", {Size = UDim2.new(0, 104, 0, 28), Position = UDim2.new(1, -120, 0.5, -14),
        BackgroundColor3 = UITheme.Panel, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ClipsDescendants = true}, row)
    addCorner(btn, 8); addStroke(btn, UITheme.Border, 1, 0.3); addGrad(btn, UITheme.BtnTop, UITheme.BtnBot, 90)
    local lbl = mk("TextLabel", {Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 4, 0, 0),
        BackgroundTransparency = 1, Font = FONTM, TextSize = 12, TextColor3 = UITheme.Text,
        TextXAlignment = Enum.TextXAlignment.Center, Text = ""}, btn)
    local listening = false
    local suppressUntil = 0
    local obj = {Value = toKey(opts.Default), isHeld = false}
    local function refresh() lbl.Text = listening and "press key..." or keyDisplay(obj.Value) end
    btn.MouseButton1Click:Connect(function()
        if obj.isHeld then
            obj.isHeld = false
            if opts.ReleasedCallback then pcall(opts.ReleasedCallback, obj.Value) end
        end
        listening = true; suppressUntil = os.clock() + 0.25; refresh()
    end)
    _UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if listening then
            obj.Value = input.KeyCode; listening = false; suppressUntil = os.clock() + 0.25; refresh()
            if opts.ChangedCallback then pcall(opts.ChangedCallback, obj.Value) end
        else
            if os.clock() < suppressUntil then return end
            if input.KeyCode == obj.Value then
                obj.isHeld = true
                if opts.Callback then pcall(opts.Callback, obj.Value) end
            end
        end
    end)
    _UIS.InputEnded:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode == obj.Value and obj.isHeld then
            obj.isHeld = false
            if opts.ReleasedCallback then pcall(opts.ReleasedCallback, obj.Value) end
        end
    end)
    refresh()
    obj.SetValue = function(_, v)
        obj.Value = toKey(v); suppressUntil = os.clock() + 0.25; refresh()
        if opts.ChangedCallback then pcall(opts.ChangedCallback, obj.Value) end
    end
    Options[id] = obj; return obj
end
function Section:AddInput(id, opts)
    local row = self:_row(40); self:_label(row, opts.Title or id)
    local bg = mk("Frame", {Size = UDim2.new(0.5, -16, 0, 28), Position = UDim2.new(0.5, 0, 0.5, -14),
        BackgroundColor3 = UITheme.Panel, BorderSizePixel = 0, ClipsDescendants = true}, row)
    addCorner(bg, 8); addStroke(bg, UITheme.Border, 1, 0.3); addGrad(bg, UITheme.BtnTop, UITheme.BtnBot, 90)
    local box = mk("TextBox", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = FONT, TextSize = 12, TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
        PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = UITheme.TextMute,
        Text = tostring(opts.Default or "")}, bg)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, box)
    local obj = {Value = tostring(opts.Default or "")}
    box.FocusLost:Connect(function(enter)
        obj.Value = box.Text
        if opts.Callback then pcall(opts.Callback, box.Text, enter) end
    end)
    obj.SetValue = function(_, v)
        box.Text = tostring(v or ""); obj.Value = box.Text
        if opts.Callback then pcall(opts.Callback, obj.Value) end
    end
    Options[id] = obj; return obj
end
function Section:AddButton(opts)
    local row = self:_row(44)
    local bg = mk("Frame", {Size = UDim2.new(1, -22, 0, 30), Position = UDim2.new(0, 11, 0.5, -15),
        BackgroundColor3 = UITheme.Panel, BorderSizePixel = 0, ClipsDescendants = true}, row)
    addCorner(bg, 8); addStroke(bg, UITheme.Border, 1, 0.3); addGrad(bg, UITheme.BtnTop, UITheme.BtnBot, 90)
    mk("Frame", {Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = UITheme.White,
        BackgroundTransparency = 0.88, BorderSizePixel = 0}, bg)
    local btn = mk("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = FONT, TextSize = 12, TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = opts.Title or "Button", AutoButtonColor = false}, bg)
    btn.MouseEnter:Connect(function() tween(bg, TI_FAST, {BackgroundColor3 = UITheme.Hover}) end)
    btn.MouseLeave:Connect(function() tween(bg, TI_FAST, {BackgroundColor3 = UITheme.Panel}) end)
    btn.MouseButton1Click:Connect(function() if opts.Callback then pcall(opts.Callback) end end)
    return btn
end

Tab = {}; Tab.__index = Tab
function Tab:AddSection(title)
    local index = #self._sections + 1
    local wrap = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = UITheme.Panel, BorderSizePixel = 0,
        LayoutOrder = index, AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true}, self._page)
    addStroke(wrap, UITheme.Border, 1, 0.35); addCorner(wrap, 11); addGrad(wrap, UITheme.RowTop, UITheme.RowBot, 90)
    mk("UIListLayout", {Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, wrap)
    mk("TextLabel", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Font = FONTB, TextSize = 11,
        TextColor3 = UITheme.TextMute, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "  " .. string.upper(title or "SECTION"), LayoutOrder = 0}, wrap)
    local sec = setmetatable({_wrap = wrap, _tab = self, _rowN = 0}, Section)
    self._sections[index] = sec
    return sec
end

Window = {}; Window.__index = Window
function Window:SelectTab(i)
    if i < 1 or i > #self._tabs then return end
    if self._active == i then return end
    if self._active then
        local o = self._tabs[self._active]
        if o then
            o._page.Visible = false; o._btn.BackgroundTransparency = 1
            o._label.TextColor3 = UITheme.TextDim; o._indicator.Visible = false
        end
    end
    self._active = i
    local t = self._tabs[i]
    if t then
        t._page.Visible = true; t._btn.BackgroundTransparency = 0
        t._label.TextColor3 = UITheme.Text; t._indicator.Visible = true
    end
end
function Window:AddTab(opts)
    local title = opts.Title or "Tab"
    local index = #self._tabs + 1
    local btn = mk("TextButton", {Size = UDim2.new(0, 126, 0, 34), Position = UDim2.new(0, 7, 0, 8 + (index - 1) * 38),
        BackgroundColor3 = UITheme.Hover, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, ClipsDescendants = true}, self._sidebar)
    addCorner(btn, 8); addGrad(btn, UITheme.RowTop, UITheme.RowBot, 90)
    local lbl = mk("TextLabel", {Size = UDim2.new(1, -22, 1, 0), Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1, Font = FONT, TextSize = 13, TextColor3 = UITheme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left, Text = title}, btn)
    local ind = mk("Frame", {Size = UDim2.new(0, 2, 0, 16), Position = UDim2.new(0, 0, 0.5, -8),
        BackgroundColor3 = UITheme.White, BorderSizePixel = 0, Visible = false}, btn)
    addCorner(ind, 1)
    local page = mk("ScrollingFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = UITheme.Off,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false}, self._content)
    mk("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, page)
    mk("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, page)
    local tab = setmetatable({_btn = btn, _label = lbl, _indicator = ind, _page = page,
        _window = self, _sections = {}, Title = title}, Tab)
    self._tabs[index] = tab
    btn.MouseEnter:Connect(function() if self._active ~= index then tween(btn, TI_FAST, {BackgroundTransparency = 0.25}) end end)
    btn.MouseLeave:Connect(function() if self._active ~= index then tween(btn, TI_FAST, {BackgroundTransparency = 1}) end end)
    btn.MouseButton1Click:Connect(function() self:SelectTab(index); closeDropdown() end)
    return tab
end
function Fluent:CreateWindow(opts)
    opts = opts or {}
    local size = opts.Size or UDim2.fromOffset(750, 450)
    local wOff = size.X.Offset or 375
    local hOff = size.Y.Offset or 225
    local gui = mk("ScreenGui", {Name = "qzxp_UI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50}, GetSafeUIParent())
    local main = mk("Frame", {Name = "Main", Size = size, Position = UDim2.new(0.5, -wOff/2, 0.5, -hOff/2),
        BackgroundColor3 = UITheme.Bg, BorderSizePixel = 0, Active = true, ClipsDescendants = true}, gui)
    addCorner(main, 14); addStroke(main, UITheme.Border, 1, 0.3); addGrad(main, UITheme.GradTop, UITheme.GradBot, 90)
    local titleBar = mk("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = UITheme.Sidebar, BorderSizePixel = 0}, main)
    addCorner(titleBar, 14)
    mk("Frame", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = UITheme.Sidebar, BorderSizePixel = 0}, titleBar)
    addGrad(titleBar, UITheme.RowTop, UITheme.Bg, 90)
    local dot = mk("Frame", {Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(0, 16, 0.5, -3),
        BackgroundColor3 = UITheme.White, BorderSizePixel = 0}, titleBar)
    addCorner(dot, 3)
    mk("TextLabel", {Size = UDim2.new(0, 300, 1, 0), Position = UDim2.new(0, 30, 0, 0), BackgroundTransparency = 1,
        Font = FONTB, TextSize = 13, TextColor3 = UITheme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = opts.Title or "Window"}, titleBar)
    local closeBtn = mk("TextButton", {Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -36, 0.5, -14),
        BackgroundTransparency = 1, Font = FONTB, TextSize = 14, TextColor3 = UITheme.TextDim, Text = "×", AutoButtonColor = false}, titleBar)
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = UITheme.White end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = UITheme.TextDim end)
    closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)
    local sidebar = mk("Frame", {Size = UDim2.new(0, 140, 1, -38), Position = UDim2.new(0, 0, 0, 38),
        BackgroundColor3 = UITheme.Sidebar, BorderSizePixel = 0}, main)
    addGrad(sidebar, Color3.fromRGB(13, 13, 17), Color3.fromRGB(8, 8, 10), 90)
    addCorner(sidebar, 14)
    mk("Frame", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UITheme.Sidebar, BorderSizePixel = 0}, sidebar)
    local content = mk("Frame", {Size = UDim2.new(1, -140, 1, -38), Position = UDim2.new(0, 140, 0, 38),
        BackgroundColor3 = UITheme.Bg, BackgroundTransparency = 1, BorderSizePixel = 0}, main)
    local window = setmetatable({_gui = gui, _main = main, _sidebar = sidebar, _content = content, _tabs = {}, _active = nil}, Window)
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = main.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    _UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    if opts.MinimizeKey then
        _UIS.InputBegan:Connect(function(i, gp)
            if gp then return end
            if i.KeyCode == opts.MinimizeKey then main.Visible = not main.Visible end
        end)
    end
    Fluent.Window = window
    return window
end

-- SaveManager / InterfaceManager
local SaveManager = {}
local InterfaceManager = {}
function SaveManager:SetLibrary(lib) self.Library = lib end
function SaveManager:IgnoreThemeSettings() end
function SaveManager:SetFolder(f)
    self.folder = f
    pcall(function()
        if makefolder then
            local parts = string.split(f, "/")
            local path = ""
            for _, part in ipairs(parts) do
                path = (path == "") and part or (path .. "/" .. part)
                if not isfolder(path) then makefolder(path) end
            end
        end
    end)
end
function SaveManager:Save(name)
    local data = {}
    for id, opt in pairs(Fluent.Options) do
        if type(id) == "string" and id:sub(1, 2) ~= "__" then
            local v = opt.Value
            if typeof(v) == "EnumItem" then
                data[id] = {t = "EnumItem", c = tostring(v.EnumType), v = v.Name}
            elseif v ~= nil then data[id] = {t = type(v), v = v} end
        end
    end
    local ok = pcall(function()
        writefile((self.folder or "qzxp/configs") .. "/" .. name .. ".json", _HS:JSONEncode(data))
    end)
    Fluent:Notify({Title = "Config", Content = ok and ("Saved: " .. name) or "Save failed", Duration = 3})
end
local LOAD_PRIORITY = {
    ManualSword = 10, AvatarSaver = 10, LockTarget = 10,
    Accuracy    = 10, SpamRPS     = 10, FPSCap     = 10,
    CurveMode   = 10, HLR = 10, HLG = 10, HLB = 10,
    APKey = 20, SpamKey = 20, TBKey = 20,
    CursorKey = 20, LockKey = 20, GUIToggleKey = 20,
    SkinToggle = 30, AvatarChanger = 30,
    UnlockAllToggle = 40, ThunderDashToggle = 40,
}
function SaveManager:Load(name)
    local ok, contents = pcall(function()
        return readfile((self.folder or "qzxp/configs") .. "/" .. name .. ".json")
    end)
    if not ok or not contents then
        Fluent:Notify({Title = "Config", Content = "Not found: " .. name, Duration = 3})
        return
    end
    local ok2, data = pcall(function() return _HS:JSONDecode(contents) end)
    if not ok2 or type(data) ~= "table" then
        Fluent:Notify({Title = "Config", Content = "Invalid config", Duration = 3})
        return
    end
    local entries = {}
    for id, entry in pairs(data) do
        local opt = Fluent.Options[id]
        if opt and opt.SetValue and type(entry) == "table" and entry.v ~= nil then
            table.insert(entries, {id = id, entry = entry, priority = LOAD_PRIORITY[id] or 50})
        end
    end
    table.sort(entries, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.id < b.id
    end)
    local wasSuppressed = getgenv().qzxp_suppressNotify
    getgenv().qzxp_suppressNotify = true
    local applied, failed = 0, 0
    for _, item in ipairs(entries) do
        local opt = Fluent.Options[item.id]
        local v   = item.entry.v
        if item.entry.t == "EnumItem" then
            if type(item.entry.c) == "string" and type(item.entry.v) == "string" then
                local ok3, e = pcall(function() return Enum[item.entry.c][item.entry.v] end)
                if ok3 and e then v = e end
            end
        end
        if pcall(function() opt:SetValue(v) end) then applied += 1 else failed += 1 end
    end
    getgenv().qzxp_suppressNotify = wasSuppressed
    Fluent:Notify({
        Title   = "Config",
        Content = ("Loaded: %s (%d applied%s)"):format(
            name, applied, failed > 0 and (", " .. failed .. " failed") or ""),
        Duration = 3,
    })
end
function SaveManager:BuildConfigSection(tab)
    local s = tab:AddSection("Config")
    local function listConfigs()
        local list = {}
        local folder = self.folder or "qzxp/configs"
        pcall(function()
            if isfolder and isfolder(folder) then
                for _, f in ipairs(listfiles(folder)) do
                    local n = f:match("([^/\\]+)%.json$")
                    if n then table.insert(list, n) end
                end
            end
        end)
        table.sort(list)
        if #list == 0 then list = {"(no configs)"} end
        return list
    end
    local cfgDropdown
    cfgDropdown = s:AddDropdown("__cfglst", {Title = "Saved Configs", Values = listConfigs(), Default = "(no configs)", Multi = false, Callback = function(v)
        if v and v ~= "(no configs)" and Options.__cfgname then
            Options.__cfgname:SetValue(v)
        end
    end})
    s:AddButton({Title = "Refresh List", Callback = function()
        local new = listConfigs()
        if cfgDropdown and cfgDropdown.SetValues then cfgDropdown:SetValues(new) end
        if new[1] and new[1] ~= "(no configs)" and Options.__cfgname then
            Options.__cfgname:SetValue(new[1])
        end
    end})
    s:AddInput("__cfgname", {Title = "Config Name", Default = "default", Placeholder = "name"})
    s:AddButton({Title = "Save", Callback = function()
        local n = Fluent.Options.__cfgname and Fluent.Options.__cfgname.Value or "default"
        if n == "" then n = "default" end
        self:Save(n)
        if cfgDropdown and cfgDropdown.SetValues then
            cfgDropdown:SetValues(listConfigs())
        end
    end})
    s:AddButton({Title = "Load", Callback = function()
        local n = Fluent.Options.__cfgname and Fluent.Options.__cfgname.Value or "default"
        if n == "" then n = "default" end
        self:Load(n)
    end})
    s:AddButton({Title = "Set as Autoload", Callback = function()
        local n = Fluent.Options.__cfgname and Fluent.Options.__cfgname.Value or "default"
        if n == "" then n = "default" end
        self:SetAutoload(n)
    end})
    s:AddButton({Title = "Clear Autoload", Callback = function() self:SetAutoload("") end})
end
function SaveManager:SetAutoload(name)
    local folder = self.folder or "qzxp/configs"
    pcall(function()
        if makefolder and not isfolder(folder) then
            local parts = string.split(folder, "/")
            local path = ""
            for _, part in ipairs(parts) do
                path = (path == "") and part or (path .. "/" .. part)
                if not isfolder(path) then makefolder(path) end
            end
        end
        writefile(folder .. "/_autoload.txt", name or "")
    end)
    Fluent:Notify({Title = "Config",
        Content = (name and name ~= "") and ("Autoload: " .. name) or "Autoload cleared", Duration = 3})
end
function SaveManager:LoadAutoloadConfig()
    local folder = self.folder or "qzxp/configs"
    local ok, name = pcall(function() return readfile(folder .. "/_autoload.txt") end)
    if not ok or type(name) ~= "string" then return end
    name = name:gsub("%s+$", "")
    if name == "" then return end
    self:Load(name)
end
function InterfaceManager:SetLibrary(lib) self.Library = lib end
function InterfaceManager:SetFolder(f) self.folder = f end
function InterfaceManager:BuildInterfaceSection(tab) end

local Window = Fluent:CreateWindow({Title = "qzxp", TabWidth = 130,
    Size = UDim2.fromOffset(750, 450), MinimizeKey = Enum.KeyCode.LeftControl})
local _ui = { value = 0, connected = false }
function _ui.getOrStoreBase(obj)
    local b = obj:GetAttribute("qzxp_baseBgTransparency")
    if b == nil then
        b = obj.BackgroundTransparency
        obj:SetAttribute("qzxp_baseBgTransparency", b)
    end
    return b
end
function _ui.applyObj(obj)
    if obj:IsA("Frame") or obj:IsA("ScrollingFrame") or obj:IsA("TextButton") then
        local b = _ui.getOrStoreBase(obj)
        obj.BackgroundTransparency = 1 - (1 - b) * (1 - _ui.value)
    end
end
function _ui.apply(t)
    _ui.value = t
    if not Window or not Window._gui then return end
    for _, obj in ipairs(Window._gui:GetDescendants()) do _ui.applyObj(obj) end
    if not _ui.connected then
        _ui.connected = true
        Window._gui.DescendantAdded:Connect(_ui.applyObj)
    end
end
getgenv().qzxp_applyUITransparency = _ui.apply
local Tabs = {
    Combat   = Window:AddTab({Title = "Combat"}),
    Swords   = Window:AddTab({Title = "Swords"}),
    Avatar   = Window:AddTab({Title = "Avatar"}),
    Visuals  = Window:AddTab({Title = "Visuals"}),
    Utility  = Window:AddTab({Title = "Utility"}),
    FFlags   = Window:AddTab({Title = "FFlags"}),
    Settings = Window:AddTab({Title = "Settings"}),
}

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats             = game:GetService("Stats")
local Workspace         = game:GetService("Workspace")
local CoreGui           = GetSafeUIParent()
local HttpService       = game:GetService("HttpService")
local LocalPlayer       = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera

local function isRealPlayerModel(model)
    if not model then return false end
    return Players:GetPlayerFromCharacter(model) ~= nil
end

local AP_On, TB_On, Spam_On = false, false, false
local AutoSpam_On = false
local Parries = 0
local ClashingThreshold = 1
local InfinityBallRaw = false
local frameCount = 0
local Stats_Network = Stats.Network
local Stats_DataPing = Stats_Network and Stats_Network.ServerStatsItem and Stats_Network.ServerStatsItem["Data Ping"]

local function notify(cfg)
    if getgenv().qzxp_suppressNotify then return end
    task.defer(function() pcall(function() Fluent:Notify(cfg) end) end)
end

-- Anticheat token finder
local _token, _tokenFound = nil, false
local _tokenAttempts = 0
local MAX_TOKEN_ATTEMPTS = 8
local function findToken()
    if _tokenFound then return true end
    pcall(function()
        for _, fn in getgc(true) do
            if type(fn) == 'function' then
                local ok, s = pcall(debug.info, fn, 's')
                if ok and s and s:find('PRY', 1, true) then
                    local ok2, ups = pcall(debug.getupvalues, fn)
                    if ok2 then
                        for _, v in ipairs(ups) do
                            if type(v) == 'function' then
                                _token = v; _tokenFound = true; return
                            end
                        end
                    end
                end
            end
        end
    end)
    return _tokenFound
end
local function scheduleTokenRetry()
    if _tokenFound then return end
    if _tokenAttempts >= MAX_TOKEN_ATTEMPTS then
        notify({Title = "AC", Content = "Bypass failed after retries", Duration = 5})
        return
    end
    _tokenAttempts += 1
    task.delay(1.5, function()
        if findToken() then
            notify({Title = "AC", Content = "Bypassed (attempt " .. _tokenAttempts .. ")", Duration = 4})
        else
            scheduleTokenRetry()
        end
    end)
end
task.defer(function()
    if findToken() then
        notify({Title = "AC", Content = "Bypassed", Duration = 4})
    else
        scheduleTokenRetry()
    end
end)

local _tokenBuf = buffer.create(16)
local function _tokenize(uid)
    if not _tokenFound or type(_token) ~= "function" then return "" end
    local t = tostring(math.floor(Workspace:GetServerTimeNow() * 100))
    local ok, k = pcall(_token, uid, 'TIME')
    if not ok or type(k) ~= "string" or #k == 0 then return "" end
    local n = #t
    local klen = #k
    for i = 1, n do
        local b = (string.byte(t, i) + i) % 256
        local kb = string.byte(k, (i - 1) % klen + 1)
        buffer.writeu8(_tokenBuf, i - 1, bit32.bxor(b, kb))
    end
    return buffer.readstring(_tokenBuf, 0, n)
end

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

local SwordAPI = ReplicatedStorage:WaitForChild("Shared", 9e9):WaitForChild("SwordAPI", 9e9)
local swordModuleInstance = ReplicatedStorage:WaitForChild("Shared", 9e9):WaitForChild("ReplicatedInstances", 9e9):WaitForChild("Swords", 9e9)
local swordModule = require(swordModuleInstance)
local swordApi = require(SwordAPI)
local animationController = require(ReplicatedStorage:WaitForChild("Controllers"):WaitForChild("AnimationController"))

local SwordRegistry = {}
local SwordRegistryReverse = {}
local function norm(s) return s and tostring(s):lower():gsub("[%s_%-%p]+", "") or "" end
local function buildRegistry()
    local seen = {}
    SwordRegistry = {}; SwordRegistryReverse = {}
    local function reg(name)
        if not name or name == "" or seen[name] then return end
        seen[name] = true
        SwordRegistry[norm(name)] = name
        SwordRegistryReverse[name] = true
    end
    pcall(function()
        if type(swordModule) == "table" then
            for k, v in pairs(swordModule) do
                if type(k) == "string" and k ~= "GetSword" and k ~= "EquipSwordTo" and k ~= "new" and k ~= "__index" then reg(k) end
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
        for _, item in ipairs(folder:GetChildren()) do reg(item.Name) end
    end)
    pcall(function()
        if SwordAPI and SwordAPI:FindFirstChild("Collection") then
            for _, item in ipairs(SwordAPI.Collection:GetChildren()) do reg(item.Name) end
        end
    end)
end
buildRegistry()
local function resolve(input)
    if not input or input == "" then return "" end
    input = tostring(input)
    local n = norm(input)
    if SwordRegistry[n] then return SwordRegistry[n] end
    for nk, actual in pairs(SwordRegistry) do
        if nk:find(n, 1, true) then return actual end
    end
    return input
end

-- Animation system
local AnimFix_AP, AnimFix_TB, AnimFix_Spam = true, true, true
local AnimFix_Cache = {}
local ANIM_FAIL = false
local Bypass_Cd = false
local AnimLastPlayed = 0
local VirtualInputManager = Instance.new("VirtualInputManager")

local function PlayParryAnimation()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    local attribute = character:GetAttribute("CurrentlyEquippedSword")
                   or LocalPlayer:GetAttribute("CurrentlyEquippedSword")
    if not attribute then return end
    local swordInfo = swordModule:GetSword(attribute)
    if not swordInfo or character ~= LocalPlayer.Character then return end
    for _, track in animationController:GetPlayingAnimationTracks(animator) do
        if track:GetAttribute("GrabParry") or track:GetAttribute("Parry")
            or track.Name == "GrabParry" or track.Name == "Grab"
            or track.Name == "Parry"
            or track.Name == "SuccessParry" or track.Name == "Success" then
            track:Stop(track:GetAttribute("StopFadeTime") or 0.1)
        end
    end
    for _, animation in swordApi:GetAnimations(character, {"Parry", "GrabParry"}, swordInfo.AnimationType, swordInfo.SwordType) do
        local track = animationController:LoadAnimation(animator, animation, true)
        local speed = track:GetAttribute("PlaySpeed") or 1
        track:Play(
            track:GetAttribute("PlayFadeTime") or 0.1,
            track:GetAttribute("PlayWeight") or 1,
            speed
        )
        character:SetAttribute("ParryTime", math.max(
            character:GetAttribute("ParryTime") or 0,
            track.Length == 0 and 1 or (track.Length - track.TimePosition) * speed
        ))
    end
end
local function PlaySingleParryAnimation()
    if os.clock() - AnimLastPlayed >= 1.2 or Bypass_Cd then
        AnimLastPlayed = os.clock()
        Bypass_Cd = false
        PlayParryAnimation()
    end
end

-- Block keybind detection (for game-native parry animation)
local Block_Keybind
do
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    Block_Keybind = pg.Settings.Frame.Frame["Keybinds/Block"].Keybind1.TextBox.Text or pg.Settings.Frame.Frame["Keybinds/Block"].Keybind2.TextBox.Text or pg.Settings.Frame.Frame["Keybinds/Block"].Keybind3.TextBox.Text
end
local function Animation_Fix()
    local identity = getthreadidentity()
    if identity ~= 8 then
        setthreadidentity(8)
    end
    local ok, message = pcall(function()
        VirtualInputManager:SendKeyEvent(true, Block_Keybind, false, game)
        VirtualInputManager:SendKeyEvent(false, Block_Keybind, false, game)
    end)
    if identity ~= 8 then
        setthreadidentity(identity)
    end
    if not ok then
        error(message, 0)
    end
end
local SpamAnimRate, SpamAnimLastPlayed, SpamAnimBypass = 100, 0, false
local SpamAnimDelayLimit, SpamAnimSpammingMode, SpamAnimParries = 0, false, 0
local SpamAnimMatchRPS = false
local _tbLastFire, _apLastFire = 0, 0
local function StopParryGrabTracks()
    local char = LocalPlayer.Character; if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator"); if not animator then return end
    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        if track:GetAttribute("GrabParry") or track:GetAttribute("Parry") or track.Name == "GrabParry" or track.Name == "Grab" then
            track:Stop(track:GetAttribute("StopFadeTime") or 0.1)
        end
    end
end
ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
    Bypass_Cd = true
    StopParryGrabTracks()
end)

-- Ball cache
local _ballCache = {}
local _ballCacheDirty = true
local _ballCanCollideSet = setmetatable({}, {__mode = "k"})
local function _markBallsDirty() _ballCacheDirty = true end
local _ballRespawnHandlers = {}
local function _onBallRespawn(ball)
    _ballCacheDirty = true
    for i = 1, #_ballRespawnHandlers do
        pcall(_ballRespawnHandlers[i], ball)
    end
end
spawnTracked(function()
    local function watchFolder(folder)
        if not folder then return end
        local function hookRealBall(child)
            if child and child:IsA("Instance") then
                child:GetAttributeChangedSignal('realBall'):Connect(function()
                    _markBallsDirty()
                    if child:GetAttribute('realBall') then _onBallRespawn(child) end
                end)
            end
        end
        folder.ChildAdded:Connect(function(child)
            _markBallsDirty()
            hookRealBall(child)
            if child:GetAttribute('realBall') then _onBallRespawn(child) end
        end)
        folder.ChildRemoved:Connect(_markBallsDirty)
        folder.DescendantAdded:Connect(function(d)
            if d:IsA("Ball") or d:IsA("BasePart") then
                _markBallsDirty()
                hookRealBall(d)
            end
        end)
        for _, child in ipairs(folder:GetChildren()) do hookRealBall(child) end
    end
    watchFolder(Workspace:WaitForChild('Balls', 9e9))
    watchFolder(Workspace:WaitForChild('TrainingBalls', 30))
end)
local function _scanBallsInto(folder, startN)
    if not folder then return startN end
    local n = startN
    for _, ball in ipairs(folder:GetChildren()) do
        if ball:GetAttribute('realBall') then
            if not _ballCanCollideSet[ball] then
                ball.CanCollide = false; _ballCanCollideSet[ball] = true
            end
            n = n + 1; _ballCache[n] = ball
        end
    end
    return n
end
local function refreshBallCache()
    if not _ballCacheDirty then return end
    _ballCacheDirty = false
    local n = _scanBallsInto(Workspace:FindFirstChild('Balls'), 0)
    n = _scanBallsInto(Workspace:FindFirstChild('TrainingBalls'), n)
    for i = n + 1, #_ballCache do _ballCache[i] = nil end
end
local function getBall()
    refreshBallCache()
    local me = LocalPlayer.Name
    for i = 1, #_ballCache do
        local b = _ballCache[i]
        if b:GetAttribute('target') == me then return b end
    end
    return _ballCache[1]
end
local function getAllBalls() refreshBallCache(); return _ballCache end
local function getTargetingBalls(out)
    refreshBallCache()
    out = out or {}
    local n = 0
    local me = LocalPlayer.Name
    for i = 1, #_ballCache do
        local b = _ballCache[i]
        if b:GetAttribute('target') == me then n = n + 1; out[n] = b end
    end
    for i = n + 1, #out do out[i] = nil end
    return out
end

-- Ping (rolling minimum)
local PING_SAMPLES = 12
local _pingRing = {}
local _pingRingN = 0
local _pingRingHead = 0
local _pingTime = 0
local function getPing()
    local n = tick()
    if (n - _pingTime) > 0.1 then
        _pingTime = n
        if Stats_DataPing then
            local ok, v = pcall(function() return Stats_DataPing:GetValue() end)
            if ok and type(v) == "number" and v > 0 then
                _pingRingHead = (_pingRingHead % PING_SAMPLES) + 1
                _pingRing[_pingRingHead] = v
                if _pingRingN < PING_SAMPLES then _pingRingN += 1 end
            end
        end
    end
    if _pingRingN == 0 then return 50 end
    local m = math.huge
    for i = 1, _pingRingN do
        if _pingRing[i] < m then m = _pingRing[i] end
    end
    return m
end

-- Curve detection
local CurveState = setmetatable({}, {__mode = "k"})
local function _newCurveState()
    return {
        __last_warping = 0, __lerp_radians = 0, __curving = 0,
        __prev_vel = {}, __prev_vel_n = 0, __prev_vel_head = 0,
        __tornado_time = 0
    }
end
local function getCurveState(ball)
    local s = CurveState[ball]
    if not s then s = _newCurveState(); CurveState[ball] = s end
    return s
end
local function _resetCurveState(ball)
    if ball then CurveState[ball] = _newCurveState() end
end
table.insert(_ballRespawnHandlers, function(ball)
    pcall(_resetCurveState, ball)
end)
local lastTornadoCheck, tornadoActive = 0, false
local function checkTornadoActive(ball)
    local now = os.clock()
    if now - lastTornadoCheck < 0.1 then return tornadoActive end
    lastTornadoCheck = now
    local Runtime = Workspace:FindFirstChild('Runtime')
    if Runtime then
        local Tornado = Runtime:FindFirstChild('Tornado')
        if Tornado then
            local tt = Tornado:GetAttribute("TornadoTime") or 1
            local CP = getCurveState(ball)
            if (tick() - (CP.__tornado_time or 0)) < (tt + 0.314159) then
                tornadoActive = true; return true
            end
        end
    end
    tornadoActive = false
    return false
end
local function isCurved(ball)
    ball = ball or getBall()
    if not ball then return false end
    local CP = getCurveState(ball)
    local z = ball:FindFirstChild("zoomies")
    if not z then return false end
    local vel = z.VectorVelocity
    local spd = vel.Magnitude
    if spd < 1 then
        CP.__curving = 0; CP.__last_warping = 0
        CP.__lerp_radians = 0; CP.__prev_vel_n = 0
        CP.__prev_vel_head = 0
        return false
    end
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
    local head = (CP.__prev_vel_head % 4) + 1
    CP.__prev_vel[head] = vel
    CP.__prev_vel_head = head
    if CP.__prev_vel_n < 4 then CP.__prev_vel_n = CP.__prev_vel_n + 1 end
    if ball:FindFirstChild('AeroDynamicSlashVFX') then CP.__tornado_time = tick() end
    if checkTornadoActive(ball) then return true end
    if spd > 160 and rt > (getPing() / 10) then
        if spd < 300 then bdt = math.max(bdt - 15, 15)
        elseif spd < 600 then bdt = math.max(bdt - 16, 16)
        elseif spd < 1000 then bdt = math.max(bdt - 17, 17)
        elseif spd < 1500 then bdt = math.max(bdt - 19, 19)
        else bdt = math.max(bdt - 20, 20) end
    end
    if dist < bdt then return false end
    if spd < 300 then
        if (tick() - (CP.__curving or 0)) < (rt / 1.2) then return true end
    elseif spd < 450 then
        if (tick() - (CP.__curving or 0)) < (rt / 1.21) then return true end
    elseif spd < 600 then
        if (tick() - (CP.__curving or 0)) < (rt / 1.335) then return true end
    else
        if (tick() - (CP.__curving or 0)) < (rt / 1.5) then return true end
    end
    local dthr = 0.5 - ping
    local cd = math.clamp(dot, -1, 1)
    local rad = math.deg(math.asin(cd))
    CP.__lerp_radians = (CP.__lerp_radians or 0) + (rad - (CP.__lerp_radians or 0)) * 0.8
    if spd < 300 then
        if CP.__lerp_radians < 0.02 then CP.__last_warping = tick() end
        if (tick() - (CP.__last_warping or 0)) < (rt / 1.19) then return true end
    else
        if CP.__lerp_radians < 0.018 then CP.__last_warping = tick() end
        if (tick() - (CP.__last_warping or 0)) < (rt / 1.5) then return true end
    end
    if CP.__prev_vel_n == 4 then
        local pv1 = CP.__prev_vel[((CP.__prev_vel_head - 1 - 1) % 4) + 1]
        local pv2 = CP.__prev_vel[((CP.__prev_vel_head - 1 - 2) % 4) + 1]
        if pv1 and pv2 then
            local d1 = (bdir - pv1.Unit).Unit
            local d2 = (bdir - pv2.Unit).Unit
            if (dot - dir:Dot(d1)) < dthr or (dot - dir:Dot(d2)) < dthr then return true end
        end
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
local _curveCache, _curveCacheTime = {}, 0
local CURVE_INTERVAL = 1 / 30
local function isCurvedCached(ball)
    local now = os.clock()
    if now - _curveCacheTime >= CURVE_INTERVAL then _curveCacheTime = now; _curveCache = {} end
    local cached = _curveCache[ball]
    if cached ~= nil then return cached end
    local result = isCurved(ball)
    _curveCache[ball] = result
    return result
end
local function horizDist(a, b)
    local dx, dz = a.X - b.X, a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end
local function isApproachingPlayer(ball, playerPos, hitRadius, lookahead)
    if not ball or not ball.Parent then return false end
    local z = ball:FindFirstChild("zoomies")
    if not z then return false end
    local vel = z.VectorVelocity
    local spd = vel.Magnitude
    if spd < 5 then return false end
    local bpos = ball.Position
    local velH = Vector3.new(vel.X, 0, vel.Z)
    local spdH = velH.Magnitude
    if spdH < 1 then
        local toPlayer = playerPos - bpos
        local t = toPlayer:Dot(vel) / (spd * spd)
        if t < 0 or t > (lookahead or 0.4) then return false end
        local closest = bpos + vel * t
        return (closest - playerPos).Magnitude <= (hitRadius or 8)
    end
    local toH = Vector3.new(playerPos.X - bpos.X, 0, playerPos.Z - bpos.Z)
    local t = toH:Dot(velH) / (spdH * spdH)
    if t < 0 or t > (lookahead or 0.4) then return false end
    local cx = bpos.X + velH.X * t
    local cz = bpos.Z + velH.Z * t
    return horizDist(Vector3.new(cx, 0, cz), playerPos) <= (hitRadius or 8)
end

-- Sender tracking
local Sender = setmetatable({}, {__mode = "k"})
local function trackBall(ball)
    if not ball then return end
    if Sender[ball] then return end
    local s = {last = nil, prev = nil, conn = nil}
    Sender[ball] = s
    s.prev = ball:GetAttribute("target")
    s.conn = ball:GetAttributeChangedSignal('target'):Connect(function()
        local nt = ball:GetAttribute("target")
        if nt == LocalPlayer.Name and s.prev and s.prev ~= LocalPlayer.Name then
            s.last = s.prev
        end
        s.prev = nt
    end)
    ball.Destroying:Once(function()
        if s.conn then pcall(function() s.conn:Disconnect() end) end
        Sender[ball] = nil
    end)
end

local function findPart(name)
    if not name or name == "" or name == LocalPlayer.Name then return nil end
    if not Players:FindFirstChild(name) then return nil end
    local af = Workspace:FindFirstChild("Alive")
    if af then local c = af:FindFirstChild(name); if c then return c.PrimaryPart or c:FindFirstChild("HumanoidRootPart") end end
    local p = Players:FindFirstChild(name)
    if p and p.Character then return p.Character.PrimaryPart end
end

local LockEnabled, LockTarget = false, "None"
local HLEnabled, HLColor = false, Color3.fromRGB(255, 60, 60)

-- Lock indicator (corner brackets)
local LockIndicator = { gui = nil, lines = {} }
local function ensureLockIndicator()
    if LockIndicator.gui and LockIndicator.gui.Parent then return end
    LockIndicator.gui = nil
    LockIndicator.lines = {}
    local sg = Instance.new("ScreenGui")
    sg.Name = "qzxp_LockIndicator"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = false
    sg.DisplayOrder = 90
    sg.Parent = GetSafeUIParent()
    LockIndicator.gui = sg
    for i = 1, 8 do
        local f = Instance.new("Frame")
        f.Name = "Corner" .. i
        f.BackgroundColor3 = HLColor
        f.BorderSizePixel = 0
        f.Visible = false
        f.Parent = sg
        LockIndicator.lines[i] = f
    end
end
local function hideLockIndicator()
    if not LockIndicator.gui then return end
    for i = 1, 8 do
        local f = LockIndicator.lines[i]
        if f then f.Visible = false end
    end
end
local function drawLockIndicator()
    if not HLEnabled or LockTarget == "None" then hideLockIndicator(); return end
    local part = findPart(LockTarget)
    if not part or not part.Parent then hideLockIndicator(); return end
    local char = part.Parent
    if not char or not char:IsA("Model") then hideLockIndicator(); return end
    local ok, cf, size = pcall(function()
        local c, s = char:GetBoundingBox()
        return c, s
    end)
    if not ok or not cf or not size then hideLockIndicator(); return end
    local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local visibleCorners = 0
    for _, sx in ipairs({-1, 1}) do
        for _, sy in ipairs({-1, 1}) do
            for _, sz in ipairs({-1, 1}) do
                local wp = (cf * CFrame.new(sx * hx, sy * hy, sz * hz)).Position
                local sp, on = Camera:WorldToViewportPoint(wp)
                if on then
                    visibleCorners += 1
                    if sp.X < minX then minX = sp.X end
                    if sp.Y < minY then minY = sp.Y end
                    if sp.X > maxX then maxX = sp.X end
                    if sp.Y > maxY then maxY = sp.Y end
                end
            end
        end
    end
    if visibleCorners < 2 then hideLockIndicator(); return end
    local vp = Camera.ViewportSize
    if (maxX - minX) > vp.X * 3 or (maxY - minY) > vp.Y * 3 then hideLockIndicator(); return end
    local padX = (maxX - minX) * 0.06 + 2
    local padY = (maxY - minY) * 0.06 + 2
    minX -= padX; maxX += padX
    minY -= padY; maxY += padY
    local w = maxX - minX
    local h = maxY - minY
    local cornerLen = math.min(w, h) * 0.22
    local t = 2
    ensureLockIndicator()
    local L = LockIndicator.lines
    L[1].Position = UDim2.fromOffset(minX, minY)
    L[1].Size     = UDim2.fromOffset(cornerLen, t)
    L[2].Position = UDim2.fromOffset(minX, minY)
    L[2].Size     = UDim2.fromOffset(t, cornerLen)
    L[3].Position = UDim2.fromOffset(maxX - cornerLen, minY)
    L[3].Size     = UDim2.fromOffset(cornerLen, t)
    L[4].Position = UDim2.fromOffset(maxX - t, minY)
    L[4].Size     = UDim2.fromOffset(t, cornerLen)
    L[5].Position = UDim2.fromOffset(maxX - cornerLen, maxY - t)
    L[5].Size     = UDim2.fromOffset(cornerLen, t)
    L[6].Position = UDim2.fromOffset(maxX - t, maxY - cornerLen)
    L[6].Size     = UDim2.fromOffset(t, cornerLen)
    L[7].Position = UDim2.fromOffset(minX, maxY - t)
    L[7].Size     = UDim2.fromOffset(cornerLen, t)
    L[8].Position = UDim2.fromOffset(minX, maxY - cornerLen)
    L[8].Size     = UDim2.fromOffset(t, cornerLen)
    for i = 1, 8 do
        L[i].Visible          = true
        L[i].BackgroundColor3 = HLColor
    end
end

local function closestToCursor()
    local ml; pcall(function() ml = UserInputService:GetMouseLocation() end)
    local c = ml or Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bp = math.huge, nil
    local af = Workspace:FindFirstChild("Alive")
    if af then
        for _, v in pairs(af:GetChildren()) do
            if v ~= LocalPlayer.Character and v.PrimaryPart and isRealPlayerModel(v) then
                local sp, on = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
                if on then local d = (Vector2.new(sp.X, sp.Y) - c).Magnitude; if d < best then best = d; bp = v.Name end end
            end
        end
    end
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
        if LockTarget ~= "None" then
            for d, n in pairs(pLookup) do if n == LockTarget then ds = d; break end end
        end
        Options.LockTarget:SetValue(ds)
    end) end)
end

-- Curve CFrame
local CURVES = {"Camera", "Dot", "Nearest", "Random", "Accel", "Backwards", "Slow", "High", "Normal", "Speed", "Down", "Left", "Right"}
local CurveMode = "Camera"
local lastCFCalcFrame, cachedCF = 0, nil
local _frameBlockOk = nil
local _frameEd, _frameEdFrame = nil, 0
local function IsBlockLegit()
    local c = LocalPlayer.Character
    if not c or not c.Parent then return false end
    if c:GetAttribute("Stunned") then return false end
    if c:GetAttribute("DoNotParry") then return false end
    local alive = Workspace:FindFirstChild("Alive")
    local dead = Workspace:FindFirstChild("Dead")
    local inAlive = alive and c.Parent == alive
    local inDead = dead and c.Parent == dead
    local lobbyParry = LocalPlayer:GetAttribute("LobbyParry")
    local lobbyTraining = LocalPlayer:GetAttribute("LobbyTraining")
    if not inAlive and not (lobbyParry or (lobbyTraining and inDead)) then return false end
    if lobbyParry and LocalPlayer:GetAttribute("InLobbyParryCooldown") then return false end
    return true
end
local _cachedCFBall = nil
local function getCurveCF(ballArg)
    if cachedCF and frameCount == lastCFCalcFrame and _cachedCFBall == ballArg then return cachedCF end
    lastCFCalcFrame = frameCount
    _cachedCFBall = ballArg
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local rp = root and root.Position or Camera.CFrame.Position
    local ball = ballArg or getBall()
    if ball then trackBall(ball) end
    local tp = nil
    if LockEnabled and LockTarget ~= "None" then tp = findPart(LockTarget) end
    local _s = ball and Sender[ball]
    if not tp and _s and _s.last then tp = findPart(_s.last) end
    if not tp then
        local ml; pcall(function() ml = UserInputService:GetMouseLocation() end)
        local c = ml or Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local bs, bw = math.huge, math.huge
        local st2, wt = nil, nil
        local af = Workspace:FindFirstChild("Alive")
        local function chk(m)
            if m == LocalPlayer.Character or not m.PrimaryPart then return end
            if not isRealPlayerModel(m) then return end
            local p = m.PrimaryPart.Position
            local sp, on = Camera:WorldToScreenPoint(p)
            if on then local d = (Vector2.new(sp.X, sp.Y) - c).Magnitude; if d < bs then bs = d; st2 = m.PrimaryPart end end
            local wd = (p - rp).Magnitude; if wd < bw then bw = wd; wt = m.PrimaryPart end
        end
        if af then for _, v in pairs(af:GetChildren()) do chk(v) end end
        for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer and p.Character then chk(p.Character) end end
        tp = st2 or wt
    end
    local tpos = tp and tp.Position
    if not tpos then
        if ball then
            local z = ball:FindFirstChild("zoomies")
            if z then
                local v = z.VectorVelocity
                if v.Magnitude > 1 then
                    tpos = rp - v.Unit * 100
                end
            end
        end
    end
    if not tpos then
        tpos = rp + Camera.CFrame.LookVector * 100
    end
    if LockEnabled and tp then cachedCF = CFrame.new(rp, tpos); return cachedCF end
    local m = (Options and Options.CurveMode and Options.CurveMode.Value) or CurveMode
    local resCF = Camera.CFrame
    if m == "Camera" then
        resCF = Camera.CFrame
    else
        local fwd = tpos - rp
        if fwd.Magnitude > 0.001 then fwd = fwd.Unit else fwd = Camera.CFrame.LookVector end
        local up = Vector3.new(0, 1, 0)
        local right = fwd:Cross(up)
        if right.Magnitude > 0.001 then right = right.Unit else right = Camera.CFrame.RightVector end
        if m == "Dot" then
            if ball then
                local z = ball:FindFirstChild("zoomies")
                local v = z and z.VectorVelocity or Vector3.zero
                local d = v.Magnitude > 1 and -v.Unit or fwd
                resCF = CFrame.new(rp, rp + d * 100)
            else resCF = CFrame.new(rp, tpos) end
        elseif m == "Nearest" then resCF = CFrame.new(rp, tpos)
        elseif m == "Random" then resCF = CFrame.new(rp, tpos + Vector3.new(math.random(-4000,4000), math.random(-4000,4000), math.random(-4000,4000)))
        elseif m == "Accel" then resCF = CFrame.new(rp, tpos + Vector3.new(0, 5, 0))
        elseif m == "Backwards" then resCF = CFrame.new(rp, rp - fwd * 10000 + Vector3.new(0, 1000, 0))
        elseif m == "Slow" then resCF = CFrame.new(rp, tpos + Vector3.new(0, -9e18, 0))
        elseif m == "High" then resCF = CFrame.new(rp, tpos + Vector3.new(0, 9e18, 0))
        elseif m == "Normal" then resCF = CFrame.new(rp, rp + fwd * 1000)
        elseif m == "Speed" then resCF = CFrame.new(rp, rp + up * 5)
        elseif m == "Down" then resCF = CFrame.new(rp, rp - up * 9e9)
        elseif m == "Left" then resCF = CFrame.new(rp, rp - right * 9e9)
        elseif m == "Right" then resCF = CFrame.new(rp, rp + right * 9e9)
        end
    end
    cachedCF = resCF
    return cachedCF
end

-- Remote fire
local _apLocked      = false
local _apLockedUntil = 0
local _apLockedBall  = nil
local _apLockedConn  = nil
local function clearAPLockout()
    _apLocked      = false
    _apLockedUntil = 0
    _apLockedBall  = nil
    if _apLockedConn then
        pcall(function() _apLockedConn:Disconnect() end)
        _apLockedConn = nil
    end
end
local function setAPLockout(ball)
    clearAPLockout()
    _apLocked      = true
    _apLockedUntil = os.clock() + 1.0
    _apLockedBall  = ball
    if ball then
        _apLockedConn = ball:GetAttributeChangedSignal('target'):Connect(function()
            if ball:GetAttribute('target') ~= _lpName then clearAPLockout() end
        end)
    end
end
local function isAPLocked()
    if not _apLocked then return false end
    if os.clock() >= _apLockedUntil then
        clearAPLockout()
        return false
    end
    return true
end
local function fireRemote(ball)
    if not ball or not ball.Parent then return false end
    if not _remote or not _args or not _tokenFound then return false end
    local rcf = getCurveCF(ball)
    if _frameEdFrame ~= frameCount then
        _frameEdFrame = frameCount
        local ed = {}
        local af = Workspace:FindFirstChild("Alive")
        if af then
            for _, e in pairs(af:GetChildren()) do
                if e.PrimaryPart then
                    local ok, sp = pcall(Camera.WorldToScreenPoint, Camera, e.PrimaryPart.Position)
                    if ok then ed[e.Name] = sp end
                end
            end
        end
        _frameEd = ed
    end
    local ed = _frameEd
    local vp = Camera.ViewportSize
    local mp = Vector2.new(vp.X / 2, vp.Y / 2)
    if LockEnabled and LockTarget ~= "None" then
        local lp = findPart(LockTarget)
        if lp then local sp = Camera:WorldToScreenPoint(lp.Position); mp = Vector2.new(sp.X, sp.Y) end
    else
        local ok, loc = pcall(UserInputService.GetMouseLocation, UserInputService)
        if ok and loc then mp = loc end
    end
    local ok = pcall(function()
        _remote:FireServer(_args[1], _args[2], _tokenize(_args[2]), 0.5, rcf, ed, {math.floor(mp.X), math.floor(mp.Y)}, false)
    end)
    if not ok then return false end
    return true
end

local function fireParryGeneric()
    if not _remote or not _args or not _tokenFound then return false end
    local rcf = getCurveCF(getBall())
    if _frameEdFrame ~= frameCount then
        _frameEdFrame = frameCount
        local ed = {}
        local af = Workspace:FindFirstChild("Alive")
        if af then
            for _, e in pairs(af:GetChildren()) do
                if e.PrimaryPart then
                    local ok, sp = pcall(Camera.WorldToScreenPoint, Camera, e.PrimaryPart.Position)
                    if ok then ed[e.Name] = sp end
                end
            end
        end
        _frameEd = ed
    end
    local ed = _frameEd
    local vp = Camera.ViewportSize
    local mp = Vector2.new(vp.X / 2, vp.Y / 2)
    if LockEnabled and LockTarget ~= "None" then
        local lp = findPart(LockTarget)
        if lp then
            local sp = Camera:WorldToScreenPoint(lp.Position)
            mp = Vector2.new(sp.X, sp.Y)
        end
    else
        local ok, loc = pcall(UserInputService.GetMouseLocation, UserInputService)
        if ok and loc then mp = loc end
    end
    local ok = pcall(function()
        _remote:FireServer(_args[1], _args[2], _tokenize(_args[2]), 0.5, rcf, ed, {math.floor(mp.X), math.floor(mp.Y)}, false)
    end)
    return ok
end

local AP_Acc, AP_Div = 50, 1.1
local RandAcc, AutoAbility = false, false
local function computeTriggerDist(spd, ping, curved, acc)
    local reaction = 0.10 + ((acc or 50) - 1) * (0.08 / 99)
    if curved then reaction = reaction * 1.25 end
    return math.max(spd * (reaction + (ping or 0) / 1000 + 0.03), 14)
end
local function updDiv() AP_Div = 0.7 + (AP_Acc - 1) * (0.9 / 99) end
updDiv()
spawnTracked(function()
    while task.wait(1) do
        if RandAcc then
            local rawPing = 50
            if Stats_DataPing then
                local ok, v = pcall(function() return Stats_DataPing:GetValue() end)
                if ok and type(v) == "number" and v > 0 then rawPing = v end
            end
            local internal = math.clamp(1.5 - (rawPing / 200) * 1.5, 0, 1.5)
            AP_Acc = math.clamp(math.floor(internal / 0.015151515151515152 + 1 + 0.5), 1, 100)
            updDiv()
            if Options and Options.Accuracy then pcall(function() Options.Accuracy:SetValue(AP_Acc) end) end
        end
    end
end)

pcall(function() ReplicatedStorage.Remotes.DeathBall.OnClientEvent:Connect(function(_,d) DSOn=d or false end) end)
pcall(function() ReplicatedStorage.Remotes.InfinityBall.OnClientEvent:Connect(function(_,b) InfOn=b or false end) end)
pcall(function() ReplicatedStorage.Remotes.InfinityBall.OnClientEvent:Connect(function(_, on) InfinityBallRaw = on == true end) end)
local _lpName = LocalPlayer.Name
local _argsContainMe = function(a)
    for i = 1, #a do
        local v = a[i]
        if v == LocalPlayer then return true end
        local t = typeof(v)
        if t == "Instance" then
            if v.Name == _lpName then
                if v:IsA("Player") or Players:GetPlayerFromCharacter(v) == LocalPlayer then return true end
            end
        end
    end
    return false
end
local _netModule = nil
do
    pcall(function() _netModule = ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net end)
    if not _netModule then
        pcall(function()
            for _, m in ipairs(ReplicatedStorage.Packages:GetDescendants()) do
                if m.Name == "net" and m:IsA("ModuleScript") then _netModule = require(m); break end
            end
        end)
    end
end
pcall(function()
    if not _netModule then return end
    local net = _netModule
    net["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...)
        local p = (...)
        if p == LocalPlayer or (p and p.Name == LocalPlayer.Name) then THOn = true end
    end)
    net["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function() THOn = false end)
    net["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...)
        local p = (...)
        if p == LocalPlayer or (p and p.Name == LocalPlayer.Name) then
            SFOn = true; slashesoffury_count = 0
        end
    end)
    net["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function()
        SFOn = false; slashesoffury_count = 0
    end)
    net["RE/SlashesOfFuryParry"].OnClientEvent:Connect(function()
        slashesoffury_count += 1
    end)
    net["RE/SlashesOfFuryCatch"].OnClientEvent:Connect(function()
        task.spawn(function()
            while SFOn and slashesoffury_count < maxParryCount do
                if SFDet then fireParryGeneric(); task.wait(parryDelay) else break end
            end
        end)
    end)
end)
local function _hookNetEvent(name, onFire)
    local hooked = false
    if _netModule then
        pcall(function()
            local ev = _netModule[name]
            if ev and ev.OnClientEvent then
                ev.OnClientEvent:Connect(function(...) onFire({...}) end); hooked = true
            end
        end)
    end
    if not hooked then
        pcall(function()
            local ev = ReplicatedStorage.Remotes:FindFirstChild(name)
            if ev and ev:IsA("RemoteEvent") then
                ev.OnClientEvent:Connect(function(...) onFire({...}) end); hooked = true
            end
        end)
    end
    if not hooked then warn("[qzxp] detection: could not hook net event " .. name) end
end

do
addRenderHandler(function()
    frameCount += 1
    _frameBlockOk = nil
end, 1)

local _apState = {
    AerodynamicTime = tick(),
    LastWarping     = tick(),
    LerpRadians     = 0,
    Curving         = tick(),
}
local _apPositions  = {}
local _apReplicator = nil
do
    local net = ReplicatedStorage:FindFirstChild("Packages")
        and ReplicatedStorage.Packages:FindFirstChild("_Index")
        and ReplicatedStorage.Packages._Index:FindFirstChild("sleitnick_net@0.1.0")
        and ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"]:FindFirstChild("net")
    if net then
        for _, child in net:GetChildren() do
            if child:IsA("UnreliableRemoteEvent") and child.Name ~= "URE/ReplicateBallPosition" then
                _apReplicator = child
                break
            end
        end
    end
end
if _apReplicator then
    _apReplicator.OnClientEvent:Connect(function(ball, pos)
        if ball and ball.Parent == Workspace:FindFirstChild("Balls")
           and ball:GetAttribute("realBall") == true then
            _apPositions[ball] = pos
        end
    end)
end
local function apFirstBall()
    local all = getAllBalls()
    return all[1]
end
local function apPosition(ball)
    local b = ball or apFirstBall()
    if b then return _apPositions[b] or b.Position end
    return Vector3.zero
end
local _apTarget = { current = nil, visited = {} }
local function apPickRandom()
    local list = {}
    local af = Workspace:FindFirstChild("Alive")
    if af then
        for _, m in ipairs(af:GetChildren()) do
            if m.Name ~= _lpName and m.PrimaryPart and isRealPlayerModel(m) then table.insert(list, m) end
        end
    end
    if #list == 0 then _apTarget.current = nil; return end
    if #list == 1 then _apTarget.current = list[1]; return end
    local candidates = {}
    for _, m in ipairs(list) do
        if not _apTarget.visited[m.Name] then table.insert(candidates, m) end
    end
    if #candidates == 0 then
        _apTarget.visited = {}
        for _, m in ipairs(list) do
            if not _apTarget.current or m.Name ~= _apTarget.current.Name then
                table.insert(candidates, m)
            end
        end
        if #candidates == 0 then candidates = list end
    end
    local picked = candidates[math.random(1, #candidates)]
    _apTarget.visited[picked.Name] = true
    _apTarget.current = picked
end
local function apByMouse()
    if LockEnabled and LockTarget ~= "None" then
        local lp = findPart(LockTarget)
        if lp and lp.Parent then
            _apTarget.current = lp.Parent
            return lp.Parent
        end
    end
    local list = {}
    local af = Workspace:FindFirstChild("Alive")
    if af then
        for _, m in ipairs(af:GetChildren()) do
            if m.Name ~= _lpName and m.PrimaryPart and isRealPlayerModel(m) then table.insert(list, m) end
        end
    end
    if #list == 0 then _apTarget.current = nil; return nil end
    local cam = Workspace.CurrentCamera
    local cf = cam.CFrame
    local origin = cf.Position
    local look   = cf.LookVector
    local dir
    if UserInputService.MouseEnabled then
        local ml = UserInputService:GetMouseLocation()
        dir = cam:ScreenPointToRay(ml.X, ml.Y).Direction
    else
        local vp = cam.ViewportSize
        dir = cam:ViewportPointToRay(vp.X * 0.5, vp.Y * 0.5).Direction
    end
    local bestScore, bestModel = -math.huge, nil
    for _, m in ipairs(list) do
        local delta = m.PrimaryPart.Position - origin
        if delta.Magnitude > 0 then
            local unit = delta.Unit
            if look:Dot(unit) > 0 then
                local score = dir:Dot(unit)
                if bestScore < score then bestScore = score; bestModel = m end
            end
        end
    end
    bestModel = bestModel or list[1]
    _apTarget.current = bestModel
    return bestModel
end
local function apGetCurveCF()
    local cam  = Workspace.CurrentCamera
    local cf   = cam.CFrame
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return cf end
    if LockEnabled and LockTarget ~= "None" then
        local lockPart = findPart(LockTarget)
        if lockPart then return CFrame.new(root.Position, lockPart.Position) end
    end
    local tp        = _apTarget.current and _apTarget.current.PrimaryPart
    local targetPos = tp and tp.Position
    if not targetPos then
        local ball = apFirstBall()
        if ball then
            local z = ball:FindFirstChild("zoomies")
            if z then
                local v = z.VectorVelocity
                if v.Magnitude > 1 then
                    targetPos = root.Position - v.Unit * 100
                end
            end
        end
    end
    if not targetPos then
        targetPos = root.Position + cf.LookVector * 1000
    end
    local delta     = targetPos - root.Position
    local unit      = delta.Magnitude > 0.001 and delta.Unit or root.CFrame.LookVector
    local method    = tostring(CurveMode or "Camera"):lower()
    if method == "dot" then
        return CFrame.lookAt(root.Position, targetPos + Vector3.new(0, 1.75, 0))
    elseif method == "backwards" then
        return CFrame.new(root.Position, root.Position + -unit * 1000)
    elseif method == "slow" then
        return CFrame.new(root.Position, root.Position + Vector3.new(0, -350, 0))
    elseif method == "random" then
        return CFrame.new(root.Position, targetPos + Vector3.new(
            math.random(-1000, 1000), math.random(-350, 1000), math.random(-1000, 1000)))
    elseif method == "nearest" then
        return CFrame.new(root.Position, targetPos)
    elseif method == "accel" then
        return CFrame.new(root.Position, targetPos + Vector3.new(0, 5, 0))
    elseif method == "high" then
        return CFrame.new(root.Position, targetPos + Vector3.new(0, 9e18, 0))
    elseif method == "normal" then
        return CFrame.new(root.Position, root.Position + root.CFrame.LookVector * 1000)
    elseif method == "speed" then
        return CFrame.new(root.Position, root.Position + root.CFrame.UpVector * 100)
    elseif method == "down" then
        return CFrame.new(root.Position, root.Position + Vector3.new(0, -9e9, 0))
    elseif method == "left" then
        return CFrame.new(root.Position, root.Position - root.CFrame.RightVector * 9e9)
    elseif method == "right" then
        return CFrame.new(root.Position, root.Position + root.CFrame.RightVector * 9e9)
    end
    return cf
end
local _apFireCount = 0
local function apFire()
    apByMouse()
    local cam = Workspace.CurrentCamera
    local rcf = apGetCurveCF()
    local targetPart = _apTarget.current and _apTarget.current.PrimaryPart
    local mp
    if targetPart then
        local sp = cam:WorldToViewportPoint(targetPart.Position)
        mp = { sp.X, sp.Y }
    elseif UserInputService.MouseEnabled then
        local ml = UserInputService:GetMouseLocation()
        mp = { ml.X, ml.Y }
    else
        local vp = cam.ViewportSize
        mp = { vp.X * 0.5, vp.Y * 0.5 }
    end
    local ed = {}
    local af = Workspace:FindFirstChild("Alive")
    if af then
        for _, m in ipairs(af:GetChildren()) do
            local pp = m.PrimaryPart
            if pp then
                local sp = cam:WorldToScreenPoint(pp.Position)
                if sp and sp.Z > 0 then ed[m.Name] = sp end
            end
        end
    end
    if not _remote or not _args or not _tokenFound then return false end
    local ok = pcall(function()
        _remote:FireServer(_args[1], _args[2], _tokenize(_args[2]),
            0.5, rcf, ed, mp, false)
    end)
    if _apFireCount > 7 then return false end
    _apFireCount += 1
    task.delay(0.5, function()
        if _apFireCount > 0 then _apFireCount -= 1 end
    end)
    return ok
end
local function apCurved(ball)
    local b = ball or apFirstBall()
    if not b then return false end
    local z = b:FindFirstChild("zoomies")
    if not z then return false end
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return false end
    local now  = tick()
    local ping = getPing()
    local vel  = z.VectorVelocity
    local spd  = vel.Magnitude
    if spd < 1 then return false end
    local unit  = vel.Unit
    local pos   = char.PrimaryPart.Position
    local bPos  = apPosition(b)
    local unit2 = (pos - bPos).Unit
    local dot   = unit2:Dot(unit)
    local v90   = math.min(spd / 100, 40)
    local n31   = dot - unit2:Dot((unit - vel).Unit)
    local dist  = (pos - bPos).Magnitude
    local n32   = 0.5 - ping / 1000
    local n33   = dist / spd - ping / 1000
    local n34   = 15 - math.min(dist / 1000, 15) + v90
    _apState.LerpRadians = _apState.LerpRadians
        + (math.rad(math.asin(math.clamp(dot, -1, 1))) - _apState.LerpRadians) * 0.8
    if spd > 100 and n33 > ping / 10 then
        n34 = math.max(n34 - 15, 15)
    end
    if dist < n34 then return false end
    if n31 < n32 then return true end
    if _apState.LerpRadians < 0.018 then
        _apState.LastWarping = now
    end
    if now - _apState.LastWarping < n33 / 1.5 then return true end
    if now - _apState.Curving    < n33 / 1.5 then return true end
    return dot < n32
end
local function apAccuracy()
    return (AP_Acc - 1) * 0.015151515151515152
end
local _apDebounce = false
local _apUntilAt  = 0
getgenv().qzxp_resetAPState = function()
    _apDebounce    = false
    _apUntilAt     = 0
    AnimLastPlayed = 0
    pcall(function() clearAPLockout() end)
end

local function getClosestPlayer()
    local alive = Workspace:FindFirstChild("Alive")
    if not alive then return nil end
    local char = LocalPlayer.Character
    if not char or char.Parent ~= alive or not char.PrimaryPart then return nil end
    local closest, closestDist = nil, math.huge
    for _, child in ipairs(alive:GetChildren()) do
        if child ~= char and child.Name ~= LocalPlayer.Name
           and child:FindFirstChild("HumanoidRootPart")
           and isRealPlayerModel(child) then
            local dist = (char.PrimaryPart.Position - child.HumanoidRootPart.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = child
            end
        end
    end
    return closest
end

local function getEntityProperties()
    local closest = getClosestPlayer()
    if not closest then return nil end
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return nil end
    local root  = char.PrimaryPart
    local other = closest.HumanoidRootPart
    return {
        Velocity  = other.AssemblyLinearVelocity,
        Direction = (root.Position - other.Position).Unit,
        Distance  = (root.Position - other.Position).Magnitude,
    }
end

local function getBallProperties(ball)
    if not ball then return nil end
    local z = ball:FindFirstChild("zoomies")
    if not z then return nil end
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return nil end
    local vel     = z.VectorVelocity
    local rootPos = char.PrimaryPart.Position
    local pos     = ball.Position
    local unit    = (rootPos - pos).Unit
    return {
        Speed     = vel.Magnitude,
        Velocity  = vel,
        Direction = unit,
        Distance  = (rootPos - pos).Magnitude,
        Dot       = unit:Dot(vel.Unit),
    }
end

local function spamService(ball, ping)
    if not ball then return 0 end
    local z = ball:FindFirstChild("zoomies")
    if not z then return 0 end
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return 0 end
    local vel   = z.VectorVelocity
    local speed = vel.Magnitude
    local rootPos = char.PrimaryPart.Position
    local pos     = ball.Position
    local dot     = (rootPos - pos).Unit:Dot(vel.Unit)
    local threshold = ping + math.min(speed / 4.5, 120) + 6 
    local ballProps   = getBallProperties(ball)
    local entityProps = getEntityProperties()
    if not ballProps or not entityProps then return 0 end
    if entityProps.Distance > threshold or ballProps.Distance > threshold then return 0 end
    local mult = 8 - math.min(speed / 4, 8)
    return (threshold + 6) - math.clamp(dot, -1, 0) * mult
end

local function apCheck()
    if not AP_On or TB_On or Spam_On then return end
    if _frameBlockOk == nil then _frameBlockOk = IsBlockLegit() end
    if not _frameBlockOk then return end
    local blocked = (InfDet and InfOn) or (DSDet and DSOn) or (THDet and THOn) or (SFDet and SFOn)
    if blocked then return end
    local char = LocalPlayer.Character
    local root = char and char.PrimaryPart
    if not root then return end
    local now = tick()
    if _apDebounce or now < _apUntilAt then return end
    local pos       = root.Position
    local pingDist  = math.clamp(getPing() / 100, 5, 17)
    local firstBall = apFirstBall()
    local firstTarget = firstBall and firstBall:GetAttribute("target")
    local runtime  = Workspace:FindFirstChild("Runtime")
    local tornado  = runtime and runtime:FindFirstChild("Tornado")
    local tornadoT = tornado and (tornado:GetAttribute("TornadoTime") or 1)
    local acc = apAccuracy()
    for _, ball in ipairs(getAllBalls()) do
        if not ball then return end
        local z = ball:FindFirstChild("zoomies")
        if not z then return end
        local target = ball:GetAttribute("target")
        local spd    = z.VectorVelocity.Magnitude
        local dist   = (pos - apPosition(ball)).Magnitude
        local n31    = (2.4 + math.min(math.max(spd - 9.5, 0), 650) * 0.002) * acc
        if ball:FindFirstChild("AeroDynamicSlashVFX") then
            ball.AeroDynamicSlashVFX:Destroy()
            _apState.AerodynamicTime = now
        end
        if tornado and now - _apState.AerodynamicTime < tornadoT + 0.314159 then
            return
        end
        if firstTarget == _lpName and apCurved(ball) then
            return
        end
        if target == _lpName
           and dist <= pingDist + math.max(spd / n31, 9.5)
           and acc * 0.8 then
            if apFire() then
                _apLastFire = os.clock()
                if AnimFix_AP then PlaySingleParryAnimation() end
                _apDebounce = true
                _apUntilAt  = now + 1

                local sr = spamService(ball, math.clamp(getPing() / 10, 5, 17))
                if sr and sr ~= 0 then
                    task.delay(0.65, function()
                        if Parries >= 7 then return end
                        Parries += 1
                        task.delay(0.5, function()
                            if Parries > 0 then Parries -= 1 end
                        end)
                    end)
                end
            end
        end
    end
end
do
    local function watchBalls(folder)
        if not folder then return end
        for _, ball in ipairs(folder:GetChildren()) do
            ball:GetAttributeChangedSignal("target"):Connect(function()
                _apDebounce = false
                _apUntilAt  = 0
            end)
        end
        folder.ChildAdded:Connect(function(ball)
            _apDebounce = false
            _apUntilAt  = 0
            ball:GetAttributeChangedSignal("target"):Connect(function()
                _apDebounce = false
                _apUntilAt  = 0
            end)
        end)
        folder.ChildRemoved:Connect(function()
            _apDebounce = false
            _apUntilAt  = 0
            _apTarget.current = nil
            _apTarget.visited = {}
        end)
    end
    watchBalls(Workspace:FindFirstChild("Balls"))
    watchBalls(Workspace:FindFirstChild("TrainingBalls"))
end
pcall(function()
    ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(_, hitPart)
        local char = LocalPlayer.Character
        if not char or not char.PrimaryPart then return end
        local ball = apFirstBall()
        if not ball then return end
        local z = ball:FindFirstChild("zoomies")
        if not z then return end
        local spd = z.VectorVelocity.Magnitude
        if spd < 1 then return end
        local dist = (char.PrimaryPart.Position - apPosition(ball)).Magnitude
        local ping = getPing()
        local n31  = dist / spd - ping / 1000
        local n32  = 15 - math.min(dist / 1000, 15) + math.min(spd / 100, 40)
        if spd > 100 and n31 > ping / 10 then
            n32 = math.max(n32 - 15, 15)
        end
        if hitPart ~= char.PrimaryPart and dist > n32 then
            _apState.Curving = tick()
        end
    end)
end)
addPostSimHandler(apCheck, 2)

addPostSimHandler(function()
    if not AutoSpam_On or not AP_On then return end
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return end
    if char.Parent ~= Workspace:FindFirstChild("Alive") then return end

    local hotbar = LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("Hotbar")
    local visible = hotbar and hotbar:FindFirstChild("Ability")
        and hotbar.Ability:FindFirstChild("Duration") and hotbar.Ability.Duration.Visible
    local abilities = char:FindFirstChild("Abilities")
    local infinity = abilities and abilities:FindFirstChild("Infinity")
    infinity = infinity and infinity.Enabled and visible and InfinityBallRaw
    if infinity then Parries = 0; return end
    local timeHole = abilities and abilities:FindFirstChild("Time Hole")
    timeHole = timeHole and timeHole.Enabled and visible
    if timeHole then Parries = 0; return end

    local ball = getBall()
    if not ball or not ball:FindFirstChild("zoomies") then return end

    local ping     = math.clamp(getPing() / 10, 10, 16.5)
    local spamDist = spamService(ball, ping)
    if spamDist == 0 then return end

    if (char.PrimaryPart.Position - ball.Position).Magnitude <= spamDist
       and Parries >= ClashingThreshold then
        if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
            PlayParryAnimation()
        else
            PlaySingleParryAnimation()
        end
        fireRemote(ball)
    end
end, 5)
end

-- Parry range visualizer
local PRV = {
    On = false, Model = nil, Segments = {}, SEG_COUNT = 48,
    COLOR = Color3.fromRGB(255, 255, 255), TRANSPARENCY = 0.35,
}
function PRV.Destroy()
    if PRV.Model then pcall(function() PRV.Model:Destroy() end) end
    PRV.Model = nil
    PRV.Segments = {}
end
function PRV.Ensure()
    if PRV.Model then return end
    local m = Instance.new("Model")
    m.Name = "qzxp_ParryRange"
    m.Parent = Workspace
    PRV.Model = m
    for i = 1, PRV.SEG_COUNT do
        local p = Instance.new("Part")
        p.Name = "Seg" .. i
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.CastShadow = false
        p.Material = Enum.Material.Neon
        p.Color = PRV.COLOR
        p.Transparency = PRV.TRANSPARENCY
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Size = Vector3.new(0.2, 0.08, 1)
        p.Parent = m
        PRV.Segments[i] = p
    end
end
function PRV.Draw(center, radius)
    PRV.Ensure()
    if not PRV.Model or #PRV.Segments == 0 then return end
    local thickness = math.clamp(radius * 0.02, 0.15, 0.6)
    local segLen = (2 * math.pi * radius) / PRV.SEG_COUNT * 1.12
    local y = center.Y - 2.5
    for i = 1, PRV.SEG_COUNT do
        local phi = (i - 1) / PRV.SEG_COUNT * math.pi * 2
        local x = center.X + math.cos(phi) * radius
        local z = center.Z + math.sin(phi) * radius
        local seg = PRV.Segments[i]
        seg.Size = Vector3.new(thickness, 0.08, segLen)
        seg.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, -phi, 0)
    end
end
addHeartbeatHandler(function()
    if not PRV.On then
        if PRV.Model then PRV.Destroy() end
        return
    end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local ball = getBall()
    local z = ball and ball.Parent and ball:FindFirstChild("zoomies")
    if not root or not z then
        if PRV.Model then PRV.Model.Parent = nil end
        return
    end
    local radius = computeTriggerDist(z.VectorVelocity.Magnitude, getPing(), isCurvedCached(ball), AP_Acc)
    PRV.Draw(root.Position, radius)
    if PRV.Model and PRV.Model.Parent ~= Workspace then PRV.Model.Parent = Workspace end
end, 6)

-- Triggerbot
local function tryTBForBall(ball)
    if not TB_On or Spam_On or not ball or not ball.Parent then return end
    if isAPLocked() then return end
    if ball:GetAttribute('target') ~= _lpName then return end
    if not IsBlockLegit() then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or root:FindFirstChild('SingularityCape') then return end
    if ball:FindFirstChild('AeroDynamicSlashVFX') then ball.AeroDynamicSlashVFX:Destroy() end
    if ball:FindFirstChild('ComboCounter') then return end
    local blocked = (InfDet and InfOn) or (DSDet and DSOn) or (THDet and THOn) or (SFDet and SFOn)
    if blocked then return end
    local fired = fireRemote(ball)
    if fired then
        _tbLastFire = os.clock()
        setAPLockout(ball)
        if AnimFix_TB then PlaySingleParryAnimation() end
    end
end
addPostSimHandler(function()
    if not TB_On or Spam_On then return end
    if _frameBlockOk == nil then _frameBlockOk = IsBlockLegit() end
    if not _frameBlockOk then return end
    if isAPLocked() then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or root:FindFirstChild('SingularityCape') then return end
    local balls = getAllBalls()
    for _, ball in pairs(balls) do
        if ball:GetAttribute('target') ~= _lpName then continue end
        if ball:FindFirstChild('ComboCounter') then continue end
        local blocked = (InfDet and InfOn) or (DSDet and DSOn) or (THDet and THOn) or (SFDet and SFOn)
        if blocked then continue end
        local fired = fireRemote(ball)
        if fired then
            _tbLastFire = os.clock()
            setAPLockout(ball)
            if AnimFix_TB then PlaySingleParryAnimation() end
            break
        end
    end
end, 3)
local _tbConns = setmetatable({}, {__mode = "k"})
local function _attachTB(ball)
    if not ball or _tbConns[ball] then return end
    if not ball:GetAttribute('realBall') then
        local waitConn
        waitConn = ball:GetAttributeChangedSignal('realBall'):Connect(function()
            if ball:GetAttribute('realBall') then
                if waitConn then pcall(function() waitConn:Disconnect() end) end
                _attachTB(ball)
            end
        end)
        ball.Destroying:Once(function()
            if waitConn then pcall(function() waitConn:Disconnect() end) end
        end)
        return
    end
    local conn
    conn = ball:GetAttributeChangedSignal('target'):Connect(function()
        if ball:GetAttribute('target') == _lpName then
            tryTBForBall(ball)
            task.defer(function()
                if TB_On and ball and ball.Parent and ball:GetAttribute('target') == _lpName then
                    tryTBForBall(ball)
                end
            end)
        end
    end)
    _tbConns[ball] = conn
    ball.Destroying:Once(function()
        if conn then pcall(function() conn:Disconnect() end) end
        _tbConns[ball] = nil
    end)
end
spawnTracked(function()
    local function watchFolder(folder)
        if not folder then return end
        for _, ball in ipairs(folder:GetChildren()) do _attachTB(ball) end
        folder.ChildAdded:Connect(function(child) task.defer(_attachTB, child) end)
    end
    watchFolder(Workspace:WaitForChild('Balls', 9e9))
    watchFolder(Workspace:WaitForChild('TrainingBalls', 30))
end)

-- Spam engine
local SpamRPS, SpamInt, SpamDetect = 100, 0.01, true
local function spamOk()
    if not SpamDetect then return true end
    local blocked = (InfDet and InfOn) or (DSDet and DSOn) or (THDet and THOn) or (SFDet and SFOn)
    if blocked then return false end
    return true
end
local timeAccumulator = 0
addPostSimHandler(function(dt)
    if not Spam_On then timeAccumulator = 0 return end
    if _frameBlockOk == nil then _frameBlockOk = IsBlockLegit() end
    if not _frameBlockOk then timeAccumulator = 0 return end
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart or char.PrimaryPart:FindFirstChild('SingularityCape') then
        timeAccumulator = 0; return
    end
    if not spamOk() then timeAccumulator = 0 return end
    local interval = (SpamInt and SpamInt > 0) and SpamInt or 0.01
    timeAccumulator += dt
    if timeAccumulator >= interval then
        local fires = math.floor(timeAccumulator / interval)
        timeAccumulator -= fires * interval
        local ball = getBall()
        if ball then
            for _ = 1, fires do fireRemote(ball) end
        end
        if AnimFix_Spam then PlaySingleParryAnimation() end
    end
end, 4)

-- ============================================================
-- SWORD CHANGER (fixed revert + real-sword tracking)
-- ============================================================
task.spawn(function()
local SKIN_KEY = "Skin.LastEquippedSword"
local CFG_FILE = "qzxp/auto_config.json"
local function readCfg()
    local d = {}
    pcall(function() if isfile and isfile(CFG_FILE) then d = HttpService:JSONDecode(readfile(CFG_FILE)) end end)
    return type(d) == "table" and d or {}
end
local function writeCfg(d)
    pcall(function()
        if isfolder and makefolder and not isfolder("qzxp") then makefolder("qzxp") end
        if writefile then writefile(CFG_FILE, HttpService:JSONEncode(d or {})) end
    end)
end
local function loadSaved() local d = readCfg(); local s = d[SKIN_KEY]; return type(s) == "string" and s or "" end
getgenv().saveLastEquippedSword = function(n)
    if type(n) ~= "string" or n == "" then return end
    local d = readCfg(); d[SKIN_KEY] = n; writeCfg(d)
end
local s = loadSaved()
do
    getgenv().skinChanger = false
    getgenv().swordModel = type(getgenv().swordModel) == "string" and getgenv().swordModel ~= "" and getgenv().swordModel or s
    getgenv().swordAnimations = type(getgenv().swordAnimations) == "string" and getgenv().swordAnimations ~= "" and getgenv().swordAnimations or s
    getgenv().swordFX = type(getgenv().swordFX) == "string" and getgenv().swordFX ~= "" and getgenv().swordFX or s
end

local realSword = ""
local _realSwordConn = nil
local function trackReal()
    local c = LocalPlayer.Character; if not c then return end
    if _realSwordConn then pcall(function() _realSwordConn:Disconnect() end) end
    _realSwordConn = c:GetAttributeChangedSignal("CurrentlyEquippedSword"):Connect(function()
        if not getgenv().skinChanger and not getgenv().qzxp_unlockAllActive then
            realSword = c:GetAttribute("CurrentlyEquippedSword") or ""
            getgenv().qzxp_realSword = realSword
        end
    end)
end
local function captureRealSword()
    local c = LocalPlayer.Character; if not c then return end
    local s = c:GetAttribute("CurrentlyEquippedSword")
    if s and s ~= "" and (not realSword or realSword == "") then
        realSword = s
        getgenv().qzxp_realSword = s
    end
end
LocalPlayer.CharacterAdded:Connect(function(char)
    task.defer(function()
        task.wait(0.2)
        if not char or not char.Parent then return end
        captureRealSword()
        trackReal()
    end)
end)
if LocalPlayer.Character then
    task.defer(function()
        task.wait(0.2)
        captureRealSword()
        trackReal()
    end)
end

local rs = ReplicatedStorage
local sc
spawnTracked(function()
    while task.wait(0.5) and not sc do
        local ok, cn = pcall(getconnections, rs.Remotes.FireSwordInfo.OnClientEvent)
        if ok and cn then
            for _, v in ipairs(cn) do
                if v.Function and islclosure and islclosure(v.Function) then
                    local ok2, up = pcall(getupvalues, v.Function)
                    if ok2 and #up == 1 and type(up[1]) == "table" then sc = up[1]; break end
                end
            end
        end
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

local function equip(name, notifyServer)
    if not name or name == "" then return false end
    if notifyServer == nil then notifyServer = false end
    if not LocalPlayer.Character then return false end
    local exact = resolve(name)
    LocalPlayer:SetAttribute("CurrentlyEquippedSword", exact)
    LocalPlayer.Character:SetAttribute("CurrentlyEquippedSword", exact)
    pcall(function()
        local f = swordModule.EquipSwordTo or rawget(swordModule, "EquipSwordTo")
        if type(f) == "function" then
            for k, v in pairs(getupvalues(f)) do
                if v == true then setupvalue(f, k, false); break end
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
            if notifyServer and rs.Remotes:FindFirstChild("FireSwordInfo") then
                rs.Remotes.FireSwordInfo:FireServer(exact)
            end
            if sc.currentSword ~= nil then pcall(function() sc.currentSword = exact end) end
            if sc.SwordFX ~= nil then pcall(function() sc.SwordFX = exact end) end
        end)
    end)
    return true
end
getgenv().updateSword = function()
    refreshSlash()
    AnimFix_Cache = {}
    if getgenv().skinChanger and getgenv().swordModel ~= "" then
        getgenv().saveLastEquippedSword(getgenv().swordModel)
        equip(getgenv().swordModel, false)
    end
end
getgenv().revertSword = function()
    getgenv().skinChanger = false
    getgenv().skinChangerEnabled = false
    AnimFix_Cache = {}
    if getgenv().qzxp_unlockAllActive then
        local ua = getgenv().qzxp_UA
        if ua and ua.selected_sword and ua.selected_sword ~= "" then
            getgenv().swordModel = ua.selected_sword
            getgenv().swordAnimations = ua.selected_sword
            getgenv().swordFX = ua.selected_sword
            refreshSlash()
            equip(ua.selected_sword, false)
        end
    elseif realSword ~= "" then
        getgenv().swordModel = realSword
        getgenv().swordAnimations = realSword
        getgenv().swordFX = realSword
        refreshSlash()
        equip(realSword, true)
    end
end

spawnTracked(function()
    while task.wait(0.5) do
        if getgenv().skinChanger and getgenv().swordModel ~= "" then
            local char = LocalPlayer.Character
            if char then
                local want = resolve(getgenv().swordModel)
                if want ~= "" and char:GetAttribute("CurrentlyEquippedSword") ~= want then
                    pcall(function() char:SetAttribute("CurrentlyEquippedSword", want) end)
                    pcall(function() LocalPlayer:SetAttribute("CurrentlyEquippedSword", want) end)
                end
            end
        end
    end
end)

-- VFX hooker
local hooked = getgenv().qzxp_VFXHooked
local vfxConns = getgenv().qzxp_VFXConns
local vfxDisabled = getgenv().qzxp_VFXDisabled
local lastPlaySoundTime = 0
local _vfxScanConn = nil
spawnTracked(function()
    local remotes = {"ParrySuccessAll", "ParryAttempt", "ParrySuccess", "PlaySound", "PlayVisuals"}
    local scanned = {}
    while task.wait(5) do
        for _, rn in ipairs(remotes) do
            local rem = rs.Remotes:FindFirstChild(rn)
            if rem and rem:IsA("RemoteEvent") then
                local ok, cn = pcall(getconnections, rem.OnClientEvent)
                if ok and type(cn) == "table" then
                    for _, v in ipairs(cn) do
                        local fn = v.Function
                        if fn and not hooked[fn] and not scanned[v] then
                            scanned[v] = true; hooked[fn] = true; v:Disable()
                            table.insert(vfxDisabled, v)
                            local target = fn
                            local rnLocal = rn
                            local ours = function(...)
                                local args = {...}
                                if rnLocal == "PlaySound" then
                                    local now = os.clock()
                                    if (now - lastPlaySoundTime) < 0.15 then return end
                                    lastPlaySoundTime = now
                                end
                                local isMe = false
                                for _, a in ipairs(args) do
                                    if tostring(a) == _lpName or (typeof(a) == "Instance" and (a == LocalPlayer.Character or a == LocalPlayer)) then isMe = true; break end
                                end
                                if isMe and (getgenv().skinChanger or getgenv().qzxp_unlockAllActive) then
                                    local fx = getgenv().swordFX ~= "" and getgenv().swordFX or getgenv().swordModel
                                    refreshSlash()
                                    local sf, slF = false, false
                                    for i, a in ipairs(args) do
                                        if type(a) == "string" then
                                            if fx ~= "" and not slF and (a:match("Slash") or a == "Default" or a:match("Effect")) then
                                                args[i] = getgenv().slashName; slF = true
                                            elseif fx ~= "" and not sf then
                                                local isSw = false
                                                pcall(function()
                                                    if rs.Shared.ReplicatedInstances.Swords:FindFirstChild(resolve(a)) or SwordRegistry[norm(a)] then isSw = true end
                                                end)
                                                if isSw or a == LocalPlayer:GetAttribute("CurrentlyEquippedSword") then args[i] = fx; sf = true end
                                            end
                                        end
                                    end
                                    if fx ~= "" and not slF and type(args[1]) == "string" then args[1] = getgenv().slashName end
                                    if fx ~= "" and not sf and type(args[3]) == "string" then args[3] = fx end
                                end
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

LocalPlayer.CharacterAdded:Connect(function()
    if (getgenv().skinChanger or getgenv().qzxp_unlockAllActive) and getgenv().swordModel ~= "" then
        task.wait(2)
        local char = LocalPlayer.Character
        if char then
            local exact = resolve(getgenv().swordModel)
            if exact and exact ~= "" then
                if LocalPlayer:GetAttribute("CurrentlyEquippedSword") ~= exact then equip(exact, false) end
                if not char:FindFirstChild(exact) then equip(exact, false) end
                for _, v in pairs(char:GetChildren()) do
                    if v:IsA("Model") and v.Name ~= exact and SwordRegistryReverse[v.Name] then
                        pcall(function() v:Destroy() end)
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

getgenv().qzxp_equipSword   = equip
getgenv().qzxp_resolveSword = resolve
getgenv().qzxp_forceEquipSword = function(name)
    if type(name) ~= "string" or name == "" then return false end
    getgenv().swordModel      = name
    getgenv().swordAnimations = name
    getgenv().swordFX         = name
    pcall(getgenv().saveLastEquippedSword, name)
    refreshSlash()
    AnimFix_Cache = {}
    equip(name, false)
    return true
end
end)

-- ============================================================
-- UNLOCK ALL (fixed revert + ownership detection)
-- ============================================================
local UA
task.spawn(function()
UA = {
    enabled            = false,
    ready              = false,
    shop_controller    = nil,
    shop_api           = nil,
    shop               = nil,
    swords             = nil,
    sword_fn           = nil,
    play_parry         = nil,
    selected_sword     = nil,
    original_sword     = nil,
    last_equipped_sword = "",
    chroma_bound       = false,
    character_connection = nil,
    sword_attr_connection = nil,
    modern_tag         = "qzxp_unlock_all",
    original_set_equipped = nil,
    original_buy_fns   = {},
    unlock_originals   = setmetatable({}, {__mode = "k"}),
    modern_originals   = setmetatable({}, {__mode = "k"}),
    page_connections   = {},
    refresh_generation = {},
    unlocked           = {},
    parry_connections  = {},
    fire_connections   = {},
    deleted_swords     = {},
    _lastError         = nil,
    _savedButtonState  = {},
    original_buy_conns = {},
}
do
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local psAll = remotes:FindFirstChild("ParrySuccessAll")
        if psAll and psAll:IsA("RemoteEvent") then
            local ok, conns = pcall(getconnections, psAll.OnClientEvent)
            if ok and type(conns) == "table" then
                for _, c in ipairs(conns) do
                    local ok2, fn = pcall(function() return c.Function end)
                    if ok2 and type(fn) == "function" then
                        table.insert(UA.parry_connections, c)
                        UA.play_parry = fn
                    end
                end
            end
        end
        local fsi = remotes:FindFirstChild("FireSwordInfo")
        if fsi and fsi:IsA("RemoteEvent") then
            local ok, conns = pcall(getconnections, fsi.OnClientEvent)
            if ok and type(conns) == "table" then
                for _, c in ipairs(conns) do
                    local ok2, fn = pcall(function() return c.Function end)
                    if ok2 and type(fn) == "function" then
                        table.insert(UA.fire_connections, c)
                        UA.sword_fn = fn
                    end
                end
            end
        end
    end
end
function UA.set_sword_override(_, on)
    for _, c in ipairs(UA.fire_connections) do
        pcall(function()
            if on then c:Disable() else c:Enable() end
        end)
    end
end
function UA.apply_chroma(_, model, sword)
    local colorConfig = sword.ColorConfig or sword.TweenColorConfig
    if not colorConfig and (sword.Name:find("Chroma") or sword.Name:find("Rainbow")) then
        colorConfig = "Chroma"
    end
    if colorConfig then
        pcall(function()
            model:SetAttribute("ColorConfig", colorConfig)
            model:AddTag("TweenColor")
        end)
    end
end
function UA.set_category_unlock(_, category, unlock)
    if not UA.shop_controller then return end
    local virtual = UA.shop_controller._virtualItems[category]
    local page    = UA.shop_controller._inventoryPages[category]
    if type(virtual) ~= "table" then return end
    if page and page.BeginBatch then pcall(page.BeginBatch, page) end
    if unlock then
        UA.unlocked[category] = true
        local backed = {}
        for _, item in pairs(virtual) do
            if item.InventoryKey then backed[item.Name] = true end
        end
        for _, item in pairs(virtual) do
            if not UA.unlock_originals[item] then
                UA.unlock_originals[item] = {
                    Section = item.Section,
                    ForceHide = item.ForceHide,
                    OriginalLayoutOrder = item.OriginalLayoutOrder or item.LayoutOrder,
                }
            end
            local dirty = false
            local deleted = UA:is_deleted(category, item.Name)
            local targetSection = deleted and "Unowned" or "Owned"
            if item.Section ~= targetSection then item.Section = targetSection; dirty = true end
            if item.OwnsItem and type(item.OwnsItem.Set) == "function" then
                pcall(item.OwnsItem.Set, item.OwnsItem, not deleted)
            end
            local forceHide = not item.InventoryKey and backed[item.Name] or false
            if item.ForceHide ~= forceHide then item.ForceHide = forceHide; dirty = true end
            if dirty and page and page.MarkDirty then
                pcall(page.MarkDirty, page, item, false, true)
            end
        end
    else
        UA.unlocked[category] = nil
        for _, item in pairs(virtual) do
            local orig = UA.unlock_originals[item]
            if orig then
                local dirty = false
                if item.Section ~= orig.Section then item.Section = orig.Section; dirty = true end
                if item.ForceHide ~= orig.ForceHide then item.ForceHide = orig.ForceHide; dirty = true end
                if dirty and page and page.MarkDirty then
                    pcall(page.MarkDirty, page, item, false, true)
                end
                UA.unlock_originals[item] = nil
            end
        end
    end
    if page and page.MarkDirty then pcall(page.MarkDirty, page, nil, true, true) end
    if page and page.EndBatch then pcall(page.EndBatch, page) end
end
function UA.set_modern_unlock(_, category, unlock)
    local api = UA.shop_api
    local bases = api and api.OwnedBases and api.OwnedBases[category]
    if type(bases) ~= "table" then return end
    for name, base in pairs(bases) do
        local ok1, key = pcall(api.ParseItemKey, api, category, {Name = name})
        local copies = nil
        if ok1 and key then
            local ok2, data = pcall(api.GetItemData, api, category, key)
            if ok2 and type(data) == "table" then copies = data.OwnedCopies end
        end
        if unlock and copies and type(copies.Get) == "function" and type(copies.Set) == "function" then
            if not UA.modern_originals[copies] then
                local okG, cur = pcall(copies.Get, copies)
                if okG then UA.modern_originals[copies] = {Value = cur} end
            end
            local okG, cur = pcall(copies.Get, copies)
            if okG and (type(cur) ~= "number" or cur < 1) then
                pcall(copies.Set, copies, 1)
            end
        end
        if base and type(base.SetTag) == "function" then
            pcall(base.SetTag, base, UA.modern_tag, unlock and true or nil)
        end
        if not unlock and copies then
            local orig = UA.modern_originals[copies]
            if orig and type(copies.Set) == "function" then
                local bought = false
                if base and base.State and type(base.State.Get) == "function" then
                    local okS, s = pcall(base.State.Get, base.State)
                    bought = okS and s == true
                end
                if not bought then pcall(copies.Set, copies, orig.Value) end
                UA.modern_originals[copies] = nil
            end
        end
    end
end
function UA.expected_size(_, category)
    local n = 0
    if category == "Sword" and UA.swords then
        local ok, coll = pcall(function() return UA.swords:GetCollection() end)
        if ok and type(coll) == "table" then
            for _ in pairs(coll) do n = n + 1 end
        end
    elseif category == "Explosion" then
        local misc = ReplicatedStorage:FindFirstChild("Misc")
        misc = misc and misc:FindFirstChild("DataExplosions")
        if misc then
            for _, c in ipairs(misc:GetChildren()) do
                if not c:GetAttribute("Hidden") then n = n + 1 end
            end
        end
    end
    return n
end
function UA.schedule_refresh(_, category)
    UA.refresh_generation[category] = (UA.refresh_generation[category] or 0) + 1
    local myGen = UA.refresh_generation[category]
    if type(UA.shop_controller._loadInventoryPage) == "function" then
        pcall(UA.shop_controller._loadInventoryPage, category)
    end
    task.spawn(function()
        local expected = UA:expected_size(category)
        local lastCount, stable = -1, 0
        for _ = 1, 120 do
            RunService.Heartbeat:Wait()
            if not UA.enabled or not UA.unlocked[category] or UA.refresh_generation[category] ~= myGen then return end
            local virt = UA.shop_controller._virtualItems[category]
            local count = 0
            if type(virt) == "table" then
                for _, it in pairs(virt) do
                    if not it.InventoryKey then count = count + 1 end
                end
            end
            if count == lastCount and count > 0 then stable = stable + 1
            else stable = 0; lastCount = count end
            if (expected > 0 and count >= expected) or (expected == 0 and stable >= 5) then
                RunService.Heartbeat:Wait()
                UA:set_category_unlock(category, true)
                return
            end
        end
        if UA.enabled and UA.unlocked[category] and UA.refresh_generation[category] == myGen then
            UA:set_category_unlock(category, true)
        end
    end)
end

function UA.is_actually_owned(_, swordName)
    local virtual = UA.shop_controller
        and UA.shop_controller._virtualItems
        and UA.shop_controller._virtualItems["Sword"]
    if type(virtual) == "table" then
        for _, item in pairs(virtual) do
            if item.Name == swordName then
                local orig = UA.unlock_originals[item]
                if orig then return orig.Section == "Owned" end
                return item.Section == "Owned"
            end
        end
    end
    local api = UA.shop_api
    if api and api.OwnedBases and api.OwnedBases["Sword"] then
        local base = api.OwnedBases["Sword"][swordName]
        if base then
            local ok1, key = pcall(api.ParseItemKey, api, "Sword", {Name = swordName})
            if ok1 and key then
                local ok2, data = pcall(api.GetItemData, api, "Sword", key)
                if ok2 and type(data) == "table" and data.OwnedCopies then
                    local orig = UA.modern_originals[data.OwnedCopies]
                    if orig then
                        return type(orig.Value) == "number" and orig.Value >= 1
                    end
                    local okG, cur = pcall(data.OwnedCopies.Get, data.OwnedCopies)
                    if okG then return type(cur) == "number" and cur >= 1 end
                end
            end
        end
    end
    return false
end

function UA.equip_sword(_, swordName, restore)
    if type(swordName) ~= "string" or swordName == "" then return false end
    if not UA.swords then return false end
    local isEquip = not restore
    local isOwned = UA:is_actually_owned(swordName)
    if isEquip and UA:is_deleted("Sword", swordName) then
        UA:undelete_item("Sword", swordName)
    end
    local sword = UA.swords:GetSword(swordName)
    if not sword then return false end
    local character = LocalPlayer.Character
    if not character then return false end
    if isEquip and not UA.original_sword then
        local scReal = getgenv().qzxp_realSword
        if scReal and scReal ~= "" then
            UA.original_sword = scReal
        else
            UA.original_sword = LocalPlayer:GetAttribute("CurrentlyEquippedSword")
                             or character:GetAttribute("CurrentlyEquippedSword")
                             or ""
        end
    end
    if restore then
        UA.selected_sword = nil
    else
        UA.selected_sword = sword.Name
        UA.last_equipped_sword = sword.Name
        UA:set_sword_override(not isOwned)
        getgenv().qzxp_unlockAllActive = true
        getgenv().swordModel      = sword.Name
        getgenv().swordAnimations = sword.Name
        getgenv().swordFX         = sword.Name
        pcall(getgenv().saveLastEquippedSword, sword.Name)
    end
    LocalPlayer:SetAttribute("CurrentlyEquippedSword", sword.Name)
    character:SetAttribute("CurrentlyEquippedSword", sword.Name)
    pcall(function()
        local equipSwordTo = UA.swords.EquipSwordTo
        for k, v in pairs(getupvalues(equipSwordTo)) do
            if v == true then
                setupvalue(equipSwordTo, k, false)
                break
            end
        end
    end)
    if not pcall(function() UA.swords:EquipSwordTo(character, sword.Name) end) then
        return false
    end
    local model = character:FindFirstChild(sword.Name)
    if model then UA:apply_chroma(model, sword) end
    if isOwned then
        if ReplicatedStorage.Remotes:FindFirstChild("FireSwordInfo") then
            pcall(function()
                ReplicatedStorage.Remotes:FindFirstChild("FireSwordInfo"):FireServer(sword.Name)
            end)
        end
    end
    if UA.sword_fn then pcall(UA.sword_fn, sword.Name) end
    return true
end

function UA.restore_sword(_)
    local prev = UA.original_sword
    UA.original_sword = nil
    UA.selected_sword = nil
    UA:set_sword_override(false)
    getgenv().qzxp_unlockAllActive = false
    if getgenv().skinChanger and getgenv().swordModel ~= "" then
        pcall(getgenv().updateSword)
    elseif prev and prev ~= "" then
        UA:equip_sword(prev, true)
        getgenv().swordModel      = prev
        getgenv().swordAnimations = prev
        getgenv().swordFX         = prev
        if getgenv().slashName ~= nil then
            pcall(function() getgenv().slashName = prev end)
        end
    end
end

function UA.is_deleted(_, category, name)
    if category == "Sword" then return UA.deleted_swords[name] == true end
    return false
end
function UA.undelete_item(_, category, name)
    if category == "Sword" then UA.deleted_swords[name] = nil end
    UA:refresh_selected()
end
function UA.refresh_selected(_)
    if not UA.shop_controller or not UA.shop then return end
    local selectedItem = UA.shop_controller._selectedItem
    if not selectedItem then return end
    local holder   = UA.shop:FindFirstChild("Holder")
    local infoBG   = holder and holder:FindFirstChild("InfoBG")
    local buyButton = infoBG and infoBG:FindFirstChild("BuyButton")
    if not buyButton then return end
    local pt = buyButton:FindFirstChild("PriceTag")
    if not pt then return end
    local tl = pt:FindFirstChild("TextLabel")
    local pr = pt:FindFirstChild("Price")
    if not UA.enabled or not UA.unlocked[selectedItem.type] then
        local saved = UA._savedButtonState[selectedItem.name]
        if saved then
            buyButton.Visible = saved.buttonVisible
            if tl then tl.Visible = saved.textVisible; tl.Text = saved.text end
            if pr then pr.Visible = saved.priceVisible end
            UA._savedButtonState[selectedItem.name] = nil
        end
        return
    end
    if selectedItem.type ~= "Sword" and selectedItem.type ~= "Explosion" then return end
    local virtItem = nil
    local virtual = UA.shop_controller._virtualItems and UA.shop_controller._virtualItems[selectedItem.type]
    if virtual then
        virtItem = virtual[selectedItem.key or selectedItem.name]
    end
    if UA:is_deleted(selectedItem.type, selectedItem.name) or (virtItem and virtItem.Section == "Unowned") then
        buyButton.Visible = false
        return
    end
    if not UA._savedButtonState[selectedItem.name] then
        UA._savedButtonState[selectedItem.name] = {
            text         = tl and tl.Text or "",
            textVisible  = tl and tl.Visible or true,
            priceVisible = pr and pr.Visible or false,
            buttonVisible = buyButton.Visible,
        }
    end
    buyButton.Visible = true
    if tl then tl.Visible = true; tl.Text = "Equip" end
    if pr then pr.Visible = false end
end
function UA.hook_modern_shop(_)
    local api = UA.shop_api
    if not api or UA.original_set_equipped then return end
    if type(api.SetEquipped) ~= "function" then return end
    UA.original_set_equipped = api.SetEquipped
    api.SetEquipped = function(self, ...)
        local args = {...}
        local itemType, name = args[1], args[2]
        if type(itemType) == "table" then
            name = itemType.Name
            itemType = itemType.ItemType
        elseif type(name) == "table" then
            name = name.Name
        end
        if UA.enabled and (itemType == "Sword" or tostring(itemType):lower():find("sword")) then
            if UA:equip_sword(name, false) then return true end
        end
        return UA.original_set_equipped(self, unpack(args))
    end
end
function UA.hook_shop(_)
    local pg   = LocalPlayer:WaitForChild("PlayerGui")
    local shop = pg:FindFirstChild("Shop")
    if not shop then
        if not UA._shopWatchConn then
            UA._shopWatchConn = pg.ChildAdded:Connect(function(child)
                if child.Name == "Shop" and not UA._hookedBuy then
                    task.defer(function() UA:hook_shop() end)
                end
            end)
        end
        return false
    end
    if UA._hookedBuy and UA.shop == shop then return true end
    local holder   = shop:FindFirstChild("Holder")
    local infoBG   = holder and holder:FindFirstChild("InfoBG")
    local buyButton = infoBG and infoBG:FindFirstChild("BuyButton")
    if not buyButton then
        if not UA._shopChildConn then
            UA._shopChildConn = shop.DescendantAdded:Connect(function(d)
                if d.Name == "BuyButton" and not UA._hookedBuy then
                    task.defer(function() UA:hook_shop() end)
                end
            end)
        end
        return false
    end
    if UA._shopWatchConn then pcall(function() UA._shopWatchConn:Disconnect() end); UA._shopWatchConn = nil end
    if UA._shopChildConn then pcall(function() UA._shopChildConn:Disconnect() end); UA._shopChildConn = nil end
    UA._hookedBuy = true
    UA.shop = shop
    local ok, conns = pcall(getconnections, buyButton.Activated)
    if ok and type(conns) == "table" then
        for _, c in ipairs(conns) do
            if c.Function then
                table.insert(UA.original_buy_fns, c.Function)
                table.insert(UA.original_buy_conns, c)
            end
        end
    end
    buyButton.Activated:Connect(function()
        if not UA.enabled then return end
        local sel = UA.shop_controller and UA.shop_controller._selectedItem
        if not sel then return end
        if UA.unlocked[sel.type] then
            if sel.type == "Sword" then
                if UA:equip_sword(sel.name, false) then
                    if buyButton.PriceTag and buyButton.PriceTag.TextLabel then
                        buyButton.PriceTag.TextLabel.Text = "Equipped"
                    end
                end
                return
            end
        end
        for _, fn in ipairs(UA.original_buy_fns) do spawnTracked(fn) end
    end)
    if UA.shop_controller.itemSelected then
        UA.shop_controller.itemSelected:Connect(function(sel)
            if sel and UA.unlocked[sel.type] then
                UA:set_category_unlock(sel.type, true)
            end
            task.defer(function() UA:refresh_selected() end)
        end)
    end
    pcall(function()
        game:GetService("GuiService"):GetPropertyChangedSignal("SelectedObject"):Connect(function()
            if not UA.enabled or not UA.shop or not UA.shop.Enabled then return end
            task.defer(function() UA:refresh_selected() end)
        end)
    end)
    shop:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not shop.Enabled or not UA.enabled then return end
        for _, cat in ipairs({"Sword", "Explosion"}) do
            if UA.unlocked[cat] then UA:schedule_refresh(cat) end
        end
    end)
    if shop.Enabled and UA.enabled then
        task.defer(function()
            for _, cat in ipairs({"Sword", "Explosion"}) do
                if UA.unlocked[cat] then UA:schedule_refresh(cat) end
            end
        end)
    end
    return true
end
function UA.hook_chroma(_)
    if UA.chroma_bound then return end
    UA.chroma_bound = true
    UA.added_connection = LocalPlayer.CharacterAdded:Connect(function(character)
        UA:setup_character(character)
    end)
    if LocalPlayer.Character then
        task.defer(function() UA:setup_character(LocalPlayer.Character) end)
    end
    UA.sword_attr_connection = LocalPlayer:GetAttributeChangedSignal("CurrentlyEquippedSword"):Connect(function()
        if getgenv().skinChanger then return end
        local selected = UA.selected_sword
        if not UA.enabled or not selected then return end
        if LocalPlayer:GetAttribute("CurrentlyEquippedSword") == selected then return end
        LocalPlayer:SetAttribute("CurrentlyEquippedSword", selected)
        if LocalPlayer.Character then
            LocalPlayer.Character:SetAttribute("CurrentlyEquippedSword", selected)
        end
        if UA.sword_fn then pcall(UA.sword_fn, selected) end
    end)
end
function UA.setup_character(_, character)
    if UA.character_connection then
        pcall(function() UA.character_connection:Disconnect() end)
        UA.character_connection = nil
    end
    if not character then return end
    if UA.enabled and UA.last_equipped_sword ~= "" then
        task.defer(function()
            if UA.enabled and UA.last_equipped_sword ~= "" then
                UA:equip_sword(UA.last_equipped_sword, false)
            end
        end)
    end
    local function checkChild(child)
        if not UA.enabled or not child:IsA("Model") or not UA.swords or not UA.selected_sword then return end
        local sword = UA.swords:GetSword(child.Name)
        if not sword then return end
        if child.Name ~= UA.selected_sword then
            local sel = UA.selected_sword
            task.defer(function()
                if UA.enabled and UA.selected_sword == sel then
                    UA:equip_sword(sel, false)
                end
            end)
        else
            UA:apply_chroma(child, sword)
            if UA.sword_fn then
                task.defer(function()
                    if UA.enabled and UA.selected_sword == child.Name then
                        pcall(UA.sword_fn, child.Name)
                    end
                end)
            end
        end
    end
    UA.character_connection = character.ChildAdded:Connect(checkChild)
    for _, child in ipairs(character:GetChildren()) do checkChild(child) end
end
function UA.initialize(_)
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    shared = shared and shared:FindFirstChild("ReplicatedInstances")
    shared = shared and shared:FindFirstChild("Swords")
    if shared then
        local ok, res = pcall(require, shared)
        if ok then UA.swords = res end
    end
    local controllersRoot = ReplicatedStorage:FindFirstChild("Controllers")
    if not controllersRoot then
        pcall(function() controllersRoot = ReplicatedStorage:WaitForChild("Controllers", 5) end)
    end
    if not controllersRoot then UA._lastError = "no Controllers root"; return false end
    local ui = controllersRoot:FindFirstChild("UI")
    local scInst = ui and ui:FindFirstChild("ShopController")
    local saInst = ui and ui:FindFirstChild("ShopControllerAPI")
    if not scInst or not saInst then
        for _, d in ipairs(controllersRoot:GetDescendants()) do
            if not scInst and d.Name == "ShopController" and d:IsA("ModuleScript") then scInst = d end
            if not saInst and d.Name == "ShopControllerAPI" and d:IsA("ModuleScript") then saInst = d end
            if scInst and saInst then break end
        end
    end
    if not scInst and not saInst then UA._lastError = "no ShopController/ShopControllerAPI"; return false end
    local sc, sa
    if scInst then
        local ok, res = pcall(require, scInst)
        if ok and type(res) == "table" then sc = res end
    end
    if saInst then
        local ok, res = pcall(require, saInst)
        if ok and type(res) == "table" then sa = res end
    end
    if not sc and not sa then UA._lastError = "require failed"; return false end
    UA.shop_controller = sc
    UA.shop_api = sa
    UA:hook_chroma()
    if UA.shop_controller then UA:hook_shop() end
    if UA.shop_api then UA:hook_modern_shop() end
    UA.ready = true
    if getgenv().swordModel and getgenv().swordModel ~= "" and UA.last_equipped_sword == "" then
        UA.last_equipped_sword = getgenv().swordModel
    end
    UA:set_enabled(UA.enabled)
    return true
end
function UA.set_enabled(_, on)
    UA.enabled = on == true
    if not UA.ready then return end
    for _, c in ipairs(UA.original_buy_conns) do
        pcall(function()
            if UA.enabled then c:Disable() else c:Enable() end
        end)
    end
    for _, cat in ipairs({"Sword", "Explosion"}) do
        if UA.enabled then
            if UA.shop_controller then
                UA:set_category_unlock(cat, true)
                UA:schedule_refresh(cat)
            end
            UA:set_modern_unlock(cat, true)
        else
            if UA.shop_controller then
                UA.refresh_generation[cat] = (UA.refresh_generation[cat] or 0) + 1
                UA:set_category_unlock(cat, false)
            end
            UA:set_modern_unlock(cat, false)
        end
    end
    if not UA.enabled then
        UA:restore_sword()
    else
        UA:refresh_selected()
        if UA.last_equipped_sword ~= "" and UA.swords then
            task.defer(function()
                if UA.enabled and UA.last_equipped_sword ~= "" then
                    UA:equip_sword(UA.last_equipped_sword, false)
                end
            end)
        end
    end
end
task.spawn(function()
    for attempt = 1, 30 do
        if UA:initialize() then return end
        if attempt == 30 then
            warn("[qzxp] unlock all: gave up after 30 attempts. Last error: " .. tostring(UA._lastError))
        end
        task.wait(2)
    end
end)
getgenv().qzxp_UA = UA
end)

-- ============================================================
-- HEADLESS / KORBLOX
-- ============================================================
local HK = {
    Headless = false, Korblox = false,
    headBak = nil, kBuilt = {}, legBak = {},
}
do
local function rigType(c)
    if not c then return "R6" end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h and h.RigType == Enum.HumanoidRigType.R15 then return "R15" end
    if c:FindFirstChild("RightUpperLeg") then return "R15" end
    return "R6"
end
local function doHeadless()
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChild("Head"); if not h then return end
    if HK.headBak then
        local b = HK.headBak; HK.headBak = nil
        if b.p and b.p.Parent then pcall(function() b.p.Transparency = b.t; b.p.LocalTransparencyModifier = 0 end) end
        for _, e in ipairs(b.d) do if e.i and e.i.Parent then pcall(function() e.i.Transparency = e.t end) end end
    end
    HK.headBak = {p = h, t = h.Transparency, d = {}}
    pcall(function() h.Transparency = 1; h.LocalTransparencyModifier = 1 end)
    for _, d in ipairs(h:GetChildren()) do
        if d:IsA("Decal") or d:IsA("Texture") then
            table.insert(HK.headBak.d, {i=d, t=d.Transparency}); pcall(function() d.Transparency = 1 end)
        end
    end
    for _, a in ipairs(c:GetChildren()) do
        if a:IsA("Accessory") then
            local hdl = a:FindFirstChild("Handle")
            if hdl and (hdl:FindFirstChild("FaceFrontAttachment") or hdl:FindFirstChild("FaceCenterAttachment")) then
                table.insert(HK.headBak.d, {i=hdl, t=hdl.Transparency}); pcall(function() hdl.Transparency = 1 end)
                for _, d in ipairs(hdl:GetDescendants()) do
                    if d:IsA("Decal") or d:IsA("Texture") then
                        table.insert(HK.headBak.d, {i=d, t=d.Transparency}); pcall(function() d.Transparency = 1 end)
                    end
                end
            end
        end
    end
end
local function undoHeadless()
    if not HK.headBak then return end
    local b = HK.headBak; HK.headBak = nil
    if b.p and b.p.Parent then pcall(function() b.p.Transparency = b.t; b.p.LocalTransparencyModifier = 0 end) end
    for _, e in ipairs(b.d) do if e.i and e.i.Parent then pcall(function() e.i.Transparency = e.t end) end end
end
local function clearK()
    for _, e in ipairs(HK.kBuilt) do if typeof(e) == "Instance" then pcall(function() e:Destroy() end) end end
    HK.kBuilt = {}
end
local function restoreLegs()
    for _, e in ipairs(HK.legBak) do
        if e.p and e.p.Parent then pcall(function() e.p.Transparency = e.t; e.p.LocalTransparencyModifier = 0 end) end
    end
    HK.legBak = {}
end
local function cleanK(c)
    if not c then return end
    for _, d in ipairs(c:GetDescendants()) do
        if d.Name == "KorbloxRightLeg" or d.Name == "KorbloxWeld" or (d:IsA("BasePart") and d:GetAttribute("IceKorblox")) then
            pcall(function() d:Destroy() end)
        end
    end
end
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
    local fake = Instance.new("Part")
    fake.Name = "KorbloxRightLeg"; fake.Size = Vector3.new(1, 2, 1)
    fake.CanCollide = false; fake.CanQuery = false; fake.CanTouch = false; fake.Massless = true
    local ys = ty / 2
    local xzs = w * (1 + (ys - 1) * 0.5)
    local m = Instance.new("SpecialMesh")
    m.MeshType = Enum.MeshType.FileMesh
    m.MeshId = "rbxassetid://101851696"; m.TextureId = "rbxassetid://101851254"
    m.Scale = Vector3.new(xzs, ys, xzs); m.Parent = fake
    fake.Parent = c; pcall(function() fake:SetAttribute("IceKorblox", true) end)
    local weld = Instance.new("Weld")
    weld.Name = "KorbloxWeld"; weld.Part0 = anchor; weld.Part1 = fake
    weld.C0 = CFrame.new(0, anchor.Size.Y / 2 - ty / 2, 0); weld.Parent = fake
    for _, p in ipairs(parts) do
        table.insert(HK.legBak, {p=p, t=p.Transparency}); pcall(function() p.Transparency = 1; p.LocalTransparencyModifier = 1 end)
    end
    table.insert(HK.kBuilt, fake)
end
local function undoKorblox() clearK(); restoreLegs(); cleanK(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function()
    HK.headBak = nil; HK.kBuilt, HK.legBak = {}, {}
    task.wait(1)
    if HK.Korblox then doKorblox() end
    if HK.Headless then doHeadless() end
end)
HK.doHeadless = doHeadless; HK.undoHeadless = undoHeadless
HK.doKorblox = doKorblox; HK.undoKorblox = undoKorblox
end

-- ============================================================
-- FFLAGS TAB  (Quality / Lighting & World / Custom / Import-Export)
-- ============================================================
;(function()
local FFTab = Tabs.FFlags

-- ============ FF ENGINE ============
local FF = {
    canSet = type(setfflag) == "function",
    canGet = type(getfflag) == "function",
    orig = {}, key = {}, applied = {}, result = {},
}
do
    local PREFIXES = { "DFFlag", "DFInt", "DFString", "DFLog", "FFlag", "FInt", "FString", "FLog" }
    function FF.prefix(n)
        for _, p in ipairs(PREFIXES) do if n:sub(1, #p) == p and #n > #p then return p end end
    end
    function FF.strip(n) local p = FF.prefix(n); return p and n:sub(#p + 1) or n end
    function FF.norm(name, v)
        local p = FF.prefix(name) or ""
        v = tostring(v)
        if p:find("Flag") then
            local l = v:lower()
            if l == "true" or l == "1" then return "True" end
            if l == "false" or l == "0" then return "False" end
            return nil
        elseif p:find("Int") then
            local n = tonumber(v); if not n then return nil end
            return tostring(math.floor(n + 0.5))
        end
        return v
    end
    function FF.words(name)
        local s = FF.strip(name):gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")
            :gsub("(%d)(%a)", "%1 %2"):gsub("_", " ")
        local out = {}
        for w in s:gmatch("%S+") do table.insert(out, w:lower()) end
        return out
    end
    function FF.blocked(name)
        return nil
    end
    local function tryGet(n)
        if not FF.canGet then return nil end
        local ok, v = pcall(getfflag, n)
        if ok and v ~= nil then return tostring(v) end
    end
    function FF.get(name)
        local k = FF.key[name]
        if k then return tryGet(k), k end
        local v = tryGet(name); if v ~= nil then FF.key[name] = name return v, name end
        v = tryGet(FF.strip(name)); if v ~= nil then FF.key[name] = FF.strip(name) return v, FF.strip(name) end
    end
    local function same(a, b) return a ~= nil and b ~= nil and tostring(a):lower() == tostring(b):lower() end

    local function writeFlag(name, value)
        if not FF.canSet then return false, false end
        local v = FF.norm(name, value)
        if v == nil then return false, false end
        local p = FF.prefix(name) or ""
        local values = { v }
        if p:find("Flag") then
            table.insert(values, v:lower())
            table.insert(values, v == "True")
        elseif p:find("Int") then
            table.insert(values, tonumber(v))
        end
        local names, seen = {}, {}
        for _, n in ipairs({ FF.key[name], FF.strip(name), name }) do
            if n and not seen[n] then seen[n] = true; table.insert(names, n) end
        end
        local accepted, matched = false, false
        for _, n in ipairs(names) do
            for _, val in ipairs(values) do
                local okS, ret = pcall(setfflag, n, val)
                if okS and ret ~= false then
                    accepted = true
                    FF.key[name] = FF.key[name] or n
                    if not FF.canGet then break end
                    local back = tryGet(n)
                    if back ~= nil and same(back, v) then FF.key[name] = n; matched = true; break end
                end
            end
            if matched or (accepted and not FF.canGet) then break end
        end
        return accepted, matched
    end

    function FF.set(name, value)
        if not FF.canSet then FF.result[name] = "fail" return false end
        local v = FF.norm(name, value); if v == nil then FF.result[name] = "fail" return false end
        local before, known = FF.get(name)
        if FF.orig[name] == nil then FF.orig[name] = before or false end
        if known and not FF.key[name] then FF.key[name] = known end
        
        local accepted, matched = writeFlag(name, value)
        
        if matched then FF.result[name] = "ok"
        elseif accepted then FF.result[name] = FF.canGet and "reverted" or "sent"
        else FF.result[name] = (FF.canGet and before == nil) and "unknown" or "fail" end
        if accepted then FF.applied[name] = v end
        return matched or (accepted and not FF.canGet)
    end

    function FF.good(name) local r = FF.result[name]; return r == "ok" or r == "sent" end

    function FF.restore(name)
        local o = FF.orig[name]
        FF.applied[name] = nil
        FF.result[name] = nil
        if not FF.canSet then return end
        local target
        if o and o ~= false then
            target = o
        else
            local p = FF.prefix(name) or ""
            if p:find("Flag") then target = "False"
            elseif p:find("Int") then target = "0"
            elseif p:find("String") then target = ""
            end
        end
        if target then writeFlag(name, target) end
    end

    function FF.refreshMaterials()
        pcall(function()
            local ms = game:GetService("MaterialService")
            local overrides = {}
            for _, mat in ipairs(Enum.Material:GetEnumItems()) do
                local ok, val = pcall(function() return ms:GetBaseMaterialOverride(mat) end)
                if ok then overrides[mat] = val end
            end
            for _, mat in ipairs(Enum.Material:GetEnumItems()) do
                pcall(function() ms:SetBaseMaterialOverride(mat, "") end)
            end
            task.defer(function()
                for mat, val in pairs(overrides) do
                    pcall(function() ms:SetBaseMaterialOverride(mat, val) end)
                end
            end)
        end)
    end
end

-- ============ CONFIG ============
local DIR, FILE = "MonoFFlags", "MonoFFlags/settings.json"
local canFile = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"

local DEFAULT_V = {
    Quality = 0, MSAA = "Auto", Textures = "Auto", MapTex = "Normal", Lighting = "Auto",
    GraySky = false, PauseVoxel = false, NoGrass = false, NoPostFx = false, NoShadows = false,
}
local Config = { Enabled = true, V = {}, Custom = {} }
for k, v in pairs(DEFAULT_V) do Config.V[k] = v end

local function loadConfig()
    if not canFile then return end
    local okI = pcall(isfile, FILE); if not okI then return end
    local okc, content = pcall(readfile, FILE); if not okc or not content then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok or type(data) ~= "table" then return end
    if type(data.Enabled) == "boolean" then Config.Enabled = data.Enabled end
    if type(data.V) == "table" then
        for k, v in pairs(data.V) do
            if Config.V[k] ~= nil and type(v) == type(Config.V[k]) then Config.V[k] = v end
        end
    end
    if type(data.Custom) == "table" then
        local l = {}
        for _, e in ipairs(data.Custom) do
            if type(e) == "table" and type(e.name) == "string" then
                table.insert(l, { name = e.name, value = tostring(e.value), on = e.on ~= false })
            end
        end
        Config.Custom = l
    end
end
local function saveConfig()
    if not canFile then return end
    pcall(function()
        if isfolder and makefolder and not isfolder(DIR) then makefolder(DIR) end
        writefile(FILE, HttpService:JSONEncode(Config))
    end)
end
loadConfig()

-- ============ MAPTEX ============
local MapTex = { mode = "Normal", saved = setmetatable({}, {__mode = "k"}), conns = {}, gen = 0, over = {} }
local MaterialService = game:GetService("MaterialService")
local PlayersS = game:GetService("Players")
local SKIP_MAT = { Air = true, Water = true, Neon = true, Glass = true, ForceField = true, SmoothPlastic = true }
local function remember(inst, prop, val)
    local t = MapTex.saved[inst]; if not t then t = {}; MapTex.saved[inst] = t end
    if t[prop] == nil then t[prop] = { val } end
end
local function isCharacter(inst)
    local cam = workspace.CurrentCamera
    if cam and inst:IsDescendantOf(cam) then return true end
    local m = inst:FindFirstAncestorOfClass("Model")
    while m do
        if m:FindFirstChildOfClass("Humanoid") or PlayersS:GetPlayerFromCharacter(m) then return true end
        m = m:FindFirstAncestorOfClass("Model")
    end
    return false
end
local function variantPhysics(name, base)
    for _, v in ipairs(MaterialService:GetDescendants()) do
        if v:IsA("MaterialVariant") and v.Name == name and (base == nil or v.BaseMaterial == base) then
            return v.CustomPhysicalProperties
        end
    end
end
local function lowInst(inst, flat)
    if inst:IsA("SurfaceAppearance") then
        local p = inst.Parent
        if p and not isCharacter(inst) then remember(inst, "Parent", p); inst.Parent = nil end
    elseif inst:IsA("BasePart") then
        if inst.MaterialVariant ~= "" and not isCharacter(inst) then
            if inst.CustomPhysicalProperties == nil then
                local pp = variantPhysics(inst.MaterialVariant, inst.Material)
                if pp then remember(inst, "CustomPhysicalProperties", nil); inst.CustomPhysicalProperties = pp end
            end
            remember(inst, "MaterialVariant", inst.MaterialVariant); inst.MaterialVariant = ""
        end
        if flat and inst:IsA("MeshPart") and inst.TextureID ~= "" and not isCharacter(inst) then
            remember(inst, "TextureID", inst.TextureID); inst.TextureID = ""
        end
    elseif flat and inst:IsA("Texture") then
        if inst.Transparency < 1 and not isCharacter(inst) then
            remember(inst, "Transparency", inst.Transparency); inst.Transparency = 1
        end
    elseif flat and inst:IsA("SpecialMesh") then
        if inst.TextureId ~= "" and not isCharacter(inst) then
            remember(inst, "TextureId", inst.TextureId); inst.TextureId = ""
        end
    end
end
local function makeOverrides()
    local folder = Instance.new("Folder"); folder.Name = "MonoFlatMaterials"
    local made = {}
    for _, mat in ipairs(Enum.Material:GetEnumItems()) do
        if not SKIP_MAT[mat.Name] then
            pcall(function()
                local v = Instance.new("MaterialVariant")
                v.Name = "MonoFlat_" .. mat.Name; v.BaseMaterial = mat; made[mat] = v
            end)
        end
    end
    local okP = pcall(function() folder.Parent = MaterialService end)
    if not okP then return 0 end
    local n = 0
    for mat, v in pairs(made) do
        local ok = pcall(function()
            local old = MaterialService:GetBaseMaterialOverride(mat)
            if MapTex.over[mat] == nil then MapTex.over[mat] = old or "" end
            if old and old ~= "" then
                local pp = variantPhysics(old, mat); if pp then v.CustomPhysicalProperties = pp end
            end
            v.Parent = folder
            MaterialService:SetBaseMaterialOverride(mat, v.Name)
        end)
        if ok then n += 1 end
    end
    MapTex.folder = folder
    return n
end
local function clearOverrides()
    for mat, old in pairs(MapTex.over) do pcall(function() MaterialService:SetBaseMaterialOverride(mat, old) end) end
    MapTex.over = {}
    if MapTex.folder then pcall(function() MapTex.folder:Destroy() end); MapTex.folder = nil end
end
local function restoreMap()
    MapTex.gen += 1
    for _, c in ipairs(MapTex.conns) do pcall(function() c:Disconnect() end) end
    MapTex.conns = {}
    clearOverrides()
    local saved = MapTex.saved
    MapTex.saved = setmetatable({}, {__mode = "k"})
    task.spawn(function()
        local n = 0
        for inst, t in pairs(saved) do
            for prop, box in pairs(t) do pcall(function() inst[prop] = box[1] end) end
            n += 1; if n % 1500 == 0 then task.wait() end
        end
    end)
end
function MapTex.set(mode)
    mode = (mode == "Low" or mode == "Flat") and mode or "Normal"
    if mode == MapTex.mode then return end
    if MapTex.mode ~= "Normal" then restoreMap() end
    MapTex.mode = mode
    if mode == "Normal" then return end
    local gen = MapTex.gen
    local flat = mode == "Flat"
    MapTex.overrides = makeOverrides()
    table.insert(MapTex.conns, workspace.DescendantAdded:Connect(function(inst)
        task.defer(function() if MapTex.gen == gen and inst.Parent then pcall(lowInst, inst, flat) end end)
    end))
    task.spawn(function()
        local list = workspace:GetDescendants()
        for i, inst in ipairs(list) do
            if MapTex.gen ~= gen then return end
            pcall(lowInst, inst, flat)
            if i % 1500 == 0 then task.wait() end
        end
    end)
end
function MapTex.sweep()
    if MapTex.mode == "Normal" or MapTex.sweeping then return end
    MapTex.sweeping = true
    local gen, flat = MapTex.gen, MapTex.mode == "Flat"
    task.spawn(function()
        for i, inst in ipairs(workspace:GetDescendants()) do
            if MapTex.gen ~= gen then break end
            pcall(lowInst, inst, flat)
            if i % 1000 == 0 then task.wait() end
        end
        MapTex.sweeping = false
    end)
end

-- ============ FORCE ============
local Force = { orig = {}, ok = {}, want = {}, watch = {} }
local Lighting = game:GetService("Lighting")
do
    local function getP(o, p)
        local ok, v = pcall(function() return o[p] end)
        if ok then return v end
        if type(gethiddenproperty) == "function" then
            local ok2, v2 = pcall(gethiddenproperty, o, p); if ok2 then return v2 end
        end
    end
    local function setP(o, p, val)
        local ok = pcall(function() o[p] = val end)
        if (not ok or getP(o, p) ~= val) and type(sethiddenproperty) == "function" then
            ok = pcall(sethiddenproperty, o, p, val)
        end
        return ok and getP(o, p) == val
    end
    local function objs()
        local R, U
        pcall(function() R = settings().Rendering end)
        pcall(function() U = UserSettings():GetService("UserGameSettings") end)
        return R, U
    end
    function Force.set(key, obj, prop, want)
        if not obj then Force.ok[key] = false return end
        local id = key .. "." .. prop
        if want ~= nil then
            if Force.orig[id] == nil then
                local cur = getP(obj, prop); Force.orig[id] = (cur == nil) and false or cur
            end
            Force.ok[key] = getP(obj, prop) == want or setP(obj, prop, want)
            Force.want[id] = want
            if not Force.watch[id] then
                pcall(function()
                    Force.watch[id] = obj:GetPropertyChangedSignal(prop):Connect(function()
                        local w = Force.want[id]
                        if w ~= nil and getP(obj, prop) ~= w then task.defer(setP, obj, prop, w) end
                    end)
                end)
            end
        else
            Force.want[id] = nil
            if Force.orig[id] ~= nil then
                local o = Force.orig[id]; Force.orig[id] = nil
                if o ~= false then setP(obj, prop, o) end
            end
            Force.ok[key] = nil
        end
    end
    local TECH = { Voxel = "Voxel", Shadow = "ShadowMap", Future = "Future" }
    local TEX_LEVEL = { Low = 1, Medium = 6, High = 14, Max = 21 }
    function Force.apply()
        local V = Config.V
        local R, U = objs()
        local q = math.floor(tonumber(V.Quality) or 0)
        local tq = TEX_LEVEL[V.Textures]
        if q <= 0 and tq then q = tq end
        if q > 0 then
            local lvl, saved
            pcall(function() lvl = Enum.QualityLevel[("Level%02d"):format(math.clamp(q, 1, 21))] end)
            pcall(function() saved = Enum.SavedQualitySetting["QualityLevel" .. math.clamp(math.ceil(q / 2.1), 1, 10)] end)
            local a = lvl and Force.set("quality", R, "QualityLevel", lvl)
            local b = saved and Force.set("qualitySaved", U, "SavedQualityLevel", saved)
            Force.ok.quality = (a or b) and true or false
            Force.ok.textures = tq and Force.ok.quality or nil
        else
            Force.set("quality", R, "QualityLevel", nil)
            Force.set("qualitySaved", U, "SavedQualityLevel", nil)
            Force.ok.textures = nil
        end
        pcall(MapTex.set, V.MapTex)
        local tech = TECH[V.Lighting]
        if tech then
            local e; pcall(function() e = Enum.Technology[tech] end)
            Force.set("lighting", Lighting, "Technology", e)
        else
            Force.set("lighting", Lighting, "Technology", nil)
        end
        Force.set("shadows", Lighting, "GlobalShadows", V.NoShadows and false or nil)
    end
end

-- ============ FLAGS ============
local Flags = {}
do
    local MSAA = { ["1x"] = 1, ["2x"] = 2, ["4x"] = 4, ["8x"] = 8 }
    local TEX = { Low = 0, Medium = 1, High = 2, Max = 3 }
    function Flags.wanted()
        local V, w = Config.V, {}
        if (tonumber(V.Quality) or 0) > 0 then w.DFIntDebugFRMQualityLevelOverride = V.Quality end
        if MSAA[V.MSAA] then w.FIntDebugForceMSAASamples = MSAA[V.MSAA] end
        if TEX[V.Textures] then
            w.DFFlagTextureQualityOverrideEnabled = "True"
            w.DFIntTextureQualityOverride = TEX[V.Textures]
            if V.Textures == "Low" then w.FIntDebugTextureManagerSkipMips = 2 end
        end
        if V.Lighting == "Voxel" then w.DFFlagDebugRenderForceTechnologyVoxel = "True"
        elseif V.Lighting == "Shadow" then w.FFlagDebugForceFutureIsBrightPhase2 = "True"
        elseif V.Lighting == "Future" then w.FFlagDebugForceFutureIsBrightPhase3 = "True" end
        if V.GraySky then w.FFlagDebugSkyGray = "True" end
        if V.PauseVoxel then w.DFFlagDebugPauseVoxelizer = "True" end
        if V.NoGrass then w.FIntFRMMinGrassDistance = 0; w.FIntFRMMaxGrassDistance = 0 end
        if V.NoPostFx then w.FFlagDisablePostFx = "True" end
        if V.NoShadows then w.FIntRenderShadowIntensity = 0 end
        for _, e in ipairs(Config.Custom) do
            if e.on and FF.prefix(e.name) and not FF.blocked(e.name) then w[e.name] = e.value end
        end
        return w
    end
    local FORCED = {
        DFIntDebugFRMQualityLevelOverride = "quality",
        DFFlagDebugRenderForceTechnologyVoxel = "lighting",
        FFlagDebugForceFutureIsBrightPhase2 = "lighting",
        FFlagDebugForceFutureIsBrightPhase3 = "lighting",
        FIntRenderShadowIntensity = "shadows",
    }
    function Flags.applyAll()
        local w = Flags.wanted()
        local toRestore = {}
        for name in pairs(FF.applied) do
            if w[name] == nil then table.insert(toRestore, name) end
        end
        for _, name in ipairs(toRestore) do FF.restore(name) end
        pcall(Force.apply)
        local ok, fail, total = 0, 0, 0
        for name, v in pairs(w) do
            total += 1
            local nv = FF.norm(name, v)
            if FF.applied[name] ~= nv or not FF.good(name) then FF.set(name, v) end
            local good = FF.good(name)
            if FORCED[name] and Force.ok[FORCED[name]] then good = true end
            if good then ok += 1 else fail += 1 end
        end
        if Flags.onApplied then pcall(Flags.onApplied, ok, fail, total) end
        return ok, fail, total
    end
    local queued = false
    function Flags.changed()
        if queued then return end
        queued = true
        task.delay(0.15, function()
            queued = false
            saveConfig()
            if not Config.Enabled then return end
            Flags.applyAll()
        end)
    end
    function Flags.setEnabled(on)
        Config.Enabled = on == true
        saveConfig()
        if Config.Enabled then
            Flags.applyAll()
        else
            local toRestore = {}
            for name in pairs(FF.applied) do table.insert(toRestore, name) end
            for _, name in ipairs(toRestore) do pcall(FF.restore, name) end
            local keep = Config.V
            Config.V = {}
            for k, v in pairs(DEFAULT_V) do Config.V[k] = v end
            pcall(Force.apply)
            Config.V = keep
        end
        if FF.refreshMaterials then FF.refreshMaterials() end
    end
    Flags.MapTex = MapTex
    Flags.Force = Force
end

-- ============ UI HELPERS ============
local function addLabel(section, text)
    section._rowN += 1
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = UITheme.Row,
        BorderSizePixel = 0, LayoutOrder = section._rowN }, section._wrap)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = UITheme.Border,
        BackgroundTransparency = 0.4, BorderSizePixel = 0 }, row)
    local lbl = mk("TextLabel", { Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Font = FONT, TextSize = 11, TextColor3 = UITheme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Text = tostring(text) }, row)
    return lbl
end
local function addMultilineBox(section, height, placeholder, default)
    section._rowN += 1
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, height + 8), BackgroundColor3 = UITheme.Row,
        BorderSizePixel = 0, LayoutOrder = section._rowN }, section._wrap)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = UITheme.Border,
        BackgroundTransparency = 0.4, BorderSizePixel = 0 }, row)
    local bg = mk("Frame", { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8),
        BackgroundColor3 = UITheme.Panel, BorderSizePixel = 0 }, row)
    addCorner(bg, 6); addStroke(bg, UITheme.Border, 1, 0.4)
    local box = mk("TextBox", { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1, Font = FONTM, TextSize = 11, TextColor3 = UITheme.Text,
        PlaceholderText = placeholder or "", PlaceholderColor3 = UITheme.TextMute,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        ClearTextOnFocus = false, MultiLine = true, TextWrapped = true,
        Text = tostring(default or "") }, bg)
    return box
end

-- ============ UI ============
local V = Config.V

-- FFLAGS TOGGLE
local sM = FFTab:AddSection("FFlags Toggle")
sM:AddToggle("FF_MasterToggle", { Title = "FFlags Enabled", Default = Config.Enabled,
    Callback = function(v) Flags.setEnabled(v) end })

-- QUALITY
local sQ = FFTab:AddSection("Quality")
sQ:AddSlider("FF_Quality", { Title = "Graphics level (0 = game default)", Default = V.Quality,
    Min = 0, Max = 21, Rounding = 0,
    Callback = function(v) V.Quality = math.floor(v + 0.5); Flags.changed() end })
sQ:AddDropdown("FF_MSAA", { Title = "Anti-aliasing", Values = { "Auto", "1x", "2x", "4x", "8x" },
    Default = V.MSAA, Multi = false,
    Callback = function(v) V.MSAA = v; Flags.changed() end })
sQ:AddDropdown("FF_Textures", { Title = "Textures", Values = { "Auto", "Low", "Medium", "High", "Max" },
    Default = V.Textures, Multi = false,
    Callback = function(v) V.Textures = v; Flags.changed() end })
sQ:AddDropdown("FF_MapTex", { Title = "Map & object textures (forced, live)", Values = { "Normal", "Low", "Flat" },
    Default = V.MapTex, Multi = false,
    Callback = function(v) V.MapTex = v; Flags.changed() end })

-- LIGHTING & WORLD
local sL = FFTab:AddSection("Lighting & World")
sL:AddDropdown("FF_Lighting", { Title = "Lighting (forced)", Values = { "Auto", "Voxel", "Shadow", "Future" },
    Default = V.Lighting, Multi = false,
    Callback = function(v) V.Lighting = v; Flags.changed() end })
sL:AddToggle("FF_NoShadows", { Title = "No shadows (forced)", Default = V.NoShadows,
    Callback = function(v) V.NoShadows = v; Flags.changed() end })
sL:AddToggle("FF_NoPostFx", { Title = "No post effects", Default = V.NoPostFx,
    Callback = function(v) V.NoPostFx = v; Flags.changed() end })
sL:AddToggle("FF_GraySky", { Title = "Gray sky", Default = V.GraySky,
    Callback = function(v) V.GraySky = v; Flags.changed() end })
sL:AddToggle("FF_PauseVoxel", { Title = "Freeze voxel lighting", Default = V.PauseVoxel,
    Callback = function(v) V.PauseVoxel = v; Flags.changed() end })
sL:AddToggle("FF_NoGrass", { Title = "No grass", Default = V.NoGrass,
    Callback = function(v) V.NoGrass = v; Flags.changed() end })

-- CUSTOM FLAGS
local sC = FFTab:AddSection("Custom flags")
local customListRow = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, LayoutOrder = 1 }, sC._wrap)
mk("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, customListRow)
local addRow = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, LayoutOrder = 2 }, sC._wrap)
mk("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, addRow)
sC._rowN += 2

local function makeCustomToggleRow(name, value, initialOn, onChange)
    local row = mk("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = UITheme.Row, BorderSizePixel = 0 }, customListRow)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = UITheme.Border, BackgroundTransparency = 0.4, BorderSizePixel = 0 }, row)
    mk("TextLabel", { Size = UDim2.new(1, -252, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1,
        Font = FONT, TextSize = 12, TextColor3 = UITheme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(name) }, row)
    mk("TextLabel", { Size = UDim2.new(0, 90, 1, 0), Position = UDim2.new(1, -230, 0, 0), BackgroundTransparency = 1,
        Font = FONTM, TextSize = 11, TextColor3 = UITheme.TextDim, TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd, Text = tostring(value or "") }, row)
    local sw = mk("Frame", { Size = UDim2.new(0, 40, 0, 22), Position = UDim2.new(1, -56, 0.5, -11),
        BackgroundColor3 = UITheme.Off, BorderSizePixel = 0, ClipsDescendants = true }, row)
    addCorner(sw, 11); addStroke(sw, UITheme.Border, 1, 0.35)
    local knob = mk("Frame", { Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(0, 2, 0.5, -9),
        BackgroundColor3 = UITheme.White, BorderSizePixel = 0 }, sw)
    addCorner(knob, 9); addStroke(knob, UITheme.Border, 1, 0.45)
    local click = mk("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, sw)
    local state = initialOn
    local function paint(on, anim)
        local t = on and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        sw.BackgroundColor3 = on and UITheme.White or UITheme.Off
        if anim then tween(knob, TI_MED, { Position = t }) else knob.Position = t end
    end
    paint(state, false)
    click.MouseButton1Click:Connect(function() state = not state; paint(state, true); onChange(state) end)
    local rm = mk("TextButton", { Size = UDim2.new(0, 68, 0, 26), Position = UDim2.new(1, -132, 0.5, -13),
        BackgroundColor3 = UITheme.Off, BorderSizePixel = 0, Font = FONT, TextSize = 11,
        TextColor3 = UITheme.TextDim, Text = "Remove", AutoButtonColor = false }, row)
    addCorner(rm, 6); addStroke(rm, UITheme.Border, 1, 0.4)
    rm.MouseButton1Click:Connect(function()
        for i, e in ipairs(Config.Custom) do if e.name == name then table.remove(Config.Custom, i); break end end
        if Flags.rebuildCustom then Flags.rebuildCustom() end
        Flags.changed()
    end)
    return row
end

do -- add-custom form
    local row1 = mk("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = UITheme.Row, BorderSizePixel = 0, LayoutOrder = 1 }, addRow)
    local row2 = mk("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = UITheme.Row, BorderSizePixel = 0, LayoutOrder = 2 }, addRow)
    local f1 = mk("Frame", { Size = UDim2.new(1, -24, 0, 28), Position = UDim2.fromOffset(12, 5),
        BackgroundColor3 = UITheme.Panel, BorderSizePixel = 0 }, row1)
    addCorner(f1, 6); addStroke(f1, UITheme.Border, 1, 0.4)
    local nameBox = mk("TextBox", { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = UITheme.Text,
        PlaceholderText = "Flag name, e.g. FFlagDebugSkyGray", PlaceholderColor3 = UITheme.TextMute,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Text = "" }, f1)
    local f2 = mk("Frame", { Size = UDim2.new(0, 130, 0, 32), Position = UDim2.fromOffset(12, 5),
        BackgroundColor3 = UITheme.Panel, BorderSizePixel = 0 }, row2)
    addCorner(f2, 6); addStroke(f2, UITheme.Border, 1, 0.4)
    local valBox = mk("TextBox", { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = UITheme.Text,
        PlaceholderText = "value", PlaceholderColor3 = UITheme.TextMute,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Text = "" }, f2)
    local addBtn = mk("TextButton", { Size = UDim2.new(0, 110, 0, 32), Position = UDim2.fromOffset(150, 5),
        BackgroundColor3 = UITheme.White, BorderSizePixel = 0, Font = FONTB, TextSize = 12,
        TextColor3 = UITheme.Black, Text = "Add flag", AutoButtonColor = false }, row2)
    addCorner(addBtn, 6)
    addBtn.MouseButton1Click:Connect(function()
        local name = (nameBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub('"', "")
        local value = (valBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then notify({ Title = "FFlags", Content = "Enter a flag name", Duration = 3 }); return end
        if not FF.prefix(name) then notify({ Title = "FFlags", Content = "Needs a prefix (DFInt/FFlag/etc)", Duration = 3 }); return end
        local b = FF.blocked(name)
        if b then notify({ Title = "FFlags", Content = "Blocked (" .. b .. ")", Duration = 3 }); return end
        local v = FF.norm(name, value)
        if v == nil then notify({ Title = "FFlags", Content = "Invalid value", Duration = 3 }); return end
        for _, e in ipairs(Config.Custom) do
            if e.name == name then
                e.value = v; e.on = true
                nameBox.Text = ""; valBox.Text = ""
                if Flags.rebuildCustom then Flags.rebuildCustom() end
                Flags.changed()
                return
            end
        end
        table.insert(Config.Custom, { name = name, value = v, on = true })
        nameBox.Text = ""; valBox.Text = ""
        if Flags.rebuildCustom then Flags.rebuildCustom() end
        Flags.changed()
    end)
end

function Flags.rebuildCustom()
    for _, c in ipairs(customListRow:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    if #Config.Custom == 0 then
        addLabel(sC, "No custom flags yet - add one above.")
        return
    end
    for i, e in ipairs(Config.Custom) do
        makeCustomToggleRow(e.name, e.value, e.on, function(v)
            e.on = v
            saveConfig()
            if v then
                if Config.Enabled then pcall(FF.set, e.name, e.value) end
            else
                pcall(FF.restore, e.name)
            end
            if Config.Enabled then Flags.applyAll() end
            FF.refreshMaterials()
        end)
    end
end
Flags.rebuildCustom()

-- IMPORT / EXPORT JSON
local sJ = FFTab:AddSection("Import / Export JSON")
local jsonBox = addMultilineBox(sJ, 180, '{"FFlagDebugSkyGray":"True","FIntDebugForceMSAASamples":4}', "")
local btnRow = mk("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1,
    LayoutOrder = sJ._rowN + 1 }, sJ._wrap)
sJ._rowN += 1
local importBtn = mk("TextButton", { Size = UDim2.new(0.333, -6, 0, 34), Position = UDim2.new(0, 4, 0.5, -17),
    BackgroundColor3 = UITheme.White, BorderSizePixel = 0, Font = FONTB, TextSize = 12,
    TextColor3 = UITheme.Black, Text = "Import", AutoButtonColor = false }, btnRow)
addCorner(importBtn, 6)
local exportBtn = mk("TextButton", { Size = UDim2.new(0.333, -6, 0, 34), Position = UDim2.new(0.333, 2, 0.5, -17),
    BackgroundColor3 = UITheme.Panel, BorderSizePixel = 0, Font = FONTB, TextSize = 12,
    TextColor3 = UITheme.Text, Text = "Export (copy)", AutoButtonColor = false }, btnRow)
addCorner(exportBtn, 6); addStroke(exportBtn, UITheme.Border, 1, 0.3)
local clearBtn = mk("TextButton", { Size = UDim2.new(0.333, -6, 0, 34), Position = UDim2.new(0.666, 0, 0.5, -17),
    BackgroundColor3 = UITheme.Panel, BorderSizePixel = 0, Font = FONTB, TextSize = 12,
    TextColor3 = UITheme.Text, Text = "Remove all", AutoButtonColor = false }, btnRow)
addCorner(clearBtn, 6); addStroke(clearBtn, UITheme.Border, 1, 0.3)

importBtn.MouseButton1Click:Connect(function()
    local txt = jsonBox.Text or ""
    if txt == "" then notify({ Title = "Import", Content = "Paste JSON first", Duration = 3 }); return end
    local ok, data = pcall(function() return HttpService:JSONDecode(txt) end)
    if not ok or type(data) ~= "table" then notify({ Title = "Import", Content = "Not valid JSON", Duration = 4 }); return end
    local added, blocked, bad = 0, 0, 0
    for k, v in pairs(data) do
        if type(k) == "string" and FF.prefix(k) then
            local b = FF.blocked(k)
            if b then blocked += 1
            else
                local nv = FF.norm(k, type(v) == "boolean" and (v and "True" or "False") or tostring(v))
                if nv then
                    local found = false
                    for _, e in ipairs(Config.Custom) do if e.name == k then e.value = nv; e.on = true; found = true end end
                    if not found then table.insert(Config.Custom, { name = k, value = nv, on = true }) end
                    added += 1
                else bad += 1 end
            end
        else bad += 1 end
    end
    if Flags.rebuildCustom then Flags.rebuildCustom() end
    Flags.changed()
    notify({ Title = "Import", Content = string.format("%d added, %d blocked, %d skipped", added, blocked, bad), Duration = 5 })
end)

exportBtn.MouseButton1Click:Connect(function()
    local out = {}
    for n, v in pairs(Flags.wanted()) do out[n] = FF.norm(n, v) or tostring(v) end
    local ok, json = pcall(function() return HttpService:JSONEncode(out) end)
    if not ok then return end
    jsonBox.Text = json
    if type(setclipboard) == "function" then
        pcall(setclipboard, json)
        notify({ Title = "Export", Content = "Copied " .. #json .. " bytes", Duration = 3 })
    else
        notify({ Title = "Export", Content = "No setclipboard - JSON is in the box", Duration = 4 })
    end
end)

clearBtn.MouseButton1Click:Connect(function()
    Config.Custom = {}
    if Flags.rebuildCustom then Flags.rebuildCustom() end
    Flags.changed()
    notify({ Title = "FFlags", Content = "All custom flags removed", Duration = 3 })
end)

-- ============ KEEP-APPLIED LOOP ============
task.spawn(function()
    local tick2 = 0
    while true do
        task.wait(2)
        if Config.Enabled then
            pcall(Force.apply)
            tick2 += 1
            if tick2 % 5 == 0 then pcall(MapTex.sweep) end
            if FF.canSet and FF.canGet then
                for name, v in pairs(FF.applied) do
                    local cur = FF.get(name)
                    if cur ~= nil and tostring(cur):lower() ~= tostring(v):lower() then
                        pcall(FF.set, name, v)
                    end
                end
            end
        end
    end
end)

-- ============ AUTO-APPLY ON LAUNCH ============
task.delay(1.5, function()
    if Config.Enabled then
        local ok, fail, total = Flags.applyAll()
        if total > 0 then
            notify({ Title = "FFlags", Content = ok .. " applied" ..
                (fail > 0 and (", " .. fail .. " not taken") or ""), Duration = 4 })
        end
    end
end)

-- ============ CLEANUP HOOK ============
do
    local old = getgenv().qzxp_Cleanup
    getgenv().qzxp_Cleanup = function()
        if old then pcall(old) end
        for name in pairs(FF.applied) do pcall(FF.restore, name) end
        pcall(function()
            local keep = Config.V
            Config.V = {}
            for k, v in pairs(DEFAULT_V) do Config.V[k] = v end
            pcall(Force.apply)
            Config.V = keep
        end)
    end
end
end)()

-- ============================================================
-- THUNDER DASH 0 COOLDOWN
-- ============================================================
local ThunderDash = {
    ability          = nil,
    originalCooldown = nil,
    originalReduction = nil,
    loopToken        = 0,
}
function ThunderDash.ensure()
    if ThunderDash.ability then return true end
    local shared    = ReplicatedStorage:FindFirstChild("Shared")
    local abilities = shared and shared:FindFirstChild("Abilities")
    local module    = abilities and abilities:FindFirstChild("Thunder Dash")
    if not module then return false end
    local ok, result = pcall(require, module)
    if not ok or not result then return false end
    ThunderDash.ability           = result
    ThunderDash.originalCooldown  = result.cooldown
    ThunderDash.originalReduction = result.cooldownReductionPerUpgrade
    return true
end
function ThunderDash.apply()
    if not ThunderDash.ensure() then return false end
    return pcall(function()
        ThunderDash.ability.cooldown                    = 0
        ThunderDash.ability.cooldownReductionPerUpgrade = 0
    end)
end
function ThunderDash.restore()
    if not ThunderDash.ability then return end
    pcall(function()
        ThunderDash.ability.cooldown                    = ThunderDash.originalCooldown
        ThunderDash.ability.cooldownReductionPerUpgrade = ThunderDash.originalReduction
    end)
end
function ThunderDash.start()
    ThunderDash.loopToken += 1
    local token = ThunderDash.loopToken
    ThunderDash.apply()
    spawnTracked(function()
        while ThunderDash.loopToken == token do
            ThunderDash.apply()
            task.wait(0.5)
        end
    end)
end
function ThunderDash.stop()
    ThunderDash.loopToken += 1
    ThunderDash.restore()
end
getgenv().qzxp_thunderDashStop = function()
    pcall(ThunderDash.stop)
end

-- ============================================================
-- ESP
-- ============================================================
local ESP_On = false
local espC = {}
local espHeads = setmetatable({}, {__mode = "k"})
local function clearESPFor(p)
    local d = espC[p]
    if d then pcall(function() d:Destroy() end) end
    espC[p] = nil
    espHeads[p] = nil
end
local function updateESP()
    if not ESP_On then
        for _, d in pairs(espC) do
            if d then pcall(function() d:Destroy() end) end
        end
        espC = {}
        espHeads = setmetatable({}, {__mode = "k"})
        return
    end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local head = espHeads[p]
            if not head or not head.Parent then
                local c = p.Character
                head = c and c:FindFirstChild("Head")
                espHeads[p] = head
            end
            if head then
                local existing = espC[p]
                if not existing or not existing.Parent or existing.Adornee ~= head then
                    if existing then pcall(function() existing:Destroy() end) end
                    local bb = Instance.new("BillboardGui")
                    bb.Name = "qESP"
                    bb.Adornee = head
                    bb.Size = UDim2.new(0, 200, 0, 40)
                    bb.StudsOffset = Vector3.new(0, 3, 2)
                    bb.AlwaysOnTop = true
                    bb.Parent = head
                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.TextColor3 = Color3.new(1, 1, 1)
                    lbl.TextStrokeTransparency = 0.5
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 14
                    lbl.Parent = bb
                    espC[p] = bb
                end
                local bb = espC[p]
                if bb and bb.Parent then
                    local lbl = bb:FindFirstChildOfClass("TextLabel")
                    if lbl then
                        local ab = p:GetAttribute("EquippedAbility")
                        lbl.Text = ab and (p.DisplayName .. " [" .. ab .. "]") or p.DisplayName
                        if LockEnabled and LockTarget ~= "None" and LockTarget == p.Name then
                            lbl.TextColor3 = Color3.fromRGB(255, 60, 60)
                        else
                            lbl.TextColor3 = Color3.new(1, 1, 1)
                        end
                    end
                end
            end
        end
    end
end
local function attachESPRespawn(p)
    if p == LocalPlayer then return end
    p.CharacterAdded:Connect(function() clearESPFor(p) end)
end
for _, p in ipairs(Players:GetPlayers()) do attachESPRespawn(p) end
Players.PlayerAdded:Connect(attachESPRespawn)
Players.PlayerRemoving:Connect(clearESPFor)
spawnTracked(function()
    while true do
        task.wait(0.25)
        if ESP_On then pcall(updateESP) end
    end
end)

-- Keybind list & ball stats
local UIFlags = {
    KBShow        = false,
    BSOn          = false,
    StatsShowFPS  = false,
    StatsShowPing = false,
}
local kbF, bsF
;(function()
local function MakeDrag(handle, frame)
    local drag, di, ds, sp = false, nil, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = i.Position; sp = frame.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drag = false end end)
        end
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then di = i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i == di and drag and ds then
            local d = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end
local kbGui = Instance.new("ScreenGui"); kbGui.Name = "q_KB"; kbGui.ResetOnSpawn = false; kbGui.IgnoreGuiInset = true; kbGui.DisplayOrder = 100; kbGui.Parent = CoreGui
kbF = Instance.new("Frame"); kbF.Size = UDim2.new(0, 220, 0, 200); kbF.Position = UDim2.new(1, -235, 0.5, -100); kbF.BackgroundColor3 = Color3.fromRGB(17, 17, 19); kbF.Visible = false; kbF.Parent = kbGui; kbF.ClipsDescendants = true
Instance.new("UICorner", kbF).CornerRadius = UDim.new(0, 10)
local kbS = Instance.new("UIStroke"); kbS.Color = Color3.fromRGB(58, 58, 66); kbS.Transparency = 0.25; kbS.Parent = kbF
local kbT = Instance.new("TextLabel"); kbT.Size = UDim2.new(1, 0, 0, 28); kbT.BackgroundColor3 = Color3.fromRGB(30, 30, 34); kbT.BackgroundTransparency = 0.2; kbT.Font = Enum.Font.GothamBold; kbT.TextSize = 13; kbT.TextColor3 = Color3.fromRGB(230, 230, 235); kbT.Text = "  Keybind List"; kbT.TextXAlignment = Enum.TextXAlignment.Left; kbT.Parent = kbF
Instance.new("UICorner", kbT).CornerRadius = UDim.new(0, 8)
local kbC = Instance.new("Frame"); kbC.Size = UDim2.new(1, -10, 1, -34); kbC.Position = UDim2.new(0, 5, 0, 31); kbC.BackgroundTransparency = 1; kbC.Parent = kbF
Instance.new("UIListLayout", kbC).Padding = UDim.new(0, 4)
MakeDrag(kbT, kbF)
local function keyStr(o) if not o then return "?" end; local v = o.Value; return typeof(v) == "EnumItem" and keyDisplay(v) or tostring(v) end
local kbItems = {
    {n = "Autoparry", k = function() return keyStr(Options and Options.APKey) end, s = function() return AP_On end},
    {n = "Manual Spam", k = function() return keyStr(Options and Options.SpamKey) end, s = function() return Spam_On end},
    {n = "Triggerbot", k = function() return keyStr(Options and Options.TBKey) end, s = function() return TB_On end},
    {n = "Parry Lock", k = function() return keyStr(Options and Options.LockKey) end, s = function() return LockEnabled end},
}
local kbL = {}
local kbLastText = {}
for i, _ in ipairs(kbItems) do
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 20); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold
    l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = Color3.fromRGB(200, 200, 200); l.LayoutOrder = i; l.Parent = kbC
    kbL[i] = l; kbLastText[i] = ""
end
local bsGui = Instance.new("ScreenGui"); bsGui.Name = "q_BS"; bsGui.ResetOnSpawn = false; bsGui.IgnoreGuiInset = true; bsGui.DisplayOrder = 100; bsGui.Parent = CoreGui
bsF = Instance.new("Frame"); bsF.Size = UDim2.new(0, 220, 0, 120); bsF.Position = UDim2.new(1, -470, 0.5, -60); bsF.BackgroundColor3 = Color3.fromRGB(17, 17, 19); bsF.Visible = false; bsF.Parent = bsGui; bsF.ClipsDescendants = true
Instance.new("UICorner", bsF).CornerRadius = UDim.new(0, 10)
local bsStroke = Instance.new("UIStroke", bsF); bsStroke.Color = Color3.fromRGB(58, 58, 66); bsStroke.Transparency = 0.25
local bsT = Instance.new("TextLabel"); bsT.Size = UDim2.new(1, 0, 0, 28); bsT.BackgroundColor3 = Color3.fromRGB(30, 30, 34); bsT.BackgroundTransparency = 0.2; bsT.Font = Enum.Font.GothamBold; bsT.TextSize = 13; bsT.TextColor3 = Color3.fromRGB(230, 230, 235); bsT.Text = "  Ball Stats"; bsT.TextXAlignment = Enum.TextXAlignment.Left; bsT.Parent = bsF
Instance.new("UICorner", bsT).CornerRadius = UDim.new(0, 8)
local bsC = Instance.new("Frame"); bsC.Size = UDim2.new(1, -10, 1, -34); bsC.Position = UDim2.new(0, 5, 0, 31); bsC.BackgroundTransparency = 1; bsC.Parent = bsF
Instance.new("UIListLayout", bsC).Padding = UDim.new(0, 3)
MakeDrag(bsT, bsF)
local function bsLabel(o)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold
    l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = Color3.fromRGB(200, 200, 200); l.LayoutOrder = o; l.Text = "N/A"; l.Parent = bsC
    return l
end
local bsSp, bsDi, bsTg, bsCu = bsLabel(1), bsLabel(2), bsLabel(3), bsLabel(4)
local uiLast = 0
addHeartbeatHandler(function()
    local now = os.clock()
    if now - uiLast < 0.1 then return end
    uiLast = now
    kbF.Visible = UIFlags.KBShow
    if UIFlags.KBShow then
        for i, it in ipairs(kbItems) do
            local s = it.s(); local k = it.k()
            local shown = (#k == 1) and k or ("[" .. k .. "]")
            local txt = shown .. " " .. it.n .. " " .. (s and "<font color='#4cd964'>ON</font>" or "<font color='#ff3b30'>OFF</font>")
            if txt ~= kbLastText[i] then
                kbLastText[i] = txt
                local lbl = kbL[i]; lbl.RichText = true; lbl.Text = txt
            end
        end
    end
    bsF.Visible = UIFlags.BSOn
    if UIFlags.BSOn then
        local ball = getBall()
        if ball and ball.Parent then
            local z = ball:FindFirstChild('zoomies')
            local sp = z and math.round(z.VectorVelocity.Magnitude) or 0
            local tg = ball:GetAttribute('target') or "None"
            local c = LocalPlayer.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            local di = r and math.round((r.Position - ball.Position).Magnitude) or 0
            bsSp.Text = "Spd: " .. sp; bsDi.Text = "Dist: " .. di
            bsTg.Text = "Tgt: " .. tg; bsCu.Text = "Curve: " .. (isCurvedCached(ball) and "Y" or "N")
        else
            bsSp.Text = "Spd: -"; bsDi.Text = "Dist: -"; bsTg.Text = "Tgt: -"; bsCu.Text = "Curve: -"
        end
    end
end, 5)
end)()

-- Stats HUD
;(function()
local function MakeDrag(handle, frame)
    local drag, di, ds, sp = false, nil, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = i.Position; sp = frame.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drag = false end end)
        end
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then di = i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i == di and drag and ds then
            local d = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end
local statsGui = Instance.new("ScreenGui")
statsGui.Name = "qzxp_Stats"
statsGui.ResetOnSpawn = false
statsGui.IgnoreGuiInset = true
statsGui.DisplayOrder = 100
statsGui.Parent = CoreGui
local statsF = Instance.new("Frame")
statsF.Size = UDim2.new(0, 220, 0, 78)
statsF.Position = UDim2.new(1, -235, 0.5, 108)
statsF.BackgroundColor3 = Color3.fromRGB(17, 17, 19)
statsF.Visible = false
statsF.Parent = statsGui
statsF.ClipsDescendants = true
Instance.new("UICorner", statsF).CornerRadius = UDim.new(0, 10)
local statsS = Instance.new("UIStroke")
statsS.Color = Color3.fromRGB(58, 58, 66)
statsS.Transparency = 0.25
statsS.Parent = statsF
local statsT = Instance.new("TextLabel")
statsT.Size = UDim2.new(1, 0, 0, 28)
statsT.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
statsT.BackgroundTransparency = 0.2
statsT.Font = Enum.Font.GothamBold
statsT.TextSize = 13
statsT.TextColor3 = Color3.fromRGB(230, 230, 235)
statsT.Text = "  Stats"
statsT.TextXAlignment = Enum.TextXAlignment.Left
statsT.Parent = statsF
Instance.new("UICorner", statsT).CornerRadius = UDim.new(0, 8)
local statsC = Instance.new("Frame")
statsC.Size = UDim2.new(1, -10, 1, -34)
statsC.Position = UDim2.new(0, 5, 0, 31)
statsC.BackgroundTransparency = 1
statsC.Parent = statsF
Instance.new("UIListLayout", statsC).Padding = UDim.new(0, 3)
MakeDrag(statsT, statsF)
local function mkStatLabel(order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBold
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = Color3.fromRGB(200, 200, 200)
    l.LayoutOrder = order
    l.Text = "N/A"
    l.Parent = statsC
    return l
end
local fpsLbl  = mkStatLabel(1)
local pingLbl = mkStatLabel(2)
local _fpsAvg = 60
local _statsLast = 0
local _lastFpsTxt  = ""
local _lastPingTxt = ""
addHeartbeatHandler(function(dt)
    if dt and dt > 0 then
        _fpsAvg = _fpsAvg * 0.9 + (1 / dt) * 0.1
    end
    local now = os.clock()
    if now - _statsLast < 0.15 then return end
    _statsLast = now
    statsF.Visible = UIFlags.StatsShowFPS or UIFlags.StatsShowPing
    fpsLbl.Visible  = UIFlags.StatsShowFPS
    pingLbl.Visible = UIFlags.StatsShowPing
    if UIFlags.StatsShowFPS then
        local t = string.format("FPS: %d", math.floor(_fpsAvg + 0.5))
        if t ~= _lastFpsTxt then _lastFpsTxt = t; fpsLbl.Text = t end
    end
    if UIFlags.StatsShowPing then
        local p = 0
        if Stats_DataPing then
            local ok, v = pcall(function() return Stats_DataPing:GetValue() end)
            if ok and type(v) == "number" then p = v end
        end
        local t = string.format("Ping: %d ms", math.floor(p + 0.5))
        if t ~= _lastPingTxt then _lastPingTxt = t; pingLbl.Text = t end
    end
end, 8)
end)()

-- ============================================================
-- UI LAYOUT
-- ============================================================
;(function()
do
    local s1 = Tabs.Combat:AddSection("Autoparry")
    local APKeyMode = "Toggle"
    s1:AddToggle("APToggle", {Title = "Enabled", Default = false, Callback = function(v)
        AP_On = v
        notify({Title = "AP", Content = v and "On" or "Off", Duration = 2})
    end})
    s1:AddKeybind("APKey", {Title = "Keybind", Default = "P",
        Callback = function()
            if APKeyMode == "Hold" then
                if Options.APToggle then Options.APToggle:SetValue(true) end
            else
                if Options.APToggle then Options.APToggle:SetValue(not AP_On) end
            end
        end,
        ReleasedCallback = function()
            if APKeyMode == "Hold" then
                if Options.APToggle then Options.APToggle:SetValue(false) end
            end
        end,
        ChangedCallback = function() end})
    s1:AddDropdown("APMode", {Title = "Key Mode", Values = {"Toggle", "Hold"}, Default = "Toggle", Multi = false,
        Callback = function(v) APKeyMode = v end})
    s1:AddSlider("Accuracy", {Title = "Accuracy", Default = 50, Min = 1, Max = 100, Rounding = 1, Callback = function(v)
        AP_Acc = v; updDiv()
    end})
    s1:AddToggle("RandAccToggle", {Title = "Auto Accuracy", Default = false, Callback = function(v)
        RandAcc = v
    end})
    s1:AddDropdown("CurveMode", {Title = "Curve", Values = CURVES, Default = "Camera", Multi = false, Callback = function(v)
        CurveMode = v
    end})
    s1:AddToggle("AnimFixAP", {Title = "Anim Fix", Default = true, Callback = function(v)
        AnimFix_AP = v
    end})
    s1:AddToggle("AbilityToggle", {Title = "Auto Ability", Default = false, Callback = function(v)
        AutoAbility = v
    end})
end
do
    local s2 = Tabs.Combat:AddSection("Detections")
    s2:AddToggle("InfDet", {Title = "Infinity", Default = false, Callback = function(v)
        InfDet = v
    end})
    s2:AddToggle("DSDet", {Title = "Death Slash", Default = false, Callback = function(v)
        DSDet = v
    end})
    s2:AddToggle("THDet", {Title = "Time Hole", Default = false, Callback = function(v)
        THDet = v
    end})
    s2:AddToggle("SFDet", {Title = "Slashes of Fury", Default = false, Callback = function(v) SFDet = v end})
    s2:AddSlider("SofDelay", {Title = "SoF Parry Delay (ms)", Default = 5, Min = 5, Max = 25, Rounding = 0, Callback = function(v) parryDelay = v/100 end})
    s2:AddSlider("SofMax",   {Title = "SoF Max Parry Count", Default = 36, Min = 1, Max = 36, Rounding = 0, Callback = function(v) maxParryCount = v end})
end
do
    local s3 = Tabs.Combat:AddSection("Spam")
    local SpamKeyMode = "Toggle"
    s3:AddToggle("SpamToggle", {Title = "Enabled", Default = false, Callback = function(v)
        Spam_On = v
        if not v and getgenv().qzxp_resetAPState then pcall(getgenv().qzxp_resetAPState) end
        notify({Title = "Spam", Content = v and "On" or "Off", Duration = 2})
    end})
    s3:AddKeybind("SpamKey", {Title = "Keybind", Default = "E",
        Callback = function()
            if SpamKeyMode == "Hold" then
                if Options.SpamToggle then Options.SpamToggle:SetValue(true) end
            else
                if Options.SpamToggle then Options.SpamToggle:SetValue(not Spam_On) else Spam_On = not Spam_On end
            end
        end,
        ReleasedCallback = function()
            if SpamKeyMode == "Hold" then
                if Options.SpamToggle then Options.SpamToggle:SetValue(false) end
            end
        end,
        ChangedCallback = function() end})
    s3:AddDropdown("SpamMode", {Title = "Key Mode", Values = {"Toggle", "Hold"}, Default = "Toggle", Multi = false,
        Callback = function(v) SpamKeyMode = v end})
    local spamRPSSlider
    spamRPSSlider = s3:AddSlider("SpamRPS", {Title = "RPS", Default = 100, Min = 5, Max = 1000, Rounding = 0, Callback = function(v)
        local snapped = math.clamp(math.floor(v / 10 + 0.5) * 10, 5, 1000)
        SpamRPS = snapped; SpamInt = 1 / snapped
        if SpamAnimMatchRPS then SpamAnimRate = snapped end
        if spamRPSSlider and spamRPSSlider.Value ~= snapped then
            task.defer(function() pcall(function() spamRPSSlider:SetValue(snapped) end) end)
        end
    end})
    s3:AddToggle("SpamAnimMatchRPS", {Title = "Match Anim Rate to RPS", Default = false, Callback = function(v)
        SpamAnimMatchRPS = v
        SpamAnimRate = v and SpamRPS or 100
    end})
    s3:AddToggle("SpamDet", {Title = "Respect Detections", Default = true, Callback = function(v)
        SpamDetect = v
    end})
    s3:AddToggle("AnimFixSpam", {Title = "Anim Fix", Default = true, Callback = function(v)
        AnimFix_Spam = v
    end})
    s3:AddToggle("AutoSpamToggle", {Title = "Auto Spam", Default = false, Callback = function(v)
        AutoSpam_On = v
    end})
    s3:AddDropdown("ClashingThreshold", {Title = "Clashing Threshold", Values = {"1", "2", "3"}, Default = "1", Callback = function(v)
        ClashingThreshold = tonumber(v) or 1
    end})
end
do
    local s4 = Tabs.Combat:AddSection("Triggerbot")
    local TBKeyMode = "Toggle"
    s4:AddToggle("TBToggle", {Title = "Enabled", Default = false, Callback = function(v)
        TB_On = v
        if not v and getgenv().qzxp_resetAPState then pcall(getgenv().qzxp_resetAPState) end
        notify({Title = "TB", Content = v and "On" or "Off", Duration = 2})
    end})
    s4:AddKeybind("TBKey", {Title = "Keybind", Default = "R",
        Callback = function()
            if TBKeyMode == "Hold" then
                if Options.TBToggle then Options.TBToggle:SetValue(true) end
            else
                if Options.TBToggle then Options.TBToggle:SetValue(not TB_On) end
            end
        end,
        ReleasedCallback = function()
            if TBKeyMode == "Hold" then
                if Options.TBToggle then Options.TBToggle:SetValue(false) end
            end
        end,
        ChangedCallback = function() end})
    s4:AddDropdown("TBMode", {Title = "Key Mode", Values = {"Toggle", "Hold"}, Default = "Toggle", Multi = false,
        Callback = function(v) TBKeyMode = v end})
    s4:AddToggle("AnimFixTB", {Title = "Anim Fix", Default = true, Callback = function(v)
        AnimFix_TB = v
    end})
end
do
    local s5 = Tabs.Swords:AddSection("Sword Changer")
    local skinRef = s5:AddToggle("SkinToggle", {Title = "Enabled", Default = false, Callback = function(v)
        getgenv().skinChanger = v; getgenv().skinChangerEnabled = v
        if v and getgenv().swordModel ~= "" then
            pcall(getgenv().updateSword)
        elseif not v then
            pcall(getgenv().revertSword)
        end
    end})
    getgenv().setSkinUI = function(v)
        if skinRef and skinRef.Value ~= v then
            skinRef:SetValue(v)
            getgenv().skinChanger = v; getgenv().skinChangerEnabled = v
        end
    end
    s5:AddInput("ManualSword", {Title = "Sword Name", Default = "", Placeholder = "type sword name...", Callback = function(v)
        local n = v and v:match("^%s*(.-)%s*$") or ""
        local e = resolve(n)
        getgenv().swordModel = e; getgenv().swordAnimations = e; getgenv().swordFX = e
        if getgenv().skinChanger then
            if e ~= "" then
                pcall(getgenv().updateSword)
            else
                pcall(getgenv().revertSword)
                if getgenv().setSkinUI then pcall(getgenv().setSkinUI, false) end
            end
        end
        pcall(getgenv().saveLastEquippedSword, e)
    end})
    local s5b = Tabs.Swords:AddSection("Unlock All (Swords)")
    s5b:AddToggle("UnlockAllToggle", {Title = "Enabled", Default = false, Callback = function(v)
        UA:set_enabled(v)
        notify({Title = "Unlock All", Content = v and "On" or "Off", Duration = 2})
    end})
    s5b:AddButton({Title = "Refresh Shop", Callback = function()
        if UA.enabled then UA:schedule_refresh() end
    end})
end
do
    local s6 = Tabs.Combat:AddSection("Parry Lock")
    s6:AddToggle("LockToggle", {Title = "Enabled", Default = false, Callback = function(v)
        LockEnabled = v
        notify({Title = "Lock", Content = v and "On" or "Off", Duration = 2})
    end})
    s6:AddKeybind("LockKey", {Title = "Toggle Key", Default = "L", Callback = function()
        if Options.LockToggle then Options.LockToggle:SetValue(not LockEnabled) end
    end, ChangedCallback = function() end})
    s6:AddDropdown("LockTarget", {Title = "Target", Values = playerList(), Default = "None", Multi = false, Callback = function(v)
        LockTarget = pLookup[v] or "None"
    end})
    s6:AddKeybind("CursorKey", {Title = "Cursor Lock", Default = "T", Callback = function()
        local t = closestToCursor()
        if t then LockTarget = t; syncLockDD(); notify({Title = "Lock", Content = t, Duration = 2}) end
    end, ChangedCallback = function() end})
    s6:AddButton({Title = "Refresh List", Callback = function() syncLockDD() end})
end
do
    local s7 = Tabs.Visuals:AddSection("ESP")
    s7:AddToggle("ESPToggle", {Title = "Ability ESP", Default = false, Callback = function(v)
        ESP_On = v; updateESP()
    end})
    local s7b = Tabs.Visuals:AddSection("Ball Stats")
    s7b:AddToggle("BSToggle", {Title = "Ball Info", Default = false, Callback = function(v)
        UIFlags.BSOn = v
    end})
    local s7p = Tabs.Visuals:AddSection("Parry Range")
    s7p:AddToggle("PRVToggle", {Title = "Range Ring", Default = false, Callback = function(v)
        PRV.On = v
        if not v then PRV.Destroy() end
    end})
    local s7c = Tabs.Avatar:AddSection("Character")
    s7c:AddToggle("HeadlessT", {Title = "Headless", Default = false, Callback = function(v)
        HK.Headless = v
        if v then HK.doHeadless() else HK.undoHeadless() end
    end})
    s7c:AddToggle("KorbloxT", {Title = "Korblox Leg", Default = false, Callback = function(v)
        HK.Korblox = v
        if v then HK.doKorblox() else HK.undoKorblox() end
    end})
    local s7ab = Tabs.Utility:AddSection("Ability")
    s7ab:AddToggle("ThunderDashToggle", {Title = "Thunder Dash 0 Cooldown", Default = false, Callback = function(v)
        if v then
            ThunderDash.start()
            notify({Title = "Thunder Dash", Content = "0 Cooldown On", Duration = 2})
        else
            ThunderDash.stop()
            notify({Title = "Thunder Dash", Content = "0 Cooldown Off", Duration = 2})
        end
    end})

-- ============================================================
-- AVATAR / PROFILE SPOOFER
-- ============================================================
do
    -- ---------------------------------------------------------
    -- STATE
    -- ---------------------------------------------------------
    local AvatarSlotNumber    = nil
    local AvatarDefaultDesc   = nil
    local AvatarKillFeedConn  = nil
    local AvatarCharacterConn = nil
    local AvatarCloneConn     = nil
    local ProfileSpoofer      = { usernameEnabled = false, displayNameEnabled = false, info = nil }
    local spoofedLabels       = setmetatable({}, {__mode = "k"})
    local hookedLabels        = setmetatable({}, {__mode = "k"})
    local watchedRoots        = setmetatable({}, {__mode = "k"})

    -- ---------------------------------------------------------
    -- SHARED HELPERS
    -- ---------------------------------------------------------
    local function findPlayerListFrame()
        local cg = game:GetService("CoreGui")
        local pl = cg:FindFirstChild("PlayerList"); if pl then return pl end
        local rg = cg:FindFirstChild("RobloxGui")
        return rg and rg:FindFirstChild("PlayerList")
    end
    local function currentRoots()
        local out = {}
        local pl = findPlayerListFrame(); if pl then out[#out + 1] = pl end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local lb = pg and pg:FindFirstChild("Leaderboard"); if lb then out[#out + 1] = lb end
        return out
    end
    local function getTargetHeadshotUrl()
        local id = getgenv().qzxp_avatarUserId
        if not id then return nil end
        return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", id)
    end

    -- ---------------------------------------------------------
    -- AVATAR APPEARANCE
    -- ---------------------------------------------------------
    local function GetDefaultAvatarDescription()
        if AvatarDefaultDesc then return AvatarDefaultDesc end
        local ok, result = pcall(function() return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId) end)
        if ok and result then AvatarDefaultDesc = result end
        return AvatarDefaultDesc
    end
    local function WeldAccessory(accessory, character)
        local handle = accessory:FindFirstChild("Handle"); if not handle then return end
        local attachment = handle:FindFirstChildOfClass("Attachment"); if not attachment then return end
        local targetAttachment = character:FindFirstChild(attachment.Name, true); if not targetAttachment then return end
        local weld = Instance.new("Weld")
        weld.Name = "AccessoryWeld"; weld.Part0 = handle; weld.Part1 = targetAttachment.Parent
        weld.C0 = attachment.CFrame; weld.C1 = targetAttachment.CFrame; weld.Parent = handle
        handle.Anchored = false
    end
    local function MeshIdOf(part)
        if part:IsA("MeshPart") then return part.MeshId end
        local sm = part:FindFirstChildOfClass("SpecialMesh")
        return sm and sm.MeshId or ""
    end
    local function CopyAttachments(src, dst)
        for _, child in ipairs(src:GetChildren()) do
            if child:IsA("Attachment") then
                local matched = dst:FindFirstChild(child.Name)
                if matched then
                    matched.CFrame = child.CFrame
                    matched.Position = child.Position
                    matched.Orientation = child.Orientation
                    matched.Axis = child.Axis
                    matched.SecondaryAxis = child.SecondaryAxis
                else
                    child:Clone().Parent = dst
                end
            end
        end
    end
    local function ApplyAvatar(parent)
        if not parent or not AvatarSlotNumber then return end
        local humanoid = parent:FindFirstChildOfClass("Humanoid") or parent:WaitForChild("Humanoid", 5)
        if not humanoid then return end
        if parent:GetAttribute("qzxp_AvatarApplied") == AvatarSlotNumber then return end
        parent:SetAttribute("qzxp_AvatarApplied", AvatarSlotNumber)
        local ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(AvatarSlotNumber) end)
        if not ok or not desc then parent:SetAttribute("qzxp_AvatarApplied", nil); return end
        local equippedSword = LocalPlayer:GetAttribute("CurrentlyEquippedSword")
        for _, child in parent:GetChildren() do
            if child:IsA("Accessory") then
                if child.Name ~= equippedSword then pcall(function() child:Destroy() end) end
            elseif child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic")
                or child:IsA("BodyColors") or child:IsA("CharacterMesh") then
                pcall(function() child:Destroy() end)
            end
        end
        local ok2, tempModel = pcall(function()
            return Players:CreateHumanoidModelFromDescription(desc, humanoid.RigType)
        end)
        if not ok2 or not tempModel then parent:SetAttribute("qzxp_AvatarApplied", nil); return end
        for _, child in tempModel:GetChildren() do
            if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
                local target = parent:FindFirstChild(child.Name)
                if target then
                    if MeshIdOf(child) ~= MeshIdOf(target) then
                        local sm = target:FindFirstChildOfClass("SpecialMesh")
                        if sm then pcall(function() sm:Destroy() end) end
                        local sm2 = child:FindFirstChildOfClass("SpecialMesh")
                        if sm2 then sm2:Clone().Parent = target end
                        if child:IsA("MeshPart") and target:IsA("MeshPart") then
                            pcall(function()
                                target.MeshId = child.MeshId
                                target.TextureID = child.TextureID
                            end)
                            CopyAttachments(child, target)
                        end
                    end
                end
            elseif child:IsA("CharacterMesh") then
                child:Clone().Parent = parent
            end
        end
        for _, child in tempModel:GetChildren() do
            if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic")
                or child:IsA("BodyColors") then
                pcall(function() child:Clone().Parent = parent end)
            elseif child:IsA("Accessory") then
                local clone = child:Clone()
                pcall(function() humanoid:AddAccessory(clone) end)
                WeldAccessory(clone, parent)
            end
        end
        local head = parent:FindFirstChild("Head")
        local tempHead = tempModel:FindFirstChild("Head")
        if head and tempHead then
            local decal = head:FindFirstChildOfClass("Decal")
            local tempDecal = tempHead:FindFirstChildOfClass("Decal")
            if tempDecal then
                if decal then decal.Texture = tempDecal.Texture
                else tempDecal:Clone().Parent = head end
            elseif decal then
                pcall(function() decal:Destroy() end)
            end
        end
        pcall(function() tempModel:Destroy() end)
    end
    local function RevertAvatar()
        local character = LocalPlayer.Character; if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
        character:SetAttribute("qzxp_AvatarApplied", nil)
        local defaultDesc = GetDefaultAvatarDescription(); if not defaultDesc then return end
        local ok, tempModel = pcall(function()
            return Players:CreateHumanoidModelFromDescription(defaultDesc, humanoid.RigType)
        end)
        if not ok or not tempModel then return end
        local accessoryList = {}
        for _, child in tempModel:GetChildren() do
            if child:IsA("Accessory") then table.insert(accessoryList, child:Clone()) end
        end
        for _, child in character:GetChildren() do
            if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic")
                or child:IsA("Accessory") or child:IsA("BodyColors")
                or child:IsA("CharacterMesh") then
                pcall(function() child:Destroy() end)
            end
        end
        for _, child in tempModel:GetChildren() do
            if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
                local target = character:FindFirstChild(child.Name)
                if target and MeshIdOf(child) ~= MeshIdOf(target) then
                    local sm = target:FindFirstChildOfClass("SpecialMesh")
                    if sm then pcall(function() sm:Destroy() end) end
                    local sm2 = child:FindFirstChildOfClass("SpecialMesh")
                    if sm2 then sm2:Clone().Parent = target end
                    if child:IsA("MeshPart") and target:IsA("MeshPart") then
                        pcall(function()
                            target.MeshId = child.MeshId
                            target.TextureID = child.TextureID
                            target.Size = child.Size
                        end)
                    end
                end
            elseif child:IsA("CharacterMesh") then
                child:Clone().Parent = character
            end
        end
        for _, child in tempModel:GetChildren() do
            if child:IsA("Shirt") or child:IsA("Pants")
                or child:IsA("ShirtGraphic") or child:IsA("BodyColors") then
                child:Clone().Parent = character
            end
        end
        for _, accessory in accessoryList do
            accessory.Parent = character
            local handle = accessory:FindFirstChild("Handle")
            if handle then
                local attachment = handle:FindFirstChildWhichIsA("Attachment", true)
                if attachment then
                    local targetAttachment = character:FindFirstChild(attachment.Name, true)
                    if targetAttachment then
                        local weld = Instance.new("Weld")
                        weld.Part0 = handle; weld.Part1 = targetAttachment.Parent
                        weld.C0 = attachment.CFrame; weld.C1 = targetAttachment.CFrame
                        weld.Parent = handle
                    end
                end
            end
        end
        pcall(function() tempModel:Destroy() end)
    end
    local function HookKillFeed()
        if AvatarKillFeedConn then pcall(function() AvatarKillFeedConn:Disconnect() end); AvatarKillFeedConn = nil end
        if not AvatarSlotNumber then return end
        local killFeed = LocalPlayer.PlayerGui:FindFirstChild("KillFeed")
                      or LocalPlayer.PlayerGui:WaitForChild("KillFeed", 10)
        if not killFeed then return end
        local frame = killFeed:FindFirstChild("Frame"); if not frame then return end
        local headshotUrl = "rbxthumb://type=AvatarHeadShot&id=" .. AvatarSlotNumber .. "&w=100&h=100"
        AvatarKillFeedConn = frame.ChildAdded:Connect(function(child)
            local holder = child:FindFirstChild("Holder"); if not holder then return end
            local left = holder:FindFirstChild("Left")
            local vector = left and left:FindFirstChild("Vector")
            if vector then pcall(function() vector.Image = headshotUrl end) end
        end)
    end
    local function HookEncryptedClone()
        if AvatarCloneConn then return end
        local alive = Workspace:FindFirstChild("Alive") or Workspace:WaitForChild("Alive", 30)
        if not alive then return end
        AvatarCloneConn = alive.ChildAdded:Connect(function(child)
            if child.Name:find("ENCRYPTED CLONE", 1, true) then
                if Options.AvatarChanger and Options.AvatarChanger.Value then
                    task.defer(function() ApplyAvatar(child) end)
                end
            end
        end)
    end
    local function SetAvatarEnabled(v)
        if v then
            if not AvatarSlotNumber then
                notify({Title = "Avatar", Content = "Waiting for User ID...", Duration = 4})
                return
            end
            local char = LocalPlayer.Character
            if char then ApplyAvatar(char) end
            HookKillFeed(); HookEncryptedClone()
            if AvatarCharacterConn then pcall(function() AvatarCharacterConn:Disconnect() end) end
            AvatarCharacterConn = LocalPlayer.CharacterAppearanceLoaded:Connect(function()
                local newChar = LocalPlayer.Character
                if newChar then ApplyAvatar(newChar); HookKillFeed() end
            end)
        else
            RevertAvatar()
            if AvatarCharacterConn then pcall(function() AvatarCharacterConn:Disconnect() end); AvatarCharacterConn = nil end
            if AvatarKillFeedConn then pcall(function() AvatarKillFeedConn:Disconnect() end); AvatarKillFeedConn = nil end
            if AvatarCloneConn then pcall(function() AvatarCloneConn:Disconnect() end); AvatarCloneConn = nil end
        end
    end

    -- ---------------------------------------------------------
    -- PROFILE SPOOFER
    -- ---------------------------------------------------------
    function getSpoofedProfileInfo()
        local id = getgenv().qzxp_avatarUserId
        if not id then return nil end
        local ok1, fetchedUsername = pcall(function() return Players:GetNameFromUserIdAsync(id) end)
        if not ok1 or type(fetchedUsername) ~= "string" or fetchedUsername == "" then return nil end
        local ok2, fetchedDisplayName = pcall(function() return Players:GetUserDisplayNameFromUserIdAsync(id) end)
        local gotDisplay = ok2 and type(fetchedDisplayName) == "string" and fetchedDisplayName ~= ""
        local finalDisplay = gotDisplay and fetchedDisplayName or fetchedUsername
        local finalUsername = fetchedUsername
        if Options and Options.ProfileSpoofDisplayName and Options.ProfileSpoofDisplayName.Value ~= "" then
            finalDisplay = Options.ProfileSpoofDisplayName.Value
        end
        if Options and Options.ProfileSpoofUsername and Options.ProfileSpoofUsername.Value ~= "" then
            finalUsername = Options.ProfileSpoofUsername.Value
        end
        return {
            userId = id,
            username = finalUsername,
            displayName = finalDisplay,
            _displayNameFetched = true,
            headshot = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", id),
        }
    end
    local function desiredText(state, info)
        if state.kind == "username" and not ProfileSpoofer.usernameEnabled then return nil end
        if state.kind == "displayName" and not ProfileSpoofer.displayNameEnabled then return nil end
        local base = (state.kind == "username") and info.username or info.displayName
        return (state.prefix or "") .. base
    end
    local function stillMine(txt)
        local name = LocalPlayer.Name
        local disp = LocalPlayer.DisplayName
        return txt == name or txt == "@" .. name or txt == disp or txt == "@" .. disp
    end
    local function enforceLabel(lbl, state, info)
        local want = desiredText(state, info)
        if want and lbl.Text ~= want then lbl.Text = want end
        state._lastSet = want
    end
    local function hookLabel(lbl)
        if hookedLabels[lbl] then return end
        hookedLabels[lbl] = true
        lbl:GetPropertyChangedSignal("Text"):Connect(function()
            if not (ProfileSpoofer.usernameEnabled or ProfileSpoofer.displayNameEnabled) then return end
            local info = ProfileSpoofer.info
            local state = spoofedLabels[lbl]
            if not info or not state then return end
            local txt = lbl.Text
            local want = desiredText(state, info)
            if not want then return end
            if txt == want then state._lastSet = want; return end
            if stillMine(txt) then
                lbl.Text = want
                state._lastSet = want
            end
        end)
    end
    local function getLocalNames()
        return LocalPlayer.Name, LocalPlayer.DisplayName
    end
    local function classifyLabel(lbl, info)
        if not lbl then return end
        local isText = lbl:IsA("TextLabel") or lbl:IsA("TextButton") or lbl:IsA("TextBox")
        if not isText then return end
        local state = spoofedLabels[lbl]
        if state then
            local want = desiredText(state, info)
            if not want then return end
            if lbl.Text == want then state._lastSet = want; return end
            if stillMine(lbl.Text) or (state._lastSet and lbl.Text == state._lastSet) then
                lbl.Text = want
            end
            state._lastSet = want
            return
        end
        local txt = lbl.Text
        local isAt = string.sub(txt, 1, 1) == "@"
        local name, displayName = getLocalNames()
        local nameOnly = isAt and string.sub(txt, 2) or txt
        if nameOnly == displayName or nameOnly == name then
            local kind = isAt and "username" or "displayName"
            if (kind == "username" and not ProfileSpoofer.usernameEnabled)
                or (kind == "displayName" and not ProfileSpoofer.displayNameEnabled) then
                return
            end
            spoofedLabels[lbl] = {kind = kind, prefix = isAt and "@" or ""}
        else
            return
        end
        hookLabel(lbl)
        enforceLabel(lbl, spoofedLabels[lbl], info)
    end
    local function classifyImage(img, info)
        if not img then return end
        if not (img:IsA("ImageLabel") or img:IsA("ImageButton")) then return end
        local myIdStr = tostring(LocalPlayer.UserId)
        if img.Name == "HeadShot" or (img.Image and string.find(img.Image, myIdStr, 1, true)) then
            if img.Image ~= info.headshot then img.Image = info.headshot end
        end
    end
    local function applyToContainer(container, info)
        if not container then return end
        for _, d in ipairs(container:GetDescendants()) do
            classifyLabel(d, info)
            classifyImage(d, info)
        end
    end
    local function watchRoot(root)
        if not root or watchedRoots[root] then return end
        watchedRoots[root] = true
        root.DescendantAdded:Connect(function(d)
            if not (ProfileSpoofer.usernameEnabled or ProfileSpoofer.displayNameEnabled) then return end
            local info = ProfileSpoofer.info
            if not info then return end
            classifyLabel(d, info)
            classifyImage(d, info)
        end)
    end
    local function applyAll(info)
        local roots = currentRoots()
        for i = 1, #roots do
            watchRoot(roots[i])
            applyToContainer(roots[i], info)
        end
    end
    local function restoreProfile(info)
        if not info then return end
        local originalHeadshot = string.format(
            "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", LocalPlayer.UserId)
        local roots = currentRoots()
        for i = 1, #roots do
            for _, d in ipairs(roots[i]:GetDescendants()) do
                local state = spoofedLabels[d]
                if state then
                    if (state.kind == "username" and not ProfileSpoofer.usernameEnabled)
                        or (state.kind == "displayName" and not ProfileSpoofer.displayNameEnabled) then
                        local orig = (state.kind == "username") and LocalPlayer.Name or LocalPlayer.DisplayName
                        d.Text = (state.prefix or "") .. orig
                        spoofedLabels[d] = nil
                    end
                elseif (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image == info.headshot then
                    if not ProfileSpoofer.usernameEnabled and not ProfileSpoofer.displayNameEnabled then
                        d.Image = originalHeadshot
                    end
                end
            end
        end
    end
    local _profileRetryActive = false
    local function retryDisplayNameInBackground()
        if _profileRetryActive then return end
        _profileRetryActive = true
        task.spawn(function()
            for _ = 1, 20 do
                task.wait(1.5)
                if not (ProfileSpoofer.usernameEnabled or ProfileSpoofer.displayNameEnabled) then break end
                local info = ProfileSpoofer.info
                if info and info._displayNameFetched then break end
                local newInfo = getSpoofedProfileInfo()
                if newInfo and newInfo._displayNameFetched then
                    ProfileSpoofer.info = newInfo
                    pcall(applyAll, newInfo)
                    break
                end
            end
            _profileRetryActive = false
        end)
    end

    -- ---------------------------------------------------------
    -- PFP SPOOFING (automatic with Avatar Changer)
    -- ---------------------------------------------------------
    local function spoofHeadshotImage(img)
        if not img or not img.Parent then return end
        if not (img:IsA("ImageLabel") or img:IsA("ImageButton")) then return end
        local target = getTargetHeadshotUrl()
        if not target then return end
        local myIdStr = tostring(LocalPlayer.UserId)
        if img.Name == "HeadShot" or (img.Image and string.find(img.Image, myIdStr, 1, true)) then
            if img.Image ~= target then img.Image = target end
        end
    end
    local function refreshAvatarHeadshots()
        local target = getTargetHeadshotUrl()
        if not target then return end
        local roots = currentRoots()
        for i = 1, #roots do
            local root = roots[i]
            if root and root.Parent then
                pcall(function()
                    for _, d in ipairs(root:GetDescendants()) do
                        spoofHeadshotImage(d)
                    end
                end)
            end
        end
    end
    local function revertAvatarHeadshots()
        local target = getTargetHeadshotUrl()
        if not target then return end
        local original = string.format(
            "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", LocalPlayer.UserId)
        local roots = currentRoots()
        for i = 1, #roots do
            local root = roots[i]
            if root and root.Parent then
                pcall(function()
                    for _, d in ipairs(root:GetDescendants()) do
                        if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image == target then
                            d.Image = original
                        end
                    end
                end)
            end
        end
    end

    -- ---------------------------------------------------------
    -- UI SECTION: Avatar
    -- Pattern: [Toggle] -> [Input]
    -- ---------------------------------------------------------
    local s7a = Tabs.Avatar:AddSection("Avatar")

    s7a:AddToggle("AvatarChanger", {Title = "Avatar Changer", Default = false, Callback = function(v)
        SetAvatarEnabled(v)
        if v then
            refreshAvatarHeadshots()
            notify({Title = "Avatar", Content = "On", Duration = 2})
        else
            if not (ProfileSpoofer.usernameEnabled or ProfileSpoofer.displayNameEnabled) then
                revertAvatarHeadshots()
            end
            notify({Title = "Avatar", Content = "Off", Duration = 2})
        end
    end})
    s7a:AddInput("AvatarSaver", {Title = "User ID / Name", Default = "", Placeholder = "UserId or username", Callback = function(v)
        local text = (v and v:match("^%s*(.-)%s*$")) or ""
        if text == "" then
            AvatarSlotNumber = nil
            getgenv().qzxp_avatarUserId = nil
            if LocalPlayer.Character then
                pcall(function() LocalPlayer.Character:SetAttribute("qzxp_AvatarApplied", nil) end)
            end
            return
        end
        local id = tonumber(text)
        if not id then
            local ok, result, attempts; attempts = 0
            repeat
                attempts += 1
                ok, result = pcall(function() return Players:GetUserIdFromNameAsync(text) end)
                if not ok then task.wait(0.5) end
            until ok or attempts >= 5
            if not ok or not result then
                notify({Title = "Avatar", Content = "User not found", Duration = 3})
                return
            end
            id = result
        end
        AvatarSlotNumber = id
        getgenv().qzxp_avatarUserId = id
        ProfileSpoofer.info = nil
        if Options.AvatarChanger and Options.AvatarChanger.Value then
            SetAvatarEnabled(true)
            refreshAvatarHeadshots()
        end
        if (Options.ProfileSpooferUsername and Options.ProfileSpooferUsername.Value)
           or (Options.ProfileSpooferDisplayName and Options.ProfileSpooferDisplayName.Value) then
            ProfileSpoofer.info = getSpoofedProfileInfo()
            if ProfileSpoofer.info then pcall(applyAll, ProfileSpoofer.info) end
        end
        notify({Title = "Avatar", Content = "Set to " .. tostring(id), Duration = 2})
    end})

    s7a:AddToggle("ProfileSpooferDisplayName", {Title = "Spoof Profile Display Name", Default = false, Callback = function(v)
        ProfileSpoofer.displayNameEnabled = v
        if v then
            if not getgenv().qzxp_avatarUserId then
                notify({Title = "Profile", Content = "Waiting for User ID...", Duration = 4})
                return
            end
            ProfileSpoofer.info = getSpoofedProfileInfo()
            if ProfileSpoofer.info then pcall(applyAll, ProfileSpoofer.info) end
        else
            pcall(restoreProfile, ProfileSpoofer.info)
        end
    end})
    s7a:AddInput("ProfileSpoofDisplayName", {Title = "Display Name", Default = "", Placeholder = "Leave empty for API name...", Callback = function(v)
        ProfileSpoofer.info = getSpoofedProfileInfo()
        if ProfileSpoofer.displayNameEnabled and ProfileSpoofer.info then
            pcall(applyAll, ProfileSpoofer.info)
        end
    end})

    s7a:AddToggle("ProfileSpooferUsername", {Title = "Spoof Profile Username", Default = false, Callback = function(v)
        ProfileSpoofer.usernameEnabled = v
        if v then
            if not getgenv().qzxp_avatarUserId then
                notify({Title = "Profile", Content = "Waiting for User ID...", Duration = 4})
                return
            end
            ProfileSpoofer.info = getSpoofedProfileInfo()
            if ProfileSpoofer.info then pcall(applyAll, ProfileSpoofer.info) end
        else
            pcall(restoreProfile, ProfileSpoofer.info)
        end
    end})
    s7a:AddInput("ProfileSpoofUsername", {Title = "Username", Default = "", Placeholder = "Leave empty for API name...", Callback = function(v)
        ProfileSpoofer.info = getSpoofedProfileInfo()
        if ProfileSpoofer.usernameEnabled and ProfileSpoofer.info then
            pcall(applyAll, ProfileSpoofer.info)
        end
    end})

    -- ---------------------------------------------------------
    -- PROFILE PREVIEW PANEL
    -- ---------------------------------------------------------
    local function createPreviewPanel()
        local frame = Instance.new("Frame")
        frame.Name = "SpooferPreview"
        frame.Parent = Window._gui
        frame.BackgroundColor3 = UITheme.Bg
        frame.Position = UDim2.new(0.5, 385, 0.5, -200)
        frame.Size = UDim2.new(0, 200, 0, 220)
        frame.BorderSizePixel = 0
        frame.Visible = false
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
        local stroke = Instance.new("UIStroke", frame); stroke.Color = UITheme.Border
        local img = Instance.new("ImageLabel")
        img.Parent = frame
        img.Size = UDim2.new(0, 100, 0, 100)
        img.Position = UDim2.new(0.5, -50, 0, 20)
        img.BackgroundColor3 = UITheme.Panel
        img.BorderSizePixel = 0
        Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
        local disp = Instance.new("TextLabel")
        disp.Parent = frame
        disp.Size = UDim2.new(1, -20, 0, 24)
        disp.Position = UDim2.new(0, 10, 0, 140)
        disp.BackgroundTransparency = 1
        disp.Font = FONTB; disp.TextSize = 16; disp.TextColor3 = UITheme.Text
        local user = Instance.new("TextLabel")
        user.Parent = frame
        user.Size = UDim2.new(1, -20, 0, 18)
        user.Position = UDim2.new(0, 10, 0, 168)
        user.BackgroundTransparency = 1
        user.Font = FONT; user.TextSize = 13; user.TextColor3 = UITheme.TextDim
        return frame, img, disp, user
    end
    local profilePrev, profileImg, profileDisp, profileUser = createPreviewPanel()
    s7a:AddToggle("ProfilePreviewToggle", {Title = "Preview Profile", Default = false, Callback = function(v)
        profilePrev.Visible = v
    end})

    -- ---------------------------------------------------------
    -- RENDER HANDLERS
    -- ---------------------------------------------------------
    addHeartbeatHandler(function()
        if not (ProfileSpoofer.usernameEnabled or ProfileSpoofer.displayNameEnabled) then return end
        local info = ProfileSpoofer.info
        if not info then
            info = getSpoofedProfileInfo()
            if not info then return end
            ProfileSpoofer.info = info
        end
        if not info._displayNameFetched then retryDisplayNameInBackground() end
        pcall(applyAll, info)
    end, 9)

    local _avatarHSPrev = 0
    addHeartbeatHandler(function()
        local on = Options.AvatarChanger and Options.AvatarChanger.Value
        if not on then return end
        if not getgenv().qzxp_avatarUserId then return end
        local now = os.clock()
        if now - _avatarHSPrev < 0.15 then return end
        _avatarHSPrev = now
        pcall(refreshAvatarHeadshots)
    end, 7)

    addHeartbeatHandler(function()
        local mainPos = Window._main.Position
        local baseX = mainPos.X.Offset + 760
        local baseY = mainPos.Y.Offset + 115
        if profilePrev.Visible then
            profilePrev.Position = UDim2.new(mainPos.X.Scale, baseX, mainPos.Y.Scale, baseY)
            if ProfileSpoofer.info then
                profileImg.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", ProfileSpoofer.info.userId)
                profileDisp.Text = ProfileSpoofer.info.displayName
                profileUser.Text = "@" .. ProfileSpoofer.info.username
            else
                profileImg.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", LocalPlayer.UserId)
                profileDisp.Text = "No Target"
                profileUser.Text = "@none"
            end
        end
    end, 11)
end -- Avatar/Profile spoofer scope

    local s7s = Tabs.Visuals:AddSection("Stats HUD")
    s7s:AddToggle("ShowFPSToggle", {Title = "Show FPS", Default = false, Callback = function(v)
        UIFlags.StatsShowFPS = v
    end})
    s7s:AddToggle("ShowPingToggle", {Title = "Show Ping", Default = false, Callback = function(v)
        UIFlags.StatsShowPing = v
    end})
end
do
    local s8v = Tabs.Visuals:AddSection("Keybind List")
    s8v:AddToggle("KBToggle", {Title = "Keybind List", Default = false, Callback = function(v)
        UIFlags.KBShow = v; kbF.Visible = v
    end})
end
end)()

-- FPS Cap
;(function()
do
    local fpsSection = Tabs.Utility:AddSection("Performance")
    local FPSUncapped = false
    local FPSCap      = 240
    local _setFPS = type(setfpscap) == "function" and setfpscap or nil
    local function applyFPS()
        if type(_setFPS) ~= "function" then return end
        pcall(function() _setFPS(FPSUncapped and 1000 or FPSCap) end)
    end
    fpsSection:AddToggle("FPSUncap", {
        Title = "Uncap FPS",
        Default = false,
        Callback = function(v) FPSUncapped = v; applyFPS() end,
    })
    fpsSection:AddSlider("FPSCap", {
        Title = "FPS Cap",
        Default = 240,
        Min = 15,
        Max = 360,
        Rounding = 0,
        Callback = function(v)
            FPSCap = math.clamp(math.floor(v + 0.5), 15, 360)
            if not FPSUncapped then applyFPS() end
        end,
    })
    task.defer(function()
        if _setFPS == nil then
            Fluent:Notify({Title = "FPS", Content = "setfpscap unavailable on this executor", Duration = 4})
            return
        end
        applyFPS()
    end)
end
end)()

;(function()
do
    local interfaceSection = Tabs.Settings:AddSection("Interface")
    interfaceSection:AddKeybind("GUIToggleKey", {Title = "GUI Toggle", Default = "LeftControl", Callback = function()
        local w = Fluent.Window
        if w and w._gui then w._gui.Enabled = not w._gui.Enabled end
    end, ChangedCallback = function() end})
    interfaceSection:AddSlider("UITransparency", {
        Title = "UI Transparency",
        Default = 0,
        Min = 0,
        Max = 90,
        Rounding = 0,
        Callback = function(v)
            if getgenv().qzxp_applyUITransparency then
                getgenv().qzxp_applyUITransparency(v / 100)
            end
        end,
    })
end
end)()

Players.PlayerAdded:Connect(function() task.wait(1); syncLockDD() end)
Players.PlayerRemoving:Connect(function(p)
    if LockTarget == p.Name then
        LockTarget = "None"
        notify({Title = "Lock", Content = "Target left", Duration = 3})
    end
    task.wait(0.1); syncLockDD()
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("qzxp")
SaveManager:SetFolder("qzxp/configs")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)

getgenv().qzxp_suppressNotify = true
pcall(function() SaveManager:LoadAutoloadConfig() end)
task.delay(1, function()
    getgenv().qzxp_suppressNotify = false
    Fluent:Notify({Title = "qzxp", Content = "Loaded", Duration = 4})
end)

-- Cleanup
getgenv().qzxp_Cleanup = function()
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
        getgenv().qzxp_VFXConns = nil
        getgenv().qzxp_VFXHooked = nil
        getgenv().qzxp_VFXDisabled = nil
        pcall(function()
            if getgenv().qzxp_thunderDashStop then getgenv().qzxp_thunderDashStop() end
        end)
        if getgenv().qzxp_Threads then
            for _, t in ipairs(getgenv().qzxp_Threads) do
                pcall(function() task.cancel(t) end)
            end
            getgenv().qzxp_Threads = nil
        end
        if getgenv().qzxp_StopRender then
            pcall(getgenv().qzxp_StopRender)
            getgenv().qzxp_StopRender = nil
        end
        pcall(function() if PRV and PRV.Destroy then PRV.Destroy() end end)
        local cg = GetSafeUIParent()
        for _, o in ipairs(cg:GetChildren()) do
            if o:IsA("ScreenGui") and (o.Name:lower():find("qzxp") or o.Name:lower():find("q_")) then
                o:Destroy()
            end
        end
        pcall(function()
            if UA and UA.ready then
                UA.enabled = false
                pcall(function() UA:set_category_unlock(false) end)
                pcall(function() UA:set_modern_unlock(false) end)
                if UA.shop_api and UA.original_set_equipped then
                    pcall(function() UA.shop_api.SetEquipped = UA.original_set_equipped end)
                end
            end
        end)
        getgenv().skinChanger = nil; getgenv().skinChangerEnabled = nil
        getgenv().qzxp_unlockAllActive = nil
        getgenv().swordModel = nil; getgenv().swordAnimations = nil; getgenv().swordFX = nil
        getgenv().slashName = nil; getgenv().updateSword = nil; getgenv().revertSword = nil
        getgenv().saveLastEquippedSword = nil; getgenv().setSkinUI = nil
        getgenv().qzxp_equipSword = nil; getgenv().qzxp_resolveSword = nil
        getgenv().qzxp_forceEquipSword = nil
        getgenv().qzxp_avatarUserId = nil
        getgenv().qzxp_resetAPState = nil
        getgenv().qzxp_Cleanup = nil
        getgenv().qzxp_realSword = nil
    end)
end

end)
