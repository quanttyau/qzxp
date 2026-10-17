-- CREDITS: S14X FOR SPAM AND ANIM FIX
--          LEAKED EAGLE HUB FOR BASICALLY EVERYTHING
--          ANGELI FOR AUTOPARRY AND TRIGGERBOT
-- Rewrite: 8 targeted fixes applied. See [FIX n] tags.

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

-- [FIX 8] Thread registry. Every long-running loop we spawn is tracked here
--         so qzxp_Cleanup can cancel them on reload.
local _threads = {}
local function spawnTracked(fn, ...)
    local t = task.spawn(fn, ...)
    table.insert(_threads, t)
    return t
end
getgenv().qzxp_Threads = _threads

local function isApproachingPlayer(ball, rootPos)
    local z = ball:FindFirstChild('zoomies'); if not z then return false end
    local v = z.VectorVelocity
    if v.Magnitude < 1 then return false end
    return (rootPos - ball.Position).Unit:Dot(v.Unit) > 0.05
end

-- [FIX 3] Single RenderStepped dispatcher. Handlers run in registration order.
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
getgenv().qzxp_StopRender = function()
    if _renderConn then pcall(function() _renderConn:Disconnect() end); _renderConn = nil end
    _renderHandlers = {}
end

task.spawn(function()

-- ============================================================
-- CUSTOM UI LIBRARY
-- ============================================================
local _UIS = game:GetService("UserInputService")
local _HS  = game:GetService("HttpService")
local _TS  = game:GetService("TweenService")

local UITheme = {
    Bg = Color3.fromRGB(15, 15, 18),
    Sidebar = Color3.fromRGB(11, 11, 14),
    Panel = Color3.fromRGB(22, 22, 27),
    Row = Color3.fromRGB(26, 26, 31),
    Border = Color3.fromRGB(46, 46, 56),
    BorderDim = Color3.fromRGB(32, 32, 39),
    Text = Color3.fromRGB(242, 242, 248),
    TextDim = Color3.fromRGB(182, 182, 194),
    TextMute = Color3.fromRGB(126, 126, 138),
    White = Color3.fromRGB(255, 255, 255),
    Black = Color3.fromRGB(0, 0, 0),
    Off = Color3.fromRGB(52, 52, 60),
    Hover = Color3.fromRGB(34, 34, 40),
    GradTop = Color3.fromRGB(22, 22, 27),
    GradBot = Color3.fromRGB(13, 13, 16),
    RowTop = Color3.fromRGB(29, 29, 35),
    RowBot = Color3.fromRGB(21, 21, 25),
    BtnTop = Color3.fromRGB(34, 34, 41),
    BtnBot = Color3.fromRGB(23, 23, 28),
    KnobTop = Color3.fromRGB(255, 255, 255),
    KnobBot = Color3.fromRGB(222, 222, 230),
    OffTop = Color3.fromRGB(58, 58, 68),
    OffBot = Color3.fromRGB(42, 42, 50),
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
    return mk("UIGradient", {Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, top or UITheme.GradTop),
        ColorSequenceKeypoint.new(1, bottom or UITheme.GradBot),
    }), Rotation = rot or 90}, par)
end
local function toKey(v)
    if typeof(v) == "EnumItem" then return v end
    if type(v) == "string" then
        local ok, kc = pcall(function() return Enum.KeyCode[v] end)
        if ok then return kc end
    end
    return Enum.KeyCode.Unknown
end

local Fluent = {Options = {}, Window = nil}
local Options = Fluent.Options

-- ============================================================
-- Notifications
-- ============================================================
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

