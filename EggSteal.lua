--=====================================================================
-- LeakWorm Egg Heist  |  Steal An Egg (2024)  |  Loadstring build
-- Host this file. Load with:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/YOU/YOURREPO/main/EggSteal.lua"))()
-- Free. Keyless. No RenderStepped. Self-configuring.
--=====================================================================

if _G.__LW_EGG_LOADED then
    pcall(function() for _, v in ipairs(game:GetService("Players").LocalPlayer.PlayerGui:GetChildren()) do
        if v.Name == "EggStealUI" then v:Destroy() end
    end end)
end
_G.__LW_EGG_LOADED = true

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer

--==================== CONFIG (auto-detected below) ==================
local Config = {
    EggKeys  = { "egg", "easteregg", "collectible", "prize" },
    GuardKeys= { "protector", "mother", "guardian", "parent", "mom", "guard", "keeper" },
    StealKeys= { "steal", "grab", "take", "pickup", "collect", "snatch" },
    DreamKeys= { "dream", "sleep", "wake", "alert", "suspicion", "detect" },
    SafeKeys = { "safe", "base", "home", "nest", "house", "spawn" },

    StealGap        = 0.05,
    DreamTick       = 0.75,
    FallbackSafe    = CFrame.new(0, 200, 0),
}

if isfile and isfile("LeakWormEggCfg.json") then
    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile("LeakWormEggCfg.json")) end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do Config[k] = v end
    end
end

--==================== DETECTORS =====================================
local function matchAny(name, keys)
    local n = name:lower()
    for _, k in ipairs(keys) do if n:find(k, 1, true) then return true end end
    return false
end

local function findRemote(keys)
    for _, root in ipairs({ ReplicatedStorage, Workspace }) do
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                if matchAny(d.Name, keys) then return d end
            end
        end
    end
    return nil
end

local function findSafeZone()
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") and matchAny(d.Name, Config.SafeKeys) then
            return d.CFrame
        end
    end
    local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
    if sp then return sp.CFrame end
    return Config.FallbackSafe
end

--==================== STATE =========================================
local ET = {}
ET.StealRemote = findRemote(Config.StealKeys)
ET.DreamRemote = findRemote(Config.DreamKeys)
ET.SafeCFrame  = findSafeZone()
ET.EasySteal   = false
ET._thread     = nil

