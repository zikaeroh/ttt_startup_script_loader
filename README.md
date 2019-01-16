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
- `getOriginalEquipment()` - returns the `Equipment` table as it was before any scripts ran (available only to `CLIENT`).
- `lookupInFunc(func, name)` - looks up a variable available to the specified function.
