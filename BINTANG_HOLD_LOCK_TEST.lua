--[[
  Bintang — Hold Lock UI
  Aim lock hold + No Frenzy Cooldown toggle
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local S = {
    HoldLock = true,
    NoFrenzyCD = false,
    FOV = 160,
    Predict = 0.12,
    ShowFOV = true,
}

local HOLD_IDS = {
    ["rbxassetid://93902163029544"] = true,  -- lungehold
    ["rbxassetid://104540716539347"] = true, -- frenzylungehold
    ["rbxassetid://79310600168078"] = true,  -- attackfr
}

local locking = false
local FOVFrame, CrossGui

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
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

-- ===== No Frenzy CD (best-effort) =====
local function tryClearFrenzyCD()
    if not S.NoFrenzyCD then return end
    local char = LP.Character
    if not char then return end

    local keywords = {"frenzy", "cooldown", "cd", "skill", "ability", "power", "lunge"}

    local function nameHit(n)
        n = string.lower(tostring(n or ""))
        for _, k in ipairs(keywords) do
            if n:find(k, 1, true) then return true end
        end
        return false
    end

    -- attributes on player / char
    pcall(function()
        for _, inst in ipairs({LP, char}) do
            for key, val in pairs(inst:GetAttributes()) do
                if nameHit(key) then
                    if type(val) == "number" and val > 0 then
                        inst:SetAttribute(key, 0)
                    elseif type(val) == "boolean" then
                        -- skip flags that might break state
                    end
                end
            end
        end
    end)

    -- values under char / playergui / backpack
    local function scan(parent, depth)
        if not parent or depth > 5 then return end
        for _, c in ipairs(parent:GetChildren()) do
            if nameHit(c.Name) then
                pcall(function()
                    if c:IsA("NumberValue") or c:IsA("IntValue") then
                        c.Value = 0
                    elseif c:IsA("BoolValue") and (string.lower(c.Name):find("cd") or string.lower(c.Name):find("cool")) then
                        c.Value = false
                    end
                end)
            end
            scan(c, depth + 1)
        end
    end
    pcall(function() scan(char, 0) end)
    pcall(function() scan(LP, 0) end)
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        if pg then scan(pg, 0) end
    end)
end

task.spawn(function()
    while true do
        task.wait(0.2)
        pcall(tryClearFrenzyCD)
    end
end)

-- ===== visuals =====
local function ensureVisual()
    if FOVFrame and FOVFrame.Parent then return end
    local g = Instance.new("ScreenGui")
    g.Name = "BintangHoldLockVis"
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
    if S.ShowFOV then
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
    CrossGui.Position = UDim2.fromOffset(cx, cy)
    CrossGui.Visible = S.HoldLock

    if S.HoldLock and locking then
        local pos = getClosest()
        if pos then
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, pos), 0.9)
        end
    end
end)

local function hookAnimator(animator)
    animator.AnimationPlayed:Connect(function(track)
        if not S.HoldLock then return end
        local anim = track.Animation
        local id = anim and anim.AnimationId
        if not (id and HOLD_IDS[id]) then return end
        locking = true
        print("[Bintang] HOLD LOCK ON", anim and anim.Name, id)
        task.spawn(function()
            while track.IsPlaying and S.HoldLock do
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
    panel = Color3.fromRGB(22, 22, 26),
    row = Color3.fromRGB(28, 28, 34),
    accent = Color3.fromRGB(155, 89, 255),
    text = Color3.fromRGB(245, 245, 248),
    muted = Color3.fromRGB(130, 130, 140),
    on = Color3.fromRGB(155, 89, 255),
    off = Color3.fromRGB(50, 50, 58),
}

pcall(function()
    if CoreGui:FindFirstChild("BintangHoldLockUI") then CoreGui.BintangHoldLockUI:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "BintangHoldLockUI"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local win = Instance.new("Frame")
win.Size = UDim2.fromOffset(240, 200)
win.Position = UDim2.new(0, 14, 0.35, 0)
win.BackgroundColor3 = C.bg
win.BorderSizePixel = 0
win.Parent = gui
corner(win, 12)
local ws = Instance.new("UIStroke")
ws.Color = C.accent
ws.Thickness = 1
ws.Parent = win

local top = Instance.new("TextLabel")
top.BackgroundTransparency = 1
top.Size = UDim2.new(1, -16, 0, 32)
top.Position = UDim2.fromOffset(12, 4)
top.Font = Enum.Font.GothamBold
top.TextSize = 14
top.TextColor3 = C.text
top.TextXAlignment = Enum.TextXAlignment.Left
top.Text = "Bintang · Hold Lock"
top.Parent = win

local function addToggle(y, key, label)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -24, 0, 34)
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
        if key == "NoFrenzyCD" then
            print("[Bintang] No Frenzy CD:", S.NoFrenzyCD)
        end
    end)
end

addToggle(40, "HoldLock", "Hold Aim Lock")
addToggle(80, "ShowFOV", "Show FOV")
addToggle(120, "NoFrenzyCD", "No Frenzy Cooldown")

local note = Instance.new("TextLabel")
note.BackgroundTransparency = 1
note.Size = UDim2.new(1, -24, 0, 36)
note.Position = UDim2.fromOffset(12, 158)
note.Font = Enum.Font.Gotham
note.TextSize = 10
note.TextColor3 = C.muted
note.TextXAlignment = Enum.TextXAlignment.Left
note.TextWrapped = true
note.Text = "Lock: lungehold + frenzylungehold\nNo CD = best-effort attribute wipe"
note.Parent = win

-- drag
do
    local drag, start, pos
    top.InputBegan:Connect(function(i)
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

print("[Bintang] Hold Lock UI loaded")
