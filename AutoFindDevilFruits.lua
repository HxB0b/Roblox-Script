-- Auto Find Devil Fruits Script
-- Version: 1.0
-- Không sử dụng giao diện, chỉ hoạt động tự động với thông báo

-- Kiểm tra để tránh chạy nhiều lần
if _G.AUTO_FIND_FRUITS_LOADED then
    return
end
_G.AUTO_FIND_FRUITS_LOADED = true

-- Services
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Variables
local Player = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

-- Load Notification System
local NotificationHolder = loadstring(game:HttpGet("https://raw.githubusercontent.com/BocusLuke/UI/main/STX/Module.Lua"))()
local Notification = loadstring(game:HttpGet("https://raw.githubusercontent.com/BocusLuke/UI/main/STX/Client.Lua"))()

-- Queue on teleport function check
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

-- Script Settings
_G.AutoFindFruitsEnabled = true
_G.CurrentTween = nil
_G.FoundFruits = {}
_G.IsSearching = false
_G.HasJoinedGame = false

-- Thông báo khởi động thành công
Notification:Notify(
    {Title = "Start Up", Description = "Script Loaded Successfully!!"},
    {OutlineColor = Color3.fromRGB(80, 80, 80), Time = 5, Type = "image"},
    {Image = "http://www.roblox.com/asset/?id=6023426923", ImageColor = Color3.fromRGB(255, 84, 84)}
)

-- Function để tham gia game (chọn team Pirates)
local function JoinGame()
    if not _G.HasJoinedGame then
        local args = {
            [1] = "SetTeam",
            [2] = "Pirates"
        }
        pcall(function()
            ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(args))
        end)
        _G.HasJoinedGame = true
        wait(2) -- Đợi team được set
    end
end

-- Function Tween (teleport đến vị trí)
local function TweenToFruit(targetCFrame)
    local Character = Player.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local HumanoidRootPart = Character.HumanoidRootPart
    local Distance = (targetCFrame.Position - HumanoidRootPart.Position).Magnitude
    local Speed = 350 -- Tốc độ di chuyển
    
    -- Cancel tween cũ nếu có
    if _G.CurrentTween then
        _G.CurrentTween:Cancel()
        _G.CurrentTween = nil
    end
    
    -- Tạo part để di chuyển smooth
    if not Character:FindFirstChild("PartTele") then
        local PartTele = Instance.new("Part", Character)
        PartTele.Size = Vector3.new(10, 1, 10)
        PartTele.Name = "PartTele"
        PartTele.Anchored = true
        PartTele.Transparency = 1
        PartTele.CanCollide = true
        PartTele.CFrame = HumanoidRootPart.CFrame
        
        PartTele:GetPropertyChangedSignal("CFrame"):Connect(function()
            task.wait()
            if Character and Character:FindFirstChild("HumanoidRootPart") then
                HumanoidRootPart.CFrame = PartTele.CFrame
            end
        end)
    end
    
    -- Tạo tween animation
    local tween = TweenService:Create(
        Character.PartTele,
        TweenInfo.new(Distance/Speed, Enum.EasingStyle.Linear),
        {CFrame = targetCFrame}
    )
    
    _G.CurrentTween = tween
    tween:Play()
    
    local completed = false
    tween.Completed:Connect(function(state)
        if state == Enum.PlaybackState.Completed then
            completed = true
            if Character:FindFirstChild("PartTele") then
                Character.PartTele:Destroy()
            end
            _G.CurrentTween = nil
        end
    end)
    
    -- Đợi tween hoàn thành
    local timeout = 0
    while not completed and timeout < (Distance/Speed + 5) do
        wait(0.1)
        timeout = timeout + 0.1
    end
    
    return completed
end

-- Function Server Hop với auto restart
local function ServerHop()
    local PlaceID = game.PlaceId
    local AllIDs = {}
    local foundAnything = ""
    local actualHour = os.date("!*t").hour
    
    local function TPReturner()
        local Site
        if foundAnything == "" then
            Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'))
        else
            Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
        end
        
        local ID = ""
        if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
            foundAnything = Site.nextPageCursor
        end
        
        local num = 0
        for i, v in pairs(Site.data) do
            local Possible = true
            ID = tostring(v.id)
            
            if tonumber(v.maxPlayers) > tonumber(v.playing) then
                for _, Existing in pairs(AllIDs) do
                    if num ~= 0 then
                        if ID == tostring(Existing) then
                            Possible = false
                        end
                    else
                        if tonumber(actualHour) ~= tonumber(Existing) then
                            local delFile = pcall(function()
                                AllIDs = {}
                                table.insert(AllIDs, actualHour)
                            end)
                        end
                    end
                    num = num + 1
                end
                
                if Possible == true then
                    table.insert(AllIDs, ID)
                    wait()
                    pcall(function()
                        wait()
                        -- Queue script để tự khởi động lại khi vào server mới
                        if queueteleport then
                            queueteleport([[
                                loadstring(game:HttpGet(']] .. "https://raw.githubusercontent.com/YourUsername/YourRepo/main/AutoFindDevilFruits.lua" .. [['))()
                            ]])
                        end
                        TeleportService:TeleportToPlaceInstance(PlaceID, ID, Players.LocalPlayer)
                    end)
                    wait(4) -- Chờ teleport
                    break
                end
            end
        end
    end
    
    local function Teleport()
        while wait() do
            pcall(function()
                TPReturner()
                if foundAnything ~= "" then
                    TPReturner()
                end
            end)
        end
    end
    
    Teleport()
