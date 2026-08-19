--[[
    ImGuiLib.luau — Full Rewrite
    Visual: ImGui dark theme (triangles, rounded corners, checkboxes, grabbers)
    Mobile: Touch-native drag + all widgets touch-supported
--]]

local CoreGui          = game:GetService("CoreGui")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

-- ================================================================
-- COLOUR PALETTE  (ImGui dark theme)
-- ================================================================
local C = {
    BG           = Color3.fromRGB(15,  15,  20),
    BG2          = Color3.fromRGB(22,  22,  30),
    TitleBar     = Color3.fromRGB(36,  36,  52),
    Accent       = Color3.fromRGB(66,  150, 250),
    AccentHover  = Color3.fromRGB(93,  169, 255),
    AccentDim    = Color3.fromRGB(41,  98,  180),
    Header       = Color3.fromRGB(41,  74,  122),
    HeaderHover  = Color3.fromRGB(52,  95,  152),
    Border       = Color3.fromRGB(80,  80,  110),
    BorderDim    = Color3.fromRGB(55,  55,  75),
    Text         = Color3.fromRGB(255, 255, 255),
    TextDim      = Color3.fromRGB(170, 175, 200),
    TextDisabled = Color3.fromRGB(110, 110, 135),
    InputBG      = Color3.fromRGB(16,  16,  22),
    SliderBG     = Color3.fromRGB(35,  35,  50),
    ButtonBG     = Color3.fromRGB(66,  150, 250),
    ButtonHover  = Color3.fromRGB(93,  169, 255),
    ButtonActive = Color3.fromRGB(45,  120, 220),
    Scrollbar    = Color3.fromRGB(80,  80,  110),
    Sep          = Color3.fromRGB(55,  55,  80),
    NotifBG      = Color3.fromRGB(20,  20,  28),
    CloseRed     = Color3.fromRGB(195, 60,  60),
    CloseHover   = Color3.fromRGB(230, 70,  70),
    MinBG        = Color3.fromRGB(50,  50,  70),
    MinHover     = Color3.fromRGB(70,  70,  95),
}

-- ================================================================
-- HELPERS
-- ================================================================
local function mkCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 2)
    c.Parent = parent
    return c
end

local function mkStroke(parent, thick, col)
    local s = Instance.new("UIStroke")
    s.Thickness = thick or 1
    s.Color = col or C.Border
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function mkPad(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.PaddingLeft   = UDim.new(0, l or 0)
    p.PaddingRight  = UDim.new(0, r or 0)
    p.Parent = parent
    return p
end

-- Touch/mouse unified drag helper
-- Returns a disconnect function
local function attachDrag(handle, target)
    local active = false
    local dragStart, objStart

    local c1 = handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            active    = true
            dragStart = input.Position
            objStart  = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    active = false
                end
            end)
        end
    end)

    local c2 = UserInputService.InputChanged:Connect(function(input)
        if active and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            target.Position = UDim2.new(
                objStart.X.Scale, objStart.X.Offset + d.X,
                objStart.Y.Scale, objStart.Y.Offset + d.Y
            )
        end
    end)

    local c3 = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            active = false
        end
    end)

    return function() c1:Disconnect(); c2:Disconnect(); c3:Disconnect() end
end

-- Touch/mouse unified slider helper
local function attachSlider(trackFrame, callback)
    local dragging = false

    local function updateFromX(x)
        local abs = trackFrame.AbsolutePosition
        local sz  = trackFrame.AbsoluteSize
        local pct = math.clamp((x - abs.X) / sz.X, 0, 1)
        callback(pct)
    end

    local c1 = trackFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    local c2 = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                      or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)

    local c3 = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return function() c1:Disconnect(); c2:Disconnect(); c3:Disconnect() end
end

-- Generic touch+click handler
local function onClick(btn, fn)
    btn.MouseButton1Click:Connect(fn)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            task.spawn(fn)
        end
    end)
end

-- ================================================================
-- MAIN LIBRARY
-- ================================================================
local ImGuiLib = {}

