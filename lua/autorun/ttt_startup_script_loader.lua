if engine.ActiveGamemode() ~= "terrortown" then return end

local SCRIPT_DIR = "ttt_startup_scripts"

local function Log(...)
    Msg("TTT Startup Script Loader: ", ...)
end

local function LogErr(...)
    MsgC(Color(255, 90, 90), "TTT Startup Script Loader: ", ...)
end

Log("starting\n")

-- Similar to https://rosettacode.org/wiki/Deepcopy#Lua and table.Copy.
local function deepCopy(o, tables)
    if o == nil then return nil end
    
    local typ = type(o)
    if typ == "Vector" then
        return Vector(o.x, o.y, o.z)
    elseif typ == "Angle" then
        return Angle(o.p, o.y, o.r)
    elseif typ ~= "table" then
        return o
    end

    if !tables then tables = {} end
    if tables[o] != nil then return tables[o] end
    
    local new_o = {}
    setmetatable(new_o, debug.getmetatable(o))
    tables[o] = new_o

    for k, v in pairs(o) do
        local k = deepCopy(k, tables)
        local v = deepCopy(v, tables)
        new_o[k] = v
    end
    
    return new_o
end

local Memo = {}
Memo.__index = Memo

function Memo:New(getter)
    local this = {
        getter = getter or function() return nil end
    }
    setmetatable(this, self)
    return this
end

function Memo:Cache()
    if !self.cached then
        local v = self.getter()
        self.v = v
        self.origV = deepCopy(v)
        self.cached = true
    end
end

function Memo:Get()
    self:Cache()
    return self.v
end

function Memo:GetOrig()
    self:Cache()
    return deepCopy(self.origV)
end

local function lookupInFuncHelper(func, name)
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

local function lookupInFunc(func, ...)
    if func == nil then return nil end
    if type(func) == "string" then func = _G[func] end
    if type(func) ~= "function" then return nil end

    local curr = func
    for _, v in ipairs({...}) do
        curr = lookupInFuncHelper(curr, v)
        if curr == nil then return nil end
    end

    return curr
end

local function extendSWEP(weapon_class, tab)
    local v = weapons.GetStored(weapon_class)
    if !v then return end
    table.Merge(v, tab)
end

local tempG = {
    lookupInFunc = lookupInFunc,
    deepCopy = deepCopy,
    extendSWEP = extendSWEP,
}

if CLIENT then
    local equipment = Memo:New(function()
        GetEquipmentForRole(0) -- Force Equipment to be populated
        return lookupInFunc(GetEquipmentForRole, "Equipment")
    end)

    tempG.getEquipment = function() return equipment:Get() end
    tempG.getOriginalEquipment = function() return equipment:GetOrig() end
end

if SERVER then
    local deathsounds = Memo:New(function()
        return lookupInFunc(GAMEMODE.DoPlayerDeath, "PlayDeathSound", "deathsounds")
    end)

    tempG.getDeathsounds = function() return deathsounds:Get() end
    tempG.getOriginalDeathsounds = function() return deathsounds:GetOrig() end
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
