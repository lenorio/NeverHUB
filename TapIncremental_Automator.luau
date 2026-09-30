-- Tap Incremental (place 82103875404639) automation panel.
-- Every spending action starts disabled. Use Stop all to end every loop.
if game.PlaceId ~= 82103875404639 then
    warn("Tap Incremental Automator: wrong place")
    return
end

local previous = getgenv().TapIncrementalAutomator
local savedConfig = previous and previous.Config
if previous and previous.Stop then
    previous.Stop()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local player = Players.LocalPlayer
local Framework = require(ReplicatedStorage.Framework)
local Multipliers = require(ReplicatedStorage.Modules.Shared.Multipliers)
local BigNum = require(ReplicatedStorage.Modules.Shared.BigNum)
local Runes = require(ReplicatedStorage.Modules.Shared.Runes)
local config = {
    tap = false,
    tapInterval = 0.05,
    rune = false,
    runeName = "Basic",
    runeFromAnywhere = true,
    class = false,
    rarity = false,
    upgrades = false,
    upgradeCategory = "All",
    mine = false,
    trees = false,
    fruit = false,
    sellOres = false,
    sellFish = false,
}
if type(savedConfig) == "table" then
    for key in config do
        if savedConfig[key] ~= nil then config[key] = savedConfig[key] end
    end
end
local runtime = {alive = true, busy = {}, window = nil, savedAutoClicker = nil, moveOwner = nil}
runtime.Config = config

local function stat(name)
    local ok, value = pcall(Framework.Stat.Get, name)
    if ok then return value end
    return nil
end

