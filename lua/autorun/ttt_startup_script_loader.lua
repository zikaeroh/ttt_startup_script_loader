local SCRIPT_DIR = "ttt_startup_scripts"
local HOOK_ID = "ttt_startup_script_loader"

local function Log(...)
    Msg("TTT Startup Script Loader: ", ...)
end

local function LogErr(...)
    MsgC(Color(255, 0, 0), "TTT Startup Script Loader: ", ...)
end

Log("starting\n")

-- Functions available inside loaded scripts.

local function lookupInFunc(func, name)
    if func == nil then return nil end
    local info = debug.getinfo(func, "uS")
    if info == nil or info.what ~= "Lua" then return nil end

    local nups = info.nups
    for i = 1, nups do
        local key, value = debug.getupvalue(func, i)
        if key == name then return value end
    end

    return nil
end

local tempG = {
    lookupInFunc = lookupInFunc,
}

if CLIENT then
    local originalEquipment

    local function getEquipment()
        if SERVER then return nil end

        GetEquipmentForRole(0) -- Force Equipment to be populated
        local equipment = lookupInFunc(GetEquipmentForRole, "Equipment")
        if !originalEquipment then
            originalEquipment = table.Copy(equipment)
        end

        return equipment
    end

    local function getOriginalEquipment()
        return table.Copy(originalEquipment)
    end

    tempG.getEquipment = getEquipment
    tempG.getOriginalEquipment = getOriginalEquipment
end

setmetatable(tempG, {
    __index = _G,
    __newindex = _G,
})

local function executeFile(filepath)
    local f = CompileFile(filepath)
    if !f then return end

    setfenv(f, tempG)
    local success, err = pcall(f)
    
    if success then
        Log("loaded ", filepath, "\n")
    else
        LogErr("failed to load ", filepath, " - ", err, "\n")
    end
end

local function findFiles()
    local files, _ = file.Find(SCRIPT_DIR .. "/*.lua", "LUA")
    if !files then
        LogErr("invalid script dir ", SCRIPT_DIR, "\n")
        return nil
    end

    local result = {}

    for i, v in ipairs(files) do
        result[i] = SCRIPT_DIR .. "/" .. v
    end

    table.sort(result)

    return result
end

local function forEachFoundFile(func)
    local foundFiles = findFiles()
    if !foundFiles then return end

    for _, f in ipairs(foundFiles) do func(f) end
end

hook.Add("InitPostEntity", HOOK_ID, function()
    hook.Remove("InitPostEntity", HOOK_ID)
    if GAMEMODE.Name ~= "Trouble in Terrorist Town" then return end
    forEachFoundFile(executeFile)
end)

if SERVER then
    forEachFoundFile(AddCSLuaFile)
end

Log("ready\n")
