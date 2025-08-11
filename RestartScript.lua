-- RestartScript với tính năng tự động khởi động lại
-- Version: Optimized (Removed unnecessary features)

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
local writefile = writefile or (syn and syn.writefile)
local readfile = readfile or (syn and syn.readfile)
local isfile = isfile or (readfile and function(file)
    local success = pcall(readfile, file)
    return success
end)

-- Tên file lưu cài đặt
local SETTINGS_FILE = "RestartScript_Settings.json"

-- Cài đặt mặc định
local Settings = {
    AutoRestart = true -- Mặc định bật tính năng tự động khởi động lại
}

-- Function lưu cài đặt
local function SaveSettings()
    if writefile then
        local success, err = pcall(function()
            writefile(SETTINGS_FILE, HttpService:JSONEncode(Settings))
        end)
        if not success then
            warn("Không thể lưu cài đặt:", err)
        end
    end
end

-- Function đọc cài đặt
local function LoadSettings()
    if readfile and isfile and isfile(SETTINGS_FILE) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(SETTINGS_FILE))
        end)
        if success and data then
            Settings = data
        end
    end
end

-- Load cài đặt khi khởi động
LoadSettings()

-- Load Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Tạo Window
local Window = Fluent:CreateWindow({
    Title = "Auto Restart Script",
    SubTitle = "Server Hop & Rejoin với Auto Restart",
    TabWidth = 160,
    Size = UDim2.fromOffset(480, 320),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- Tạo Tab Main
local MainTab = Window:AddTab({ 
    Title = "Main", 
    Icon = "home" 
})

-- Toggle Auto Restart
local AutoRestartToggle = MainTab:AddToggle("AutoRestart", {
    Title = "Auto Restart Script",
    Description = "Tự động khởi động lại Script khi teleport",
    Default = Settings.AutoRestart
})

AutoRestartToggle:OnChanged(function()
    Settings.AutoRestart = Fluent.Options.AutoRestart.Value
    SaveSettings()
    
    if Settings.AutoRestart then
        Fluent:Notify({
            Title = "Auto Restart",
            Content = "Đã BẬT tính năng tự động khởi động lại",
            SubContent = "Script sẽ tự động chạy khi bạn đổi server",
            Duration = 3
        })
    else
        Fluent:Notify({
            Title = "Auto Restart", 
            Content = "Đã TẮT tính năng tự động khởi động lại",
            Duration = 3
        })
    end
end)

-- Spacing
MainTab:AddParagraph({
    Title = "",
    Content = ""
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

-- Spacing
MainTab:AddParagraph({
    Title = "",
    Content = ""
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

-- TÍNH NĂNG CHÍNH: Tự động khởi động lại khi teleport
local TeleportCheck = false
Players.LocalPlayer.OnTeleport:Connect(function(State)
    if Settings.AutoRestart and (not TeleportCheck) and queueteleport then
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

-- Select tab đầu tiên
Window:SelectTab(1)

-- Thông báo khởi động thành công
Fluent:Notify({
    Title = "Khởi động thành công!",
    Content = "RestartScript đã sẵn sàng",
    SubContent = Settings.AutoRestart and "Auto Restart: BẬT" or "Auto Restart: TẮT",
    Duration = 3
})
