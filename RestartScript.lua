-- Kiểm tra nếu Script đã được load để tránh chạy nhiều lần
if _G.RESTART_SCRIPT_LOADED then
    warn("RestartScript đã được khởi động!")
    return
end
_G.RESTART_SCRIPT_LOADED = true

-- Services
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- Biến toàn cục
local PlaceId = game.PlaceId
local JobId = game.JobId

-- Kiểm tra và thiết lập các function cần thiết
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

-- ========================================
-- CÀI ĐẶT AUTO RESTART (Chỉnh sửa ở đây)
-- ========================================
local AUTO_RESTART_ENABLED = true -- Đổi thành false nếu muốn tắt Auto Restart
-- ========================================

-- Load Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Tạo Window
local Window = Fluent:CreateWindow({
    Title = "Server Control Panel",
    SubTitle = "Server Hop & Rejoin Tools",
    TabWidth = 160,
    Size = UDim2.fromOffset(420, 300),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.End
})

-- Tạo Tab Main
local MainTab = Window:AddTab({ 
    Title = "Main", 
    Icon = "home" 
})

-- Thông tin Server
MainTab:AddParagraph({
    Title = "Thông tin Server",
    Content = string.format("Place ID: %s\nJob ID: %s\nSố người chơi: %d/%d", 
        tostring(PlaceId), 
        tostring(JobId),
        #Players:GetPlayers(),
        Players.MaxPlayers)
})

-- Button Server Hop (Không có dialog xác nhận)
MainTab:AddButton({
    Title = "Server Hop",
    Description = "Chuyển sang server khác ngẫu nhiên",
    Callback = function()
        -- Tìm server mới ngay lập tức
        local servers = {}
        local success, req = pcall(function()
            return game:HttpGetAsync("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
        end)
        
        if success then
            local body = HttpService:JSONDecode(req)
            
            if body and body.data then
                for i, v in pairs(body.data) do
                    if type(v) == "table" and v.playing and v.maxPlayers and v.playing < v.maxPlayers and v.id ~= JobId then
                        table.insert(servers, v.id)
                    end
                end
            end
            
            if #servers > 0 then
                TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)], Players.LocalPlayer)
            else
                print("Không tìm thấy server phù hợp!")
            end
        else
            print("Lỗi khi lấy danh sách server!")
        end
    end
})

-- Button Rejoin Server (Không có dialog xác nhận)
MainTab:AddButton({
    Title = "Rejoin Server", 
    Description = "Tham gia lại server hiện tại",
    Callback = function()
        -- Rejoin ngay lập tức
        if #Players:GetPlayers() <= 1 then
            Players.LocalPlayer:Kick("\nRejoining...")
            wait()
            TeleportService:Teleport(PlaceId, Players.LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(PlaceId, JobId, Players.LocalPlayer)
        end
    end
})

-- TÍNH NĂNG CHÍNH: Tự động khởi động lại khi teleport
local TeleportCheck = false
Players.LocalPlayer.OnTeleport:Connect(function(State)
    if AUTO_RESTART_ENABLED and (not TeleportCheck) and queueteleport then
        TeleportCheck = true
        -- Queue script để chạy khi vào server mới
        queueteleport([[
            loadstring(game:HttpGet('https://raw.githubusercontent.com/HxB0b/Roblox-Script/refs/heads/main/RestartScript.lua'))()
        ]])
    end
end)

-- Chỉ giữ lại cảnh báo quan trọng về executor không hỗ trợ
if not queueteleport then
    wait(1)
    Fluent:Notify({
        Title = "Cảnh báo",
        Content = "Executor của bạn không hỗ trợ queue_on_teleport!",
        SubContent = "Tính năng Auto Restart sẽ không hoạt động",
        Duration = 5
    })
end
