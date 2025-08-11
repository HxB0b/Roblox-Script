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

local AUTO_RESTART_ENABLED = true -- Đổi thành false nếu muốn tắt Auto Restart
local MIN_PLAYERS = 1 -- Server phải có ít nhất số người này
local MAX_PING = 500 -- Ping tối đa cho phép (ms)

-- Load Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Tạo Window
local Window = Fluent:CreateWindow({
    Title = "Server Control Panel",
    SubTitle = "Advanced Server Hop & Rejoin Tools",
    TabWidth = 160,
    Size = UDim2.fromOffset(450, 350),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.End
})

-- Tab Main
local MainTab = Window:AddTab({ 
    Title = "Main", 
    Icon = "home" 
})

-- Tab Settings
local SettingsTab = Window:AddTab({
    Title = "Settings",
    Icon = "settings"
})

-- Thông tin Server với auto-update
local ServerInfo = MainTab:AddParagraph({
    Title = "Thông tin Server",
    Content = string.format("Place ID: %s\nJob ID: %s\nSố người chơi: %d/%d\nPing: %d ms", 
        tostring(PlaceId), 
        tostring(JobId),
        #Players:GetPlayers(),
        Players.MaxPlayers,
        math.floor(Players.LocalPlayer:GetNetworkPing() * 1000))
})

-- Auto update server info
spawn(function()
    while wait(2) do
        pcall(function()
            ServerInfo:SetDesc(string.format("Place ID: %s\nJob ID: %s\nSố người chơi: %d/%d\nPing: %d ms", 
                tostring(PlaceId), 
                tostring(JobId),
                #Players:GetPlayers(),
                Players.MaxPlayers,
                math.floor(Players.LocalPlayer:GetNetworkPing() * 1000)))
        end)
    end
end)

-- Function Server Hop cải tiến
function ServerHop()
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
                        -- Queue script trước khi teleport
                        if queueteleport and AUTO_RESTART_ENABLED then
                            queueteleport([[
                                loadstring(game:HttpGet('https://raw.githubusercontent.com/HxB0b/Roblox-Script/refs/heads/main/RestartScript.lua'))()
                            ]])
                        end
                        TeleportService:TeleportToPlaceInstance(PlaceID, ID, Players.LocalPlayer)
                    end)
                    wait(4) -- Chờ một chút để teleport hoàn tất
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

-- Button Server Hop với cơ chế mới
MainTab:AddButton({
    Title = "Server Hop",
    Description = "Chuyển sang server khác (Cơ chế nâng cao)",
    Callback = function()
        -- Thông báo trước khi hop
        Fluent:Notify({
            Title = "Server Hop",
            Content = "Đang tìm server mới...",
            Duration = 3
        })
        
        -- Gọi function Server Hop cải tiến
        ServerHop()
    end
})

-- Button Rejoin Server
MainTab:AddButton({
    Title = "Rejoin Server", 
    Description = "Tham gia lại server hiện tại",
    Callback = function()
        -- Queue script trước khi rejoin
        if queueteleport and AUTO_RESTART_ENABLED then
            queueteleport([[
                loadstring(game:HttpGet('https://raw.githubusercontent.com/HxB0b/Roblox-Script/refs/heads/main/RestartScript.lua'))()
            ]])
        end
        
        -- Rejoin với thông báo
        Fluent:Notify({
            Title = "Rejoin",
            Content = "Đang kết nối lại server...",
            Duration = 2
        })
        
        wait(0.5)
        
        -- Rejoin logic cải tiến
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

-- Toggle Auto Restart trong Settings tab
local ToggleAutoRestart = SettingsTab:AddToggle("AutoRestart", {
    Title = "Auto Restart Script",
    Description = "Tự động chạy lại script khi chuyển server",
    Default = AUTO_RESTART_ENABLED
})

ToggleAutoRestart:OnChanged(function(Value)
    AUTO_RESTART_ENABLED = Value
    Fluent:Notify({
        Title = "Auto Restart",
        Content = Value and "Đã bật" or "Đã tắt",
        Duration = 2
    })
end)

-- Slider cài đặt Min Players
local SliderMinPlayers = SettingsTab:AddSlider("MinPlayers", {
    Title = "Số người tối thiểu",
    Description = "Server phải có ít nhất số người này",
    Default = MIN_PLAYERS,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(Value)
        MIN_PLAYERS = Value
    end
})

-- Slider cài đặt Max Ping
local SliderMaxPing = SettingsTab:AddSlider("MaxPing", {
    Title = "Ping tối đa (ms)",
    Description = "Chỉ chuyển đến server có ping thấp hơn",
    Default = MAX_PING,
    Min = 100,
    Max = 1000,
    Rounding = 0,
    Callback = function(Value)
        MAX_PING = Value
    end
})

-- Button Quick Server Hop (tìm server có ít người nhất)
MainTab:AddButton({
    Title = "Quick Low Pop Server",
    Description = "Tìm server có ít người nhất",
    Callback = function()
        local servers = {}
        local success, data = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        
        if success and data and data.data then
            local lowestServer = nil
            local lowestCount = math.huge
            
            for _, server in pairs(data.data) do
                if server.playing < lowestCount and server.playing >= MIN_PLAYERS and server.id ~= JobId then
                    lowestServer = server.id
                    lowestCount = server.playing
                end
            end
            
            if lowestServer then
                Fluent:Notify({
                    Title = "Server Found",
                    Content = "Tìm thấy server với " .. lowestCount .. " người",
                    Duration = 2
                })
                
                if queueteleport and AUTO_RESTART_ENABLED then
                    queueteleport([[
                        loadstring(game:HttpGet('https://raw.githubusercontent.com/HxB0b/Roblox-Script/refs/heads/main/RestartScript.lua'))()
                    ]])
                end
                
                wait(0.5)
                TeleportService:TeleportToPlaceInstance(PlaceId, lowestServer, Players.LocalPlayer)
            else
                Fluent:Notify({
                    Title = "Không tìm thấy",
                    Content = "Không có server phù hợp!",
                    Duration = 3
                })
            end
        end
    end
})

if not queueteleport then
    wait(1)
    Fluent:Notify({
        Title = "Cảnh báo",
        Content = "Executor của bạn không hỗ trợ queue_on_teleport!",
        SubContent = "Tính năng Auto Restart sẽ không hoạt động",
        Duration = 5
    })
end
