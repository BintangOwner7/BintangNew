--[[
    SILENT THE BUTCHER
    Chain silent for The Butcher (Halloween)
    UI + Laser | − minimize | ✕ close
    RightShift toggle | 48 stud | FOV synced
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera

local CONFIG = {
    MAX_RANGE = 48,
    FOV_DEFAULT = 110,
    AIM_POINT = "HumanoidRootPart",
    AIM_Y_OFFSET = 0.45,
    PREDICTION = 0.95,
    SPEED = 110,
    LASER_COLOR = Color3.fromRGB(0, 255, 130)
}

local STATE = {
    enabled = true,
    minimized = false,
    fovDeg = CONFIG.FOV_DEFAULT,
    lockedTarget = nil,
    lastAimDir = nil,
    lastOrigin = nil,
    lastVel = Vector3.zero,
    gui = nil,
    panel = nil,
    miniBtn = nil,
    fovCircle = nil,
    lockLabel = nil,
    statusLabel = nil,
    toggleBtn = nil,
    laser = nil,
    oldNamecall = nil,
    hookMT = nil,
    conn = nil,
    remote = nil
}

local function predict(part, t)
    if not part then return nil end
    local vel = part.AssemblyLinearVelocity or Vector3.zero
    STATE.lastVel = STATE.lastVel:Lerp(vel, 0.35)
    local lead = Vector3.new(STATE.lastVel.X, STATE.lastVel.Y * 0.15, STATE.lastVel.Z) * (t or 0.35) * CONFIG.PREDICTION
    return part.Position + lead + Vector3.new(0, CONFIG.AIM_Y_OFFSET, 0)
end

local function getFovRadiusPx()
    local vp = Cam.ViewportSize
    local camFov = math.rad(Cam.FieldOfView)
    local aimFov = math.rad(math.clamp(STATE.fovDeg, 30, 150))
    local r = (vp.Y * 0.5) * (math.tan(aimFov * 0.5) / math.tan(camFov * 0.5))
    return math.clamp(r, 25, vp.Y * 0.75)
end

local function isEnemy(plr)
    if plr == LP then return false end
    local a, b = LP.Team, plr.Team
    if a and b then return a ~= b end
    return true
end

local function isValid(char, hum)
    if not hum or hum.Health <= 25 then return false end
    if char:GetAttribute("Knocked") or char:GetAttribute("IsKnocked") then return false end
    if char:GetAttribute("IsHooked") then return false end
    local hp = char:GetAttribute("HookPhase") or char:GetAttribute("HookedPhase")
    if hp and hp > 0 then return false end
    return true
end

local accum = 0
local function updateTarget(dt)
    if not STATE.enabled then
        STATE.lockedTarget = nil
        STATE.lastAimDir = nil
        STATE.lastVel = Vector3.zero
        return
    end

    local radius = getFovRadiusPx()
    local center = Vector2.new(Cam.ViewportSize.X * 0.5, Cam.ViewportSize.Y * 0.5)
    local origin = Cam.CFrame.Position

    if STATE.lockedTarget then
        local ch = STATE.lockedTarget.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local hrp = ch and ch:FindFirstChild(CONFIG.AIM_POINT)
        if not (ch and ch.Parent and hum and hrp and isValid(ch, hum)) then
            STATE.lockedTarget = nil
            STATE.lastAimDir = nil
            STATE.lastVel = Vector3.zero
        else
            local dist = (hrp.Position - origin).Magnitude
            if dist > CONFIG.MAX_RANGE then
                STATE.lockedTarget = nil
                STATE.lastAimDir = nil
                STATE.lastVel = Vector3.zero
            else
                local sp, on = Cam:WorldToViewportPoint(hrp.Position)
                if on and (Vector2.new(sp.X, sp.Y) - center).Magnitude <= radius then
                    local pred = predict(hrp, dist / CONFIG.SPEED)
                    STATE.lastAimDir = (pred - origin).Unit
                    STATE.lastOrigin = origin
                    return
                end
                STATE.lockedTarget = nil
                STATE.lastAimDir = nil
            end
        end
    end

    accum = accum + dt
    if accum < 0.04 then return end
    accum = 0

    local best, bestD = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local ch = plr.Character
            if ch then
                local hrp = ch:FindFirstChild(CONFIG.AIM_POINT)
                local hum = ch:FindFirstChildOfClass("Humanoid")
                if hrp and hum and isValid(ch, hum) then
                    local dist = (hrp.Position - origin).Magnitude
                    if dist <= CONFIG.MAX_RANGE then
                        local sp, on = Cam:WorldToViewportPoint(hrp.Position)
                        if on then
                            local screenD = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            if screenD <= radius and screenD < bestD then
                                best = plr
                                bestD = screenD
                            end
                        end
                    end
                end
            end
        end
    end

    STATE.lockedTarget = best
    if best then
        local hrp = best.Character and best.Character:FindFirstChild(CONFIG.AIM_POINT)
        if hrp then
            local dist = (hrp.Position - origin).Magnitude
            local pred = predict(hrp, dist / CONFIG.SPEED)
            STATE.lastAimDir = (pred - origin).Unit
            STATE.lastOrigin = origin
        end
    else
        STATE.lastAimDir = nil
        STATE.lastVel = Vector3.zero
    end
end

local function setupHook()
    local remote
    local paths = {
        function() return ReplicatedStorage.Remotes.Killers.Butcher.Chain end,
        function() return ReplicatedStorage.Remotes.Killers.Butcher.YourHeartIsMine end,
        function() return ReplicatedStorage.Remotes.Killers.Butcher.Throw end,
        function() return ReplicatedStorage.Remotes.Killers.Butcher.Cast end,
        function() return ReplicatedStorage.Remotes.Killers.Butcher.Use end,
    }
    for _, fn in ipairs(paths) do
        local ok, r = pcall(fn)
        if ok and r then remote = r break end
    end

    if not remote then
        pcall(function()
            for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
                if r:IsA("RemoteEvent") then
                    local n = r.Name:lower()
                    if n:find("chain") or n:find("heart") or (n:find("butcher") and (n:find("throw") or n:find("cast") or n:find("use") or n:find("fire"))) then
                        remote = r
                        break
                    end
                end
            end
        end)
    end

    if not remote then
        pcall(function()
            for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
                if r:IsA("RemoteEvent") and (r.Name:lower():find("chain") or r.Name:lower():find("hook")) then
                    remote = r
                    break
                end
            end
        end)
    end

    if not remote or type(hookmetamethod) ~= "function" then
        warn("[SILENT THE BUTCHER] remote/hook missing")
        return
    end

    STATE.remote = remote
    print("[SILENT THE BUTCHER] hooked:", remote:GetFullName())

    local mt = getrawmetatable(game)
    local old = mt.__namecall
    STATE.oldNamecall = old
    STATE.hookMT = mt

    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if method == "FireServer" and self == remote then
            if STATE.enabled and STATE.lastAimDir and STATE.lockedTarget then
                local payload = args[1]
                if type(payload) == "table" then
                    local np = {}
                    for k, v in pairs(payload) do np[k] = v end
                    np.Direction = STATE.lastAimDir
                    np.LookVector = STATE.lastAimDir
                    np.Origin = STATE.lastOrigin or Cam.CFrame.Position
                    np.Position = STATE.lastOrigin or Cam.CFrame.Position
                    args[1] = np
                end
                return old(self, unpack(args))
            end
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
end

local function cleanup()
    if STATE.conn then pcall(function() STATE.conn:Disconnect() end) end
    if STATE.hookMT and STATE.oldNamecall then
        pcall(function()
            setreadonly(STATE.hookMT, false)
            STATE.hookMT.__namecall = STATE.oldNamecall
            setreadonly(STATE.hookMT, true)
        end)
    end
    if STATE.laser then pcall(function() STATE.laser:Remove() end) end
    if STATE.gui then pcall(function() STATE.gui:Destroy() end) end
    print("[SILENT THE BUTCHER] Unloaded")
end

local function buildUI()
    local parent = (type(gethui) == "function" and gethui()) or CoreGui

    local gui = Instance.new("ScreenGui")
    gui.Name = "SilentTheButcher"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999999
    gui.Parent = parent
    STATE.gui = gui

    -- FOV circle
    local fov = Instance.new("Frame")
    fov.AnchorPoint = Vector2.new(0.5, 0.5)
    fov.Position = UDim2.fromScale(0.5, 0.5)
    fov.Size = UDim2.fromOffset(280, 280)
    fov.BackgroundTransparency = 1
    fov.Visible = STATE.enabled
    fov.ZIndex = 2
    fov.Parent = gui
    Instance.new("UICorner", fov).CornerRadius = UDim.new(1, 0)
    local fs = Instance.new("UIStroke", fov)
    fs.Color = Color3.fromRGB(255, 80, 80)
    fs.Thickness = 1.4
    fs.Transparency = 0.45
    STATE.fovCircle = fov

    -- lock label
    local lock = Instance.new("TextLabel")
    lock.AnchorPoint = Vector2.new(0.5, 0.5)
    lock.BackgroundTransparency = 1
    lock.Text = ""
    lock.TextColor3 = Color3.fromRGB(0, 255, 130)
    lock.Font = Enum.Font.GothamBold
    lock.TextSize = 13
    lock.TextStrokeTransparency = 0.5
    lock.Visible = false
    lock.ZIndex = 5
    lock.Parent = gui
    STATE.lockLabel = lock

    -- laser
    pcall(function()
        if Drawing then
            local line = Drawing.new("Line")
            line.Thickness = 1.5
            line.Color = CONFIG.LASER_COLOR
            line.Transparency = 0.3
            line.Visible = false
            STATE.laser = line
        end
    end)

    -- panel
    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(290, 172)
    panel.Position = UDim2.new(0.5, -145, 0, 70)
    panel.BackgroundColor3 = Color3.fromRGB(14, 10, 10)
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.Draggable = true
    panel.ZIndex = 10
    panel.Parent = gui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
    local pStroke = Instance.new("UIStroke", panel)
    pStroke.Color = Color3.fromRGB(200, 40, 40)
    pStroke.Thickness = 1.3
    pStroke.Transparency = 0.25
    STATE.panel = panel

    -- top bar
    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 36)
    top.BackgroundColor3 = Color3.fromRGB(28, 12, 12)
    top.BorderSizePixel = 0
    top.ZIndex = 11
    top.Parent = panel
    Instance.new("UICorner", top).CornerRadius = UDim.new(0, 10)
    local topFix = Instance.new("Frame")
    topFix.Size = UDim2.new(1, 0, 0, 14)
    topFix.Position = UDim2.new(0, 0, 1, -14)
    topFix.BackgroundColor3 = Color3.fromRGB(28, 12, 12)
    topFix.BorderSizePixel = 0
    topFix.ZIndex = 11
    topFix.Parent = top

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.fromOffset(14, 0)
    title.BackgroundTransparency = 1
    title.Text = "SILENT THE BUTCHER"
    title.TextColor3 = Color3.fromRGB(255, 90, 90)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 12
    title.Parent = top

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.fromOffset(28, 28)
    minBtn.Position = UDim2.new(1, -64, 0, 4)
    minBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
    minBtn.Text = "−"
    minBtn.TextColor3 = Color3.new(1,1,1)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 18
    minBtn.BorderSizePixel = 0
    minBtn.ZIndex = 13
    minBtn.Parent = top
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(28, 28)
    closeBtn.Position = UDim2.new(1, -32, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 35, 35)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.BorderSizePixel = 0
    closeBtn.ZIndex = 13
    closeBtn.Parent = top
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.fromOffset(262, 22)
    status.Position = UDim2.fromOffset(14, 46)
    status.BackgroundTransparency = 1
    status.Text = "STATUS: ACTIVE  •  CHAIN"
    status.TextColor3 = Color3.fromRGB(0, 255, 140)
    status.Font = Enum.Font.GothamBold
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.ZIndex = 11
    status.Parent = panel
    STATE.statusLabel = status

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.fromOffset(262, 36)
    toggle.Position = UDim2.fromOffset(14, 72)
    toggle.BackgroundColor3 = Color3.fromRGB(140, 30, 30)
    toggle.Text = "SILENT  •  ON"
    toggle.TextColor3 = Color3.new(1,1,1)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 14
    toggle.BorderSizePixel = 0
    toggle.ZIndex = 11
    toggle.Parent = panel
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 7)
    STATE.toggleBtn = toggle

    local fovLbl = Instance.new("TextLabel")
    fovLbl.Size = UDim2.fromOffset(262, 18)
    fovLbl.Position = UDim2.fromOffset(14, 116)
    fovLbl.BackgroundTransparency = 1
    fovLbl.Text = "FOV  110    |    RANGE  48"
    fovLbl.TextColor3 = Color3.fromRGB(190, 170, 170)
    fovLbl.Font = Enum.Font.Gotham
    fovLbl.TextSize = 11
    fovLbl.TextXAlignment = Enum.TextXAlignment.Left
    fovLbl.ZIndex = 11
    fovLbl.Parent = panel

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.fromOffset(262, 8)
    sliderBg.Position = UDim2.fromOffset(14, 140)
    sliderBg.BackgroundColor3 = Color3.fromRGB(45, 30, 30)
    sliderBg.BorderSizePixel = 0
    sliderBg.ZIndex = 11
    sliderBg.Parent = panel
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0.45, 1)
    fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    fill.BorderSizePixel = 0
    fill.ZIndex = 12
    fill.Parent = sliderBg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    -- mini
    local mini = Instance.new("TextButton")
    mini.Size = UDim2.fromOffset(170, 34)
    mini.Position = UDim2.new(0, 20, 0, 20)
    mini.BackgroundColor3 = Color3.fromRGB(20, 12, 12)
    mini.BorderSizePixel = 0
    mini.Text = "SILENT BUTCHER"
    mini.TextColor3 = Color3.fromRGB(255, 90, 90)
    mini.Font = Enum.Font.GothamBold
    mini.TextSize = 12
    mini.Visible = false
    mini.Active = true
    mini.ZIndex = 15
    mini.Parent = gui
    Instance.new("UICorner", mini).CornerRadius = UDim.new(0, 8)
    local mStroke = Instance.new("UIStroke", mini)
    mStroke.Color = Color3.fromRGB(180, 40, 40)
    mStroke.Thickness = 1
    mStroke.Transparency = 0.3
    STATE.miniBtn = mini

    local function setEnabled(on)
        STATE.enabled = on
        toggle.Text = on and "SILENT  •  ON" or "SILENT  •  OFF"
        toggle.BackgroundColor3 = on and Color3.fromRGB(140, 30, 30) or Color3.fromRGB(50, 40, 40)
        status.Text = on and "STATUS: ACTIVE  •  CHAIN" or "STATUS: OFF"
        status.TextColor3 = on and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 100, 100)
        STATE.fovCircle.Visible = on
        if not on then
            STATE.lockedTarget = nil
            STATE.lastAimDir = nil
            STATE.lastVel = Vector3.zero
            STATE.lockLabel.Visible = false
            if STATE.laser then STATE.laser.Visible = false end
        end
    end

    toggle.MouseButton1Click:Connect(function()
        setEnabled(not STATE.enabled)
    end)

    closeBtn.MouseButton1Click:Connect(cleanup)

    minBtn.MouseButton1Click:Connect(function()
        STATE.minimized = true
        mini.Position = panel.Position
        panel.Visible = false
        mini.Visible = true
    end)

    mini.MouseButton1Click:Connect(function()
        STATE.minimized = false
        panel.Position = mini.Position
        panel.Visible = true
        mini.Visible = false
    end)

    local dragging, dragStart, startPos
    mini.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mini.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    mini.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            mini.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local function applyFov(rel)
        rel = math.clamp(rel, 0, 1)
        fill.Size = UDim2.fromScale(rel, 1)
        STATE.fovDeg = 50 + rel * 100
        fovLbl.Text = string.format("FOV  %.0f    |    RANGE  48", STATE.fovDeg)
        local r = getFovRadiusPx()
        STATE.fovCircle.Size = UDim2.fromOffset(r * 2, r * 2)
        STATE.lockedTarget = nil
        STATE.lastAimDir = nil
    end

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local rel = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
            applyFov(rel)
            local m
            m = UserInputService.InputChanged:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                    local r2 = (inp.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
                    applyFov(r2)
                end
            end)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End and m then m:Disconnect() end
            end)
        end
    end)

    local r = getFovRadiusPx()
    STATE.fovCircle.Size = UDim2.fromOffset(r * 2, r * 2)
