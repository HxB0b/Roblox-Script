-- API Check
local function API_Check()
    if Drawing == nil then
        return "No"
    else
        return "Yes"
    end
end

local Find_Required = API_Check()

if Find_Required == "No" then
    game:GetService("StarterGui"):SetCore("SendNotification",{
        Title = "Script";
        Text = "Script could not be loaded because your exploit is unsupported.";
        Duration = math.huge;
        Button1 = "OK"
    })
    return
end

-- PLACEID
if game.PlaceId ~= 122874030534085 then return end

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Cam = Workspace.CurrentCamera
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

-- Load Wally UI Library
local library = loadstring(game:HttpGet(('https://raw.githubusercontent.com/bloodball/-back-ups-for-libs/main/wall%20v3')))()
local w = library:CreateWindow("Potato Hell Backrooms") 
local mainTab = w:CreateFolder("Main")

-- Typing detection
local Typing = false

UserInputService.TextBoxFocused:Connect(function()
    Typing = true
end)

UserInputService.TextBoxFocusReleased:Connect(function()
    Typing = false
end)

-- Table of colours to choose from
local colourTable = {
    Green = Color3.fromRGB(0, 255, 0),
    Blue = Color3.fromRGB(0, 0, 255),
    Red = Color3.fromRGB(255, 0, 0),
    Yellow = Color3.fromRGB(255, 255, 0),
    Orange = Color3.fromRGB(255, 165, 0),
    Purple = Color3.fromRGB(128, 0, 128),
    White = Color3.fromRGB(255, 255, 255)
}

-- Rainbow color function
local function getRainbowColor()
    local hue = (tick() * 50) % 360 -- Tốc độ thay đổi màu
    return Color3.fromHSV(hue / 360, 1, 1)
end

-- Danh sách vũ khí
local weaponsList = {
    "AG043", "AK47", "AWP", "D_Eagle", "FN57", "Glock", "KrisVector", 
    "Landmine", "M4A4", "MP5", "P90", "SCORPION", "TEC9", "UZI", "Wbarrel", "BERETTA", "AA12"
}

-- Màu cho từng loại object
local espConfig = {
    ["Players"] = colourTable.White,
    ["Almond Water"] = colourTable.Yellow,
    ["AmmoGiver"] = colourTable.White,
    ["Zombie"] = colourTable.Green,
    ["RareZombie"] = colourTable.Yellow,
    ["EpicZombie"] = colourTable.Orange,
    ["BossZombie"] = colourTable.Red,
    ["fastZombie"] = colourTable.Purple
}

-- Thêm màu cho vũ khí
for _, weapon in pairs(weaponsList) do
    espConfig[weapon] = colourTable.Blue
end

_G.ESPToggle = false
_G.AimbotToggle = false
_G.AutoEvasionToggle = false
_G.PositionESPToggle = false
_G.FullbrightToggle = false

-- Aimbot settings
local fov = 40

-- AutoEvasion settings (Giảm lực đẩy và khoảng cách)
local evadeDistance = 10 -- Giảm từ 17 xuống 15
local evadeForce = 30 -- Giảm từ 75 xuống 50
local maxEvadeVelocity = 40 -- Giảm từ 80 xuống 60

-- Cache variables
local espCache = {}
local zombieCache = {}
local boxEspCache = {}
local highlightedObjects = {}
local nameEspCache = {}
local connections = {}
local lastCacheUpdate = 0
local lastHighlightCheck = 0
local cacheUpdateInterval = 0.5
local highlightCheckInterval = 1

-- Position ESP variables
local positionEspDrawings = {}

-- Buy weapon and collect variables
local isBuyingWeapon = false
local isCollectingAlmondWater = false

-- Drawing helpers
local newVector2, newColor3, newDrawing = Vector2.new, Color3.new, Drawing.new
local tan, rad = math.tan, math.rad
local round = function(...) 
    local a = {}
    for i,v in next, table.pack(...) do 
        a[i] = math.round(v)
    end 
    return unpack(a) 
end
local wtvp = function(...) 
    local a, b = Cam.WorldToViewportPoint(Cam, ...) 
    return newVector2(a.X, a.Y), b, a.Z 
end

-- FOV Ring for Aimbot
local FOVring = Drawing.new("Circle")
FOVring.Visible = false
FOVring.Thickness = 2
FOVring.Color = Color3.fromRGB(128, 0, 128)
FOVring.Filled = false
FOVring.Radius = fov
FOVring.Position = Cam.ViewportSize / 2

-- Fullbright function
local function doFullbright()
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
    Lighting.ColorShift_Top = Color3.new(1, 1, 1)
end

-- Store original lighting values
local originalLighting = {
    Ambient = Lighting.Ambient,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    ColorShift_Top = Lighting.ColorShift_Top
}

-- Fullbright connection
local fullbrightConnection = nil

-- Create Zombie Counter GUI
local zombieCounterGui = Instance.new("ScreenGui")
zombieCounterGui.Name = "ZombieCounter"
zombieCounterGui.ResetOnSpawn = false

