-- RestartScript với tính năng tự động khởi động lại
-- Tương tự Infinite Yield FE V6 nhưng sử dụng Fluent UI Library

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

-- =====================================================
-- CÀI ĐẶT AUTO RESTART (Thay đổi true/false ở đây)
-- =====================================================
local AUTO_RESTART_ENABLED = true  -- Đổi thành false nếu muốn tắt Auto Restart
-- =====================================================

-- Kiểm tra và thiết lập các function cần thiết
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

-- Load Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Tạo Window
local Window = Fluent:CreateWindow({
    Title = "Auto Restart Script",
    SubTitle = "Server Hop & Rejoin",
    TabWidth = 160,
    Size = UDim2.fromOffset(380, 250),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- Tạo Tab Main
local MainTab = Window:AddTab({ 
    Title = "Main", 
    Icon = "home" 
})

-- Button Server Hop
MainTab:AddButton({
    Title = "Server Hop",
    Description = "Chuyển sang server khác ngẫu nhiên",
    Callback = function()
        -- Hiển thị dialog xác nhận
        Window:Dialog({
            Title = "Xác nhận Server Hop",
            Content = "Bạn có chắc muốn chuyển sang server khác?",
            Buttons = {
                {
                    Title = "Đồng ý",
                    Callback = function()
                        Fluent:Notify({
                            Title = "Server Hop",
                            Content = "Đang tìm server mới...",
                            Duration = 2
                        })
                        
                        -- Tìm server mới
                        local servers = {}
                        local req = game:HttpGetAsync("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
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
                            Fluent:Notify({
                                Title = "Lỗi",
                                Content = "Không tìm thấy server phù hợp!",
                                Duration = 3
                            })
                        end
                    end
                },
                {
                    Title = "Hủy",
                    Callback = function()
                        print("Đã hủy Server Hop")
                    end
                }
            }
        })
    end
})

-- Button Rejoin Server
MainTab:AddButton({
    Title = "Rejoin Server", 
    Description = "Tham gia lại server hiện tại",
    Callback = function()
        -- Hiển thị dialog xác nhận
        Window:Dialog({
            Title = "Xác nhận Rejoin",
            Content = "Bạn có chắc muốn rejoin server này?",
            Buttons = {
                {
                    Title = "Đồng ý",
                    Callback = function()
                        Fluent:Notify({
                            Title = "Rejoin",
                            Content = "Đang rejoin server...",
                            Duration = 2
                        })
                        
                        -- Rejoin logic
                        if #Players:GetPlayers() <= 1 then
                            Players.LocalPlayer:Kick("\nRejoining...")
                            wait()
                            TeleportService:Teleport(PlaceId, Players.LocalPlayer)
                        else
                            TeleportService:TeleportToPlaceInstance(PlaceId, JobId, Players.LocalPlayer)
                        end
                    end
                },
                {
                    Title = "Hủy", 
                    Callback = function()
                        print("Đã hủy Rejoin")
                    end
                }
            }
        })
    end
})

-- TÍNH NĂNG CHÍNH: Tự động khởi động lại khi teleport
local TeleportCheck = false
Players.LocalPlayer.OnTeleport:Connect(function(State)
    if AUTO_RESTART_ENABLED and (not TeleportCheck) and queueteleport then
        TeleportCheck = true
        -- Queue script để chạy khi vào server mới
        -- Link này trỏ đến chính script này trên GitHub của bạn
        queueteleport([[
            loadstring(game:HttpGet('https://raw.githubusercontent.com/HxB0b/Roblox-Script/refs/heads/main/RestartScript.lua'))()
        ]])
    end
end)

-- Kiểm tra executor support
if not queueteleport then
    wait(1)
    Fluent:Notify({
        Title = "Cảnh báo",
        Content = "Executor của bạn không hỗ trợ queue_on_teleport!",
        SubContent = "Tính năng Auto Restart sẽ không hoạt động",
        Duration = 5
    })
end

-- Select tab mặc định
Window:SelectTab(1)

-- Thông báo khởi động thành công
Fluent:Notify({
    Title = "Khởi động thành công!",
    Content = "RestartScript đã sẵn sàng",
    SubContent = AUTO_RESTART_ENABLED and "Auto Restart: BẬT" or "Auto Restart: TẮT",
    Duration = 3
})

print("RestartScript loaded successfully!")
print("Auto Restart Status:", AUTO_RESTART_ENABLED)
