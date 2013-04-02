---------------------------------------
-- Useful globals
---------------------------------------

H = wesnoth.require "lua/helper.lua"
W = H.set_wml_action_metatable {}
T = H.set_wml_tag_metatable {}
V = H.set_wml_var_metatable {}
TERRAIN_TYPES = {"shallow_water", "reef", "swamp_water", "flat", "sand", 
                 "forest", "hills", "mountains", "village", "castle", "cave", 
                 "frozen", "fungus", "unwalkable", "impassable"}


-- Unused as of yet
local function round(num)
    local f = math.floor(num)
    if f == num or num - f < .5 then
        return f
    else
        return f + 1
    end
end


function clear_vars(vars)
   for i, v in ipairs(vars) do
       wesnoth.set_variable(v)
   end
end


-- `sub` is an optional sub-path
function drw_path(varname, sub)
    local i = V[varname .. ".variables.drw_index"]
    local path = string.format("drw_hero_stats[%s]", i)
    if sub ~= nil then
        path = string.format("%s.%s", path, sub)
    end
    return path
end


---------------------------------------
-- "Matching attacks exist?" series
---------------------------------------


-- The core function
local function attacks_exist(unit, filters)
    for attack in H.child_range(unit, "attack") do
        local this_matches = true
        for filter in string.gmatch(filters, "[^%s,][^,]*") do
            -- Split on the equals sign. Anyone know a better way to do this?
            -- TODO: Maybe use a (nonstandard?) filter_attack tag?
            local attr, value = string.match(filter, "([^%s]*)=([^%s]*)")
            if attack[attr] ~= value then
                this_matches = false
                break
            end    
        end
        if this_matches == true then
            return true
        end
    end
    return false
end


-- The to-variable derivative
function attacks_exist_to_var(unit, filters, var)
    wesnoth.set_variable(var, attacks_exist(unit, filters))
end


---------------------------------------
-- Other functions
---------------------------------------

-- Store the unit's defenses, max defense, and min defense into a new var; 
-- Note that these defense values are converted to normal, chance not to hit, 
-- defenses.
function store_defenses(unit, var)
    dtable = {}
    -- Start at the far extremes
    local best = 0
    -- Get the defense box
    local dbox = H.get_child(unit, "defense")[1]
    
    -- Get all the defenses from the [defense] tag
    local def, ter
    for i = 1, #TERRAIN_TYPES do
        ter = TERRAIN_TYPES[i]
        -- WML defenses: 100 = 100% chance *to* hit
        def = dbox[ter]
        -- Skip terrains that are not given -- these will always be uncrossable 
        -- for this particular unit.
        if def ~= nil then
            -- Convert to normal defenses: 100 will equal a 100% chance *not* 
            -- to hit.
            def = 100 - def
            -- Check for better defense
            if def > best then
                best = def
            end
            -- Store defense
            dtable[ter] = def
        end
    end
    -- This should possibly be separated from the "true" defenses, perhaps with 
    -- a [defense] tag around the "true" defenses. But I'm going with this: for 
    -- now, anyways.
    dtable.best_defense = best
    -- This var is now basically a [defense] tag... with a special addition :)
    V[var] = dtable
end
    