--==================================================
-- AUTO FRUIT HOP | BLOX FRUITS | MAIN SCRIPT
--==================================================

repeat task.wait() until game:IsLoaded()

--================ CONFIG (OVERRIDABLE BY LOADER) =================
local CFG = getgenv().AFH_CONFIG or {}

CFG.ScanDelay = CFG.ScanDelay or 6
CFG.RetryDelay = CFG.RetryDelay or 5
CFG.AutoStore = CFG.AutoStore ~= false
CFG.RetryUntilCollected = CFG.RetryUntilCollected ~= false
CFG.EnableRaid = CFG.EnableRaid ~= false
CFG.FloatHeight = CFG.FloatHeight or 8

CFG.SafeZoneCFrame = CFG.SafeZoneCFrame
    or CFrame.new(-5073, 315, -3150) -- Castle on the Sea

CFG.Webhook = CFG.Webhook or ""

--================ SERVICES =================
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")

local request = request or http_request or (syn and syn.request)

--================ SAFE ZONE =================
local function goSafe()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFG.SafeZoneCFrame
        task.wait(1)
    end
end

--================ FRUIT UTILS =================
local function isFruit(obj)
    return obj:IsA("Tool")
        and obj:FindFirstChild("Handle")
        and obj.Name:lower():find("fruit")
end

local function findFruits()
    local fruits = {}
    for _,v in ipairs(workspace:GetDescendants()) do
        if isFruit(v) then
            table.insert(fruits, v)
        end
    end
    return fruits
end

--================ COLLECT FRUIT =================
local function collectFruit(fruit)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    pcall(function()
        hrp.CFrame = fruit.Handle.CFrame * CFrame.new(0, 0, 2)
        task.wait(0.25)
        firetouchinterest(hrp, fruit.Handle, 0)
        firetouchinterest(hrp, fruit.Handle, 1)
    end)

    task.wait(0.6)
    return backpack:FindFirstChild(fruit.Name) ~= nil
end

--================ WEBHOOK =================
local function sendFruitWebhook(fruitName)
    if CFG.Webhook == "" or not request then return end

    request({
        Url = CFG.Webhook,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({
            username = "Auto Fruit Hop",
            content =
                "🍎 **Fruit Collected**\n"..
                "**Fruit:** "..fruitName.."\n"..
                "**Player:** "..player.Name.."\n"..
                "**Server:** "..string.sub(game.JobId,1,8)
        })
    })
end

--================ AUTO STORE =================
local function storeFruits()
    if not CFG.AutoStore then return end

    for _,tool in ipairs(backpack:GetChildren()) do
        if isFruit(tool) then
            pcall(function()
                ReplicatedStorage.Remotes.CommF_:InvokeServer(
                    "StoreFruit",
                    tool.Name
                )
                sendFruitWebhook(tool.Name)
            end)
            task.wait(0.3)
        end
    end
end

--================ PIRATE RAID =================
local function getRaidNPCs()
    local npcs = {}
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model")
        and v:FindFirstChild("Humanoid")
        and v:FindFirstChild("HumanoidRootPart")
        and v.Name:lower():find("pirate") then
            table.insert(npcs, v)
        end
    end
    return npcs
end

-- FLOAT ABOVE NPC + MELEE KILL
local function killNPC(npc)
    local char = player.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    while npc.Parent
    and npc:FindFirstChild("Humanoid")
    and npc.Humanoid.Health > 0 do

        hrp.CFrame =
            npc.HumanoidRootPart.CFrame *
            CFrame.new(0, CFG.FloatHeight, 0)

        pcall(function()
            ReplicatedStorage.Remotes.CommF_:InvokeServer(
                "Attack",
                "Melee"
            )
        end)

        task.wait(0.15)
    end
end

local function handleRaid()
    if not CFG.EnableRaid then return false end

    local npcs = getRaidNPCs()
    if #npcs == 0 then return false end

    for _,npc in ipairs(npcs) do
        killNPC(npc)
    end

    task.wait(1)
    storeFruits()
    return true
end

--================ SERVER HOP =================
local function getServer()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet(
                "https://games.roblox.com/v1/games/"..
                game.PlaceId..
                "/servers/Public?sortOrder=Asc&limit=100"
            )
        )
    end)

    if not ok or not data or not data.data then return nil end

    for _,s in ipairs(data.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            return s.id
        end
    end
end

local function hop()
    goSafe()
    task.wait(2)

    local server = getServer()
    if server then
        TeleportService:TeleportToPlaceInstance(
            game.PlaceId,
            server,
            player
        )
    end
end

--================ MAIN LOOP =================
task.spawn(function()
    while true do
        task.wait(CFG.ScanDelay)

        goSafe()

        local fruits = findFruits()
        if #fruits > 0 then
            for _,fruit in ipairs(fruits) do
                local ok = collectFruit(fruit)
                if CFG.RetryUntilCollected and not ok then
                    task.wait(1)
                    collectFruit(fruit)
                end
            end
            task.wait(1)
            storeFruits()

        elseif handleRaid() then
            -- raid handled, re-scan next loop

        else
            task.wait(CFG.RetryDelay)
            hop()
        end
    end
end)

print("[AutoFruitHop] Main script loaded")