end

-- Function quét Devil Fruits (tham khảo từ ESP Devil Fruits)
local function ScanForDevilFruits()
    local fruits = {}
    for i, v in pairs(game.Workspace:GetChildren()) do
        if v:IsA("Model") and string.find(v.Name, "Fruit") then
            if v:FindFirstChild("Handle") then
                table.insert(fruits, {
                    Name = v.Name,
                    CFrame = v.Handle.CFrame,
                    Object = v
                })
            end
        end
    end
    return fruits
end

-- Function xử lý khi tìm thấy Devil Fruit
local function ProcessFoundFruit(fruitData)
    -- Thông báo tìm thấy
    Notification:Notify(
        {Title = "Find", Description = fruitData.Name .. " Found"},
        {OutlineColor = Color3.fromRGB(80, 80, 80), Time = 5, Type = "image"},
        {Image = "http://www.roblox.com/asset/?id=6023426923", ImageColor = Color3.fromRGB(255, 84, 84)}
    )
    
    -- Tham gia game nếu chưa
    JoinGame()
    
    -- Teleport đến Devil Fruit
    wait(1)
    local success = TweenToFruit(fruitData.CFrame)
    
    if success then
        -- Đợi người chơi nhặt fruit
        wait(2)
        
        -- Kiểm tra xem fruit còn tồn tại không
        if fruitData.Object and fruitData.Object.Parent then
            -- Fruit vẫn còn, có thể người chơi chưa nhặt
            wait(3)
        end
    end
    
    return success
end

-- Function hỏi người dùng về Server Hop
local function AskServerHop(reason)
    local description = reason or "Do you want to change server?"
    
    Notification:Notify(
        {Title = "Server", Description = description},
        {OutlineColor = Color3.fromRGB(80, 80, 80), Time = 10, Type = "option"},
        {Image = "http://www.roblox.com/asset/?id=6023426923", ImageColor = Color3.fromRGB(255, 84, 84), 
         Callback = function(State)
            if State then
                -- Người dùng chọn "Có" - Server Hop
                ServerHop()
            else
                -- Người dùng chọn "Không" - Tiếp tục quét
                wait(5)
                _G.IsSearching = false -- Reset để quét lại
            end
         end}
    )
end

-- Main Loop - Quét và xử lý Devil Fruits
spawn(function()
    wait(3) -- Đợi script load hoàn toàn
    
    while _G.AutoFindFruitsEnabled do
        if not _G.IsSearching then
            _G.IsSearching = true
            
            -- Quét Devil Fruits
            local fruits = ScanForDevilFruits()
            
            if #fruits > 0 then
                -- Tìm thấy Devil Fruits
                for _, fruitData in pairs(fruits) do
                    -- Kiểm tra xem đã xử lý fruit này chưa
                    local alreadyProcessed = false
                    for _, processedName in pairs(_G.FoundFruits) do
                        if processedName == fruitData.Name then
                            alreadyProcessed = true
                            break
                        end
                    end
                    
                    if not alreadyProcessed then
                        table.insert(_G.FoundFruits, fruitData.Name)
                        local success = ProcessFoundFruit(fruitData)
                        
                        if success then
                            -- Đợi 5 giây sau khi teleport
                            wait(5)
                            
                            -- Quét lại xem còn Devil Fruits không
                            local newFruits = ScanForDevilFruits()
                            local hasNewFruits = false
                            
                            for _, newFruit in pairs(newFruits) do
                                local isNew = true
                                for _, foundName in pairs(_G.FoundFruits) do
                                    if foundName == newFruit.Name then
                                        isNew = false
                                        break
                                    end
                                end
                                if isNew then
                                    hasNewFruits = true
                                    break
                                end
                            end
                            
                            if not hasNewFruits then
                                -- Không còn Devil Fruits mới
                                AskServerHop("No more Devil Fruits found. Do you want to change server?")
                                _G.IsSearching = false
                                break
                            end
                        end
                    end
                end
            else
                -- Không tìm thấy Devil Fruits ngay từ đầu
                wait(5) -- Đợi 5 giây để chắc chắn
                
                -- Quét lại lần nữa
                fruits = ScanForDevilFruits()
                if #fruits == 0 then
                    -- Vẫn không tìm thấy
                    AskServerHop("No Devil Fruits found in this server. Do you want to change server?")
                    _G.IsSearching = false
                end
            end
        end
        
        wait(2) -- Đợi trước khi quét tiếp
    end
end)

-- Auto restart khi teleport (cho các executor hỗ trợ)
if queueteleport then
    Players.LocalPlayer.OnTeleport:Connect(function(State)
        if State == Enum.TeleportState.Started then
            queueteleport([[
                wait(5) -- Đợi game load
                loadstring(game:HttpGet(']] .. "https://raw.githubusercontent.com/YourUsername/YourRepo/main/AutoFindDevilFruits.lua" .. [['))()
            ]])
        end
    end)
end

-- Anti AFK
game:GetService("Players").LocalPlayer.Idled:connect(function()
    game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    wait()
    game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)