local counterFrame = Instance.new("Frame")
counterFrame.Size = UDim2.new(0, 200, 0, 50)
counterFrame.Position = UDim2.new(0.5, -100, 0, 10) -- Đặt giữa màn hình
counterFrame.BackgroundColor3 = Color3.new(1, 1, 1)
counterFrame.BackgroundTransparency = 1 -- Transparent = 1
counterFrame.Parent = zombieCounterGui

local counterLabel = Instance.new("TextLabel")
counterLabel.Size = UDim2.new(1, 0, 1, 0)
counterLabel.BackgroundTransparency = 1
counterLabel.Text = "Zombies: 0"
counterLabel.TextColor3 = Color3.new(1, 1, 1)
counterLabel.TextScaled = true
counterLabel.Font = Enum.Font.SourceSansBold
counterLabel.TextStrokeTransparency = 0 -- Thêm stroke để dễ đọc
counterLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
counterLabel.Parent = counterFrame

pcall(function()
    zombieCounterGui.Parent = CoreGui
end)

-- Update counters
local frameCount = 0
local espUpdateRate = 3
local aimbotUpdateRate = 2

-- Helper function: Kiểm tra xem object có phải là vũ khí không
local function isWeapon(objName)
    for _, weaponName in pairs(weaponsList) do
        if objName == weaponName then
            return true
        end
    end
    return false
end

-- Helper function: Kiểm tra object có trong folder give_weapon không
local function isInGiveWeaponFolder(obj)
    local parent = obj.Parent
    while parent do
        if parent.Name == "give_weapon" and parent.Parent == Workspace then
            return true
        end
        parent = parent.Parent
    end
    return false
end

-- Helper function: Kiểm tra object có trong folder AmmoGiver không
local function isInAmmoGiverFolder(obj)
    local parent = obj.Parent
    while parent do
        if parent.Name == "AmmoGiver" and parent.Parent == Workspace then
            return true
        end
        parent = parent.Parent
    end
    return false
end

-- Function để update zombie count
local function updateZombieCount()
    local count = 0
    local zombieTypes = {
        ["Zombie"] = 0,
        ["RareZombie"] = 0,
        ["EpicZombie"] = 0,
        ["BossZombie"] = 0,
        ["fastZombie"] = 0
    }
    
    for _, zombie in pairs(zombieCache) do
        if zombie and zombie.Parent then
            local humanoid = zombie:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                count = count + 1
                if zombieTypes[zombie.Name] then
                    zombieTypes[zombie.Name] = zombieTypes[zombie.Name] + 1
                end
            end
        end
    end
    
    if count > 0 then
        local detailText = string.format("Zombies: %d\n", count)
        local details = {}
        if zombieTypes["Zombie"] > 0 then
            table.insert(details, string.format("Normal: %d", zombieTypes["Zombie"]))
        end
        if zombieTypes["RareZombie"] > 0 then
            table.insert(details, string.format("Rare: %d", zombieTypes["RareZombie"]))
        end
        if zombieTypes["EpicZombie"] > 0 then
            table.insert(details, string.format("Epic: %d", zombieTypes["EpicZombie"]))
        end
        if zombieTypes["BossZombie"] > 0 then
            table.insert(details, string.format("Boss: %d", zombieTypes["BossZombie"]))
        end
        if zombieTypes["fastZombie"] > 0 then
            table.insert(details, string.format("Fast: %d", zombieTypes["fastZombie"]))
        end
        
        if #details > 0 then
            counterLabel.Text = detailText .. "(" .. table.concat(details, ", ") .. ")"
            counterFrame.Size = UDim2.new(0, 280, 0, 70)
            counterFrame.Position = UDim2.new(0.5, -140, 0, 10) -- Giữ giữa màn hình
        else
            counterLabel.Text = string.format("Zombies: %d", count)
            counterFrame.Size = UDim2.new(0, 200, 0, 50)
            counterFrame.Position = UDim2.new(0.5, -100, 0, 10) -- Giữ giữa màn hình
        end
    else
        counterLabel.Text = "Zombies: 0"
        counterFrame.Size = UDim2.new(0, 200, 0, 50)
        counterFrame.Position = UDim2.new(0.5, -100, 0, 10) -- Giữ giữa màn hình
    end
end

-- Create Box ESP with Health
local function createBoxEsp(name, color)
    local drawings = {}
    
    drawings.box = newDrawing("Square")
    drawings.box.Thickness = 1.4
    drawings.box.Filled = false
    drawings.box.Color = color or colourTable.White
    drawings.box.Visible = false
    drawings.box.ZIndex = 2
    
    drawings.boxoutline = newDrawing("Square")
    drawings.boxoutline.Thickness = 3.4
    drawings.boxoutline.Filled = false
    drawings.boxoutline.Color = newColor3()
    drawings.boxoutline.Visible = false
    drawings.boxoutline.ZIndex = 1
    
    drawings.name = newDrawing("Text")
    drawings.name.Text = name
    drawings.name.Size = 13
    drawings.name.Center = true
    drawings.name.Outline = true
    drawings.name.Color = color or colourTable.White
    drawings.name.Visible = false
    
    -- Thêm health text cho NPC (TĂng size từ 12 lên 18)
    drawings.health = newDrawing("Text")
    drawings.health.Text = ""
    drawings.health.Size = 18  -- Tăng kích thước chữ
    drawings.health.Center = true
    drawings.health.Outline = true
    drawings.health.OutlineColor = Color3.new(0, 0, 0)  -- Thêm outline đen để dễ đọc hơn
    drawings.health.Color = colourTable.White
    drawings.health.Visible = false
    
    return drawings
