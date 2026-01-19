-- =========================
--  FRUIT HOP – ACTUALLY FLAWLESS v4 (LOCKED FINAL)
-- =========================

repeat task.wait() until game:IsLoaded()

-- ===== CONFIG SAFETY =====
getgenv().FRUIT_HOP_CFG = getgenv().FRUIT_HOP_CFG or {}
local CFG = getgenv().FRUIT_HOP_CFG

-- ===== TELEPORT PERSISTENCE =====
pcall(function()
    local q = (syn and syn.queue_on_teleport) or queue_on_teleport
    if q and CFG.RawScriptURL then
        q(game:HttpGet(CFG.RawScriptURL))
    end
end)

-- ===== SERVICES =====
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

-- ===== EXECUTOR COMPAT =====
local req =
    (syn and syn.request) or
    request or
    http_request or
    (fluxus and fluxus.request)

local fireTouch = firetouchinterest or (syn and syn.firetouchinterest)

-- ===== AUTO MARINE =====
pcall(function()
    CommF:InvokeServer("SetTeam","Marines")
end)

-- ===== CHARACTER SAFE =====
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 10)
end

-- ===== SAFE ZONE =====
local function goSafe()
    if not CFG.SafeZoneBeforeHop then return end
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = CFrame.new(-5073,315,-3150)
    end
end

-- =========================
--  FRUIT CACHE (HARD SAFE)
-- =========================
local FruitCache = {}

local function isRealFruit(obj)
    return obj
        and obj:IsA("Tool")
        and obj:FindFirstChild("Handle")
        and obj:FindFirstChild("Eat")
        and obj:IsDescendantOf(workspace)
end

local function rebuildCache()
    table.clear(FruitCache)
    for _,v in ipairs(workspace:GetDescendants()) do
        if isRealFruit(v) then
            FruitCache[v] = true
        end
    end
end

rebuildCache()

workspace.DescendantAdded:Connect(function(v)
    if isRealFruit(v) then
        FruitCache[v] = true
    end
end)

workspace.DescendantRemoving:Connect(function(v)
    FruitCache[v] = nil
end)

-- =========================
--  CLOSEST FRUIT
-- =========================
local function getClosestFruit()
    local hrp = getHRP()
    if not hrp then return end

    local closest, dist = nil, math.huge
    for fruit in pairs(FruitCache) do
        if fruit and fruit.Parent and fruit:FindFirstChild("Handle") then
            local d = (fruit.Handle.Position - hrp.Position).Magnitude
            if d < dist then
                dist = d
                closest = fruit
            end
        end
    end
    return closest
end

-- =========================
--  INVENTORY CHECK (PERFECT MATCH)
-- =========================
local function ownsFruit(name)
    local bp = player:FindFirstChild("Backpack")
    local char = player.Character
    for _,src in ipairs({bp, char}) do
        if src then
            for _,v in ipairs(src:GetChildren()) do
                if v:IsA("Tool") and v.Name == name then
                    return true
                end
            end
        end
    end
end

local function waitForFruit(name, timeout)
    local t = os.clock()
    while os.clock() - t < (timeout or 5) do
        if ownsFruit(name) then return true end
        task.wait(0.2)
    end
end

-- =========================
--  PICKUP (DESPAWN-PROOF)
-- =========================
local function pickupFruit(fruit)
    local hrp = getHRP()
    if not hrp then return end

    for _ = 1,10 do
        if not fruit or not fruit.Parent or not fruit:FindFirstChild("Handle") then
            return
        end
        if ownsFruit(fruit.Name) then return true end

        hrp.CFrame = fruit.Handle.CFrame * CFrame.new(0,1.5,0)
        task.wait(0.12)

        if fireTouch then
            pcall(function()
                fireTouch(hrp, fruit.Handle, 0)
                fireTouch(hrp, fruit.Handle, 1)
            end)
        end

        for _,v in ipairs(fruit:GetDescendants()) do
            if v:IsA("TouchTransmitter") and fireTouch then
                fireTouch(hrp, v.Parent, 0)
                fireTouch(hrp, v.Parent, 1)
            end
        end

        task.wait(0.25)
    end
end

-- =========================
--  STORE
-- =========================
local function storeFruit(name)
    for _ = 1,6 do
        pcall(function()
            CommF:InvokeServer("StoreFruit", name)
        end)
        task.wait(1)
        if not ownsFruit(name) then return true end
    end
end

-- =========================
--  WEBHOOK (SAFE)
-- =========================
local function sendWebhook(fruit)
    if not CFG.FruitWebhook or not req then return end
    pcall(function()
        req({
            Url = CFG.FruitWebhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                username = "Fruit Hopper",
                content =
                    "🍏 Fruit Stored\n"..
                    "• Fruit: "..fruit.."\n"..
                    "• Player: "..player.Name.."\n"..
                    "• JobId: "..string.sub(game.JobId,1,8)
            })
        })
    end)
end

-- =========================
--  SERVER HOP (HTTP SAFE)
-- =========================
local visited = {}

local function hop()
    if not req then return end
    goSafe()
    task.wait(1)

    local cursor = ""
    for _ = 1,5 do
        local res = req({
            Url = "https://games.roblox.com/v1/games/"..game.PlaceId..
            "/servers/Public?sortOrder=Asc&limit=100"..(cursor ~= "" and "&cursor="..cursor or ""),
            Method = "GET"
        })

        if not res or not res.Body then return end
        local body = typeof(res.Body) == "string" and res.Body or HttpService:JSONEncode(res.Body)
        local data = HttpService:JSONDecode(body)

        for _,s in ipairs(data.data or {}) do
            if s.playing < s.maxPlayers
            and s.id ~= game.JobId
            and not visited[s.id] then
                visited[s.id] = true
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, player)
                return
            end
        end

        cursor = data.nextPageCursor
        if not cursor then break end
        task.wait(2)
    end
end

-- =========================
--  MAIN LOOP (LOCKED)
-- =========================
while task.wait(CFG.RetryDelay or 2) do
    local fruit = getClosestFruit()

    if fruit then
        pickupFruit(fruit)
        waitForFruit(fruit.Name, 5)

        if CFG.AutoStoreFruit ~= false and ownsFruit(fruit.Name) then
            if storeFruit(fruit.Name) then
                sendWebhook(fruit.Name)
                task.wait(CFG.ConfirmTime or 6)
            end
        end
    elseif CFG.RetryUntilFruit then
        rebuildCache()
        task.wait(1)
        if not getClosestFruit() then
            hop()
        end
    end
end
