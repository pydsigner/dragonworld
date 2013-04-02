---------------------------------------
-- Standard tag derivatives
---------------------------------------

-- Slight modification of the standard [modify_unit] tag, using a pre-stored 
-- unit variable rather than a [filter] tag.
function wesnoth.wml_actions.modify_unit_in_var(cfg)
    local var = cfg.variable
        
    local function start_var_scope(name)
        local var = H.get_variable_array(name) --containers and arrays
        if #var == 0 then var = wesnoth.get_variable(name) end --scalars (and nil/empty)
        wesnoth.set_variable(name)
        return var
    end
    
    local function end_var_scope(name, var)
        wesnoth.set_variable(name)
        if type(var) == "table" then
            H.set_variable_array(name, var)
        else
            wesnoth.set_variable(name, var)
        end
    end
    
    local function handle_attributes(cfg, unit_path, toplevel)
        for current_key, current_value in pairs(H.shallow_parsed(cfg)) do
            if type(current_value) ~= "table" and (not toplevel or current_key ~= "type") then
                wesnoth.set_variable(string.format("%s.%s", unit_path, current_key), current_value)
            end
        end
    end
    
    local function handle_child(cfg, unit_path)
        local children_handled = {}
        local cfg = H.shallow_parsed(cfg)
        handle_attributes(cfg, unit_path)
    
        for current_index, current_table in ipairs(cfg) do
            local current_tag = current_table[1]
            local tag_index = children_handled[current_tag] or 0
            handle_child(current_table[2], string.format("%s.%s[%u]",
                    unit_path, current_tag, tag_index))
            children_handled[current_tag] = tag_index + 1
        end
    end
    
    local function handle_unit(unit_num)
        local children_handled = {}
        local unit_path = string.format("%s[%u]", var, unit_num)
        local this_unit = wesnoth.get_variable(unit_path)
        wesnoth.set_variable("this_unit", this_unit)
        handle_attributes(cfg, unit_path, true)
    
        for current_index, current_table in ipairs(H.shallow_parsed(cfg)) do
            local current_tag = current_table[1]
            if current_tag == "filter" then
                        -- nothing
            elseif current_tag == "object" or current_tag == "trait" then
                local unit = wesnoth.get_variable(unit_path)
                unit = wesnoth.create_unit(unit)
                wesnoth.add_modification(unit, current_tag, current_table[2])
                unit = unit.__cfg;
                wesnoth.set_variable(unit_path, unit)
            else
                local tag_index = children_handled[current_tag] or 0
                handle_child(current_table[2], string.format("%s.%s[%u]",
                        unit_path, current_tag, tag_index))
                children_handled[current_tag] = tag_index + 1
            end
        end
    
        if cfg.type then
            if cfg.type ~= "" then wesnoth.set_variable(unit_path .. ".advances_to", cfg.type) end
            wesnoth.set_variable(unit_path .. ".experience", wesnoth.get_variable(unit_path .. ".max_experience"))
        end
        W.kill({id = this_unit.id, animate = false})
        W.unstore_unit({variable = unit_path})
    end
    
    local max_index = wesnoth.get_variable(var .. ".length") - 1
    
    local this_unit = start_var_scope("this_unit")
    for current_unit = 0, max_index do
        handle_unit(current_unit)
    end
    end_var_scope("this_unit", this_unit)
end


---------------------------------------
-- Custom WML tags
---------------------------------------

-- The from-WML derivative of the "matching attacks exist?" in utilities.lua
function wesnoth.wml_actions.attacks_exist(cfg)
    local unit = wesnoth.get_variable(cfg.store or "unit")
    local filters = cfg.filters
    attacks_exist_to_var(unit, filters, cfg.variable or "drw_attacks_exist")
end