end

-- Create Name ESP for items using Drawing API
local function createNameEsp(name, color)
    local drawing = newDrawing("Text")
    drawing.Text = name
    drawing.Size = 14
    drawing.Center = true
    drawing.Outline = true
    drawing.Color = color
    drawing.Visible = false
    
    return drawing
end

-- Create Position ESP with Rainbow color (CHỈ POSITION 1 - BACKROOM)
local function createPositionEsp()
    local esp = newDrawing("Text")
    esp.Text = "BackRoom"
    esp.Size = 24  -- Tăng size từ 20 lên 24
    esp.Center = true
    esp.Outline = true
    esp.OutlineColor = Color3.new(0, 0, 0)
    esp.Color = getRainbowColor()
    esp.Visible = false
    esp.Font = Drawing.Fonts.UI  -- Thêm Bold font
    
    positionEspDrawings[1] = esp
end

-- Update Position ESP with Rainbow effect (CHỈ POSITION 1)
local function updatePositionEsp()
    if not _G.PositionESPToggle then
        for _, drawing in pairs(positionEspDrawings) do
            drawing.Visible = false
        end
        return
    end
    
    -- Update rainbow color
    local rainbowColor = getRainbowColor()
    
    -- BackRoom Position (Position 1)
    local pos1 = Vector3.new(186, -6, 116.4)
    local screenPos1, visible1 = Cam:WorldToViewportPoint(pos1)
    if visible1 then
        positionEspDrawings[1].Visible = true
        positionEspDrawings[1].Position = newVector2(screenPos1.X, screenPos1.Y)
        positionEspDrawings[1].Color = rainbowColor
    else
        positionEspDrawings[1].Visible = false
    end
end

-- Initialize Position ESP
createPositionEsp()

-- Update Box ESP
local function updateBoxEsp(obj, drawings, name)
    if not obj or not obj.Parent then
        drawings.box.Visible = false
        drawings.boxoutline.Visible = false
        drawings.name.Visible = false
        drawings.health.Visible = false
        return false
    end
    
    local character = nil
    local humanoidRootPart = nil
    local isNPC = false
    
    if obj:IsA("Player") then
        character = obj.Character
        if character then
            humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        end
    elseif obj:IsA("Model") then
        humanoidRootPart = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
        character = obj
        isNPC = true
        
        local humanoid = obj:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            drawings.box.Visible = false
            drawings.boxoutline.Visible = false
            drawings.name.Visible = false
            drawings.health.Visible = false
            return false
        end
    end
    
    if character and humanoidRootPart then
        local cframe = character:GetModelCFrame()
        local position, visible, depth = wtvp(cframe.Position)
        
        -- Kiểm tra visibility và set tất cả drawings
        local shouldShow = visible and _G.ESPToggle
        
        drawings.box.Visible = shouldShow
        drawings.boxoutline.Visible = shouldShow
        drawings.name.Visible = shouldShow
        
        if shouldShow then
            local scaleFactor = 1 / (depth * tan(rad(Cam.FieldOfView / 2)) * 2) * 1000
            local width, height = round(4 * scaleFactor, 5 * scaleFactor)
            local x, y = round(position.X, position.Y)
            
            drawings.box.Size = newVector2(width, height)
            drawings.box.Position = newVector2(round(x - width / 2, y - height / 2))
            
            drawings.boxoutline.Size = drawings.box.Size
            drawings.boxoutline.Position = drawings.box.Position
            
            drawings.name.Position = newVector2(x, y - height / 2 - 15)
            drawings.name.Text = name
            
            -- Update health cho NPC
            if isNPC then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local healthPercent = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
                    drawings.health.Text = healthPercent .. "%"
                    drawings.health.Position = newVector2(x, y + height / 2 + 5)
                    drawings.health.Visible = shouldShow
                    
                    -- Đổi màu theo % máu
                    if healthPercent > 75 then
                        drawings.health.Color = colourTable.Green
                    elseif healthPercent > 50 then
                        drawings.health.Color = colourTable.Yellow
                    elseif healthPercent > 25 then
                        drawings.health.Color = colourTable.Orange
                    else
                        drawings.health.Color = colourTable.Red
                    end
                else
                    drawings.health.Visible = false
                end
            else
                drawings.health.Visible = false
            end
        else
            drawings.health.Visible = false
        end
    else
        drawings.box.Visible = false
        drawings.boxoutline.Visible = false
        drawings.name.Visible = false
        drawings.health.Visible = false
        return false
    end
    
    return true
