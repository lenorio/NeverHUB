-- Put this file in Real's AutoExec folder. It runs the hub after injection.
local url = "https://raw.githubusercontent.com/lenorio/NeverHUB/main/NeverHUB.luau"
local cache = "NeverHUB/entry.luau"
pcall(function()
    if not isfolder("NeverHUB") then makefolder("NeverHUB") end
end)
local ok, source = pcall(function() return game:HttpGet(url) end)
local chunk, err
if ok and type(source) == "string" and #source > 0 then
    chunk, err = loadstring(source, "@NeverHUB")
    if chunk then pcall(writefile, cache, source) end
end
if not chunk then
    local cached, saved = pcall(readfile, cache)
    if cached then
        chunk, err = loadstring(saved, "@NeverHUB/cache")
    end
end
if not chunk then
    warn("NeverHUB: download failed: " .. tostring(err or source))
    return
end
local ran, runError = pcall(chunk)
if not ran then warn("NeverHUB: " .. tostring(runError)) end
