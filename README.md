# ttt_startup_script_loader

Loads lua scripts at TTT startup. To use, add lua files to `lua/ttt_startup_scripts`.

For example, `lua/ttt_startup_scripts/say_hi.lua`:

```lua
if SERVER then
    print("Hi server!")
else
    print("Hi client!")
end
```

The scripts are run once at TTT initialization, within a `pcall`.
The scripts are run in the global environment, with the following extra functions:

- `getEquipment()` - returns TTT's underlying `Equipment` table (available only to `CLIENT`).
- `getOriginalEquipment()` - returns a copy of the `Equipment` table as it was before any scripts ran (available only to `CLIENT`).
- `getDeathsounds()` - returns TTT's underlying `deathsounds` table (available only to `SERVER`).
- `getOriginalDeathsounds()` - returns a copy of the `deathsounds` table as it was before any scripts ran (available only to `SERVER`).
- `lookupInFunc(func, ...)` - looks up a variable available to the specified function. Specify multiple varargs to chain lookups.
- `deepCopy(v)` - makes a deep copy of any value.
- `extendSWEP(weapon_class, tab)` - merges `tab` into a SWEP. Note that all calls to this function after `getEquipment()` or `getOriginalEqipment()` have undefined behavior.