end

-- Remove Box ESP
local function removeBoxEsp(key)
    if boxEspCache[key] then
        for _, drawing in pairs(boxEspCache[key]) do
            drawing:Remove()
        end
        boxEspCache[key] = nil
    end
end

-- Remove Name ESP
local function removeNameEsp(key)
    if nameEspCache[key] and nameEspCache[key].drawing then
        nameEspCache[key].drawing:Remove()
        nameEspCache[key] = nil
    end
end

-- Update FOV Ring position
local function updateDrawings()
    local camViewportSize = Cam.ViewportSize
    FOVring.Position = camViewportSize / 2
end

-- Check if player is holding a weapon
local function isHoldingWeapon()
    local character = LocalPlayer.Character
    if not character then return false end
    
    local tool = character:FindFirstChildOfClass("Tool")
    if tool then
        for _, weaponName in pairs(weaponsList) do
            if tool.Name == weaponName then
                return true
            end
        end
    end
    
    return false
end

-- Add highlight to object
local function addHighlight(obj, color, displayName)
    if not obj or not obj.Parent then return end
    
    -- Ngăn ESP hiển thị trên Tool vũ khí trong tay người chơi
    if obj:IsA("Tool") and isWeapon(obj.Name) then
        return
    end
    
    if obj:FindFirstChild("Highlight") then return end
    
    -- Create unique key for this object
    local objKey = tostring(obj:GetDebugId())
    
    -- Xử lý highlight
    local success = pcall(function()
        local highlight = Instance.new("Highlight")
        highlight.Name = "Highlight"
        highlight.Adornee = obj
        highlight.Parent = obj
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = color
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.3
    end)
    
    if success then
        highlightedObjects[obj] = true
        
        -- Tạo Name ESP với Drawing API
        if not nameEspCache[objKey] then
            nameEspCache[objKey] = {
                obj = obj,
                drawing = createNameEsp(displayName or obj.Name, color),
                name = displayName or obj.Name
            }
        end
    end
end

-- Remove highlight from object
local function removeHighlight(obj)
    if not obj or not obj.Parent then return end
    
    local highlight = obj:FindFirstChild("Highlight")
    if highlight then
        highlight:Destroy()
    end
    
    -- Remove name ESP
    local objKey = tostring(obj:GetDebugId())
    removeNameEsp(objKey)
    
    highlightedObjects[obj] = nil
end

-- Update name ESP positions
local function updateNameEspPositions()
    for key, data in pairs(nameEspCache) do
        if data and data.obj and data.obj.Parent and data.drawing then
            local position = nil
            
            if data.obj:IsA("BasePart") or data.obj:IsA("MeshPart") then
                position = data.obj.Position
            elseif data.obj:IsA("Model") then
                local part = data.obj:FindFirstChild("Handle") or data.obj:FindFirstChildWhichIsA("BasePart")
                if part then
                    position = part.Position
                end
            elseif data.obj:IsA("Tool") then
                local handle = data.obj:FindFirstChild("Handle")
                if handle then
                    position = handle.Position
                end
            end
            
            if position then
                local screenPos, visible = Cam:WorldToViewportPoint(position + Vector3.new(0, 2, 0))
                if visible and _G.ESPToggle then
                    data.drawing.Visible = true
                    data.drawing.Position = newVector2(screenPos.X, screenPos.Y)
                else
                    data.drawing.Visible = false
                end
            else
                data.drawing.Visible = false
            end
        elseif data and data.drawing then
            -- Object no longer exists, clean up
            data.drawing:Remove()
            nameEspCache[key] = nil
        end
    end
end

-- Check and refresh highlights
local function checkAndRefreshHighlights()
    if not _G.ESPToggle then return end
    
    local currentTime = tick()
    if currentTime - lastHighlightCheck < highlightCheckInterval then
        return
    end
    lastHighlightCheck = currentTime
    
    for obj, _ in pairs(highlightedObjects) do
        if obj and obj.Parent then
            if obj:IsA("Tool") and isWeapon(obj.Name) then
                removeHighlight(obj)
            elseif not obj:FindFirstChild("Highlight") then
                for _, data in pairs(espCache) do
                    if data.obj == obj then
                        addHighlight(data.obj, espConfig[data.name], data.name)
                        break
                    end
                end
            end
        else
            highlightedObjects[obj] = nil
        end
    end
end

-- Monitor zombie for death/removal
local function monitorZombie(zombie)
    if not zombie or not zombie.Parent then return end
    
    local humanoid = zombie:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local deathConnection = humanoid.Died:Connect(function()
            removeBoxEsp(zombie)
            
            for i, cached in ipairs(zombieCache) do
                if cached == zombie then
                    table.remove(zombieCache, i)
                    break
                end
            end
        end)
        
        if not connections[zombie] then
            connections[zombie] = {}
        end
        table.insert(connections[zombie], deathConnection)
    end
end

