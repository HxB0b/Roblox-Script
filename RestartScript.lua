-- Restart Script: Fluent UI + Server Hop/Rejoin + Auto-reload Infinite Yield on teleport

-- services
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

-- executor queue_on_teleport compatibility
local queueTeleportFunc = rawget(getfenv(), "queue_on_teleport")
    or (rawget(getfenv(), "syn") and syn.queue_on_teleport)
    or (rawget(getfenv(), "fluxus") and fluxus.queue_on_teleport)

-- use the exact Infinite Yield link from original source
local INFINITE_YIELD_URL = "https://raw.githubusercontent.com/HxB0b/Roblox-Script/refs/heads/main/RestartScript.lua"

-- automatically queue Infinite Yield to run after teleport
local queuedThisTeleport = false
if queueTeleportFunc then
    localPlayer.OnTeleport:Connect(function()
        if not queuedThisTeleport then
            queuedThisTeleport = true
            pcall(function()
                queueTeleportFunc("loadstring(game:HttpGet('" .. INFINITE_YIELD_URL .. "'))()")
            end)
        end
    end)
end

-- UI using Fluent library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Restart Script",
    SubTitle = "Server Hop / Rejoin + Auto IY",
    TabWidth = 160,
    Size = UDim2.fromOffset(520, 360),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" }),
}

if queueTeleportFunc then
    Fluent:Notify({
        Title = "Auto-Restart",
        Content = "Infinite Yield sẽ tự chạy lại khi Teleport.",
        Duration = 6
    })
else
    Fluent:Notify({
        Title = "Auto-Restart",
        Content = "Executor không hỗ trợ queue_on_teleport, tự khởi động lại có thể không hoạt động.",
        Duration = 8
    })
end

-- Server Hop button
Tabs.Main:AddButton({
    Title = "Server Hop",
    Description = "Chuyển sang public server khác",
    Callback = function()
        local servers = {}
        local ok, res = pcall(function()
            local url = "https://games.roblox.com/v1/games/" .. tostring(PLACE_ID) .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
            local body = game:HttpGet(url)
            return HttpService:JSONDecode(body)
        end)
        if ok and res and res.data then
            for _, v in ipairs(res.data) do
                if typeof(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers)
                    and v.playing < v.maxPlayers and v.id ~= JOB_ID then
                    table.insert(servers, v.id)
                end
            end
        end

        if #servers > 0 then
            local target = servers[math.random(1, #servers)]
            TeleportService:TeleportToPlaceInstance(PLACE_ID, target, localPlayer)
        else
            Fluent:Notify({ Title = "Server Hop", Content = "Không tìm thấy server phù hợp.", Duration = 6 })
        end
    end
})

-- Rejoin Server button
Tabs.Main:AddButton({
    Title = "Rejoin Server",
    Description = "Tham gia lại server hiện tại",
    Callback = function()
        if #Players:GetPlayers() <= 1 then
            localPlayer:Kick("\nRejoining...")
            task.wait()
            TeleportService:Teleport(PLACE_ID, localPlayer)
        else
            TeleportService:TeleportToPlaceInstance(PLACE_ID, JOB_ID, localPlayer)
        end
    end
})

Window:SelectTab(1)


