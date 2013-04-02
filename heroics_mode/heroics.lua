wesnoth.dofile '~add-ons/Dragonworld/heroics_mode/utility.lua'
wesnoth.dofile '~add-ons/Dragonworld/heroics_mode/wml-tags.lua'


function build_goods_entry(mid, cfg)
    -- Load CFG
    local name, desc = tostring(cfg.name), tostring(cfg.desc)
    local icon, price = tostring(cfg.icon), tostring(cfg.price)
    local id = tostring(cfg.id or "some_item")
    
    local function make_entry(icon, name, desc, price, color)
        -- I think that the UI cramps the two text parts together... 
        -- so here's a hack expander to fix that
        local s = "   "
        -- Colorize is a format()-ready string to add the desired color
        local colorize = "%s"
        if color ~= nil then
            colorize = string.format("<span color='%s'>", color) .. "%s</span>"
        end
        
        local p1 = string.format(
          colorize, string.format("%s\n<small>%s</small>", name, desc)
        )
        local p2 = string.format(colorize, 
                                 string.format("%s<big>%s</big>", s, price))
        
        return string.format("&%s=%s=%s", icon, p1, p2)
    end
    
    -- Green or white? Here we have light green
    local line1 = make_entry(icon, name, desc, price, "#AAFFAA")
    -- Should we use gray or red? Here we have gray
    local line2 = make_entry(icon, name, desc, price, "#A0A0A0")
    
    local show = {
      T.variable {
        name="$drw_curvar", 
        greater_than_equal_to=price
      }
    }
    
    for req_tag in H.child_range(cfg, "requires") do
        for i = 1, #req_tag do
            table.insert(show, req_tag[i])
        end
    end
    
    -- Setup the execute_entry tag for the active option
    local exent = {
      curvar="$drw_curvar", 
      price=price, 
      gid=id, 
      mid=mid
    }
    -- Copy effects
    for effect in H.child_range(cfg, "effect") do
        table.insert(exent, T.effect(effect))
    end
    -- Insert setup and cleanup scripts
    for c in H.child_range(cfg, "before") do
        table.insert(exent, T.before(c))
    end
    for c in H.child_range(cfg, "after") do
        table.insert(exent, T.after(c))
    end
    
    -- Actually construct the options
    local opt1 = T.option {
      message=line1, 
      T.show_if(show), 
      T.command {
        T.execute_entry(exent)
      }
    }
    local opt2 = T.option {
      message=line2, 
      T.show_if {
        T["not"](show)
      },
      T.command {}
    }
    -- Done!
    return opt1, opt2
end


function wesnoth.wml_actions.execute_entry(cfg)
    -- Increment the purchase count
    local gid, mid = cfg.gid, cfg.mid
    local p = drw_path("unit", "upgrades." .. mid)
    if V[p] ~= nil then
        V[p] = V[p] + 1
    else
        V[p] = 1
    end
    p = drw_path("unit", "upgrades." .. gid)
    if V[p] ~= nil then
        V[p] = V[p] + 1
    else
        V[p] = 1
    end
    
    -- Charge the price
    local price = tonumber(cfg.price)
    local var = cfg.curvar
    -- Do the subtraction
    V[var] = V[var] - price
    
    -- Setup
    for c in H.child_range(cfg, "before") do
        W.command(c)
    end

    -- Apply effects
    local objtag = {
      silent=true,
      duration="forever" 
    }
    for effect in H.child_range(cfg, "effect") do
        table.insert(objtag, T.effect(effect))
    end
    
    W.object(objtag)
    
    -- Cleanup
    for c in H.child_range(cfg, "after") do
        W.command(c)
    end
end


local function have_currency(currency, attr, gold)
    if currency == "gold" then
        return gold > 0
    else
        return attr > 0
    end
end


function wesnoth.wml_actions.goods_menu(cfg)
    -- Load CFG
    local name = cfg.name or "Goods Menu"
    local text = cfg.text or "Buy something or finish."
    local currency  = cfg.currency or "gold"
    local id = cfg.id or "some_menu"
    
    -- Setup the message
    local message_wml = {
      side_for="$side_number", 
      speaker="narrator", 
      image="data/campaigns/The_South_Guard/images/portraits/sir-gerrick.png", 
      caption=name, 
      message=text .. "\n(You have $drw_balance left)",
      T.option {
        message="&check.png=I'm done here.", 
        T.command {
          T.set_variable{name="lua_drw_m2_done", value=true}
        }
      }
    }
    
    for entry in H.child_range(cfg, "goods_option") do
        on, off = build_goods_entry(id, entry)
        table.insert(message_wml, on)
        table.insert(message_wml, off)
    end
    
    
    -- Prepare the main loop
    V.lua_drw_m2_done = false
    W.store_unit{T.filter{x=V.x1, y=V.y1}, variable="unit"}
    unit = wesnoth.get_variable("unit[0]")
    local gold = wesnoth.sides[V.side_number].gold
    local index = V.drw_index
    local attr = V[drw_path("unit", "attrs")]
    
    if currency == "gold" then
       V.drw_curvar = "drw_gold"
    else
        V.drw_curvar = drw_path("unit", "attrs")
    end
    
    -- Run the main loop
    while V.lua_drw_m2_done == false and have_currency(currency, attr, gold) do
        -- Set the balance string
        if currency == "gold" then
            V.drw_balance = string.format("%s gold", gold)
        else
            local title
            if attr ~= 1 then
                title = "points"
            else
                title = "point"
            end
            V.drw_balance = string.format("%s attribute %s (for this unit)", 
                                          attr, title)
        end
        
        -- Insert lua variables into wesnoth variables
        V.drw_gold = gold
        -- Create/refresh some common attack existence checks
        attacks_exist_to_var(unit, "range=melee", "drw_have_melee")
        attacks_exist_to_var(unit, "range=ranged", "drw_have_ranged")
        
        -- Display the menu we built
        W.message(message_wml)
        
        -- Refresh our variables
        W.store_unit{T.filter{x=V.x1, y=V.y1}, variable="unit"}
        unit = wesnoth.get_variable("unit[0]")
        gold = V.drw_gold
        attr = V[drw_path("unit", "attrs")]
        wesnoth.sides[V.side_number].gold = gold
        -- Is this necessary?
        W.unstore_unit{variable="unit", find_vacant=false}
        W.redraw()
    end
    -- Wheee! A few variables going here!
    clear_vars({"lua_drw_m2_done", "unit", "drw_curvar", "drw_gold", 
                "drw_have_melee", "drw_have_ranged", "drw_balance"})
end