-- Update cache periodically
local function updateCache()
    local currentTime = tick()
    if currentTime - lastCacheUpdate < cacheUpdateInterval then
        return
    end
    lastCacheUpdate = currentTime
    
    espCache = {}
    zombieCache = {}
    
    local toRemove = {}
    for key, _ in pairs(boxEspCache) do
        if type(key) ~= "string" then
            if not key or not key.Parent then
                table.insert(toRemove, key)
            end
        end
    end
    
    for _, key in ipairs(toRemove) do
        removeBoxEsp(key)
    end
    
    -- Tìm zombie trong toàn Workspace
    for _, obj in pairs(Workspace:GetDescendants()) do
        local objName = obj.Name
        
        if objName == "Zombie" or objName == "RareZombie" or objName == "EpicZombie" or objName == "BossZombie" or objName == "fastZombie" then
            if obj:IsA("Model") then
                local humanoid = obj:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    table.insert(zombieCache, obj)
                    if not boxEspCache[obj] and _G.ESPToggle then
                        boxEspCache[obj] = createBoxEsp(objName, espConfig[objName])
                        monitorZombie(obj)
                    end
                end
            end
        end
    end
    
    -- Tìm vũ khí chỉ trong folder give_weapon
    local giveWeaponFolder = Workspace:FindFirstChild("give_weapon")
    if giveWeaponFolder and giveWeaponFolder:IsA("Folder") then
        for _, obj in pairs(giveWeaponFolder:GetChildren()) do
            local objName = obj.Name
            if isWeapon(objName) and obj:IsA("Model") then
                table.insert(espCache, {obj = obj, name = objName})
                if _G.ESPToggle and not obj:FindFirstChild("Highlight") then
                    addHighlight(obj, espConfig[objName], objName)
                end
            end
        end
    end
    
    -- Tìm AmmoGiver chỉ trong folder AmmoGiver
    local ammoGiverFolder = Workspace:FindFirstChild("AmmoGiver")
    if ammoGiverFolder and ammoGiverFolder:IsA("Folder") then
        for _, obj in pairs(ammoGiverFolder:GetChildren()) do
            if obj.Name == "AmmoGiver" and (obj:IsA("MeshPart") or obj:IsA("BasePart")) then
                table.insert(espCache, {obj = obj, name = "AmmoGiver"})
                if _G.ESPToggle and not obj:FindFirstChild("Highlight") then
                    addHighlight(obj, espConfig["AmmoGiver"], "AmmoGiver")
                end
            end
        end
    end
    
    -- Tìm Almond Water trực tiếp trong Workspace (Tool)
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj.Name == "Almond Water" and obj:IsA("Tool") then
            table.insert(espCache, {obj = obj, name = "Almond Water"})
            if _G.ESPToggle and not obj:FindFirstChild("Highlight") then
                addHighlight(obj, espConfig["Almond Water"], "Almond Water")
            end
        end
    end
    
    -- Xử lý Players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local key = "Player_" .. player.Name
            if not boxEspCache[key] and _G.ESPToggle and player.Character then
                boxEspCache[key] = createBoxEsp(player.Name, espConfig["Players"])
            end
        end
    end
    
    updateZombieCount()
end

-- Simplified ESP update
local function updateESP()
    if not _G.ESPToggle then
        for _, data in pairs(espCache) do
            if data.obj and data.obj.Parent then
                removeHighlight(data.obj)
            end
        end
        
        highlightedObjects = {}
        
        for key, _ in pairs(boxEspCache) do
            removeBoxEsp(key)
        end
        
        for key, _ in pairs(nameEspCache) do
            removeNameEsp(key)
        end
        return
    end
    
    -- Update highlights cho items
    for _, data in pairs(espCache) do
        if data.obj and data.obj.Parent then
            if not data.obj:FindFirstChild("Highlight") then
                addHighlight(data.obj, espConfig[data.name], data.name)
            end
        end
    end
    
    -- Update name ESP positions
    updateNameEspPositions()
    
    -- Update box ESP cho players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local key = "Player_" .. player.Name
            if boxEspCache[key] then
                local exists = updateBoxEsp(player, boxEspCache[key], player.Name)
                if not exists then
                    removeBoxEsp(key)
                end
            elseif player.Character and _G.ESPToggle then
                boxEspCache[key] = createBoxEsp(player.Name, espConfig["Players"])
            end
        end
    end
    
    -- Update box ESP cho zombies
    local zombiesToRemove = {}
    for zombie, drawings in pairs(boxEspCache) do
        if type(zombie) ~= "string" then
            if zombie and zombie.Parent then
                local exists = updateBoxEsp(zombie, drawings, zombie.Name)
                if not exists then
                    table.insert(zombiesToRemove, zombie)
                end
            else
                table.insert(zombiesToRemove, zombie)
            end
        end
    end
    
    for _, zombie in ipairs(zombiesToRemove) do
        removeBoxEsp(zombie)
        
        if connections[zombie] then
            for _, conn in ipairs(connections[zombie]) do
                conn:Disconnect()
            end
            connections[zombie] = nil
        end
    end
    
    checkAndRefreshHighlights()