function ImGuiLib:CreateWindow(config)
    local title    = config.Title or "ImGui"
    local size     = config.Size  or Vector2.new(380, 460)
    local pos      = config.Position  -- optional: Vector2

    -- ScreenGui
    local SG = Instance.new("ScreenGui")
    SG.Name           = "ImGui_" .. title:gsub("%s", "_")
    SG.ResetOnSpawn   = false
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.DisplayOrder   = 100

    if syn and syn.protect_gui then
        syn.protect_gui(SG)
    elseif gethui then
        SG.Parent = gethui()
    else
        SG.Parent = CoreGui
    end

    -- Main frame
    local startX = pos and pos.X or (workspace.CurrentCamera.ViewportSize.X / 2 - size.X / 2)
    local startY = pos and pos.Y or (workspace.CurrentCamera.ViewportSize.Y / 2 - size.Y / 2)

    local Main = Instance.new("Frame")
    Main.Name             = "Main"
    Main.Size             = UDim2.new(0, size.X, 0, size.Y)
    Main.Position         = UDim2.new(0, startX, 0, startY)
    Main.BackgroundColor3 = C.BG
    Main.BorderSizePixel  = 0
    Main.ClipsDescendants = false
    Main.Parent           = SG
    mkCorner(Main, 5)
    mkStroke(Main, 1, C.Border)

    -- Clip wrap (keeps content inside rounded corners)
    local Clip = Instance.new("Frame")
    Clip.Size             = UDim2.new(1, 0, 1, 0)
    Clip.BackgroundTransparency = 1
    Clip.BorderSizePixel  = 0
    Clip.ClipsDescendants = true
    Clip.Parent           = Main

    -- ── Title bar ──────────────────────────────────────────────
    local TitleBar = Instance.new("Frame")
    TitleBar.Name             = "TitleBar"
    TitleBar.Size             = UDim2.new(1, 0, 0, 24)
    TitleBar.BackgroundColor3 = C.TitleBar
    TitleBar.BorderSizePixel  = 0
    TitleBar.ZIndex           = 5
    TitleBar.Parent           = Clip

    -- Top accent line (ImGui blue edge)
    local TopAccent = Instance.new("Frame")
    TopAccent.Size             = UDim2.new(1, 0, 0, 1)
    TopAccent.BackgroundColor3 = C.Accent
    TopAccent.BorderSizePixel  = 0
    TopAccent.ZIndex           = 6
    TopAccent.Parent           = TitleBar

    local TitleText = Instance.new("TextLabel")
    TitleText.Size              = UDim2.new(1, -56, 1, 0)
    TitleText.Position          = UDim2.new(0, 9, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text              = title
    TitleText.TextColor3        = C.Text
    TitleText.Font              = Enum.Font.GothamBold
    TitleText.TextSize          = 12
    TitleText.TextXAlignment    = Enum.TextXAlignment.Left
    TitleText.ZIndex            = 6
    TitleText.Parent            = TitleBar

    -- Minimize button
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size             = UDim2.new(0, 18, 0, 18)
    MinBtn.Position         = UDim2.new(1, -42, 0.5, -9)
    MinBtn.BackgroundColor3 = C.MinBG
    MinBtn.BorderSizePixel  = 0
    MinBtn.Text             = "−"
    MinBtn.TextColor3       = C.TextDim
    MinBtn.Font             = Enum.Font.GothamBold
    MinBtn.TextSize         = 14
    MinBtn.AutoButtonColor  = false
    MinBtn.ZIndex           = 6
    MinBtn.Parent           = TitleBar
    mkCorner(MinBtn, 3)

    MinBtn.MouseEnter:Connect(function() MinBtn.BackgroundColor3 = C.MinHover end)
    MinBtn.MouseLeave:Connect(function() MinBtn.BackgroundColor3 = C.MinBG   end)

    -- Close button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size             = UDim2.new(0, 18, 0, 18)
    CloseBtn.Position         = UDim2.new(1, -22, 0.5, -9)
    CloseBtn.BackgroundColor3 = C.CloseRed
    CloseBtn.BorderSizePixel  = 0
    CloseBtn.Text             = "×"
    CloseBtn.TextColor3       = Color3.fromRGB(255, 215, 215)
    CloseBtn.Font             = Enum.Font.GothamBold
    CloseBtn.TextSize         = 14
    CloseBtn.AutoButtonColor  = false
    CloseBtn.ZIndex           = 6
    CloseBtn.Parent           = TitleBar
    mkCorner(CloseBtn, 3)

    CloseBtn.MouseEnter:Connect(function() CloseBtn.BackgroundColor3 = C.CloseHover end)
    CloseBtn.MouseLeave:Connect(function() CloseBtn.BackgroundColor3 = C.CloseRed   end)
    onClick(CloseBtn, function() SG:Destroy() end)

    -- ── Drag (PC + Mobile) ─────────────────────────────────────
    attachDrag(TitleBar, Main)

    -- ── Minimize logic ─────────────────────────────────────────
    local IsMinimized = false
    local IsTweening  = false
    local fullHeight  = size.Y

    -- Content region (hidden on minimize)
    local ContentClip = Instance.new("Frame")
    ContentClip.Name             = "ContentClip"
    ContentClip.Size             = UDim2.new(1, 0, 1, -24)
    ContentClip.Position         = UDim2.new(0, 0, 0, 24)
    ContentClip.BackgroundTransparency = 1
    ContentClip.BorderSizePixel  = 0
    ContentClip.ClipsDescendants = true
    ContentClip.Parent           = Clip

    local ContentScroll = Instance.new("ScrollingFrame")
    ContentScroll.Size                = UDim2.new(1, -4, 1, -6)
    ContentScroll.Position            = UDim2.new(0, 2, 0, 4)
    ContentScroll.BackgroundTransparency = 1
    ContentScroll.BorderSizePixel     = 0
    ContentScroll.ScrollBarThickness  = 3
    ContentScroll.ScrollBarImageColor3 = C.Scrollbar
    ContentScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
    ContentScroll.ClipsDescendants    = false
    ContentScroll.ScrollingDirection  = Enum.ScrollingDirection.Y
    ContentScroll.Parent              = ContentClip

    local RootLayout = Instance.new("UIListLayout")
    RootLayout.Padding   = UDim.new(0, 2)
    RootLayout.SortOrder = Enum.SortOrder.LayoutOrder
    RootLayout.Parent    = ContentScroll

    RootLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ContentScroll.CanvasSize = UDim2.new(0, 0, 0, RootLayout.AbsoluteContentSize.Y + 14)
    end)

    onClick(MinBtn, function()
        if IsTweening then return end
        IsTweening = true
        IsMinimized = not IsMinimized
        MinBtn.Text = IsMinimized and "+" or "−"
        TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, size.X, 0, IsMinimized and 24 or fullHeight)
        }):Play()
        task.wait(0.22)
        IsTweening = false
    end)

    -- ── Opacity (right-click + drag title bar) ─────────────────
    local opacityDragging = false
    local opStartX, opStartVal = 0, 0
    local currentOpacity = 0

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            opacityDragging = true
            opStartX   = input.Position.X
            opStartVal = currentOpacity
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if opacityDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = (input.Position.X - opStartX) / 200
            currentOpacity = math.clamp(opStartVal + delta, 0, 0.92)
            Main.BackgroundTransparency    = currentOpacity
            TitleBar.BackgroundTransparency = currentOpacity
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            opacityDragging = false
        end
    end)

    -- ================================================================
    -- WINDOW OBJECT
    -- ================================================================
    local WindowObj = {}

    -- Separator at the window root level
    function WindowObj:CreateSeparator()
        local Sep = Instance.new("Frame")
        Sep.Size             = UDim2.new(1, -8, 0, 1)
        Sep.BackgroundColor3 = C.Sep
        Sep.BorderSizePixel  = 0
        Sep.Parent           = ContentScroll
    end

    -- ── CreateHeader ────────────────────────────────────────────
    function WindowObj:CreateHeader(headerConfig)
        local headerName  = headerConfig.Name or "Category"
        local Expanded    = headerConfig.Expanded == true   -- default: collapsed

        -- Collapsible header button
        local HeaderBtn = Instance.new("TextButton")
        HeaderBtn.Name            = "Hdr_" .. headerName
        HeaderBtn.Size            = UDim2.new(1, 0, 0, 22)
        HeaderBtn.BackgroundColor3 = C.Header
        HeaderBtn.BorderSizePixel  = 0
        HeaderBtn.Text             = ""
        HeaderBtn.AutoButtonColor  = false
        HeaderBtn.Parent           = ContentScroll

        -- ▶ / ▼ triangle
        local Arrow = Instance.new("TextLabel")
        Arrow.Size             = UDim2.new(0, 16, 1, 0)
        Arrow.Position         = UDim2.new(0, 5, 0, 0)
        Arrow.BackgroundTransparency = 1
        Arrow.Text             = Expanded and "▼" or "▶"
        Arrow.TextColor3       = C.Text
        Arrow.Font             = Enum.Font.Code
        Arrow.TextSize         = 10
        Arrow.ZIndex           = 2
        Arrow.Parent           = HeaderBtn

        local HeaderLbl = Instance.new("TextLabel")
        HeaderLbl.Size             = UDim2.new(1, -24, 1, 0)
        HeaderLbl.Position         = UDim2.new(0, 20, 0, 0)
        HeaderLbl.BackgroundTransparency = 1
        HeaderLbl.Text             = headerName
        HeaderLbl.TextColor3       = C.Text
        HeaderLbl.Font             = Enum.Font.GothamBold
        HeaderLbl.TextSize         = 11
        HeaderLbl.TextXAlignment   = Enum.TextXAlignment.Left
        HeaderLbl.ZIndex           = 2
        HeaderLbl.Parent           = HeaderBtn

        -- Child container
        local Container = Instance.new("Frame")
        Container.Name             = "Ctr_" .. headerName
        Container.Size             = UDim2.new(1, 0, 0, 0)
        Container.BackgroundColor3 = C.BG2
        Container.BorderSizePixel  = 0
        Container.AutomaticSize    = Enum.AutomaticSize.Y
        Container.Visible          = Expanded
        Container.ZIndex           = 2
        Container.Parent           = ContentScroll

        -- Left indent accent bar
        local IndentBar = Instance.new("Frame")
        IndentBar.Size             = UDim2.new(0, 2, 1, 0)
        IndentBar.BackgroundColor3 = C.AccentDim
        IndentBar.BorderSizePixel  = 0
        IndentBar.ZIndex           = 3
        IndentBar.Parent           = Container

        mkPad(Container, 5, 7, 14, 8)

        local ContLayout = Instance.new("UIListLayout")
        ContLayout.Padding   = UDim.new(0, 5)
        ContLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ContLayout.Parent    = Container

        -- Hover + toggle
        HeaderBtn.MouseEnter:Connect(function() HeaderBtn.BackgroundColor3 = C.HeaderHover end)
        HeaderBtn.MouseLeave:Connect(function() HeaderBtn.BackgroundColor3 = C.Header      end)

        local function toggleHeader()
            Expanded = not Expanded
            Container.Visible = Expanded
            Arrow.Text = Expanded and "▼" or "▶"
        end

        HeaderBtn.MouseButton1Click:Connect(toggleHeader)
        HeaderBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then toggleHeader() end
        end)

        -- ============================================================
        -- HEADER OBJECT — widgets
        -- ============================================================
        local HeaderObj = {}

        -- ── BUTTON ──────────────────────────────────────────────
        function HeaderObj:CreateButton(bConfig)
            local name     = bConfig.Name or "Button"
            local callback = bConfig.Callback or function() end

            local Btn = Instance.new("TextButton")
            Btn.Size             = UDim2.new(1, 0, 0, 24)
            Btn.BackgroundColor3 = C.ButtonBG
            Btn.BorderSizePixel  = 0
            Btn.Text             = name
            Btn.TextColor3       = C.Text
            Btn.Font             = Enum.Font.GothamBold
            Btn.TextSize         = 11
            Btn.AutoButtonColor  = false
            Btn.Parent           = Container
            mkCorner(Btn, 3)

            Btn.MouseEnter:Connect(function()    Btn.BackgroundColor3 = C.ButtonHover  end)
            Btn.MouseLeave:Connect(function()    Btn.BackgroundColor3 = C.ButtonBG     end)
            Btn.MouseButton1Down:Connect(function() Btn.BackgroundColor3 = C.ButtonActive end)
            Btn.MouseButton1Up:Connect(function()
                Btn.BackgroundColor3 = C.ButtonHover
                task.spawn(callback)
            end)
            Btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    Btn.BackgroundColor3 = C.ButtonActive
                end
            end)
            Btn.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    Btn.BackgroundColor3 = C.ButtonBG
                    task.spawn(callback)
                end
            end)
        end

        -- ── TOGGLE (checkbox) ───────────────────────────────────
        function HeaderObj:CreateToggle(tConfig)
            local state    = tConfig.Default  or false
            local name     = tConfig.Name     or "Toggle"
            local callback = tConfig.Callback or function() end

            local Row = Instance.new("Frame")
            Row.Size             = UDim2.new(1, 0, 0, 20)
            Row.BackgroundTransparency = 1
            Row.Parent           = Container

            -- Checkbox square
            local Box = Instance.new("Frame")
            Box.Size             = UDim2.new(0, 14, 0, 14)
            Box.Position         = UDim2.new(0, 0, 0.5, -7)
            Box.BackgroundColor3 = state and C.Accent or C.InputBG
            Box.BorderSizePixel  = 0
            Box.ZIndex           = 3
            Box.Parent           = Row
            mkCorner(Box, 2)
            mkStroke(Box, 1, state and C.Accent or C.Border)

            -- Checkmark label
            local CheckMark = Instance.new("TextLabel")
            CheckMark.Size             = UDim2.new(1, 0, 1, 0)
            CheckMark.BackgroundTransparency = 1
            CheckMark.Text             = state and "✓" or ""
            CheckMark.TextColor3       = C.Text
            CheckMark.Font             = Enum.Font.GothamBold
            CheckMark.TextSize         = 11
            CheckMark.ZIndex           = 4
            CheckMark.Parent           = Box

            local Lbl = Instance.new("TextLabel")
            Lbl.Size             = UDim2.new(1, -22, 1, 0)
            Lbl.Position         = UDim2.new(0, 20, 0, 0)
            Lbl.BackgroundTransparency = 1
            Lbl.Text             = name
            Lbl.TextColor3       = C.Text
            Lbl.Font             = Enum.Font.Gotham
            Lbl.TextSize         = 11
            Lbl.TextXAlignment   = Enum.TextXAlignment.Left
            Lbl.ZIndex           = 2
            Lbl.Parent           = Row

            local function applyState()
                local stroke = Box:FindFirstChildWhichIsA("UIStroke")
                Box.BackgroundColor3 = state and C.Accent or C.InputBG
                if stroke then stroke.Color = state and C.Accent or C.Border end
                CheckMark.Text = state and "✓" or ""
            end

            local function toggle()
                state = not state
                applyState()
                callback(state)
            end

            Row.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    toggle()
                end
            end)

            local ToggleObj = {}
            function ToggleObj:SetState(v) state = v; applyState() end
            function ToggleObj:GetState()  return state end
            return ToggleObj
        end

        -- ── SLIDER ──────────────────────────────────────────────
        function HeaderObj:CreateSlider(sConfig)
            local min      = sConfig.Min      or 0
            local max      = sConfig.Max      or 100
            local step     = sConfig.Step     or 1
            local current  = sConfig.Default  or min
            local name     = sConfig.Name     or "Slider"
            local callback = sConfig.Callback or function() end

            local SF = Instance.new("Frame")
            SF.Size             = UDim2.new(1, 0, 0, 40)
            SF.BackgroundTransparency = 1
            SF.Parent           = Container

            -- Label row
            local LblRow = Instance.new("Frame")
            LblRow.Size             = UDim2.new(1, 0, 0, 14)
            LblRow.BackgroundTransparency = 1
            LblRow.Parent           = SF

            local NameLbl = Instance.new("TextLabel")
            NameLbl.Size             = UDim2.new(0.6, 0, 1, 0)
            NameLbl.BackgroundTransparency = 1
            NameLbl.Text             = name
            NameLbl.TextColor3       = C.TextDim
            NameLbl.Font             = Enum.Font.Gotham
            NameLbl.TextSize         = 11
            NameLbl.TextXAlignment   = Enum.TextXAlignment.Left
            NameLbl.Parent           = LblRow

            local ValLbl = Instance.new("TextLabel")
            ValLbl.Size             = UDim2.new(0.4, 0, 1, 0)
            ValLbl.Position         = UDim2.new(0.6, 0, 0, 0)
            ValLbl.BackgroundTransparency = 1
            ValLbl.Text             = tostring(current)
            ValLbl.TextColor3       = C.Accent
            ValLbl.Font             = Enum.Font.GothamBold
            ValLbl.TextSize         = 11
            ValLbl.TextXAlignment   = Enum.TextXAlignment.Right
            ValLbl.Parent           = LblRow

            -- Track
            local Track = Instance.new("Frame")
            Track.Size             = UDim2.new(1, 0, 0, 8)
            Track.Position         = UDim2.new(0, 0, 0, 22)
            Track.BackgroundColor3 = C.SliderBG
            Track.BorderSizePixel  = 0
            Track.ZIndex           = 2
            Track.Parent           = SF
            mkCorner(Track, 4)

            -- Fill
            local startPct = (current - min) / math.max(max - min, 1)
            local Fill = Instance.new("Frame")
            Fill.Size             = UDim2.new(startPct, 0, 1, 0)
            Fill.BackgroundColor3 = C.Accent
            Fill.BorderSizePixel  = 0
            Fill.ZIndex           = 3
            Fill.Parent           = Track
            mkCorner(Fill, 4)

            -- Grabber dot
            local Grab = Instance.new("Frame")
            Grab.Size             = UDim2.new(0, 13, 0, 13)
            Grab.AnchorPoint      = Vector2.new(0.5, 0.5)
            Grab.Position         = UDim2.new(startPct, 0, 0.5, 0)
            Grab.BackgroundColor3 = Color3.new(1, 1, 1)
            Grab.BorderSizePixel  = 0
            Grab.ZIndex           = 4
            Grab.Parent           = Track
            mkCorner(Grab, 7)  -- full circle

            local function updateFromPct(pct)
                local raw     = min + pct * (max - min)
                local stepped = math.floor(raw / step + 0.5) * step
                local val     = math.clamp(stepped, min, max)
                local tp      = (val - min) / math.max(max - min, 1)
                Fill.Size           = UDim2.new(tp, 0, 1, 0)
                Grab.Position       = UDim2.new(tp, 0, 0.5, 0)
                ValLbl.Text         = tostring(val)
                current             = val
                callback(val)
            end

            -- Also make grabber draggable  (same X-based update)
            attachSlider(Track, updateFromPct)
            attachSlider(Fill,  updateFromPct)
            attachSlider(Grab,  updateFromPct)

            local SliderObj = {}
            function SliderObj:SetValue(v)
                local val = math.clamp(v, min, max)
                updateFromPct((val - min) / math.max(max - min, 1))
            end
            function SliderObj:GetValue() return current end
            return SliderObj
        end

        -- ── DROPDOWN ────────────────────────────────────────────
        function HeaderObj:CreateDropdown(dConfig)
            local options   = dConfig.Options   or {}
            local current   = dConfig.Default   or (options[1] or "None")
            local name      = dConfig.Name      or "Dropdown"
            local callback  = dConfig.Callback  or function() end

            local DF = Instance.new("Frame")
            DF.Size             = UDim2.new(1, 0, 0, 40)
            DF.BackgroundTransparency = 1
            DF.ClipsDescendants = false
            DF.Parent           = Container

            local Lbl = Instance.new("TextLabel")
            Lbl.Size             = UDim2.new(1, 0, 0, 14)
            Lbl.BackgroundTransparency = 1
            Lbl.Text             = name
            Lbl.TextColor3       = C.TextDim
            Lbl.Font             = Enum.Font.Gotham
            Lbl.TextSize         = 11
            Lbl.TextXAlignment   = Enum.TextXAlignment.Left
            Lbl.ZIndex           = 2
            Lbl.Parent           = DF

            local SelectBtn = Instance.new("TextButton")
            SelectBtn.Size             = UDim2.new(1, 0, 0, 22)
            SelectBtn.Position         = UDim2.new(0, 0, 0, 16)
            SelectBtn.BackgroundColor3 = C.InputBG
            SelectBtn.BorderSizePixel  = 0
            SelectBtn.Text             = ""
            SelectBtn.AutoButtonColor  = false
            SelectBtn.ZIndex           = 3
            SelectBtn.Parent           = DF
            mkCorner(SelectBtn, 3)
            mkStroke(SelectBtn, 1, C.BorderDim)

            local SelText = Instance.new("TextLabel")
            SelText.Size             = UDim2.new(1, -26, 1, 0)
            SelText.Position         = UDim2.new(0, 7, 0, 0)
            SelText.BackgroundTransparency = 1
            SelText.Text             = current
            SelText.TextColor3       = C.Text
            SelText.Font             = Enum.Font.Gotham
            SelText.TextSize         = 11
            SelText.TextXAlignment   = Enum.TextXAlignment.Left
            SelText.ZIndex           = 4
            SelText.Parent           = SelectBtn

            local ArrowLbl = Instance.new("TextLabel")
            ArrowLbl.Size             = UDim2.new(0, 20, 1, 0)
            ArrowLbl.Position         = UDim2.new(1, -22, 0, 0)
            ArrowLbl.BackgroundTransparency = 1
            ArrowLbl.Text             = "▾"
            ArrowLbl.TextColor3       = C.TextDim
            ArrowLbl.Font             = Enum.Font.Code
            ArrowLbl.TextSize         = 14
            ArrowLbl.ZIndex           = 4
            ArrowLbl.Parent           = SelectBtn

            -- Options list
            local OList = Instance.new("ScrollingFrame")
            OList.Size                = UDim2.new(1, 0, 0, 0)
            OList.Position            = UDim2.new(0, 0, 1, 3)
            OList.BackgroundColor3    = Color3.fromRGB(26, 26, 38)
            OList.BorderSizePixel     = 0
            OList.ScrollBarThickness  = 3
            OList.ScrollBarImageColor3 = C.Scrollbar
            OList.CanvasSize          = UDim2.new(0, 0, 0, #options * 22)
            OList.Visible             = false
            OList.ZIndex              = 10
            OList.ClipsDescendants    = true
            OList.Parent              = SelectBtn
            mkCorner(OList, 3)
            mkStroke(OList, 1, C.Accent)

            local OLayout = Instance.new("UIListLayout")
            OLayout.Parent = OList

            local isOpen = false

            for _, opt in ipairs(options) do
                local OptBtn = Instance.new("TextButton")
                OptBtn.Size             = UDim2.new(1, 0, 0, 22)
                OptBtn.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
                OptBtn.BorderSizePixel  = 0
                OptBtn.Text             = ""
                OptBtn.AutoButtonColor  = false
                OptBtn.ZIndex           = 11
                OptBtn.Parent           = OList

                local OptTxt = Instance.new("TextLabel")
                OptTxt.Size             = UDim2.new(1, -8, 1, 0)
                OptTxt.Position         = UDim2.new(0, 7, 0, 0)
                OptTxt.BackgroundTransparency = 1
                OptTxt.Text             = opt
                OptTxt.TextColor3       = (opt == current) and C.Accent or C.TextDim
                OptTxt.Font             = Enum.Font.Gotham
                OptTxt.TextSize         = 11
                OptTxt.TextXAlignment   = Enum.TextXAlignment.Left
                OptTxt.ZIndex           = 12
                OptTxt.Parent           = OptBtn

                OptBtn.MouseEnter:Connect(function()
                    OptBtn.BackgroundColor3 = C.Header
                    OptTxt.TextColor3 = C.Text
                end)
                OptBtn.MouseLeave:Connect(function()
                    OptBtn.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
                    OptTxt.TextColor3 = (opt == current) and C.Accent or C.TextDim
                end)

                local function selectOpt()
                    current = opt
                    SelText.Text = opt
                    -- update active colour
                    for _, ch in OList:GetChildren() do
                        if ch:IsA("TextButton") then
                            local tl = ch:FindFirstChildWhichIsA("TextLabel")
                            if tl then tl.TextColor3 = (tl.Text == current) and C.Accent or C.TextDim end
                        end
                    end
                    isOpen = false
                    OList.Visible = false
                    OList.Size = UDim2.new(1, 0, 0, 0)
                    ArrowLbl.Text = "▾"
                    callback(opt)
                end

                OptBtn.MouseButton1Click:Connect(selectOpt)
                OptBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then selectOpt() end
                end)
            end

            local function toggleDrop()
                isOpen = not isOpen
                OList.Visible = isOpen
                local h = math.clamp(#options * 22, 0, 132)
                OList.Size = isOpen and UDim2.new(1, 0, 0, h) or UDim2.new(1, 0, 0, 0)
                ArrowLbl.Text = isOpen and "▴" or "▾"
            end

            SelectBtn.MouseButton1Click:Connect(toggleDrop)
            SelectBtn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then toggleDrop() end
            end)

            local DropObj = {}
            function DropObj:GetSelected() return current end
            return DropObj
        end

        -- ── PLAYER DROPDOWN ─────────────────────────────────────
        function HeaderObj:CreatePlayerDropdown(pdConfig)
            local name     = pdConfig.Name     or "Select Player"
            local callback = pdConfig.Callback or function() end
            local current  = nil

            local DF = Instance.new("Frame")
            DF.Size             = UDim2.new(1, 0, 0, 40)
            DF.BackgroundTransparency = 1
            DF.ClipsDescendants = false
            DF.Parent           = Container

            local Lbl = Instance.new("TextLabel")
            Lbl.Size             = UDim2.new(1, 0, 0, 14)
            Lbl.BackgroundTransparency = 1
            Lbl.Text             = name
            Lbl.TextColor3       = C.TextDim
            Lbl.Font             = Enum.Font.Gotham
            Lbl.TextSize         = 11
            Lbl.TextXAlignment   = Enum.TextXAlignment.Left
            Lbl.ZIndex           = 2
            Lbl.Parent           = DF

            local SelectBtn = Instance.new("TextButton")
            SelectBtn.Size             = UDim2.new(1, 0, 0, 22)
            SelectBtn.Position         = UDim2.new(0, 0, 0, 16)
            SelectBtn.BackgroundColor3 = C.InputBG
            SelectBtn.BorderSizePixel  = 0
            SelectBtn.Text             = ""
            SelectBtn.AutoButtonColor  = false
            SelectBtn.ZIndex           = 3
            SelectBtn.Parent           = DF
            mkCorner(SelectBtn, 3)
            mkStroke(SelectBtn, 1, C.BorderDim)

            local SelText = Instance.new("TextLabel")
            SelText.Size             = UDim2.new(1, -26, 1, 0)
            SelText.Position         = UDim2.new(0, 7, 0, 0)
            SelText.BackgroundTransparency = 1
            SelText.Text             = "Select a player..."
            SelText.TextColor3       = C.TextDisabled
            SelText.Font             = Enum.Font.Gotham
            SelText.TextSize         = 11
            SelText.TextXAlignment   = Enum.TextXAlignment.Left
            SelText.ZIndex           = 4
            SelText.Parent           = SelectBtn

            local ArrowLbl = Instance.new("TextLabel")
            ArrowLbl.Size             = UDim2.new(0, 20, 1, 0)
            ArrowLbl.Position         = UDim2.new(1, -22, 0, 0)
            ArrowLbl.BackgroundTransparency = 1
            ArrowLbl.Text             = "▾"
            ArrowLbl.TextColor3       = C.TextDim
            ArrowLbl.Font             = Enum.Font.Code
            ArrowLbl.TextSize         = 14
            ArrowLbl.ZIndex           = 4
            ArrowLbl.Parent           = SelectBtn

            local OList = Instance.new("ScrollingFrame")
            OList.Size                = UDim2.new(1, 0, 0, 0)
            OList.Position            = UDim2.new(0, 0, 1, 3)
            OList.BackgroundColor3    = Color3.fromRGB(26, 26, 38)
            OList.BorderSizePixel     = 0
            OList.ScrollBarThickness  = 3
            OList.ScrollBarImageColor3 = C.Scrollbar
            OList.Visible             = false
            OList.ZIndex              = 10
            OList.ClipsDescendants    = true
            OList.Parent              = SelectBtn
            mkCorner(OList, 3)
            mkStroke(OList, 1, C.Accent)

            Instance.new("UIListLayout").Parent = OList

            local isOpen = false

            local function buildList()
                for _, ch in ipairs(OList:GetChildren()) do
                    if ch:IsA("TextButton") then ch:Destroy() end
                end
                local count = 0
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= Players.LocalPlayer then
                        count += 1
                        local OptBtn = Instance.new("TextButton")
                        OptBtn.Size             = UDim2.new(1, 0, 0, 22)
                        OptBtn.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
                        OptBtn.BorderSizePixel  = 0
                        OptBtn.Text             = ""
                        OptBtn.AutoButtonColor  = false
                        OptBtn.ZIndex           = 11
                        OptBtn.Parent           = OList

                        local OptTxt = Instance.new("TextLabel")
                        OptTxt.Size             = UDim2.new(1, -8, 1, 0)
                        OptTxt.Position         = UDim2.new(0, 7, 0, 0)
                        OptTxt.BackgroundTransparency = 1
                        OptTxt.Text             = p.Name
                        OptTxt.TextColor3       = C.TextDim
                        OptTxt.Font             = Enum.Font.Gotham
                        OptTxt.TextSize         = 11
                        OptTxt.TextXAlignment   = Enum.TextXAlignment.Left
                        OptTxt.ZIndex           = 12
                        OptTxt.Parent           = OptBtn

                        OptBtn.MouseEnter:Connect(function()
                            OptBtn.BackgroundColor3 = C.Header
                            OptTxt.TextColor3 = C.Text
                        end)
                        OptBtn.MouseLeave:Connect(function()
                            OptBtn.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
                            OptTxt.TextColor3 = C.TextDim
                        end)

                        local function selectP()
                            current = p.Name
                            SelText.Text = p.Name
                            SelText.TextColor3 = C.Text
                            isOpen = false
                            OList.Visible = false
                            OList.Size = UDim2.new(1, 0, 0, 0)
                            ArrowLbl.Text = "▾"
                            callback(p.Name)
                        end
                        OptBtn.MouseButton1Click:Connect(selectP)
                        OptBtn.InputBegan:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.Touch then selectP() end
                        end)
                    end
                end
                OList.CanvasSize = UDim2.new(0, 0, 0, count * 22)
                if isOpen then
                    OList.Size = UDim2.new(1, 0, 0, math.clamp(count * 22, 22, 132))
                end
            end

            local function toggleDrop()
                isOpen = not isOpen
                OList.Visible = isOpen
                ArrowLbl.Text = isOpen and "▴" or "▾"
                if isOpen then buildList() else OList.Size = UDim2.new(1, 0, 0, 0) end
            end

            SelectBtn.MouseButton1Click:Connect(toggleDrop)
            SelectBtn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then toggleDrop() end
            end)

            Players.PlayerAdded:Connect(function()
                task.wait(0.5)
                if isOpen then buildList() end
            end)
            Players.PlayerRemoving:Connect(function(p)
                if current == p.Name then
                    current = nil
                    SelText.Text = "Select a player..."
                    SelText.TextColor3 = C.TextDisabled
                end
                task.wait(0.5)
                if isOpen then buildList() end
            end)
        end

        -- ── TEXTBOX ─────────────────────────────────────────────
        function HeaderObj:CreateTextBox(tbConfig)
            local name      = tbConfig.Name        or "Input"
            local callback  = tbConfig.Callback    or function() end

            local TBF = Instance.new("Frame")
            TBF.Size             = UDim2.new(1, 0, 0, 40)
            TBF.BackgroundTransparency = 1
            TBF.Parent           = Container

            local Lbl = Instance.new("TextLabel")
            Lbl.Size             = UDim2.new(1, 0, 0, 14)
            Lbl.BackgroundTransparency = 1
            Lbl.Text             = name
            Lbl.TextColor3       = C.TextDim
            Lbl.Font             = Enum.Font.Gotham
            Lbl.TextSize         = 11
            Lbl.TextXAlignment   = Enum.TextXAlignment.Left
            Lbl.ZIndex           = 2
            Lbl.Parent           = TBF

            local Box = Instance.new("TextBox")
            Box.Size              = UDim2.new(1, 0, 0, 22)
            Box.Position          = UDim2.new(0, 0, 0, 16)
            Box.BackgroundColor3  = C.InputBG
            Box.BorderSizePixel   = 0
            Box.Text              = ""
            Box.PlaceholderText   = tbConfig.Placeholder or "Type here..."
            Box.PlaceholderColor3 = C.TextDisabled
            Box.TextColor3        = C.Text
            Box.Font              = Enum.Font.Gotham
            Box.TextSize          = 11
            Box.TextXAlignment    = Enum.TextXAlignment.Left
            Box.ClearTextOnFocus  = false
            Box.ZIndex            = 2
            Box.Parent            = TBF
            mkCorner(Box, 3)
            local boxStroke = mkStroke(Box, 1, C.BorderDim)
            mkPad(Box, 0, 0, 7, 0)

            Box.Focused:Connect(function()    boxStroke.Color = C.Accent    end)
            Box.FocusLost:Connect(function()
                boxStroke.Color = C.BorderDim
                callback(Box.Text)
            end)

            local TBObj = {}
            function TBObj:SetText(t)  Box.Text = t  end
            function TBObj:GetText()   return Box.Text end
            return TBObj
        end

        -- ── KEYBIND ─────────────────────────────────────────────
        function HeaderObj:CreateKeybind(kConfig)
            local currentKey = kConfig.Default  or Enum.KeyCode.E
            local mode       = kConfig.Mode     or "Toggle"
            local name       = kConfig.Name     or "Keybind"
            local callback   = kConfig.Callback or function() end
            local listening  = false
            local isToggled  = false

            local KF = Instance.new("Frame")
            KF.Size             = UDim2.new(1, 0, 0, 22)
            KF.BackgroundTransparency = 1
            KF.Parent           = Container

            local Lbl = Instance.new("TextLabel")
            Lbl.Size             = UDim2.new(1, -90, 1, 0)
            Lbl.BackgroundTransparency = 1
            Lbl.Text             = name
            Lbl.TextColor3       = C.Text
            Lbl.Font             = Enum.Font.Gotham
            Lbl.TextSize         = 11
            Lbl.TextXAlignment   = Enum.TextXAlignment.Left
            Lbl.ZIndex           = 2
            Lbl.Parent           = KF

            local BindBtn = Instance.new("TextButton")
            BindBtn.Size             = UDim2.new(0, 82, 0, 18)
            BindBtn.Position         = UDim2.new(1, -84, 0.5, -9)
            BindBtn.BackgroundColor3 = C.InputBG
            BindBtn.BorderSizePixel  = 0
            BindBtn.Text             = currentKey.Name
            BindBtn.TextColor3       = C.Accent
            BindBtn.Font             = Enum.Font.GothamBold
            BindBtn.TextSize         = 10
            BindBtn.AutoButtonColor  = false
            BindBtn.ZIndex           = 2
            BindBtn.Parent           = KF
            mkCorner(BindBtn, 3)
            mkStroke(BindBtn, 1, C.BorderDim)

            local function startListen()
                listening = true
                BindBtn.Text = "..."
                BindBtn.TextColor3 = Color3.fromRGB(230, 200, 50)
            end

            BindBtn.MouseButton1Click:Connect(startListen)
            BindBtn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then startListen() end
            end)

            UserInputService.InputBegan:Connect(function(input, gpe)
                if gpe then return end
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    listening = false
                    currentKey = input.KeyCode
                    BindBtn.Text = currentKey.Name
                    BindBtn.TextColor3 = C.Accent
                elseif not listening and input.KeyCode == currentKey then
                    if mode == "Toggle" then
                        isToggled = not isToggled
                        callback(isToggled)
                    elseif mode == "Hold" then
                        callback(true)
                    end
                end
            end)
            UserInputService.InputEnded:Connect(function(input, gpe)
                if gpe then return end
                if not listening and mode == "Hold" and input.KeyCode == currentKey then
                    callback(false)
                end
            end)
        end

        -- ── PARAGRAPH ───────────────────────────────────────────
        function HeaderObj:CreateParagraph(pConfig)
            local PF = Instance.new("Frame")
            PF.Size             = UDim2.new(1, 0, 0, 0)
            PF.BackgroundTransparency = 1
            PF.AutomaticSize    = Enum.AutomaticSize.Y
            PF.Parent           = Container

            local TLbl = Instance.new("TextLabel")
            TLbl.Size             = UDim2.new(1, 0, 0, 0)
            TLbl.BackgroundTransparency = 1
            TLbl.Text             = pConfig.Text or ""
            TLbl.TextColor3       = pConfig.Color or C.TextDim
            TLbl.Font             = Enum.Font.Gotham
            TLbl.TextSize         = 11
            TLbl.TextWrapped      = true
            TLbl.TextXAlignment   = Enum.TextXAlignment.Left
            TLbl.AutomaticSize    = Enum.AutomaticSize.Y
            TLbl.ZIndex           = 2
            TLbl.Parent           = PF

            local PObj = {}
            function PObj:SetText(t)  TLbl.Text = t end
            function PObj:SetColor(c) TLbl.TextColor3 = c end
            return PObj
        end

        -- ── LABEL ───────────────────────────────────────────────
        function HeaderObj:CreateLabel(lConfig)
            local LF = Instance.new("Frame")
            LF.Size             = UDim2.new(1, 0, 0, 16)
            LF.BackgroundTransparency = 1
            LF.Parent           = Container

            local TLbl = Instance.new("TextLabel")
            TLbl.Size             = UDim2.new(1, 0, 1, 0)
            TLbl.BackgroundTransparency = 1
            TLbl.Text             = lConfig.Text or ""
            TLbl.TextColor3       = lConfig.Color or C.TextDim
            TLbl.Font             = Enum.Font.Gotham
            TLbl.TextSize         = 11
            TLbl.TextXAlignment   = Enum.TextXAlignment.Left
            TLbl.ZIndex           = 2
            TLbl.Parent           = LF

            local LObj = {}
            function LObj:SetText(t)  TLbl.Text = t end
            function LObj:SetColor(c) TLbl.TextColor3 = c end
            return LObj
        end

        -- ── SEPARATOR (inside header) ────────────────────────────
        function HeaderObj:CreateSeparator()
            local Sep = Instance.new("Frame")
            Sep.Size             = UDim2.new(1, 0, 0, 1)
            Sep.BackgroundColor3 = C.Sep
            Sep.BorderSizePixel  = 0
            Sep.ZIndex           = 2
            Sep.Parent           = Container
        end

        return HeaderObj
    end   -- CreateHeader

    return WindowObj
