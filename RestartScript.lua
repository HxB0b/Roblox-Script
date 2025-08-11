-- RestartScript.lua
-- Minimal UI with Server Hop and Rejoin, plus auto-restart Infinite Yield on teleport using the same link as IY

-- Services
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

-- Executor compatibility: discover queue_on_teleport across popular executors
local function getQueueOnTeleport()
    local ok, q = pcall(function()
        return queue_on_teleport
    end)
    if ok and type(q) == "function" then return q end
    local okSyn, synQ = pcall(function()
        return syn and syn.queue_on_teleport
    end)
    if okSyn and type(synQ) == "function" then return synQ end
    local okFlux, fluxQ = pcall(function()
        return fluxus and fluxus.queue_on_teleport
    end)
    if okFlux and type(fluxQ) == "function" then return fluxQ end
    return nil
end

local queueOnTeleport = getQueueOnTeleport()

-- The exact same link used by Infinite Yield for auto-restart
local INFINITE_YIELD_LINK = "https://raw.githubusercontent.com/HxB0b/Roblox-Script/refs/heads/main/RestartScript.lua"

-- Ensure we only queue once per teleport
local hasQueuedForThisTeleport = false

-- Auto-queue Infinite Yield to run after teleport
local function setupAutoRestartOnTeleport()
    if not queueOnTeleport then return end
    if not localPlayer then return end
    localPlayer.OnTeleport:Connect(function()
        if hasQueuedForThisTeleport then return end
        hasQueuedForThisTeleport = true
        queueOnTeleport("loadstring(game:HttpGet('" .. INFINITE_YIELD_LINK .. "'))()")
    end)
end

setupAutoRestartOnTeleport()

-- Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Restart Tools",
    SubTitle = "Server Hop & Rejoin",
    TabWidth = 160,
    Size = UDim2.fromOffset(520, 360),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" })
}

local function notify(title, content, duration)
    Fluent:Notify({
        Title = title or "Info",
        Content = content or "",
        Duration = duration or 5
    })
end

-- Warn if executor lacks queue_on_teleport
if not queueOnTeleport then
    notify("Incompatible Executor", "queue_on_teleport is not available; auto-restart on teleport will be disabled.")
end

-- Server Hop button
Tabs.Main:AddButton({
    Title = "Server Hop",
    Description = "Teleport to another public server",
    Callback = function()
        -- Query public servers and pick one that is not full and not the current server
        local success, body = pcall(function()
            local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        if not success or not body or not body.data then
            return notify("Server Hop", "Failed to fetch server list.")
        end

        local candidateServers = {}
        for _, server in ipairs(body.data) do
            if typeof(server) == "table" and tonumber(server.playing) and tonumber(server.maxPlayers) then
                if server.playing < server.maxPlayers and server.id ~= JobId then
                    table.insert(candidateServers, server.id)
                end
            end
        end

        if #candidateServers == 0 then
            return notify("Server Hop", "No available servers found.")
        end

        local targetId = candidateServers[math.random(1, #candidateServers)]
        hasQueuedForThisTeleport = false -- allow queue for the next teleport
        TeleportService:TeleportToPlaceInstance(PlaceId, targetId, localPlayer)
    end
})

-- Rejoin button
Tabs.Main:AddButton({
    Title = "Rejoin Server",
    Description = "Rejoin the current server",
    Callback = function()
        hasQueuedForThisTeleport = false -- allow queue for the next teleport
        if #Players:GetPlayers() <= 1 then
            localPlayer:Kick("\nRejoining...")
            task.wait()
            TeleportService:Teleport(PlaceId, localPlayer)
        else
            TeleportService:TeleportToPlaceInstance(PlaceId, JobId, localPlayer)
        end
    end
})

Window:SelectTab(1)
notify("Restart Tools", "Loaded. Use the buttons to Server Hop or Rejoin.")