end

-- Aimbot function
local function lookAt(target)
    local lookVector = (target - Cam.CFrame.Position).unit
    local newCFrame = CFrame.new(Cam.CFrame.Position, Cam.CFrame.Position + lookVector)
    Cam.CFrame = newCFrame
end

-- Get closest zombie from cache (ĐỔI TỪ HEAD SANG TORSO)
local function getClosestZombie()
    if not isHoldingWeapon() then return nil end
    
    local nearest = nil
    local lastDistance = math.huge
    local screenCenter = Cam.ViewportSize / 2
    
    for _, zombie in pairs(zombieCache) do
        if zombie and zombie.Parent then
            local humanoid = zombie:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                -- Ưu tiên Torso trước, nếu không có mới dùng HumanoidRootPart
                local targetPart = zombie:FindFirstChild("Torso") or zombie:FindFirstChild("UpperTorso") or zombie:FindFirstChild("HumanoidRootPart")
                
                if targetPart then
                    local pos, onScreen = Cam:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local distance = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                        
                        if distance < fov and distance < lastDistance then
                            lastDistance = distance
                            nearest = targetPart
                        end
                    end
                end
            end
        end
    end
    
    return nearest
end

-- AutoEvasion function (ĐÃ GIẢM LỰC ĐẨY)
local function performAutoEvasion()
    if not _G.AutoEvasionToggle then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoidRootPart or not humanoid then return end
    
    local totalForce = Vector3.zero
    local zombiesNearby = 0
    
    for _, zombie in pairs(zombieCache) do
        if zombie and zombie.Parent then
            local zombieHRP = zombie:FindFirstChild("HumanoidRootPart") or zombie:FindFirstChild("Torso")
            if zombieHRP then
                local distance = (zombieHRP.Position - humanoidRootPart.Position).Magnitude
                
                if distance < evadeDistance then
                    local direction = (humanoidRootPart.Position - zombieHRP.Position).Unit
                    totalForce = totalForce + (direction * evadeForce)
                    zombiesNearby = zombiesNearby + 1
                end
            end
        end
    end
    
    if zombiesNearby > 0 then
        local finalVelocity = totalForce / zombiesNearby
        if finalVelocity.Magnitude > maxEvadeVelocity then
            finalVelocity = finalVelocity.Unit * maxEvadeVelocity
        end
        
        humanoidRootPart.Velocity = humanoidRootPart.Velocity + finalVelocity
    end
end

-- Teleport Functions
local function teleportToPosition(cframe)
    local character = LocalPlayer.Character
    if character then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            humanoidRootPart.CFrame = cframe
        end
    end
end

-- Buy Weapon Functions (ĐÃ SỬA ĐỂ TÌM PART THAY VÌ MODEL)
local function buyWeapon(weaponName, giverName)
    if isBuyingWeapon then
        StarterGui:SetCore("SendNotification",{
            Title = "Buy Weapon";
            Text = "Already buying a weapon!";
            Duration = 3;
        })
        return
    end
    
    isBuyingWeapon = true
    
    -- Save current position
    local character = LocalPlayer.Character
    if not character then 
        isBuyingWeapon = false
        return 
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        isBuyingWeapon = false
        return 
    end
    
    local savedPosition = humanoidRootPart.CFrame
    
    -- Find weapon giver
    local giveWeaponFolder = Workspace:FindFirstChild("give_weapon")
    if not giveWeaponFolder then
        StarterGui:SetCore("SendNotification",{
            Title = "Buy Weapon";
            Text = "Weapon shop not found!";
            Duration = 3;
        })
        isBuyingWeapon = false
        return
    end
    
    -- TÌM PART THAY VÌ MODEL
    local weaponGiver = nil
    for _, obj in pairs(giveWeaponFolder:GetChildren()) do
        if obj.Name == giverName and obj:IsA("Part") then
            weaponGiver = obj
            break
        end
    end
    
    if not weaponGiver then
        StarterGui:SetCore("SendNotification",{
            Title = "Buy Weapon";
            Text = weaponName .. " giver not found!";
            Duration = 3;
        })
        isBuyingWeapon = false
        return
    end
    
    -- Teleport to weapon giver
    humanoidRootPart.CFrame = weaponGiver.CFrame + Vector3.new(0, 3, 0)
    
    spawn(function()
        wait(0.5)
        
        -- Fire proximity prompt
        local proximityPrompt = weaponGiver:FindFirstChildOfClass("ProximityPrompt")
        if proximityPrompt then
            fireproximityprompt(proximityPrompt)
        end
        
        -- Wait to check if weapon was bought
        wait(2)
        
        -- Check backpack
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local weaponBought = false
        
        if backpack then
            if backpack:FindFirstChild(weaponName) then
                weaponBought = true
            end
        end
        
        -- Check character (in case weapon is equipped)
        if character:FindFirstChild(weaponName) then
            weaponBought = true
        end
        
        -- Return to saved position
        humanoidRootPart.CFrame = savedPosition
        
        if weaponBought then
            StarterGui:SetCore("SendNotification",{
                Title = "Buy Weapon";
                Text = "Successfully bought " .. weaponName .. "!";
                Duration = 3;
            })
        else
            StarterGui:SetCore("SendNotification",{
                Title = "Buy Weapon";
                Text = "Failed to buy " .. weaponName;
                Duration = 3;
            })
        end
        
        isBuyingWeapon = false
    end)