local function refresh()
    ET.Eggs  = {}
    ET.Guards= {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Model") or d:IsA("BasePart") then
            if matchAny(d.Name, Config.EggKeys)   then table.insert(ET.Eggs,   d) end
            if matchAny(d.Name, Config.GuardKeys) then table.insert(ET.Guards, d) end
        end
    end
    ET.SafeCFrame = findSafeZone()
end
refresh()

local function getHRP()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local function tp(cf)
    local hrp = getHRP()
    if hrp then hrp.CFrame = cf + Vector3.new(0, 3, 0) end
end

--==================== EASY STEAL (dream lock) =======================
local function startDreamLock()
    if ET._thread then return end
    ET._thread = task.spawn(function()
        while ET.EasySteal do
            if ET.DreamRemote then
                pcall(function() ET.DreamRemote:FireServer(true) end)
            end
            for _, g in ipairs(ET.Guards) do
                pcall(function()
                    local hum = g:IsA("Model") and g:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum.WalkSpeed = 0
                        hum.JumpPower = 0
                        hum:ChangeState(Enum.HumanoidStateType.Physics)
                    end
                    local part = g:IsA("BasePart") and g or (g:IsA("Model") and (g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart")))
                    if part then part.Anchored = true end
                end)
            end
            task.wait(Config.DreamTick)
        end
    end)
end

local function stopDreamLock()
    ET.EasySteal = false
    ET._thread   = nil
end

--==================== STEAL =========================================
local function eggPart(e)
    if not e then return nil end
    if e:IsA("BasePart") then return e end
    return e.PrimaryPart or e:FindFirstChildWhichIsA("BasePart")
end

local function nearestEgg(filter)
    local hrp = getHRP(); if not hrp then return nil end
    local best, bestD
    for _, e in ipairs(ET.Eggs) do
        local p = eggPart(e)
        if p then
            local ok = (not filter) or p.Name:lower():find(filter:lower(), 1, true)
                       or e.Name:lower():find(filter:lower(), 1, true)
            if ok then
                local d = (p.Position - hrp.Position).Magnitude
                if not bestD or d < bestD then bestD, best = d, p end
            end
        end
    end
    return best
end

local function steal(part)
    if not part then return false end
    local hrp = getHRP(); if not hrp then return false end
    hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
    if ET.StealRemote then pcall(function() ET.StealRemote:FireServer(part) end) end
    pcall(function()
        if part:IsA("BasePart") then
            firetouchinterest(hrp, part, 0)
            firetouchinterest(hrp, part, 1)
        end
    end)
    task.wait(Config.StealGap)
    tp(ET.SafeCFrame)
    return true
end

local function stealAll(filter)
    refresh()
    for _, e in ipairs(ET.Eggs) do
        local p = eggPart(e)
        if p and (not filter or p.Name:lower():find(filter:lower(), 1, true)) then
            steal(p)
            task.wait(Config.StealGap)
        end
    end
end

--==================== AUTO REJOIN SAFE ==============================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1); tp(ET.SafeCFrame)
end)

Workspace.DescendantAdded:Connect(function(d)
    if matchAny(d.Name, Config.EggKeys)   and (d:IsA("Model") or d:IsA("BasePart")) then table.insert(ET.Eggs,   d) end
    if matchAny(d.Name, Config.GuardKeys) and (d:IsA("Model") or d:IsA("BasePart")) then table.insert(ET.Guards, d) end
end)

--==================== UI ============================================
local screen = Instance.new("ScreenGui")
screen.Name           = "EggStealUI"
screen.ResetOnSpawn   = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent         = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
pcall(function() if syn and syn.protect_gui then syn.protect_gui(screen) end end)

local frame = Instance.new("Frame")
frame.Size             = UDim2.new(0, 260, 0, 250)
frame.Position         = UDim2.new(0.5, -130, 0.5, -125)
frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
frame.Parent           = screen
local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = frame
local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(235, 195, 60); s.Thickness = 1; s.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32); title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold; title.TextColor3 = Color3.fromRGB(235, 195, 60)
title.Text = "STEAL AN EGG  •  LeakWorm"; title.TextSize = 14; title.Parent = frame

local ddLabel = Instance.new("TextLabel")
ddLabel.Position = UDim2.new(0, 12, 0, 40); ddLabel.Size = UDim2.new(1, -24, 0, 16)
ddLabel.BackgroundTransparency = 1; ddLabel.Font = Enum.Font.Gotham
ddLabel.TextColor3 = Color3.fromRGB(210, 210, 210); ddLabel.TextXAlignment = Enum.TextXAlignment.Left
ddLabel.Text = "Egg:"; ddLabel.TextSize = 12; ddLabel.Parent = frame

local ddButton = Instance.new("TextButton")
ddButton.Position = UDim2.new(0, 12, 0, 58); ddButton.Size = UDim2.new(1, -24, 0, 28)
ddButton.BackgroundColor3 = Color3.fromRGB(38, 38, 46); ddButton.BorderSizePixel = 0
ddButton.Font = Enum.Font.Gotham; ddButton.TextColor3 = Color3.fromRGB(235, 235, 235)
ddButton.Text = "— click to pick egg —"; ddButton.TextSize = 12; ddButton.Parent = frame
local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0, 6); dc.Parent = ddButton

local ddList = Instance.new("ScrollingFrame")
ddList.Position = UDim2.new(0, 12, 0, 88); ddList.Size = UDim2.new(1, -24, 0, 90)
ddList.BackgroundColor3 = Color3.fromRGB(30, 30, 36); ddList.BorderSizePixel = 0
ddList.ScrollBarThickness = 4; ddList.CanvasSize = UDim2.new(0, 0, 0, 0)
ddList.Visible = false; ddList.ClipsDescendants = true; ddList.Parent = frame
local dlc = Instance.new("UICorner"); dlc.CornerRadius = UDim.new(0, 6); dlc.Parent = ddList
local dll = Instance.new("UIListLayout"); dll.Padding = UDim.new(0, 2)
dll.SortOrder = Enum.SortOrder.LayoutOrder; dll.Parent = ddList