end

local function updateVisuals()
    if STATE.lockLabel then
        if STATE.enabled and STATE.lockedTarget and STATE.lastAimDir then
            local ch = STATE.lockedTarget.Character
            local hrp = ch and ch:FindFirstChild(CONFIG.AIM_POINT)
            if hrp then
                local pos = hrp.Position + Vector3.new(0, CONFIG.AIM_Y_OFFSET, 0)
                local sp, on = Cam:WorldToViewportPoint(pos)
                if on then
                    local dist = (pos - Cam.CFrame.Position).Magnitude
                    STATE.lockLabel.Visible = true
                    STATE.lockLabel.Position = UDim2.fromOffset(sp.X, sp.Y - 22)
                    STATE.lockLabel.Text = string.format("CHAIN LOCK\n%.0f studs", dist)
                else
                    STATE.lockLabel.Visible = false
                end
            else
                STATE.lockLabel.Visible = false
            end
        else
            STATE.lockLabel.Visible = false
        end
    end

    if STATE.laser then
        if STATE.enabled and STATE.lockedTarget and STATE.lastAimDir then
            local ch = STATE.lockedTarget.Character
            local hrp = ch and ch:FindFirstChild(CONFIG.AIM_POINT)
            if hrp then
                local from = Cam.ViewportSize / 2
                local toPos = hrp.Position + Vector3.new(0, CONFIG.AIM_Y_OFFSET, 0)
                local sp, on = Cam:WorldToViewportPoint(toPos)
                if on and sp.Z > 0 then
                    STATE.laser.From = Vector2.new(from.X, from.Y)
                    STATE.laser.To = Vector2.new(sp.X, sp.Y)
                    STATE.laser.Visible = true
                else
                    STATE.laser.Visible = false
                end
            else
                STATE.laser.Visible = false
            end
        else
            STATE.laser.Visible = false
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        STATE.enabled = not STATE.enabled
        if STATE.toggleBtn then
            STATE.toggleBtn.Text = STATE.enabled and "SILENT  •  ON" or "SILENT  •  OFF"
            STATE.toggleBtn.BackgroundColor3 = STATE.enabled and Color3.fromRGB(140, 30, 30) or Color3.fromRGB(50, 40, 40)
        end
        if STATE.statusLabel then
            STATE.statusLabel.Text = STATE.enabled and "STATUS: ACTIVE  •  CHAIN" or "STATUS: OFF"
            STATE.statusLabel.TextColor3 = STATE.enabled and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 100, 100)
        end
        if STATE.fovCircle then STATE.fovCircle.Visible = STATE.enabled end
        if not STATE.enabled then
            STATE.lockedTarget = nil
            STATE.lastAimDir = nil
            STATE.lastVel = Vector3.zero
            if STATE.laser then STATE.laser.Visible = false end
        end
    end
end)

buildUI()
setupHook()

STATE.conn = RunService.RenderStepped:Connect(function(dt)
    updateTarget(dt)
    updateVisuals()
end)

print("[SILENT THE BUTCHER] Loaded | Laser | − ✕ | 48 stud | FOV synced")