end

-- UI TOGGLES
-- ESP Toggle
mainTab:Toggle("ESP",function(bool)
    _G.ESPToggle = bool
    lastCacheUpdate = 0
    lastHighlightCheck = 0
    
    if _G.ESPToggle then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local key = "Player_" .. player.Name
                if not boxEspCache[key] then
                    boxEspCache[key] = createBoxEsp(player.Name, espConfig["Players"])
                end
            end
        end
        
        StarterGui:SetCore("SendNotification",{
            Title = "ESP";
            Text = "ESP has been enabled!";
            Duration = 3;
        })
    else
        StarterGui:SetCore("SendNotification",{
            Title = "ESP";
            Text = "ESP has been disabled!";
            Duration = 3;
        })
    end
end)

-- Aimbot Toggle
mainTab:Toggle("Aimbot",function(bool)
    _G.AimbotToggle = bool
    
    if _G.AimbotToggle then
        StarterGui:SetCore("SendNotification",{
            Title = "Aimbot";
            Text = "Aimbot has been enabled!";
            Duration = 3;
        })
    else
        StarterGui:SetCore("SendNotification",{
            Title = "Aimbot";
            Text = "Aimbot has been disabled!";
            Duration = 3;
        })
    end
end)

-- Auto Evasion Toggle
mainTab:Toggle("Auto Evasion",function(bool)
    _G.AutoEvasionToggle = bool
    
    if _G.AutoEvasionToggle then
        StarterGui:SetCore("SendNotification",{
            Title = "AutoEvasion";
            Text = "AutoEvasion has been enabled!";
            Duration = 3;
        })
    else
        StarterGui:SetCore("SendNotification",{
            Title = "AutoEvasion";
            Text = "AutoEvasion has been disabled!";
            Duration = 3;
        })
    end
end)

-- Position ESP Toggle
mainTab:Toggle("BackRoom ESP",function(bool)
    _G.PositionESPToggle = bool
    
    if _G.PositionESPToggle then
        StarterGui:SetCore("SendNotification",{
            Title = "BackRoom ESP";
            Text = "BackRoom ESP has been enabled!";
            Duration = 3;
        })
    else
        StarterGui:SetCore("SendNotification",{
            Title = "BackRoom ESP";
            Text = "BackRoom ESP has been disabled!";
            Duration = 3;
        })
    end
end)

-- Fullbright Toggle
mainTab:Toggle("Fullbright",function(bool)
    _G.FullbrightToggle = bool
    
    if _G.FullbrightToggle then
        doFullbright()
        fullbrightConnection = Lighting.LightingChanged:Connect(doFullbright)
        
        StarterGui:SetCore("SendNotification",{
            Title = "Fullbright";
            Text = "Fullbright has been enabled!";
            Duration = 3;
        })
    else
        -- Restore original lighting
        Lighting.Ambient = originalLighting.Ambient
        Lighting.ColorShift_Bottom = originalLighting.ColorShift_Bottom
        Lighting.ColorShift_Top = originalLighting.ColorShift_Top
        
        if fullbrightConnection then
            fullbrightConnection:Disconnect()
            fullbrightConnection = nil
        end
        
        StarterGui:SetCore("SendNotification",{
            Title = "Fullbright";
            Text = "Fullbright has been disabled!";
            Duration = 3;
        })
    end
end)

-- Teleport Buttons
mainTab:Button("TP to Starter", function()
    teleportToPosition(CFrame.new(49, -3, -115))
    StarterGui:SetCore("SendNotification",{
        Title = "Teleport";
        Text = "Teleported to Starter!";
        Duration = 3;
    })
end)

mainTab:Button("TP to BackRoom", function()
    teleportToPosition(CFrame.new(193, -3, 338.4))
    StarterGui:SetCore("SendNotification",{
        Title = "Teleport";
        Text = "Teleported to BackRoom!";
        Duration = 3;
    })
end)