end   -- CreateWindow

-- ================================================================
-- NOTIFICATIONS
-- ================================================================
local _notifCounter = 0

function ImGuiLib:Notify(config)
    local title    = config.Title    or "Notification"
    local message  = config.Message  or ""
    local duration = config.Duration or 3
    local color    = config.Color    or C.Accent

    local holder = CoreGui:FindFirstChild("ImGui_NotifHolder")
    if not holder then
        holder = Instance.new("ScreenGui")
        holder.Name         = "ImGui_NotifHolder"
        holder.ResetOnSpawn = false
        holder.DisplayOrder = 999
        if syn and syn.protect_gui then syn.protect_gui(holder)
        elseif gethui then holder.Parent = gethui()
        else holder.Parent = CoreGui end

        local layout = Instance.new("UIListLayout")
        layout.VerticalAlignment   = Enum.VerticalAlignment.Bottom
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        layout.Padding       = UDim.new(0, 6)
        layout.SortOrder     = Enum.SortOrder.LayoutOrder
        layout.FillDirection  = Enum.FillDirection.Vertical
        layout.Parent        = holder

        local pad = Instance.new("UIPadding")
        pad.PaddingBottom = UDim.new(0, 14)
        pad.PaddingRight  = UDim.new(0, 14)
        pad.Parent        = holder
    end

    _notifCounter += 1

    local Wrapper = Instance.new("Frame")
    Wrapper.Size             = UDim2.new(0, 245, 0, 58)
    Wrapper.BackgroundTransparency = 1
    Wrapper.BorderSizePixel  = 0
    Wrapper.ClipsDescendants = true
    Wrapper.LayoutOrder      = _notifCounter
    Wrapper.Parent           = holder

    local NF = Instance.new("Frame")
    NF.Size             = UDim2.new(1, 0, 1, 0)
    NF.Position         = UDim2.new(1, 0, 0, 0)
    NF.BackgroundColor3 = C.NotifBG
    NF.BorderSizePixel  = 0
    NF.Parent           = Wrapper
    mkCorner(NF, 5)
    mkStroke(NF, 1, C.Border)

    -- Coloured accent bar
    local Accent = Instance.new("Frame")
    Accent.Size             = UDim2.new(0, 3, 1, 0)
    Accent.BackgroundColor3 = color
    Accent.BorderSizePixel  = 0
    Accent.ZIndex           = 2
    Accent.Parent           = NF
    mkCorner(Accent, 4)

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size             = UDim2.new(1, -16, 0, 20)
    TitleLbl.Position         = UDim2.new(0, 12, 0, 5)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Text             = title
    TitleLbl.TextColor3       = C.Text
    TitleLbl.Font             = Enum.Font.GothamBold
    TitleLbl.TextSize         = 12
    TitleLbl.TextXAlignment   = Enum.TextXAlignment.Left
    TitleLbl.ZIndex           = 2
    TitleLbl.Parent           = NF

    local MsgLbl = Instance.new("TextLabel")
    MsgLbl.Size             = UDim2.new(1, -16, 0, 18)
    MsgLbl.Position         = UDim2.new(0, 12, 0, 26)
    MsgLbl.BackgroundTransparency = 1
    MsgLbl.Text             = message
    MsgLbl.TextColor3       = C.TextDim
    MsgLbl.Font             = Enum.Font.Gotham
    MsgLbl.TextSize         = 11
    MsgLbl.TextXAlignment   = Enum.TextXAlignment.Left
    MsgLbl.ZIndex           = 2
    MsgLbl.Parent           = NF

    -- Progress bar
    local PBG = Instance.new("Frame")
    PBG.Size             = UDim2.new(1, -14, 0, 2)
    PBG.Position         = UDim2.new(0, 12, 1, -4)
    PBG.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    PBG.BorderSizePixel  = 0
    PBG.ZIndex           = 2
    PBG.Parent           = NF
    mkCorner(PBG, 1)

    local PFill = Instance.new("Frame")
    PFill.Size             = UDim2.new(1, 0, 1, 0)
    PFill.BackgroundColor3 = color
    PFill.BorderSizePixel  = 0
    PFill.ZIndex           = 3
    PFill.Parent           = PBG
    mkCorner(PFill, 1)

    -- Slide in
    TweenService:Create(NF, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()

    -- Progress drain
    TweenService:Create(PFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Size = UDim2.new(0, 0, 1, 0)
    }):Play()

    -- Slide out + destroy
    task.delay(duration, function()
        TweenService:Create(NF, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 0, 0, 0)
        }):Play()
        task.wait(0.26)
        Wrapper:Destroy()
    end)
end

return ImGuiLib
