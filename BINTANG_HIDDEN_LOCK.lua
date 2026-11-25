--[[
  Bintang — Hidden Hold/Skill Aim Lock
  All dump IDs + FOV slider UI
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local S = {
    Enabled = true,
    ShowFOV = true,
    FOV = 160,
    Predict = 0.12,
}

-- semua ID dari dump Hidden (kecuali WalkAnim)
local LOCK_IDS = {
    ["rbxassetid://113255068724446"] = true, -- lungehold
    ["rbxassetid://74968262036854"] = true,  -- attack
    ["rbxassetid://109928123357793"] = true, -- LONG ability
    ["rbxassetid://98163597193511"] = true,  -- LONG ability
    ["rbxassetid://70400864844827"] = true,  -- LONG ability (normalized)
    ["rbxassetid://12380926872645"] = true,  -- Animation1
    ["rbxassetid://111816962746891"] = true, -- UNKNOWN
    ["rbxassetid://76385865186777"] = true,  -- WallHitStun2
}

local locking = false
local FOVFrame, CrossGui

local function corner(p, r)
    Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 8)
end
local function tween(o, t, props)
    TweenService:Create(o, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad), props):Play()
end

local function isSurvivor(plr)
    if plr == LP then return false end
    if LP.Team and plr.Team and LP.Team == plr.Team then return false end
    local role = plr:GetAttribute("Role") or plr:GetAttribute("role")
    if role and string.lower(tostring(role)):find("kill") then return false end
    return true
end

local function alive(plr)
    local c = plr.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    local r = c:FindFirstChild("HumanoidRootPart")
    return h and h.Health > 0 and r
end

local function getClosest()
    local best, bestD = nil, S.FOV
    local center = Camera.ViewportSize / 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if isSurvivor(plr) and alive(plr) then
            local char = plr.Character
            local part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
            if part then
                local pos = part.Position + (part.AssemblyLinearVelocity or Vector3.zero) * S.Predict
                local v, on = Camera:WorldToViewportPoint(pos)
                if on then
                    local d = (Vector2.new(v.X, v.Y) - center).Magnitude
                    if d < bestD then
                        bestD = d
                        best = pos
                    end
                end
            end
        end
    end
    return best
end

local function normalizeId(id)
    if not id then return nil end
    id = tostring(id)
    local num = id:match("(%d+)")
    if num then return "rbxassetid://" .. num end
    return id
end

local function ensureVisual()
    if FOVFrame and FOVFrame.Parent then return end
    local g = Instance.new("ScreenGui")
    g.Name = "BintangHiddenVis"
    g.IgnoreGuiInset = true
    g.ResetOnSpawn = false
    pcall(function() g.Parent = gethui and gethui() or CoreGui end)
    if not g.Parent then g.Parent = LP:WaitForChild("PlayerGui") end

    FOVFrame = Instance.new("Frame")
    FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    FOVFrame.BackgroundTransparency = 1
    FOVFrame.Parent = g
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(155, 89, 255)
    s.Thickness = 1.5
    s.Transparency = 0.35
    s.Parent = FOVFrame
    Instance.new("UICorner", FOVFrame).CornerRadius = UDim.new(1, 0)

    CrossGui = Instance.new("Frame")
    CrossGui.AnchorPoint = Vector2.new(0.5, 0.5)
    CrossGui.Size = UDim2.fromOffset(16, 16)
    CrossGui.BackgroundTransparency = 1
    CrossGui.Parent = g
    for _, d in ipairs({{0.5,0,2,6},{0.5,1,2,6},{0,0.5,6,2},{1,0.5,6,2}}) do
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromScale(d[1], d[2])
        f.Size = UDim2.fromOffset(d[3], d[4])
        f.BackgroundColor3 = Color3.new(1, 1, 1)
        f.BorderSizePixel = 0
        f.Parent = CrossGui
    end
end

RunService.RenderStepped:Connect(function()
    ensureVisual()
    local vp = Camera.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    if S.ShowFOV and S.Enabled then
        FOVFrame.Visible = true
        FOVFrame.Size = UDim2.fromOffset(S.FOV * 2, S.FOV * 2)
        FOVFrame.Position = UDim2.fromOffset(cx, cy)
        local st = FOVFrame:FindFirstChildOfClass("UIStroke")
        if st then
            st.Color = locking and Color3.fromRGB(255, 70, 90) or Color3.fromRGB(155, 89, 255)
            st.Transparency = locking and 0.12 or 0.35
        end
    else
        FOVFrame.Visible = false
    end
    CrossGui.Visible = S.Enabled
    CrossGui.Position = UDim2.fromOffset(cx, cy)

    if S.Enabled and locking then
        local pos = getClosest()
        if pos then
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, pos), 0.9)
        end
    end
end)

local function hookAnimator(animator)
    animator.AnimationPlayed:Connect(function(track)
        if not S.Enabled then return end
        local id = normalizeId(track.Animation and track.Animation.AnimationId)
        if not (id and LOCK_IDS[id]) then return end
        locking = true
        print("[Bintang Hidden] LOCK ON", track.Animation and track.Animation.Name, id)
        task.spawn(function()
            while track.IsPlaying and S.Enabled do
                task.wait(0.03)
            end
            locking = false
        end)
    end)
end