local function fire(name, ...)
    local ok, result = pcall(Framework.Network.Fire, name, ...)
    if not ok then
        warn("Tap Incremental Automator / " .. name .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function rootPart()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function nearest(folder, maxDistance, predicate)
    local root = rootPart()
    if not root or not folder then return nil end
    local chosen, best = nil, maxDistance or math.huge
    for _, model in folder:GetChildren() do
        if model:IsA("Model") and (not predicate or predicate(model)) then
            local distance = (model:GetPivot().Position - root.Position).Magnitude
            if distance < best then
                chosen, best = model, distance
            end
        end
    end
    return chosen
end

local function distanceTo(model)
    local root = rootPart()
    if not root or not model or not model.Parent then return math.huge end
    local delta = model:GetPivot().Position - root.Position
    return (delta * Vector3.new(1, 0, 1)).Magnitude
end

local function walkTo(owner, model, radius, isEnabled)
    if not model or not model.Parent or (runtime.moveOwner and runtime.moveOwner ~= owner) then return false end
    runtime.moveOwner = owner
    local started = os.clock()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local speed = humanoid and math.max(8, humanoid.WalkSpeed) or 16
    local limit = math.clamp(distanceTo(model) / speed + 8, 12, 75)
    while runtime.alive and isEnabled() and model.Parent and distanceTo(model) > radius and os.clock() - started < limit do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then break end
        humanoid:MoveTo(model:GetPivot().Position)
        task.wait(0.35)
    end
    local reached = model.Parent ~= nil and distanceTo(model) <= radius
    runtime.moveOwner = nil
    return reached
end

local function walkToRune(button)
    local main = button and button:FindFirstChild("Main")
    if not main or runtime.moveOwner and runtime.moveOwner ~= "rune" then return false end
    runtime.moveOwner = "rune"
    local reached = false
    for _ = 1, 3 do
        if not runtime.alive or not config.rune or not main.Parent then break end
        local root = rootPart()
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid then break end
        local flat = (main.Position - root.Position) * Vector3.new(1, 0, 1)
        if flat.Magnitude <= 4 then
            reached = true
            break
        end
        local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
        local ok = pcall(function() path:ComputeAsync(root.Position, main.Position) end)
        if not ok or path.Status ~= Enum.PathStatus.Success then break end
        local blocked = false
        for index, waypoint in path:GetWaypoints() do
            if index > 1 then
                if not runtime.alive or not config.rune or not main.Parent then
                    blocked = true
                    break
                end
                if ((main.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude <= 4 then
                    reached = true
                    break
                end
                if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
                humanoid:MoveTo(waypoint.Position)
                local started = os.clock()
                while runtime.alive and config.rune and main.Parent and os.clock() - started < 2 do
                    if ((waypoint.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude <= 2.5 then break end
                    task.wait(0.1)
                end
                if ((waypoint.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude > 2.5 then
                    blocked = true
                    break
                end
            end
        end
        if reached then break end
        if not blocked and ((main.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude <= 4 then
            reached = true
            break
        end
    end
    runtime.moveOwner = nil
    return reached
end

local function buyRuneFromAnywhere(button, runeName)
    local main = button and button:FindFirstChild("Main")
    local root = rootPart()
    if not main or not root or runtime.moveOwner then return end
    local saved = root.CFrame
    local flat = (main.Position - root.Position) * Vector3.new(1, 0, 1)
    if flat.Magnitude <= 4 then
        fire("BuyRune", runeName)
        return
    end
    runtime.moveOwner = "rune"
    local ok, err = pcall(function()
        root.CFrame = CFrame.new(main.Position + Vector3.new(0, 3, 0))
        task.wait(0.6)
        if runtime.alive and config.rune then fire("BuyRune", runeName) end
        task.wait(0.4)
    end)
    if root.Parent then root.CFrame = saved end
    runtime.moveOwner = nil
    if not ok then warn("Tap Incremental Automator / rune: " .. tostring(err)) end
end

local function restoreAutoClicker()
    if runtime.savedAutoClicker ~= nil then
        fire("SetAutoClicker", runtime.savedAutoClicker)
        runtime.savedAutoClicker = nil
    end
end

local function stop()
    if not runtime.alive then return end
    runtime.alive = false
    restoreAutoClicker()
    if runtime.window then
        local window = runtime.window
        runtime.window = nil
        pcall(function() window:Destroy() end)
    end
    if getgenv().TapIncrementalAutomator == runtime then
        getgenv().TapIncrementalAutomator = nil
    end
end
runtime.Stop = stop
getgenv().TapIncrementalAutomator = runtime

local function worker(name, enabled, delay, action)
    task.spawn(function()
        while runtime.alive do
            if enabled() and not runtime.busy[name] then
                runtime.busy[name] = true
                local ok, result = pcall(action)
                runtime.busy[name] = false
                if not ok then warn("Tap Incremental Automator / " .. name .. ": " .. tostring(result)) end
            end
            task.wait(delay())
        end
    end)
end

local upgradeModules = {}
local upgradeNames = {"All"}
for _, child in ReplicatedStorage.Modules.Shared.Upgrades:GetChildren() do
    if child:IsA("ModuleScript") and not child.Name:find("Robux") then
        local ok, module = pcall(require, child)
        if ok and type(module) == "table" and type(module.Upgrades) == "table" and module.Currency then
            table.insert(upgradeModules, {name = child.Name, module = module})
            table.insert(upgradeNames, child.Name)
        end
    end
end
table.sort(upgradeModules, function(a, b) return a.name < b.name end)
table.sort(upgradeNames)

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
local window = WindUI:CreateWindow({
    Title = "Tap Incremental Automator",
    Icon = "mouse-pointer-click",
    Author = "Place 82103875404639",
    Folder = "TapIncrementalAutomator",
    Size = UDim2.fromOffset(620, 470),
    Theme = "Dark",
})
runtime.window = window
window:OnDestroy(function()
    runtime.window = nil
    stop()
end)
window:SetToggleKey(Enum.KeyCode.RightShift)

local tapTab = window:Tab({Title = "Taps", Icon = "mouse-pointer-click"})
tapTab:Toggle({Title = "Auto tap", Desc = "Uses the measured server pace; pauses the game's own auto clicker", Value = config.tap,
    Callback = function(value) config.tap = value end})
tapTab:Slider({Title = "Tap interval (seconds)", Value = {Min = 0.05, Max = 0.3, Default = config.tapInterval}, Step = 0.01,
    Callback = function(value) config.tapInterval = value end})
tapTab:Button({Title = "Stop all and close", Desc = "Stops the loops and restores the game's auto clicker", Icon = "square",
    Callback = stop})

local rollsTab = window:Tab({Title = "Rolls", Icon = "dice-5"})
rollsTab:Dropdown({Title = "Rune", Values = {"Basic", "Color", "Circuit", "Reef", "Glacier", "Candy", "Astral"}, Value = config.runeName,
    Callback = function(value) config.runeName = value end})
rollsTab:Toggle({Title = "Auto runes", Desc = "Spends the chosen rune's normal currency", Value = config.rune,
    Callback = function(value) config.rune = value end})
rollsTab:Toggle({Title = "Buy runes from anywhere", Desc = "Briefly visits the rune button, then returns to your position", Value = config.runeFromAnywhere,
    Callback = function(value) config.runeFromAnywhere = value end})
rollsTab:Toggle({Title = "Auto classes", Desc = "Uses the normal class roll", Value = config.class,
    Callback = function(value) config.class = value end})
rollsTab:Toggle({Title = "Auto rarity", Desc = "Uses the normal rarity roll", Value = config.rarity,
    Callback = function(value) config.rarity = value end})

local upgradesTab = window:Tab({Title = "Upgrades", Icon = "trending-up"})
upgradesTab:Dropdown({Title = "Upgrade group", Values = upgradeNames, Value = config.upgradeCategory,
    Callback = function(value) config.upgradeCategory = value end})
upgradesTab:Toggle({Title = "Buy affordable upgrades", Desc = "Max purchase, one upgrade per cycle", Value = config.upgrades,
    Callback = function(value) config.upgrades = value end})

local resourcesTab = window:Tab({Title = "Resources", Icon = "pickaxe"})
resourcesTab:Toggle({Title = "Auto mine ore", Desc = "Walks to a mineable ore and uses its exact OreId", Value = config.mine,
    Callback = function(value) config.mine = value end})
resourcesTab:Toggle({Title = "Chop nearby trees", Desc = "Walks to a tree and chops it", Value = config.trees,
    Callback = function(value) config.trees = value end})
resourcesTab:Toggle({Title = "Auto collect fruit", Desc = "Teleports between fruits with no added pause after collection", Value = config.fruit,
    Callback = function(value) config.fruit = value end})
resourcesTab:Toggle({Title = "Sell ores", Desc = "Walks to the sell station when you have ores", Value = config.sellOres,
    Callback = function(value) config.sellOres = value end})
resourcesTab:Toggle({Title = "Sell fish", Desc = "Walks to the sell station when you have fish", Value = config.sellFish,
    Callback = function(value) config.sellFish = value end})

window:SelectTab(tapTab.Index)

worker("tap", function() return config.tap end,
    function() return math.max(config.tapInterval, Multipliers.GetTapCooldown(), 0.05) end,
    function()
        if runtime.savedAutoClicker == nil then
            local enabled = stat("AutoClickerEnabled")
            runtime.savedAutoClicker = enabled and enabled.Value or false
            if runtime.savedAutoClicker then fire("SetAutoClicker", false) end
        end
        ReplicatedStorage.Remotes.Tap:FireServer()
    end)

task.spawn(function()
    while runtime.alive do
        if not config.tap then restoreAutoClicker() end
        task.wait(0.2)
    end
end)

worker("rune", function() return config.rune end, function() return math.max(0.5, Multipliers.GetRuneCooldown(player)) end, function()
    local info = Runes[config.runeName]
    if type(info) ~= "table" then return end
    local ascension = stat("Ascension")
    if not ascension or ascension.Value < (tonumber(info.RequiredAscension) or 4) then return end
    if info.UnlockStat then
        local unlock = stat(tostring(info.UnlockStat))
        if not unlock or unlock.Value < (tonumber(info.UnlockAmount) or 1) then return end
    end
    local currency = stat(info.Currency)
    if currency and BigNum.gte(currency.Value, info.Price) then
        local runes = workspace:FindFirstChild("Runes")
        local area = runes and runes:FindFirstChild(config.runeName)
        local button = area and area:FindFirstChild("RuneButton")
        if button then
            if config.runeFromAnywhere then
                buyRuneFromAnywhere(button, config.runeName)
            elseif walkToRune(button) then
                fire("BuyRune", config.runeName)
            end
        end
    end
end)

worker("class", function() return config.class end, function() return 1.5 end, function()
    local rolling = stat("IsRolling")
    if not rolling or not rolling.Value then fire("RollClass") end
end)

worker("rarity", function() return config.rarity end, function() return 1 end, function()
    fire("RollRarity")
end)

worker("upgrades", function() return config.upgrades end, function() return 0.8 end, function()
    for _, entry in upgradeModules do
        if config.upgradeCategory == "All" or config.upgradeCategory == entry.name then
            local currency = stat(entry.module.Currency)
            if currency then
                for upgradeName, info in entry.module.Upgrades do
                    local current = stat(entry.name .. upgradeName)
                    if current and type(info) == "table" and type(info.Max) == "function" and type(info.Price) == "function" then
                        local ok, affordable = pcall(function()
                            return current.Value < info.Max() and BigNum.gte(currency.Value, info.Price(current.Value))
                        end)
                        if ok and affordable then
                            fire("BuyUpgrade", entry.name, upgradeName, "Max")
                            return
                        end
                    end
                end
            end
        end
    end
end)

worker("mine", function() return config.mine end, function() return 0.6 end, function()
    local pickaxe = stat("PickaxeTier")
    local ore = nearest(workspace:FindFirstChild("Ores"), nil, function(model)
        return model:GetAttribute("OreId") ~= nil
            and (not pickaxe or (model:GetAttribute("RequiredPickaxe") or 1) <= pickaxe.Value)
    end)
    if ore and walkTo("mine", ore, 8, function() return config.mine end) then
        fire("MineOre", ore:GetAttribute("OreId"))
    end
end)

worker("trees", function() return config.trees end, function() return 0.8 end, function()
    local tree = nearest(workspace:FindFirstChild("ClientTrees"), nil,
        function(model) return model.Name:match("_(%d+)$") ~= nil end)
    if tree and walkTo("trees", tree, 5.5, function() return config.trees end) then
        fire("ChopTree", tonumber(tree.Name:match("_(%d+)$")))
    end
end)

local rejectedFruit = setmetatable({}, {__mode = "k"})
worker("fruit", function() return config.fruit end, function() return 0 end, function()
    if runtime.moveOwner then return end
    local root = rootPart()
    if not root then return end
    local fruit = nearest(workspace:FindFirstChild("ClientFruits"), nil,
        function(model)
            return model.Name:match("_(%d+)$") ~= nil and (rejectedFruit[model] or 0) < os.clock()
        end)
    if not fruit then return end
    runtime.moveOwner = "fruit"
    local ok, err = pcall(function()
        root.CFrame = CFrame.new(fruit:GetPivot().Position + Vector3.new(0, 2.5, 0))
        root.AssemblyLinearVelocity = Vector3.zero
        for _ = 1, 2 do
            if not runtime.alive or not config.fruit or not fruit.Parent then return end
            local result = fire("CollectFruit", tonumber(fruit.Name:match("_(%d+)$")))
            if result == true then
                rejectedFruit[fruit] = math.huge
                return
            end
            if not fruit.Parent then return end
        end
        rejectedFruit[fruit] = os.clock() + 30
    end)
    runtime.moveOwner = nil
    if not ok then warn("Tap Incremental Automator / fruit: " .. tostring(err)) end
end)

local function hasInventory(module)
    for key in module do
        local value = stat(key)
        if value and tonumber(value.Value) and tonumber(value.Value) > 0 then return true end
    end
    return false
end

worker("sellOres", function() return config.sellOres end, function() return 10 end, function()
    local ores = require(ReplicatedStorage.Modules.Shared.OreSellValues)
    local rings = workspace:FindFirstChild("Rings")
    local station = rings and rings:FindFirstChild("Sell")
    if station and hasInventory(ores) and walkTo("sellOres", station, 8, function() return config.sellOres end) then
        fire("SellOres", "All", station.Name)
    end
end)

worker("sellFish", function() return config.sellFish end, function() return 10 end, function()
    local fish = require(ReplicatedStorage.Modules.Shared.Fish)
    local rings = workspace:FindFirstChild("Rings")
    local station = rings and rings:FindFirstChild("SellFish")
    if station and hasInventory(fish.List) and walkTo("sellFish", station, 8, function() return config.sellFish end) then
        fire("SellFish", "All")
    end
end)

WindUI:Notify({Title = "Tap Incremental Automator", Content = "Ready. Enable the activities you want. Right Shift hides the panel.", Duration = 5, Icon = "check"})