-- ============================================================
-- Section / Tab / Window
-- ============================================================
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
        BackgroundColor3 = UITheme.BorderDim, BackgroundTransparency = 0.55, BorderSizePixel = 0}, row)
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
    local trackGrad = addGrad(switch, UITheme.OffTop, UITheme.OffBot, 90)
    local knob = mk("Frame", {Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(0, 2, 0.5, -9),
        BackgroundColor3 = UITheme.Text, BorderSizePixel = 0}, switch)
    addCorner(knob, 9); local knobGrad = addGrad(knob, UITheme.KnobTop, UITheme.KnobBot, 90)
    addStroke(knob, UITheme.Border, 1, 0.45)
    local click = mk("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = ""}, switch)
    local obj = {Value = not not opts.Default}
    local function apply(on, animate)
        local knobPos = on and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        trackGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, on and UITheme.White or UITheme.OffTop),
            ColorSequenceKeypoint.new(1, on and Color3.fromRGB(205, 205, 215) or UITheme.OffBot)})
        knobGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, on and Color3.fromRGB(255, 255, 255) or UITheme.KnobTop),
            ColorSequenceKeypoint.new(1, on and Color3.fromRGB(226, 226, 234) or UITheme.KnobBot)})
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
        if _openDropdown then closeDropdown() return end
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
    local obj = {Value = toKey(opts.Default)}
    local function refresh() lbl.Text = listening and "press key..." or (obj.Value and obj.Value.Name or "?") end
    btn.MouseButton1Click:Connect(function() listening = true; suppressUntil = os.clock() + 0.25; refresh() end)
    _UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if listening then
            obj.Value = input.KeyCode; listening = false; suppressUntil = os.clock() + 0.25; refresh()
            if opts.ChangedCallback then pcall(opts.ChangedCallback, obj.Value) end
        else
            if os.clock() < suppressUntil then return end
            if input.KeyCode == obj.Value then if opts.Callback then pcall(opts.Callback, obj.Value) end end
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
    btn.MouseEnter:Connect(function()
        tween(bg, TI_FAST, {BackgroundColor3 = UITheme.Hover})
    end)
    btn.MouseLeave:Connect(function()
        tween(bg, TI_FAST, {BackgroundColor3 = UITheme.Panel})
    end)
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
    local titleBarMask = mk("Frame", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
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

-- ============================================================
-- SaveManager / InterfaceManager shims
-- ============================================================
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
function SaveManager:Load(name)
    local ok, contents = pcall(function() return readfile((self.folder or "qzxp/configs") .. "/" .. name .. ".json") end)
    if not ok or not contents then
        Fluent:Notify({Title = "Config", Content = "Not found: " .. name, Duration = 3}); return
    end
    local ok2, data = pcall(function() return _HS:JSONDecode(contents) end)
    if not ok2 or type(data) ~= "table" then
        Fluent:Notify({Title = "Config", Content = "Invalid config", Duration = 3}); return
    end
    for id, entry in pairs(data) do
        local opt = Fluent.Options[id]
        if opt and opt.SetValue then
            local v = entry.v
            if entry.t == "EnumItem" then
                local ok3, e = pcall(function() return Enum[entry.c][entry.v] end)
                if ok3 then v = e end
            end
            pcall(function() opt:SetValue(v) end)
        end
    end
    Fluent:Notify({Title = "Config", Content = "Loaded: " .. name, Duration = 3})
end
function SaveManager:BuildConfigSection(tab)
    local s = tab:AddSection("Config")
    s:AddInput("__cfgname", {Title = "Config Name", Default = "default", Placeholder = "name"})
    s:AddButton({Title = "Save", Callback = function()
        local n = Fluent.Options.__cfgname and Fluent.Options.__cfgname.Value or "default"
        if n == "" then n = "default" end
        self:Save(n)
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

-- ============================================================
-- Window & Tabs
-- ============================================================
local Window = Fluent:CreateWindow({Title = "qzxp", TabWidth = 130,
    Size = UDim2.fromOffset(750, 450), MinimizeKey = Enum.KeyCode.LeftControl})
local Tabs = {
    Main = Window:AddTab({Title = "Parry"}), Detection = Window:AddTab({Title = "Detect"}),
    Spam = Window:AddTab({Title = "Spam"}), Trigger = Window:AddTab({Title = "Trigger"}),
    Skins = Window:AddTab({Title = "Skins"}), Lock = Window:AddTab({Title = "Lock"}),
    Visuals = Window:AddTab({Title = "Visuals"}), Settings = Window:AddTab({Title = "Config"}),
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

local AP_On, TB_On, Spam_On = false, false, false
local frameCount = 0

local Stats_Network = Stats.Network
local Stats_DataPing = Stats_Network and Stats_Network.ServerStatsItem and Stats_Network.ServerStatsItem["Data Ping"]

local suppressNotifies = false
local function notify(cfg)
    if suppressNotifies then return end
    task.defer(function() pcall(function() Fluent:Notify(cfg) end) end)
end

-- ============================================================
-- [FIX 4] ANTICHEAT BYPASS — retry-capable token finder
-- ============================================================
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

-- [FIX 6] _tokenize: empty token guard, pcall around _token call
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
    local n = norm(input)
    if SwordRegistry[n] then return SwordRegistry[n] end
    for nk, actual in pairs(SwordRegistry) do
        if nk:find(n, 1, true) then return actual end
    end
    return input
end

-- ============================================================
-- ANIMATION SYSTEM
-- ============================================================
local AnimFix_AP, AnimFix_TB, AnimFix_Spam = true, true, true
local AnimFix_Cache = {}
local ANIM_FAIL = false  -- [FIX 2] sentinel for "tried, failed"

local function GetParryAnimation(swordName)
    if not swordName or swordName == "" then
        return SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    end
    local cached = AnimFix_Cache[swordName]
    if cached ~= nil then
        if cached == ANIM_FAIL then
            return SwordAPI.Collection.Default:FindFirstChild("GrabParry")
        end
        return cached
    end
    local ok, swordData = pcall(function()
        return ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(swordName)
    end)
    if not ok or not swordData or type(swordData) ~= "table" or not swordData.AnimationType then
        AnimFix_Cache[swordName] = ANIM_FAIL
        return SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    end
    for _, obj in pairs(SwordAPI.Collection:GetChildren()) do
        if obj.Name == swordData.AnimationType then
            local anim = obj:FindFirstChild("GrabParry") or obj:FindFirstChild("Grab")
            if anim then AnimFix_Cache[swordName] = anim return anim end
        end
    end
    AnimFix_Cache[swordName] = ANIM_FAIL
    return SwordAPI.Collection.Default:FindFirstChild("GrabParry")
end

local function PlayParryAnimation()
    local char = LocalPlayer.Character; if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator"); if not animator then return end
    local animation = GetParryAnimation(char:GetAttribute("CurrentlyEquippedSword")); if not animation then return end
    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        if track.Name == "GrabParry" or track.Name == "Grab" then
            pcall(function() track.TimePosition = 0 end); pcall(function() track:Stop(0.1) end)
        elseif track.Name == "SuccessParry" or track.Name == "Success" then
            pcall(function() track:Stop(0.1) end)
        end
    end
    local ok, newTrack = pcall(function() return animator:LoadAnimation(animation) end)
    if ok and newTrack then
        pcall(function()
            newTrack:Play(newTrack:GetAttribute("PlayFadeTime") or 0,
                newTrack:GetAttribute("PlayWeight") or 1, newTrack:GetAttribute("PlaySpeed") or 1)
        end)
    end
end

local SingleAnimLast = 0
local function PlaySingleParryAnimation()
    if os.clock() - SingleAnimLast < 0.1 then return end
    SingleAnimLast = os.clock()
    PlayParryAnimation()
end

local SpamAnimRate, SpamAnimLastPlayed, SpamAnimBypass = 140, 0, false
local SpamAnimDelayLimit, SpamAnimSpammingMode, SpamAnimParries = 0, false, 0
local SpamAnimMatchRPS = false

local function SpamParryAnimation()
    if os.clock() - SpamAnimDelayLimit >= (1 / SpamAnimRate) then
        SpamAnimDelayLimit = os.clock()
        if (os.clock() - SpamAnimLastPlayed) >= 0.1 or SpamAnimBypass or SpamAnimSpammingMode then
            SpamAnimLastPlayed = os.clock(); SpamAnimBypass = false
            PlayParryAnimation()
        end
    end
end

spawnTracked(function()
    while true do SpamAnimSpammingMode = (SpamAnimParries > 1); task.wait(0.1) end
end)

local _tbLastFire, _apLastFire = 0, 0
local function _shouldTouchParryAnim()
    if Spam_On and AnimFix_Spam then return true end
    if TB_On and AnimFix_TB then return (os.clock() - _tbLastFire) < 0.5 end
    if AP_On and AnimFix_AP then return (os.clock() - _apLastFire) < 0.5 end
    return false
end
local function StopParryGrabTracks()
    local char = LocalPlayer.Character; if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator"); if not animator then return end
    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        if track.Name == "GrabParry" or track.Name == "Grab" then
            pcall(function() track:Stop(0.1) end)
        end
    end
end

pcall(function()
    ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
        if SpamAnimParries < 5 then
            SpamAnimParries += 1
            task.delay(0.05, function() if SpamAnimParries > 0 then SpamAnimParries -= 1 end end)
        end
        SpamAnimBypass = true
        if not _shouldTouchParryAnim() then return end
        StopParryGrabTracks()
    end)
end)
pcall(function()
    ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function()
        if not _shouldTouchParryAnim() then return end
        StopParryGrabTracks()
    end)
end)

-- ============================================================
-- BALL SYSTEM (event-driven cache)
-- ============================================================
local _ballCache = {}
local _ballCacheDirty = true
local _ballCanCollideSet = setmetatable({}, {__mode = "k"})
local function _markBallsDirty() _ballCacheDirty = true end

-- [RESPAWN RESET] A ball "respawns" whenever its realBall attribute
-- flips to true (fresh instance, or a pooled Instance being reused).
-- Every subsystem that keeps per-ball state registers a handler here.
local _ballRespawnHandlers = {}
local function _onBallRespawn(ball)
    _ballCacheDirty = true                -- force cache rebuild
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
            -- Already active at spawn time -> fire reset immediately.
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
-- Returns all balls currently targeting the local player. Reuses the
-- passed table if given, so callers can keep a scratch buffer and avoid
-- allocating every frame.
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

-- ============================================================
-- [FIX 1] PING — rolling minimum over last N samples
-- ============================================================
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

-- ============================================================
-- CURVE DETECTION
-- ============================================================
-- Per-ball curve state. Weak-keyed by ball so destroyed balls don't leak.
local CurveState = setmetatable({}, {__mode = "k"})
local function _newCurveState()
    return {
        __last_warping = tick(), __lerp_radians = 0, __curving = tick(),
        __prev_vel = {}, __prev_vel_n = 0, __prev_vel_head = 0,
        __tornado_time = tick()
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

-- ============================================================
-- [FIX 7] TARGET TRACKING — reset curve buffers on ball change
-- ============================================================
-- Per-ball sender tracking. Weak-keyed by ball so destroyed balls don't leak.
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
    local af = Workspace:FindFirstChild("Alive")
    if af then local c = af:FindFirstChild(name); if c then return c.PrimaryPart or c:FindFirstChild("HumanoidRootPart") end end
    local p = Players:FindFirstChild(name)
    if p and p.Character then return p.Character.PrimaryPart end
end

local LockEnabled, LockTarget = false, "None"
local HLEnabled, HLColor = false, Color3.fromRGB(255, 60, 60)
local hlInst = nil
local function clearHL() if hlInst then pcall(function() hlInst:Destroy() end); hlInst = nil end end
local function refreshHL()
    clearHL()
    if not HLEnabled or LockTarget == "None" then return end
    local p = findPart(LockTarget)
    if p and p.Parent then
        local h = Instance.new("Highlight")
        h.Name = "PL_HL"; h.FillColor = HLColor; h.OutlineColor = HLColor
        h.FillTransparency = 0.6; h.OutlineTransparency = 0
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; h.Adornee = p.Parent; h.Parent = p.Parent
        hlInst = h
    end
end
spawnTracked(function()
    while task.wait(0.5) do
        if HLEnabled then if not hlInst or not hlInst.Parent then refreshHL() end
        else clearHL() end
    end
end)

local function closestToCursor()
    local ml; pcall(function() ml = UserInputService:GetMouseLocation() end)
    local c = ml or Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bp = math.huge, nil
    local af = Workspace:FindFirstChild("Alive")
    if af then
        for _, v in pairs(af:GetChildren()) do
            if v ~= LocalPlayer.Character and v.PrimaryPart then
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

-- ============================================================
-- CURVE CFRAME
-- ============================================================
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
    if LockEnabled and tp then cachedCF = CFrame.new(rp, tpos); return cachedCF end
    local m = (Options and Options.CurveMode and Options.CurveMode.Value) or CurveMode
    local resCF = Camera.CFrame
    if m == "Camera" then resCF = Camera.CFrame
    elseif m == "Dot" then
        if ball then
            local z = ball:FindFirstChild("zoomies")
            local v = z and z.VectorVelocity or Vector3.zero
            local d = v.Magnitude > 1 and -v.Unit or (tpos - rp).Unit
            resCF = CFrame.new(rp, rp + d * 100)
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
-- [[ GLOBAL AP/TB LOCKOUT — ported from angeli ]]
-- After any successful AP or TB fire, ALL AP/TB fires are blocked until the
-- parried ball's `target` attribute no longer equals the local player, OR
-- 1.0 second elapses (hard timeout). This replaces the old per-ball
-- `parryLockouts` / `firedForCycle` trackers so the two systems can't clash.
--
-- Allocation notes:
--   * at most ONE connection is alive at any time (_apLockedConn)
--   * no per-ball tables that grow with ball count
--   * isAPLocked() is allocation-free (reads 2 locals + os.clock())
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
            if ball:GetAttribute('target') ~= _lpName then
                clearAPLockout()
            end
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
    -- Lockout is NOT set here. Callers (tryAPForBall / tryTBForBall) call
    -- setAPLockout() after a successful fire. Spam deliberately skips it.
    return true
end

-- ============================================================
-- AUTOPARRY
-- ============================================================
local AP_Acc, AP_Div = 50, 1.1
local RandAcc, AutoAbility = false, false

-- Shared parry-range calculation. Used by both the AP engine and the
-- range visualizer so the drawn ring always matches what AP actually uses.
--
-- Time-to-impact formulation. Equivalent trigger condition:
--   tti           = dist / max(spd, 1)
--   effective_tti = tti - ping/1000 - 0.03
--   fire when effective_tti <= reaction
-- The returned value is the distance at which that condition becomes true.
local function computeTriggerDist(spd, ping, curved, acc)
    local reaction = 0.20 + ((acc or 50) - 1) * (0.15 / 99)
    if curved then reaction = reaction * 1.25 end
    return math.max(spd * (reaction + (ping or 0) / 1000 + 0.03), 18)
end
local function updDiv() AP_Div = 0.7 + (AP_Acc - 1) * (0.9 / 99) end
updDiv()

spawnTracked(function()
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

local InfOn, DSOn, THOn, SFOn = false, false, false, false
local InfDet, DSDet, THDet, SFDet = false, false, false, false

pcall(function()
    ReplicatedStorage.Remotes.DeathBall.OnClientEvent:Connect(function(_, d) DSOn = d or false end)
    ReplicatedStorage.Remotes.InfinityBall.OnClientEvent:Connect(function(_, b) InfOn = b or false end)
end)

local _lpName = LocalPlayer.Name
local function _argsContainMe(a)
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
_hookNetEvent("RE/TimeHoleActivate", function(a) if _argsContainMe(a) then THOn = true end end)
_hookNetEvent("RE/TimeHoleDeactivate", function(a) if _argsContainMe(a) then THOn = false end end)
_hookNetEvent("RE/SlashesOfFuryActivate", function(a) if _argsContainMe(a) then SFOn = true end end)
_hookNetEvent("RE/SlashesOfFuryEnd", function(a) if _argsContainMe(a) then SFOn = false end end)

-- ============================================================
-- [FIX 3] AP / TB / Spam as RenderStepped handlers
-- ============================================================
do
addRenderHandler(function()
    frameCount += 1
    _frameBlockOk = nil
end, 1)

-- ============================================================
-- AUTOPARRY — event-driven arming, range-gated firing
-- ============================================================
-- Two-stage "triggerbot" behaviour:
--   Stage 1 (event-driven): ball acquires us as target  -> AP arms on that ball.
--   Stage 2 (render tick on armed balls only): ball enters parry range
--           (computeTriggerDist, unchanged) -> fire.
local _apArmed = setmetatable({}, {__mode = "k"})
local _apConns = setmetatable({}, {__mode = "k"})
table.insert(_ballRespawnHandlers, function(ball)
    _apArmed[ball] = nil
    if _apLocked and _apLockedBall == ball then clearAPLockout() end
end)

local function tryAPForBall(ball)
    if not AP_On or TB_On then return end
    if not ball or not ball.Parent then return end

    -- [[ GLOBAL AP LOCKOUT ]] — skip ALL AP work while locked (angeli port).
    if isAPLocked() then return end

    if not _apArmed[ball] then return end
    if ball:GetAttribute('target') ~= _lpName then _apArmed[ball] = nil; return end
    if _frameBlockOk == nil then _frameBlockOk = IsBlockLegit() end
    if not _frameBlockOk then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or root:FindFirstChild('SingularityCape') then return end

    local z = ball:FindFirstChild('zoomies')
    if not z then return end

    if ball:FindFirstChild('AeroDynamicSlashVFX') then ball.AeroDynamicSlashVFX:Destroy() end
    if ball:FindFirstChild('ComboCounter') then return end
    if InfDet and InfOn then return end
    if DSDet and DSOn then return end
    if THDet and THOn then return end
    if SFDet and SFOn then return end

    local vel = z.VectorVelocity
    local dist = (root.Position - ball.Position).Magnitude
    local spd = math.max(vel.Magnitude, 1)
    local ping = getPing()
    local curved = isCurvedCached(ball)

    -- Trigger-range is the sole distance gate. computeTriggerDist already
    -- scales reaction by 1.25x for curved balls and adds ping compensation,
    -- so the old hardcoded 18-stud curved cap and the velocity-direction
    -- check were rejecting valid in-window parries. Removed.
    local trigger_dist = computeTriggerDist(spd, ping, curved, AP_Acc)
    if dist > trigger_dist then return end

    if AutoAbility then
        pcall(function()
            local cd = LocalPlayer.PlayerGui.Hotbar.Ability.UIGradient
            if cd and cd.Offset.Y == 0.5 and char:FindFirstChild("Abilities") then
                local ab = char.Abilities
                if (ab:FindFirstChild("Raging Deflection") and ab["Raging Deflection"].Enabled) or
                   (ab:FindFirstChild("Rapture") and ab["Rapture"].Enabled) or
                   (ab:FindFirstChild("Calming Deflection") and ab["Calming Deflection"].Enabled) or
                   (ab:FindFirstChild("Aerodynamic Slash") and ab["Aerodynamic Slash"].Enabled) or
                   (ab:FindFirstChild("Fracture") and ab["Fracture"].Enabled) or
                   (ab:FindFirstChild("Death Slash") and ab["Death Slash"].Enabled) then
                    ReplicatedStorage.Remotes.AbilityButtonPress:Fire()
                end
            end
        end)
    end

    local fired = fireRemote(ball)
    if fired then
        _apLastFire = os.clock()
        _apArmed[ball] = nil
        setAPLockout(ball)   -- [[ GLOBAL AP LOCKOUT ]] arm the gate
        if AnimFix_AP then PlaySingleParryAnimation() end
    end
end

local function _attachAP(ball)
    if not ball or _apConns[ball] then return end
    if not ball:GetAttribute('realBall') then
        local waitConn
        waitConn = ball:GetAttributeChangedSignal('realBall'):Connect(function()
            if ball:GetAttribute('realBall') then
                if waitConn then pcall(function() waitConn:Disconnect() end) end
                _attachAP(ball)
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
            _apArmed[ball] = true
            _resetCurveState(ball)
            task.defer(function()
                if AP_On and not TB_On and not Spam_On and ball.Parent
                   and ball:GetAttribute('target') == _lpName then
                    tryAPForBall(ball)
                end
            end)
        else
            _apArmed[ball] = nil
        end
    end)
    _apConns[ball] = conn
    if ball:GetAttribute('target') == _lpName then
        _apArmed[ball] = true
        _resetCurveState(ball)
    end
    ball.Destroying:Once(function()
        if conn then pcall(function() conn:Disconnect() end) end
        _apConns[ball] = nil
        _apArmed[ball] = nil
    end)
end

spawnTracked(function()
    local function watchFolder(folder)
        if not folder then return end
        for _, ball in ipairs(folder:GetChildren()) do _attachAP(ball) end
        folder.ChildAdded:Connect(_attachAP)
    end
    watchFolder(Workspace:WaitForChild('Balls', 9e9))
    watchFolder(Workspace:WaitForChild('TrainingBalls', 30))
end)

-- Only walks balls that have us as target. Much lighter than the old
-- "loop every ball every frame" approach.
local _apScanN = 0
addRenderHandler(function()
    if not AP_On or TB_On or Spam_On then return end
    if _frameBlockOk == nil then _frameBlockOk = IsBlockLegit() end
    if not _frameBlockOk then return end
    _apScanN += 1
    if _apScanN >= 8 then
        _apScanN = 0
        local function scanFolder(folder)
            if not folder then return end
            for _, ball in ipairs(folder:GetChildren()) do
                if ball:GetAttribute('realBall') then
                    if not _apConns[ball] then _attachAP(ball) end
                    if ball:GetAttribute('target') == _lpName then
                        _apArmed[ball] = true
                    end
                end
            end
        end
        scanFolder(Workspace:FindFirstChild('Balls'))
        scanFolder(Workspace:FindFirstChild('TrainingBalls'))
    end
    for ball in pairs(_apArmed) do
        if ball and ball.Parent then
            tryAPForBall(ball)
        else
            _apArmed[ball] = nil
        end
    end
end, 2)

end

-- ============================================================
-- PARRY RANGE VISUALIZER
-- ============================================================
-- Collapsed into a single table to keep the enclosing function
-- under Luau's 200-register ceiling. Table methods do not consume
-- a local register slot, only the `PRV` binding does.
local PRV = {
    On           = false,
    Model        = nil,
    Segments     = {},
    SEG_COUNT    = 48,
    COLOR        = Color3.fromRGB(255, 255, 255),
    TRANSPARENCY = 0.35,
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

addRenderHandler(function()
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
    -- [[ GLOBAL AP/TB LOCKOUT ]] shared with AP (AP and TB are mutually exclusive)
    if isAPLocked() then return end
    if ball:GetAttribute('target') ~= _lpName then return end
    if not IsBlockLegit() then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or root:FindFirstChild('SingularityCape') then return end
    if ball:FindFirstChild('AeroDynamicSlashVFX') then ball.AeroDynamicSlashVFX:Destroy() end
    if ball:FindFirstChild('ComboCounter') then return end
    if InfDet and InfOn then return end
    if DSDet and DSOn then return end
    if THDet and THOn then return end
    if SFDet and SFOn then return end
    local fired = fireRemote(ball)
    if fired then
        _tbLastFire = os.clock()
        setAPLockout(ball)   -- [[ GLOBAL AP/TB LOCKOUT ]]
        if AnimFix_TB then PlaySingleParryAnimation() end
    end
end

addRenderHandler(function()
    if not TB_On or Spam_On then return end
    if _frameBlockOk == nil then _frameBlockOk = IsBlockLegit() end
    if not _frameBlockOk then return end
    -- [[ GLOBAL AP/TB LOCKOUT ]]
    if isAPLocked() then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or root:FindFirstChild('SingularityCape') then return end
    local balls = getAllBalls()
    for _, ball in pairs(balls) do
        if ball:GetAttribute('target') ~= _lpName then continue end
        if ball:FindFirstChild('ComboCounter') then continue end
        if InfDet and InfOn then continue end
        if DSDet and DSOn then continue end
        if THDet and THOn then continue end
        if SFDet and SFOn then continue end
        local fired = fireRemote(ball)
        if fired then
            _tbLastFire = os.clock()
            setAPLockout(ball)   -- [[ GLOBAL AP/TB LOCKOUT ]]
            if AnimFix_TB then PlaySingleParryAnimation() end
            break                -- lockout is now armed → stop scanning
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
                if TB_On and not Spam_On and ball and ball.Parent and ball:GetAttribute('target') == _lpName then
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
    if InfDet and InfOn then return false end
    if DSDet and DSOn then return false end
    if THDet and THOn then return false end
    if SFDet and SFOn then return false end
    return true
end
local timeAccumulator = 0
addRenderHandler(function(dt)
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
        if AnimFix_Spam then SpamParryAnimation() end
    end
end, 4)

-- ============================================================
-- SWORD CHANGER
-- ============================================================
do
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
do
    local s = loadSaved()
    getgenv().skinChanger = getgenv().skinChanger or s ~= ""
    getgenv().swordModel = type(getgenv().swordModel) == "string" and getgenv().swordModel ~= "" and getgenv().swordModel or s
    getgenv().swordAnimations = type(getgenv().swordAnimations) == "string" and getgenv().swordAnimations ~= "" and getgenv().swordAnimations or s
    getgenv().swordFX = type(getgenv().swordFX) == "string" and getgenv().swordFX ~= "" and getgenv().swordFX or s
end

local realSword = ""
local _realSwordConn = nil
local function trackReal()
    local c = LocalPlayer.Character; if not c then return end
    realSword = c:GetAttribute("CurrentlyEquippedSword") or ""
    if _realSwordConn then pcall(function() _realSwordConn:Disconnect() end) end
    _realSwordConn = c:GetAttributeChangedSignal("CurrentlyEquippedSword"):Connect(function()
        if not getgenv().skinChanger then realSword = c:GetAttribute("CurrentlyEquippedSword") or "" end
    end)
end
LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); trackReal() end)
if LocalPlayer.Character then trackReal() end

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

local function equip(name)
    if not LocalPlayer.Character then return end
    local exact = resolve(name)
    pcall(function()
        local f = rawget(swordModule, "EquipSwordTo")
        if type(f) == "function" then
            local ups = getupvalues(f)
            for i = 1, #ups do
                if type(ups[i]) == "boolean" then setupvalue(f, i, false); break end
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
    refreshSlash(); AnimFix_Cache = {}
    if getgenv().skinChanger and getgenv().swordModel ~= "" then
        getgenv().saveLastEquippedSword(getgenv().swordModel)
        equip(getgenv().swordModel)
    end
end
getgenv().revertSword = function()
    if realSword ~= "" then equip(realSword) end
    AnimFix_Cache = {}
end

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
                                if isMe and getgenv().skinChanger then
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
                                -- [FIX 5] Thread identity NOT lowered. Just call the target.
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
    if getgenv().skinChanger and getgenv().swordModel ~= "" then
        task.wait(2)
        local char = LocalPlayer.Character
        if char then
            local exact = resolve(getgenv().swordModel)
            if exact and exact ~= "" then
                if LocalPlayer:GetAttribute("CurrentlyEquippedSword") ~= exact then equip(exact) end
                if not char:FindFirstChild(exact) then equip(exact) end
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
end -- sword changer scope

-- ============================================================
-- HEADLESS / KORBLOX
-- ============================================================
local Headless, Korblox = false, false
local headBak, kBuilt, legBak = nil, {}, {}
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
    if headBak then
        local b = headBak; headBak = nil
        if b.p and b.p.Parent then pcall(function() b.p.Transparency = b.t; b.p.LocalTransparencyModifier = 0 end) end
        for _, e in ipairs(b.d) do if e.i and e.i.Parent then pcall(function() e.i.Transparency = e.t end) end end
    end
    headBak = {p = h, t = h.Transparency, d = {}}
    pcall(function() h.Transparency = 1; h.LocalTransparencyModifier = 1 end)
    for _, d in ipairs(h:GetChildren()) do
        if d:IsA("Decal") or d:IsA("Texture") then
            table.insert(headBak.d, {i=d, t=d.Transparency}); pcall(function() d.Transparency = 1 end)
        end
    end
    for _, a in ipairs(c:GetChildren()) do
        if a:IsA("Accessory") then
            local hdl = a:FindFirstChild("Handle")
            if hdl and (hdl:FindFirstChild("FaceFrontAttachment") or hdl:FindFirstChild("FaceCenterAttachment")) then
                table.insert(headBak.d, {i=hdl, t=hdl.Transparency}); pcall(function() hdl.Transparency = 1 end)
                for _, d in ipairs(hdl:GetDescendants()) do
                    if d:IsA("Decal") or d:IsA("Texture") then
                        table.insert(headBak.d, {i=d, t=d.Transparency}); pcall(function() d.Transparency = 1 end)
                    end
                end
            end
        end
    end
end
local function undoHeadless()
    if not headBak then return end
    local b = headBak; headBak = nil
    if b.p and b.p.Parent then pcall(function() b.p.Transparency = b.t; b.p.LocalTransparencyModifier = 0 end) end
    for _, e in ipairs(b.d) do if e.i and e.i.Parent then pcall(function() e.i.Transparency = e.t end) end end
end
local function clearK()
    for _, e in ipairs(kBuilt) do if typeof(e) == "Instance" then pcall(function() e:Destroy() end) end end
    kBuilt = {}
end
local function restoreLegs()
    for _, e in ipairs(legBak) do
        if e.p and e.p.Parent then pcall(function() e.p.Transparency = e.t; e.p.LocalTransparencyModifier = 0 end) end
    end
    legBak = {}
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
        table.insert(legBak, {p=p, t=p.Transparency}); pcall(function() p.Transparency = 1; p.LocalTransparencyModifier = 1 end)
    end
    table.insert(kBuilt, fake)
end
local function undoKorblox() clearK(); restoreLegs(); cleanK(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function()
    headBak = nil; kBuilt, legBak = {}, {}
    task.wait(1)
    if Korblox then doKorblox() end
    if Headless then doHeadless() end
end)

-- ============================================================
-- ESP
-- ============================================================
local ESP_On = false
local espC = {}
local espHeads = setmetatable({}, {__mode = "k"})
local function updateESP()
    if not ESP_On then
        for _, d in pairs(espC) do if d then pcall(function() d:Destroy() end) end end
        espC = {}; return
    end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local head = espHeads[p]
            if not head or not head.Parent then
                local c = p.Character; head = c and c:FindFirstChild("Head"); espHeads[p] = head
            end
            if head then
                local existing = espC[p]
                if not existing or existing.Adornee ~= head then
                    if existing then pcall(function() existing:Destroy() end) end
                    local bb = Instance.new("BillboardGui")
                    bb.Name = "qESP"; bb.Adornee = head; bb.Size = UDim2.new(0, 200, 0, 40)
                    bb.StudsOffset = Vector3.new(0, 3, 2); bb.AlwaysOnTop = true; bb.Parent = head
                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
                    lbl.TextColor3 = Color3.new(1,1,1); lbl.TextStrokeTransparency = 0.5
                    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 14; lbl.Parent = bb
                    espC[p] = bb
                end
                local lbl = espC[p] and espC[p]:FindFirstChildOfClass("TextLabel")
                if lbl then
                    local ab = p:GetAttribute("EquippedAbility")
                    lbl.Text = ab and (p.DisplayName .. " [" .. ab .. "]") or p.DisplayName
                end
            end
        end
    end
end
spawnTracked(function() while task.wait(0.25) do if ESP_On then updateESP() end end end)

-- ============================================================
-- KEYBIND LIST & BALL STATS
-- ============================================================
local KBShow = false
local BS_On = false
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
local kbG = Instance.new("UIGradient"); kbG.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 22, 26)), ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12))}); kbG.Rotation = 90; kbG.Parent = kbF
local kbS = Instance.new("UIStroke"); kbS.Color = Color3.fromRGB(58, 58, 66); kbS.Transparency = 0.25; kbS.Parent = kbF
local kbT = Instance.new("TextLabel"); kbT.Size = UDim2.new(1, 0, 0, 28); kbT.BackgroundColor3 = Color3.fromRGB(30, 30, 34); kbT.BackgroundTransparency = 0.2; kbT.Font = Enum.Font.GothamBold; kbT.TextSize = 13; kbT.TextColor3 = Color3.fromRGB(230, 230, 235); kbT.Text = "  Keybind List"; kbT.TextXAlignment = Enum.TextXAlignment.Left; kbT.Parent = kbF
Instance.new("UICorner", kbT).CornerRadius = UDim.new(0, 8)
local kbC = Instance.new("Frame"); kbC.Size = UDim2.new(1, -10, 1, -34); kbC.Position = UDim2.new(0, 5, 0, 31); kbC.BackgroundTransparency = 1; kbC.Parent = kbF
Instance.new("UIListLayout", kbC).Padding = UDim.new(0, 4)
MakeDrag(kbT, kbF)
local function keyStr(o) if not o then return "?" end; local v = o.Value; return typeof(v) == "EnumItem" and v.Name or tostring(v) end
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
local bsG = Instance.new("UIGradient"); bsG.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 22, 26)), ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12))}); bsG.Rotation = 90; bsG.Parent = bsF
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
addRenderHandler(function()
    local now = os.clock()
    if now - uiLast < 0.1 then return end
    uiLast = now
    kbF.Visible = KBShow
    if KBShow then
        for i, it in ipairs(kbItems) do
            local s = it.s(); local k = it.k()
            local txt = "[" .. k .. "] " .. it.n .. " " .. (s and "<font color='#4cd964'>ON</font>" or "<font color='#ff3b30'>OFF</font>")
            if txt ~= kbLastText[i] then
                kbLastText[i] = txt
                local lbl = kbL[i]; lbl.RichText = true; lbl.Text = txt
            end
        end
    end
    bsF.Visible = BS_On
    if BS_On then
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
end)() -- kb/bs scope