local selected = nil
local function rebuild()
    for _, ch in ipairs(ddList:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
    refresh()
    local seen, y = {}, 0
    for _, e in ipairs(ET.Eggs) do
        if not seen[e.Name] then
            seen[e.Name] = true
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -8, 0, 24); b.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
            b.BorderSizePixel = 0; b.Font = Enum.Font.Gotham; b.TextColor3 = Color3.fromRGB(225, 225, 225)
            b.TextSize = 12; b.TextXAlignment = Enum.TextXAlignment.Left; b.Text = "  " .. e.Name
            b.Parent = ddList
            local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = b
            b.MouseButton1Click:Connect(function()
                selected = e.Name; ddButton.Text = "Egg: " .. e.Name; ddList.Visible = false
            end)
            y = y + 26
        end
    end
    ddList.CanvasSize = UDim2.new(0, 0, 0, y + 4)
end

ddButton.MouseButton1Click:Connect(function()
    ddList.Visible = not ddList.Visible
    if ddList.Visible then rebuild() end
end)

local stealBtn = Instance.new("TextButton")
stealBtn.Position = UDim2.new(0, 12, 0, 182); stealBtn.Size = UDim2.new(0, 113, 0, 28)
stealBtn.BackgroundColor3 = Color3.fromRGB(235, 195, 60); stealBtn.BorderSizePixel = 0
stealBtn.Font = Enum.Font.GothamBold; stealBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
stealBtn.Text = "STEAL"; stealBtn.TextSize = 13; stealBtn.Parent = frame
local sbc = Instance.new("UICorner"); sbc.CornerRadius = UDim.new(0, 6); sbc.Parent = stealBtn
stealBtn.MouseButton1Click:Connect(function()
    steal(selected and nearestEgg(selected) or nearestEgg(nil))
end)

local easyBtn = Instance.new("TextButton")
easyBtn.Position = UDim2.new(0, 135, 0, 182); easyBtn.Size = UDim2.new(0, 113, 0, 28)
easyBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 46); easyBtn.BorderSizePixel = 0
easyBtn.Font = Enum.Font.GothamBold; easyBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
easyBtn.Text = "EASY STEAL: OFF"; easyBtn.TextSize = 11; easyBtn.Parent = frame
local ebc = Instance.new("UICorner"); ebc.CornerRadius = UDim.new(0, 6); ebc.Parent = easyBtn
easyBtn.MouseButton1Click:Connect(function()
    ET.EasySteal = not ET.EasySteal
    if ET.EasySteal then
        easyBtn.BackgroundColor3 = Color3.fromRGB(120, 200, 120)
        easyBtn.Text = "EASY STEAL: ON"
        startDreamLock()
    else
        easyBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
        easyBtn.Text = "EASY STEAL: OFF"
        stopDreamLock()
    end
end)

local allBtn = Instance.new("TextButton")
allBtn.Position = UDim2.new(0, 12, 0, 214); allBtn.Size = UDim2.new(1, -24, 0, 24)
allBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 90); allBtn.BorderSizePixel = 0
allBtn.Font = Enum.Font.GothamBold; allBtn.TextColor3 = Color3.fromRGB(220, 220, 255)
allBtn.Text = "STEAL ALL (filtered)"; allBtn.TextSize = 12; allBtn.Parent = frame
local abc = Instance.new("UICorner"); abc.CornerRadius = UDim.new(0, 6); abc.Parent = allBtn
allBtn.MouseButton1Click:Connect(function() stealAll(selected) end)

local x = Instance.new("TextButton")
x.Size = UDim2.new(0, 24, 0, 24); x.Position = UDim2.new(1, -30, 0, 4)
x.BackgroundColor3 = Color3.fromRGB(60, 30, 30); x.BorderSizePixel = 0
x.Font = Enum.Font.GothamBold; x.TextColor3 = Color3.fromRGB(255, 200, 200)
x.Text = "X"; x.TextSize = 13; x.Parent = frame
local xc = Instance.new("UICorner"); xc.CornerRadius = UDim.new(0, 6); xc.Parent = x
x.MouseButton1Click:Connect(function() screen:Destroy() end)

task.spawn(function() task.wait(2); tp(ET.SafeCFrame) end)

print("[LeakWorm] Egg Heist loaded — steal remote:",
    ET.StealRemote and ET.StealRemote.Name or "NOT FOUND",
    "| dream remote:", ET.DreamRemote and ET.DreamRemote.Name or "NOT FOUND",
    "| eggs:", #ET.Eggs, "| guards:", #ET.Guards)