-- Auto Collect Food
mainTab:Button("Auto Collect Food", function()
    if isCollectingAlmondWater then
        StarterGui:SetCore("SendNotification",{
            Title = "Auto Collect";
            Text = "Already collecting Food!";
            Duration = 3;
        })
        return
    end
    
    isCollectingAlmondWater = true
    
    -- Save current position
    local character = LocalPlayer.Character
    if not character then 
        isCollectingAlmondWater = false
        return 
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        isCollectingAlmondWater = false
        return 
    end
    
    local savedPosition = humanoidRootPart.CFrame
    local almondWaters = {}
    
    -- Find all Almond Water
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj.Name == "Almond Water" and obj:IsA("Tool") then
            table.insert(almondWaters, obj)
        end
    end
    
    if #almondWaters == 0 then
        StarterGui:SetCore("SendNotification",{
            Title = "Auto Collect";
            Text = "No Almond Water found!";
            Duration = 3;
        })
        isCollectingAlmondWater = false
        return
    end
    
    -- Collect all Almond Water
    spawn(function()
        for _, almondWater in pairs(almondWaters) do
            if almondWater and almondWater.Parent then
                local handle = almondWater:FindFirstChild("Handle")
                if handle then
                    humanoidRootPart.CFrame = handle.CFrame
                    wait(1) -- Wait 1 second between teleports
                end
            end
        end
        
        -- Return to saved position
        wait(0.5)
        humanoidRootPart.CFrame = savedPosition
        
        StarterGui:SetCore("SendNotification",{
            Title = "Auto Collect";
            Text = "Collected all Almond Water!";
            Duration = 3;
        })
        
        isCollectingAlmondWater = false
    end)
end)

-- Buy Weapon Buttons
mainTab:Button("Buy FN57", function()
    buyWeapon("FN57", "FN57Giver")
end)

mainTab:Button("Buy P90", function()
    buyWeapon("P90", "P90Giver")
end)

mainTab:Button("Buy AA12", function()
    buyWeapon("AA12", "AA12Giver")
end)

-- Credits
mainTab:Label("By HxBob",{
    TextSize = 20;
    TextColor = getRainbowColor();
    BgColor = Color3.fromRGB(38,38,38);
})

-- Main render loop
RunService.Heartbeat:Connect(function()
    frameCount = frameCount + 1
    
    updateCache()
    
    if frameCount % espUpdateRate == 0 then
        updateESP()
    end
    
    -- Update Position ESP
    updatePositionEsp()
    
    -- Auto Evasion
    performAutoEvasion()
    
    if _G.AimbotToggle and frameCount % aimbotUpdateRate == 0 then
        if isHoldingWeapon() then
            FOVring.Visible = true
            updateDrawings()
            
            local target = getClosestZombie()
            if target then
                lookAt(target.Position)
            end
        else
            FOVring.Visible = false
        end
    elseif not _G.AimbotToggle then
        FOVring.Visible = false
    end
end)

-- Handle player connections
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function()
            wait(0.1)
            local key = "Player_" .. player.Name
            if _G.ESPToggle and not boxEspCache[key] then
                boxEspCache[key] = createBoxEsp(player.Name, espConfig["Players"])
            end
        end)
        
        player.CharacterRemoving:Connect(function()
            local key = "Player_" .. player.Name
            removeBoxEsp(key)
        end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local key = "Player_" .. player.Name
    removeBoxEsp(key)
end)

-- Handle new objects
Workspace.DescendantAdded:Connect(function(descendant)
    local objName = descendant.Name
    
    if objName == "Zombie" or objName == "RareZombie" or objName == "EpicZombie" or objName == "BossZombie" or objName == "fastZombie" then
        wait(0.1)
        if descendant:IsA("Model") and not boxEspCache[descendant] then
            local humanoid = descendant:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                if _G.ESPToggle then
                    boxEspCache[descendant] = createBoxEsp(objName, espConfig[objName])
                end
                monitorZombie(descendant)
                table.insert(zombieCache, descendant)
            end
        end
    elseif isWeapon(objName) and isInGiveWeaponFolder(descendant) and descendant:IsA("Model") then
        wait(0.1)
        table.insert(espCache, {obj = descendant, name = objName})
        if _G.ESPToggle then
            addHighlight(descendant, espConfig[objName], objName)
        end
    elseif objName == "AmmoGiver" and isInAmmoGiverFolder(descendant) and (descendant:IsA("MeshPart") or descendant:IsA("BasePart")) then
        wait(0.1)
        table.insert(espCache, {obj = descendant, name = objName})
        if _G.ESPToggle then
            addHighlight(descendant, espConfig[objName], "AmmoGiver")
        end
    elseif objName == "Almond Water" and descendant:IsA("Tool") and descendant.Parent == Workspace then
        wait(0.1)
        table.insert(espCache, {obj = descendant, name = objName})
        if _G.ESPToggle then
            addHighlight(descendant, espConfig[objName], "Almond Water")
        end
    end
end)

-- Handle object removal
Workspace.DescendantRemoving:Connect(function(descendant)
    if boxEspCache[descendant] then
        removeBoxEsp(descendant)
    end
    
    removeHighlight(descendant)
    
    if connections[descendant] then
        for _, conn in ipairs(connections[descendant]) do
            conn:Disconnect()
        end
        connections[descendant] = nil
    end
    
    for i, cached in ipairs(zombieCache) do
        if cached == descendant then
            table.remove(zombieCache, i)
            break
        end
    end
    
    for i, data in ipairs(espCache) do
        if data.obj == descendant then
            table.remove(espCache, i)
            break
        end
    end
end)

-- Show success notification
StarterGui:SetCore("SendNotification",{
    Title = "Script";
    Text = "Script has successfully loaded!";
    Duration = 5;
})
