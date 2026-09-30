-- NeverHUB: detect the current game and offer its script.
local BASE_URL = "https://raw.githubusercontent.com/lenorio/NeverHUB/main/"
local UI_URL = "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
local HttpService = game:GetService("HttpService")
local environment = getgenv()
local previous = environment.NeverHUB
if previous and previous.Stop then previous.Stop() end

if not game:IsLoaded() then game.Loaded:Wait() end

local runtime = {alive = true, loading = false, window = nil, catalog = nil, selected = nil}
environment.NeverHUB = runtime

local function stop()
    runtime.alive = false
    runtime.loading = false
    local window = runtime.window
    runtime.window = nil
    runtime.catalog = nil
    runtime.selected = nil
    runtime.Load = nil
    runtime.Refresh = nil
    runtime.FindScript = nil
    if environment.NeverHUB == runtime then environment.NeverHUB = nil end
    if window then pcall(function() window:Destroy() end) end
end
runtime.Stop = stop

pcall(function()
    if not isfolder("NeverHUB") then makefolder("NeverHUB") end
end)

local function download(url, cachePath, validate)
    local ok, content = pcall(function() return game:HttpGet(url) end)
    local valid = ok and type(content) == "string" and #content > 0
    if valid and validate then valid = pcall(validate, content) end
    if valid then
        pcall(writefile, cachePath, content)
        return content, false
    end
    local cached, saved = pcall(readfile, cachePath)
    local validCache = cached and type(saved) == "string" and #saved > 0
    if validCache and validate then validCache = pcall(validate, saved) end
    if validCache then return saved, true end
    error("Failed to download " .. url .. ": " .. tostring(content))
end

local function compile(content, name)
    local chunk, err = loadstring(content, "@NeverHUB/" .. name)
    if not chunk then error("Error in " .. name .. ": " .. tostring(err)) end
    return chunk
end

local WindUI
local loadedUI, uiError = pcall(function()
    local source = download(UI_URL, "NeverHUB/WindUI.luau", function(text) compile(text, "WindUI") end)
    WindUI = compile(source, "WindUI")()
    assert(type(WindUI) == "table", "The UI library failed to load")
    WindUI:SetLanguage("en")
end)
if not loadedUI then
    warn("NeverHUB: " .. tostring(uiError))
    stop()
    return
end

local function notify(title, text)
    WindUI:Notify({Title = title, Content = text, Duration = 5, Icon = "info"})
end

local function validateCatalog(catalog)
    assert(type(catalog) == "table" and catalog.schemaVersion == 1 and type(catalog.scripts) == "table", "Invalid catalog format")
    local ids = {}
    for _, entry in catalog.scripts do
        assert(type(entry) == "table" and type(entry.id) == "string" and entry.id:match("^[%w_-]+$"), "Invalid script ID")
        assert(not ids[entry.id], "Duplicate script ID: " .. entry.id)
        ids[entry.id] = true
        assert(type(entry.name) == "string" and type(entry.file) == "string", "Missing script name or file")
        assert(entry.file:match("^[%w_./-]+$") and not entry.file:find("..", 1, true) and entry.file:sub(1, 1) ~= "/", "Invalid script path")
        assert(type(entry.placeIds) == "table" or type(entry.universeIds) == "table", "Missing game IDs for " .. entry.id)
    end
end

local function includes(ids, id)
    if type(ids) ~= "table" then return false end
    for _, value in ids do
        if tonumber(value) == id then return true end
    end
    return false
end

local function findScript(catalog, placeId, universeId)
    for _, entry in catalog.scripts do
        if includes(entry.placeIds, placeId) then return entry end
    end
    for _, entry in catalog.scripts do
        if includes(entry.universeIds, universeId) then return entry end
    end
    return nil
end
runtime.FindScript = findScript

local function activeScript(entry)
    local active = entry.runtimeKey and environment[entry.runtimeKey]
    return type(active) == "table" and active.alive and active or nil
end

