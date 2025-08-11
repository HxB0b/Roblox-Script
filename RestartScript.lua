-- RestartScript với tính năng tự động khởi động lại
-- Version: Fixed & Stable

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
local RunService = game:GetService("RunService")

-- Đợi LocalPlayer load hoàn toàn
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

-- Đợi Character load (quan trọng để tránh lỗi)
if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
    wait(0.5) -- Thêm delay để đảm bảo mọi thứ load xong
end

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
    AutoRestart = true
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

-- Cleanup function trước khi teleport
local function CleanupBeforeTeleport()
    -- Destroy old GUI if exists
    if _G.FluentGui then
        pcall(function()
            _G.FluentGui:Destroy()
        end)
        _G.FluentGui = nil
    end
    
    -- Clear connections
    if _G.RestartConnections then
        for _, connection in pairs(_G.RestartConnections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        _G.RestartConnections = nil
    end
end

-- Load Fluent UI Library với error handling
local Fluent
local success, err = pcall(function()
    Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not success then
    warn("Không thể load Fluent UI:", err)
    return
end

-- Đợi một chút trước khi tạo GUI
wait(0.5)

-- Tạo Window với error handling
local Window
success, err = pcall(function()
    Window = Fluent:CreateWindow({
        Title = "Auto Restart Script",
        SubTitle = "Server Hop & Rejoin với Auto Restart",
        TabWidth = 160,
        Size = UDim2.fromOffset(480, 320),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.RightControl
    })
end)

if not success then
    warn("Không thể tạo Window:", err)
    return
end

-- Lưu reference để cleanup sau
_G.FluentGui = Window
_G.RestartConnections = {}

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
                        
                        -- Cleanup trước khi hop
                        CleanupBeforeTeleport()
                        
                        -- Tìm server mới với error handling
                        local servers = {}
                        local success, result = pcall(function()
                            return game:HttpGetAsync("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
                        end)
                        
                        if success and result then
                            local body = HttpService:JSONDecode(result)
                            
                            if body and body.data then
                                for i, v in pairs(body.data) do
                                    if type(v) == "table" and v.playing and v.maxPlayers and v.playing < v.maxPlayers and v.id ~= JobId then
                                        table.insert(servers, v.id)
                                    end
                                end
                            end
                        end
                        
                        if #servers > 0 then
                            -- Queue script nếu AutoRestart bật
                            if Settings.AutoRestart and queueteleport then
                                queueteleport([[
                                    wait(3) -- Đợi game load
                                    loadstring(game:HttpGet('https://raw.githubusercontent.com/HxB0b/Roblox-Script/refs/heads/main/RestartScript.lua'))()
                                ]])
                            end
                            
                            TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)], LocalPlayer)
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
                        
                        -- Cleanup trước khi rejoin
                        CleanupBeforeTeleport()
                        
                        -- Queue script nếu AutoRestart bật
                        if Settings.AutoRestart and queueteleport then
                            queueteleport([[
                                wait(3) -- Đợi game load
                                loadstring(game:HttpGet('https://raw.githubusercontent.com/HxB0b/Roblox-Script/refs/heads/main/RestartScript.lua'))()
                            ]])
                        end
                        
                        -- Rejoin logic
                        if #Players:GetPlayers() <= 1 then
                            LocalPlayer:Kick("\nRejoining...")
                            wait()
                            TeleportService:Teleport(PlaceId, LocalPlayer)
                        else
                            TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer)
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
