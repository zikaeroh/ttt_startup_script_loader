local SCRIPT_DIR = "ttt_startup_scripts"

local function Log(...)
    Msg("TTT Startup Script Loader: ", ...)
end

local function LogErr(...)
    MsgC(Color(255, 90, 90), "TTT Startup Script Loader: ", ...)
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
    local equipment

    local function getActualEquipment()
        if !equipment then
            GetEquipmentForRole(0) -- Force Equipment to be populated
            equipment = lookupInFunc(GetEquipmentForRole, "Equipment")
        end

        return equipment
    end

    local function getEquipment()
        local equipment = getActualEquipment()
        if !equipment then return nil end

        if !originalEquipment then
            originalEquipment = table.Copy(equipment)
        end

        return equipment
    end

    local function getOriginalEquipment()
        if !originalEquipment then
            local equipment = getActualEquipment()
            if !equipment then return nil end
            
            originalEquipment = table.Copy(equipment)
        end

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
    if !f then
        LogErr("compiled func for ", filepath, " was nil\n")
        return
    end

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

local HOOK_ID = "ttt_startup_script_loader"
local HOOK_INIT = "PostGamemodeLoaded"
local HOOK_WORK = "InitPostEntity"

hook.Add(HOOK_INIT, HOOK_ID, function()
    hook.Remove(HOOK_INIT, HOOK_ID)
    if GAMEMODE.Name ~= "Trouble in Terrorist Town" then return end

    -- Some addons use the InitPostEntity hook to add equipment items,
    -- so depending on the table of hooks, the loader may come before them
    -- and force Equipment to be cached, preventing those addons from having
    -- any effect. Instead of using the hook directly, hook earlier and
    -- replace the gamemode's function entirely to ensure that the loader
    -- is last.

    local orig = GAMEMODE[HOOK_WORK]

    if !orig then
        LogErr("Hook " .. HOOK_WORK .. "not found; loader will not run\n")
        return
    end

    GAMEMODE[HOOK_WORK] = function(...)
        GAMEMODE[HOOK_WORK] = orig

        local success, err = pcall(forEachFoundFile, executeFile)
        if !success then
            LogErr(err)
        end

        return orig(...)
    end
end)

if SERVER then
    forEachFoundFile(AddCSLuaFile)
end

Log("ready\n")