-- ============================================================
-- STATS HUD (FPS + Ping) — draggable, matches kb/bs styling
-- ============================================================
local Stats_ShowFPS = false
local Stats_ShowPing = false

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

-- Same visual language as kbF / bsF, and positioned in the same column:
-- sits just below the keybind list (which is at 0.5, -100 with height 200).
local statsF = Instance.new("Frame")
statsF.Size = UDim2.new(0, 220, 0, 78)
statsF.Position = UDim2.new(1, -235, 0.5, 108)
statsF.BackgroundColor3 = Color3.fromRGB(17, 17, 19)
statsF.Visible = false
statsF.Parent = statsGui
statsF.ClipsDescendants = true
Instance.new("UICorner", statsF).CornerRadius = UDim.new(0, 10)

local statsG = Instance.new("UIGradient")
statsG.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 22, 26)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
})
statsG.Rotation = 90
statsG.Parent = statsF

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

addRenderHandler(function(dt)
    if dt and dt > 0 then
        _fpsAvg = _fpsAvg * 0.9 + (1 / dt) * 0.1
    end
    local now = os.clock()
    if now - _statsLast < 0.15 then return end
    _statsLast = now

    statsF.Visible = Stats_ShowFPS or Stats_ShowPing
    fpsLbl.Visible  = Stats_ShowFPS
    pingLbl.Visible = Stats_ShowPing

    if Stats_ShowFPS then
        local t = string.format("FPS: %d", math.floor(_fpsAvg + 0.5))
        if t ~= _lastFpsTxt then _lastFpsTxt = t; fpsLbl.Text = t end
    end
    if Stats_ShowPing then
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
do
    local s1 = Tabs.Main:AddSection("Autoparry")
    s1:AddToggle("APToggle", {Title = "Enabled", Default = false, Callback = function(v) AP_On = v; notify({Title = "AP", Content = v and "On" or "Off", Duration = 2}) end})
    s1:AddSlider("Accuracy", {Title = "Accuracy", Default = 50, Min = 1, Max = 100, Rounding = 1, Callback = function(v) AP_Acc = v; updDiv() end})
    s1:AddToggle("RandAccToggle", {Title = "Randomize Acc", Default = false, Callback = function(v) RandAcc = v end})
    s1:AddDropdown("CurveMode", {Title = "Curve", Values = CURVES, Default = "Camera", Multi = false, Callback = function(v) CurveMode = v end})
    s1:AddToggle("AbilityToggle", {Title = "Auto Ability", Default = false, Callback = function(v) AutoAbility = v end})
    s1:AddToggle("AnimFixAP", {Title = "Anim Fix", Default = true, Callback = function(v) AnimFix_AP = v end})
    s1:AddKeybind("APKey", {Title = "Keybind", Default = "P", Callback = function()
        if Options.APToggle then Options.APToggle:SetValue(not AP_On) end
    end, ChangedCallback = function() end})
end
do
    local s2 = Tabs.Detection:AddSection("Detections")
    s2:AddToggle("InfDet", {Title = "Infinity", Default = false, Callback = function(v) InfDet = v end})
    s2:AddToggle("DSDet", {Title = "Death Slash", Default = false, Callback = function(v) DSDet = v end})
    s2:AddToggle("THDet", {Title = "Time Hole", Default = false, Callback = function(v) THDet = v end})
    s2:AddToggle("SFDet", {Title = "Slashes of Fury", Default = false, Callback = function(v) SFDet = v end})
end
do
    local s3 = Tabs.Spam:AddSection("Spam")
    s3:AddToggle("SpamToggle", {Title = "Enabled", Default = false, Callback = function(v) Spam_On = v; notify({Title = "Spam", Content = v and "On" or "Off", Duration = 2}) end})
    local spamRPSSlider
    spamRPSSlider = s3:AddSlider("SpamRPS", {
        Title = "RPS", Default = 100, Min = 5, Max = 1000, Rounding = 0,
        Callback = function(v)
            local snapped = math.clamp(math.floor(v / 10 + 0.5) * 10, 5, 1000)
            SpamRPS = snapped; SpamInt = 1 / snapped
            if SpamAnimMatchRPS then SpamAnimRate = snapped end
            if spamRPSSlider and spamRPSSlider.Value ~= snapped then
                task.defer(function() pcall(function() spamRPSSlider:SetValue(snapped) end) end)
            end
        end,
    })
    s3:AddToggle("SpamAnimMatchRPS", {
        Title = "Match Anim Rate to RPS",
        Default = false,
        Callback = function(v)
            SpamAnimMatchRPS = v
            SpamAnimRate = v and SpamRPS or 100
        end,
    })
    s3:AddToggle("SpamDet", {Title = "Respect Detections", Default = true, Callback = function(v) SpamDetect = v end})
    s3:AddToggle("AnimFixSpam", {Title = "Anim Fix", Default = true, Callback = function(v) AnimFix_Spam = v end})
    s3:AddKeybind("SpamKey", {Title = "Keybind", Default = "E", Callback = function()
        if Options.SpamToggle then Options.SpamToggle:SetValue(not Spam_On) else Spam_On = not Spam_On end
    end, ChangedCallback = function() end})
end
do
    local s4 = Tabs.Trigger:AddSection("Triggerbot")
    s4:AddToggle("TBToggle", {Title = "Enabled", Default = false, Callback = function(v) TB_On = v; notify({Title = "TB", Content = v and "On" or "Off", Duration = 2}) end})
    s4:AddToggle("AnimFixTB", {Title = "Anim Fix", Default = true, Callback = function(v) AnimFix_TB = v end})
    s4:AddKeybind("TBKey", {Title = "Keybind", Default = "R", Callback = function()
        if Options.TBToggle then Options.TBToggle:SetValue(not TB_On) end
    end, ChangedCallback = function() end})
end
do
    local s5 = Tabs.Skins:AddSection("Sword Changer")
    local skinRef = s5:AddToggle("SkinToggle", {Title = "Enabled", Default = false, Callback = function(v)
        getgenv().skinChanger = v; getgenv().skinChangerEnabled = v
        if v and getgenv().swordModel ~= "" then pcall(getgenv().updateSword)
        elseif not v then pcall(getgenv().revertSword) end
    end})
    getgenv().setSkinUI = function(v)
        if skinRef and skinRef.Value ~= v then
            skinRef:SetValue(v); getgenv().skinChanger = v; getgenv().skinChangerEnabled = v
        end
    end
    s5:AddInput("ManualSword", {Title = "Sword Name", Default = "", Placeholder = "type sword name...", Callback = function(v)
        local n = v and v:match("^%s*(.-)%s*$") or ""
        local e = resolve(n)
        if getgenv().skinChanger then pcall(getgenv().revertSword) end
        getgenv().swordModel = e; getgenv().swordAnimations = e; getgenv().swordFX = e
        if getgenv().skinChanger and e ~= "" then pcall(getgenv().updateSword) end
        pcall(getgenv().saveLastEquippedSword, e)
    end})
end
do
    local s6 = Tabs.Lock:AddSection("Parry Lock")
    s6:AddToggle("LockToggle", {Title = "Enabled", Default = false, Callback = function(v) LockEnabled = v; notify({Title = "Lock", Content = v and "On" or "Off", Duration = 2}) end})
    s6:AddDropdown("LockTarget", {Title = "Target", Values = playerList(), Default = "None", Multi = false, Callback = function(v) LockTarget = pLookup[v] or "None"; refreshHL() end})
    s6:AddKeybind("CursorKey", {Title = "Cursor Lock", Default = "T", Callback = function()
        local t = closestToCursor()
        if t then LockTarget = t; syncLockDD(); notify({Title = "Lock", Content = t, Duration = 2}) end
    end, ChangedCallback = function() end})
    s6:AddKeybind("LockKey", {Title = "Toggle Key", Default = "L", Callback = function()
        if Options.LockToggle then Options.LockToggle:SetValue(not LockEnabled) end
    end, ChangedCallback = function() end})
    s6:AddButton({Title = "Refresh List", Callback = function() syncLockDD() end})
end
do
    local s6h = Tabs.Lock:AddSection("Highlight")
    s6h:AddToggle("HLToggle", {Title = "Enabled", Default = false, Callback = function(v) HLEnabled = v; refreshHL() end})
    local hr, hg, hb = 255, 60, 60
    local function updHL() HLColor = Color3.fromRGB(hr, hg, hb); refreshHL() end
    s6h:AddSlider("HLR", {Title = "R", Default = 255, Min = 0, Max = 255, Rounding = 0, Callback = function(v) hr = v; updHL() end})
    s6h:AddSlider("HLG", {Title = "G", Default = 60, Min = 0, Max = 255, Rounding = 0, Callback = function(v) hg = v; updHL() end})
    s6h:AddSlider("HLB", {Title = "B", Default = 60, Min = 0, Max = 255, Rounding = 0, Callback = function(v) hb = v; updHL() end})
end
do
    local s7 = Tabs.Visuals:AddSection("ESP")
    s7:AddToggle("ESPToggle", {Title = "Ability ESP", Default = false, Callback = function(v) ESP_On = v; updateESP() end})
    local s7b = Tabs.Visuals:AddSection("Ball Stats")
    s7b:AddToggle("BSToggle", {Title = "Ball Info", Default = false, Callback = function(v) BS_On = v end})
    local s7p = Tabs.Visuals:AddSection("Parry Range")
    s7p:AddToggle("PRVToggle", {Title = "Range Ring", Default = false, Callback = function(v)
        PRV.On = v
        if not v then PRV.Destroy() end
    end})
    local s7c = Tabs.Visuals:AddSection("Character")
    s7c:AddToggle("HeadlessT", {Title = "Headless", Default = false, Callback = function(v) Headless = v; if v then doHeadless() else undoHeadless() end end})
    s7c:AddToggle("KorbloxT", {Title = "Korblox Leg", Default = false, Callback = function(v) Korblox = v; if v then doKorblox() else undoKorblox() end end})

    local s7s = Tabs.Visuals:AddSection("Stats HUD")
    s7s:AddToggle("ShowFPSToggle", {Title = "Show FPS", Default = false,
        Callback = function(v) Stats_ShowFPS = v end})
    s7s:AddToggle("ShowPingToggle", {Title = "Show Ping", Default = false,
        Callback = function(v) Stats_ShowPing = v end})
end
do
    local s8 = Tabs.Settings:AddSection("Engine")
    s8:AddToggle("KBToggle", {Title = "Keybind List", Default = false, Callback = function(v) KBShow = v; kbF.Visible = v end})
    s8:AddKeybind("GUIToggleKey", {Title = "GUI Toggle", Default = "LeftControl", Callback = function()
        local w = Fluent.Window
        if w and w._gui then w._gui.Enabled = not w._gui.Enabled end
    end, ChangedCallback = function() end})
end

-- ============================================================
-- FPS CAP — realtime, uncap toggle + 15..360 slider
-- ============================================================
do
    local fpsSection = Tabs.Settings:AddSection("Performance")

    local FPSUncapped = false
    local FPSCap      = 240

    local _setFPS = type(setfpscap) == "function" and setfpscap or nil

    local function applyFPS()
        if type(_setFPS) ~= "function" then return end
        pcall(function()
            _setFPS(FPSUncapped and 1000 or FPSCap)
        end)
    end

    fpsSection:AddToggle("FPSUncap", {
        Title = "Uncap FPS",
        Default = false,
        Callback = function(v)
            FPSUncapped = v
            applyFPS()
        end,
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

Players.PlayerAdded:Connect(function() task.wait(1); syncLockDD() end)
Players.PlayerRemoving:Connect(function(p)
    if LockTarget == p.Name then
        LockTarget = "None"; refreshHL()
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

suppressNotifies = true
pcall(function() SaveManager:LoadAutoloadConfig() end)
task.delay(1, function()
    suppressNotifies = false
    Fluent:Notify({Title = "qzxp", Content = "Loaded", Duration = 4})
end)

-- ============================================================
-- [FIX 8] CLEANUP — now actually kills everything
-- ============================================================
getgenv().qzxp_Cleanup = function()
    pcall(function()
        -- VFX hooks
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

        -- Kill every tracked background thread
        if getgenv().qzxp_Threads then
            for _, t in ipairs(getgenv().qzxp_Threads) do
                pcall(function() task.cancel(t) end)
            end
            getgenv().qzxp_Threads = nil
        end

        -- Kill the consolidated RenderStepped dispatcher
        if getgenv().qzxp_StopRender then
            pcall(getgenv().qzxp_StopRender)
            getgenv().qzxp_StopRender = nil
        end

        -- Parry range visualizer
        pcall(function() if PRV and PRV.Destroy then PRV.Destroy() end end)

        -- Destroy our ScreenGuis
        local cg = GetSafeUIParent()
        for _, o in ipairs(cg:GetChildren()) do
            if o:IsA("ScreenGui") and (o.Name:lower():find("qzxp") or o.Name:lower():find("q_")) then
                o:Destroy()
            end
        end

        getgenv().skinChanger = nil; getgenv().skinChangerEnabled = nil
        getgenv().swordModel = nil; getgenv().swordAnimations = nil; getgenv().swordFX = nil
        getgenv().slashName = nil; getgenv().updateSword = nil; getgenv().revertSword = nil
        getgenv().saveLastEquippedSword = nil; getgenv().setSkinUI = nil
        getgenv().qzxp_Cleanup = nil
    end)
end

end) -- top-level task.spawn