local function hookChar(char)
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 8)
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5)
        if animator then hookAnimator(animator) end
    end)
end
if LP.Character then hookChar(LP.Character) end
LP.CharacterAdded:Connect(hookChar)

-- ===== UI =====
local C = {
    bg = Color3.fromRGB(16, 16, 18),
    row = Color3.fromRGB(28, 28, 34),
    accent = Color3.fromRGB(155, 89, 255),
    text = Color3.fromRGB(245, 245, 248),
    muted = Color3.fromRGB(130, 130, 140),
    on = Color3.fromRGB(155, 89, 255),
    off = Color3.fromRGB(50, 50, 58),
}

pcall(function()
    if CoreGui:FindFirstChild("BintangHiddenUI") then CoreGui.BintangHiddenUI:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "BintangHiddenUI"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local win = Instance.new("Frame")
win.Size = UDim2.fromOffset(250, 230)
win.Position = UDim2.new(0, 14, 0.32, 0)
win.BackgroundColor3 = C.bg
win.BorderSizePixel = 0
win.Parent = gui
corner(win, 12)
local stroke = Instance.new("UIStroke")
stroke.Color = C.accent
stroke.Thickness = 1
stroke.Parent = win

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -16, 0, 30)
title.Position = UDim2.fromOffset(12, 4)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = C.text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Bintang · Hidden Lock"
title.Parent = win

local function addToggle(y, key, label)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -24, 0, 32)
    row.Position = UDim2.fromOffset(12, y)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.Parent = win
    corner(row, 8)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.fromOffset(10, 0)
    lbl.Size = UDim2.new(1, -54, 1, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row
    local track = Instance.new("TextButton")
    track.Size = UDim2.fromOffset(40, 22)
    track.Position = UDim2.new(1, -48, 0.5, -11)
    track.BackgroundColor3 = S[key] and C.on or C.off
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = row
    corner(track, 11)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(18, 18)
    knob.Position = S[key] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 9)
    track.MouseButton1Click:Connect(function()
        S[key] = not S[key]
        tween(track, 0.12, {BackgroundColor3 = S[key] and C.on or C.off})
        tween(knob, 0.12, {Position = S[key] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)})
    end)
end

addToggle(38, "Enabled", "Aim Lock")
addToggle(76, "ShowFOV", "Show FOV")

-- FOV slider
local fovLabel = Instance.new("TextLabel")
fovLabel.BackgroundTransparency = 1
fovLabel.Size = UDim2.new(1, -24, 0, 20)
fovLabel.Position = UDim2.fromOffset(12, 116)
fovLabel.Font = Enum.Font.Gotham
fovLabel.TextSize = 12
fovLabel.TextColor3 = C.text
fovLabel.TextXAlignment = Enum.TextXAlignment.Left
fovLabel.Text = "FOV: " .. tostring(S.FOV)
fovLabel.Parent = win

local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, -24, 0, 10)
bar.Position = UDim2.fromOffset(12, 140)
bar.BackgroundColor3 = C.row
bar.BorderSizePixel = 0
bar.Parent = win
corner(bar, 5)

local fill = Instance.new("Frame")
fill.Size = UDim2.new(math.clamp((S.FOV - 40) / 260, 0, 1), 0, 1, 0)
fill.BackgroundColor3 = C.accent
fill.BorderSizePixel = 0
fill.Parent = bar
corner(fill, 5)

local knobBtn = Instance.new("TextButton")
knobBtn.Size = UDim2.fromOffset(16, 16)
knobBtn.AnchorPoint = Vector2.new(0.5, 0.5)
knobBtn.Position = UDim2.new(math.clamp((S.FOV - 40) / 260, 0, 1), 0, 0.5, 0)
knobBtn.BackgroundColor3 = Color3.new(1, 1, 1)
knobBtn.Text = ""
knobBtn.AutoButtonColor = false
knobBtn.Parent = bar
corner(knobBtn, 8)

local sliding = false
local function setFOVFromX(x)
    local abs = bar.AbsolutePosition.X
    local w = bar.AbsoluteSize.X
    local a = math.clamp((x - abs) / math.max(w, 1), 0, 1)
    S.FOV = math.floor(40 + a * 260)
    fill.Size = UDim2.new(a, 0, 1, 0)
    knobBtn.Position = UDim2.new(a, 0, 0.5, 0)
    fovLabel.Text = "FOV: " .. tostring(S.FOV)
end

knobBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        sliding = true
    end
end)
bar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        sliding = true
        setFOVFromX(i.Position.X)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        sliding = false
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        setFOVFromX(i.Position.X)
    end
end)

local note = Instance.new("TextLabel")
note.BackgroundTransparency = 1
note.Size = UDim2.new(1, -24, 0, 40)
note.Position = UDim2.fromOffset(12, 160)
note.Font = Enum.Font.Gotham
note.TextSize = 10
note.TextColor3 = C.muted
note.TextXAlignment = Enum.TextXAlignment.Left
note.TextWrapped = true
note.Text = "Hidden: lungehold + attack + skill IDs\nFOV merah = sedang lock"
note.Parent = win

-- drag window
do
    local drag, start, pos
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true
            start = i.Position
            pos = win.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            win.Position = UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
        end
    end)
end

print("[Bintang] Hidden Lock UI — all skill IDs")