local function launch(forceReload)
    local entry = runtime.selected
    if not runtime.alive or runtime.loading or not entry then return end
    local active = activeScript(entry)
    if active and not forceReload then
        if active.window then pcall(function() active.window:Open() end) end
        stop()
        return
    end
    runtime.loading = true
    task.spawn(function()
        local ok, err = pcall(function()
            local source = download(BASE_URL .. entry.file, "NeverHUB/" .. entry.id .. ".luau", function(text) compile(text, entry.file) end)
            local chunk = compile(source, entry.file)
            if not runtime.alive then return end
            chunk()
        end)
        runtime.loading = false
        if not runtime.alive then return end
        if ok then
            stop()
        else
            warn("NeverHUB: " .. tostring(err))
            notify("Could not load script", tostring(err))
        end
    end)
end
runtime.Load = launch

local function showCatalog()
    local window = runtime.window
    runtime.window = nil
    if window then pcall(function() window:Destroy() end) end
    if not runtime.alive then return end
    window = WindUI:CreateWindow({
        Title = "NeverHUB",
        Icon = "layers",
        Author = "lenorio · Place " .. tostring(game.PlaceId),
        Folder = "NeverHUB",
        Size = UDim2.fromOffset(580, 390),
        Theme = "Dark",
        IgnoreAlerts = true,
    })
    runtime.window = window
    window:OnDestroy(function()
        if runtime.window == window then
            runtime.window = nil
            stop()
        end
    end)
    window:SetToggleKey(Enum.KeyCode.RightShift)
    local current = window:Tab({Title = "Current game", Icon = "gamepad-2"})
    local entry = runtime.selected
    if entry then
        current:Button({
            Title = activeScript(entry) and "Open " .. entry.name or "Load " .. entry.name,
            Desc = tostring(entry.description or "") .. " · v" .. tostring(entry.version or "1"),
            Icon = "play",
            Callback = function() launch(false) end,
        })
        current:Button({Title = "Reload script", Desc = "Load the latest version from GitHub", Icon = "refresh-cw",
            Callback = function() launch(true) end})
    end
    current:Button({Title = "Refresh catalog", Desc = entry and "Check for updates" or "No script is available for this game yet", Icon = "refresh-cw",
        Callback = function() runtime.Refresh(false) end})
    current:Button({Title = "Unload hub", Desc = "Your game script will keep running", Icon = "x", Callback = stop})
    local catalogTab = window:Tab({Title = "All games", Icon = "list"})
    for _, item in runtime.catalog.scripts do
        catalogTab:Button({Title = item.name, Desc = tostring(item.description or "") .. " · v" .. tostring(item.version or "1"),
            Callback = function()
                if item == runtime.selected then launch(false) else notify("Join the game first", "Join " .. item.name .. " to load this script") end
            end})
    end
    window:SelectTab(current.Index)
end

local function refresh(offer)
    if not runtime.alive or runtime.loading then return end
    runtime.loading = true
    task.spawn(function()
        local ok, err = pcall(function()
            local source, cached = download(BASE_URL .. "manifest.json", "NeverHUB/manifest.json", function(text)
                validateCatalog(HttpService:JSONDecode(text))
            end)
            local catalog = HttpService:JSONDecode(source)
            validateCatalog(catalog)
            if not runtime.alive then return end
            runtime.catalog = catalog
            runtime.selected = findScript(catalog, game.PlaceId, game.GameId)
            runtime.cachedCatalog = cached
            showCatalog()
        end)
        runtime.loading = false
        if not runtime.alive then return end
        if not ok then
            warn("NeverHUB: " .. tostring(err))
            notify("Catalog unavailable", tostring(err))
            return
        end
        local entry = runtime.selected
        if offer and entry and not activeScript(entry) then
            runtime.window:Dialog({Title = entry.name .. " is supported", Content = "Load the script for this game? The hub will unload after the script starts.",
                Buttons = {
                    {Title = "Not now", Variant = "Secondary", Callback = function() end},
                    {Title = "Load script", Variant = "Primary", Callback = function() launch(false) end},
                }})
        elseif not entry then
            notify("Game detected", "No script is available for this game yet")
        end
    end)
end
runtime.Refresh = refresh
refresh(true)
