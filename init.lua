-- Boosts Mod for Minetest
-- Copyright © 2022 activivan

-- PLEASE READ README.md CAREFULLY AND CONFIGURE YOUR BOOSTS IN boosts.lua


-- ---------------------------
-- Utilities

local S = minetest.get_translator(minetest.get_current_modname())

local function set_priv(name, priv, value)
    local privs = minetest.get_player_privs(name)

    privs[priv] = value

    minetest.set_player_privs(name, privs)
end

local function table_contains(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

local function get_index(key, table)
    local index = nil
    for i, v in ipairs(table) do
        if v == key then
            index = i
        end
    end
    return index
end

local function index_table(t)
    local tkeys = {}
    for k in pairs(t) do 
        table.insert(tkeys, k) 
    end
    table.sort(tkeys)
    local indexed = {}
    for _, k in ipairs(tkeys) do
        indexed[_] = {
            key = k,
            value = t[k]
        }
    end
    return indexed
end

local function get_table_length(table)
    if not table then
        return 0
    end
    local count = 0
    for _ in pairs(table) do count = count + 1 end
    return count
end


-- ---------------------------
-- Import boosts config

local boosts = dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/boosts.lua") or {}

local worldboosts_file = io.open(minetest.get_worldpath() .. "/boosts.lua", "r")

if worldboosts_file then
    boosts = loadstring(worldboosts_file:read("*all"))() or {}
    worldboosts_file.close()
    minetest.log("action", "[Boosts] Using world-specific boosts configuration")
end

if get_table_length(boosts) == 0 then
    minetest.log("warning", "[Boosts] No boosts configured")
end


-- ---------------------------
-- Payment integrations

local money_mod = nil

local currency = "€"

local money_providers = {
    jeans_economy = function(name, amount, boost)
        return jeans_economy.book(name, "!SERVER!", amount, S("@1 boost", boost ))
    end,
    money = function(name, amount, boost)
        local balance = money_mod.get(name)

        if balance - amount >= 0 then
            local new_balance = balance - amount
            money_mod.set(name, new_balance)
            return true
        else
            return false
        end
    end
}

local function get_money_provider()
    if money_mod then
        return money_providers["money"]
    elseif minetest.get_modpath("jeans_economy") then
        return money_providers["jeans_economy"]
    else
        return nil
    end
end

local function pay_money(player, boost)
    local name = player:get_player_name()
    local provider = get_money_provider()

    if not provider then
        return false
    end

    local res = provider(name, boosts[boost]["cost"]["amount"], boost)

    if res then
        return true
    else
        minetest.chat_send_player(name, S("You don't have enough money for a @1 boost!", boost))
        return false
    end
end

local function pay_item(player, boost)
    local inv = player:get_inventory()

    local stack = ItemStack(boosts[boost]["cost"]["stack"]["item"])
    stack:set_count(boosts[boost]["cost"]["stack"]["count"])

    if inv:contains_item("main", stack) then
        inv:remove_item("main", stack)
        return true
    else
        minetest.chat_send_player(player:get_player_name(), S("You need @1x @2 in your inventory for a @3 boost!", stack:get_count(), stack:get_description(), boost))
        return false
    end
end


-- ---------------------------
-- Boost handling

local function activate_boost(player, boost, active_boosts)
    local name = player:get_player_name()
    local pmeta = player:get_meta()

    table.insert(active_boosts, boost)
    pmeta:set_string("boosts:active_boosts", minetest.serialize(active_boosts))

    set_priv(name, boosts[boost]["priv"], true)

    local minutes = boosts[boost]["duration"] / 60
    minetest.chat_send_player(name, S("You now have a @1 boost for @2 minutes!", boost, minutes))

    minetest.after(boosts[boost]["duration"] - 5, function()
        if minetest.get_player_by_name(name) then -- check for player going offline
            active_boosts = minetest.deserialize(pmeta:get_string("boosts:active_boosts"))

            if get_table_length(active_boosts) > 0 then -- check if active boosts have been removed
                minetest.chat_send_player(name, S("Your @1 boost expires in 5 seconds!", boost))
            
                minetest.after(5, function()
                    if minetest.get_player_by_name(name) then
                        set_priv(name, boosts[boost]["priv"], nil)

                        active_boosts = minetest.deserialize(pmeta:get_string("boosts:active_boosts"))

                        if get_table_length(active_boosts) > 0 then
                            table.remove(active_boosts, get_index(boost, active_boosts))
                            pmeta:set_string("boosts:active_boosts", minetest.serialize(active_boosts))
                
                            minetest.chat_send_player(name, S("Your @1 boost expired!", boost))
                            minetest.log("action", "[Boosts] "..boost.." boost of "..name.." expired")
                        end
                    end
                end)
            end
        end
    end)
end

local function buy_boost(payor_name, receiver_name, boost, pay)
    local payor = minetest.get_player_by_name(payor_name) 
    local receiver = minetest.get_player_by_name(receiver_name)

    if not payor then
        return false, S("You must be online to buy boosts!")
    end

    if not receiver and payor_name ~= receiver_name then
        return false, S("Player @1 must be online to get boosted!", receiver_name)
    end

    local rmeta = receiver:get_meta()

    local active_boosts = minetest.deserialize(rmeta:get_string("boosts:active_boosts"))
    
    if active_boosts == nil or active_boosts == "" then
        active_boosts = {}
    end

    if table_contains(active_boosts, boost) then
        return false, (payor_name == receiver_name and S("You already have a @1 boost!", boost) or S("Player @1 already has a @2 boost!", receiver_name, boost))
    else
        if minetest.get_player_privs(receiver_name)[boosts[boost]["priv"]] ~= nil then
            return false, (payor_name == receiver_name and S("You already got the @1 privilege!", boosts[boost]["priv"]) or S("Player @1 already got the @2 privilege!", receiver_name, boosts[boost]["priv"]))
        else
            if pay and boosts[boost]["cost"] then
                local payment = nil

                if boosts[boost]["cost"]["type"] == "money" then
                    payment = pay_money(payor, boost)
                else
                    payment = pay_item(payor, boost)
                end

                if not payment then
                    return false
                end
            end

            if payor_name ~= receiver_name then
                minetest.chat_send_player(payor_name, S("You gifted player @1 a @2 boost!", receiver_name, boost))
                minetest.chat_send_player(receiver_name, S("Player @1 gifted you a @2-boost!", payor_name, boost))
                minetest.log("action", "[Boosts] "..payor_name.." gifted "..receiver_name.." a "..boost.." boost")
            else
                minetest.log("action", "[Boosts] "..receiver_name.." bought a "..boost.." boost")
            end

            activate_boost(receiver, boost, active_boosts)

            return true
        end
    end
end


-- ---------------------------
-- Registrations

minetest.register_privilege("booster", {
	description = S("Buy and gift boosts for free."),
	give_to_singleplayer = false,
})

minetest.register_chatcommand("boost", {
    params = "buy <boost> | gift <player> <boost>",
    description = S("Buy or gift a boost. Available boosts are listed at /boosts"),
	privs = {},
	func = function(name, param)
        local params = param:split(" ")

        if not params[1] or (params[1] ~= "buy" and params[1] ~= "gift") then
            return false, S("The boost command has been used incorrectly: @1 Help: /help boost", S("Please enter a valid command!"))
        end

        local boost = ""

        local receiver_name = name

        if params[1] == "buy" then
            boost = params[2]
        else
            if params[2] == "" or params[2] == nil or core.get_auth_handler().get_auth(params[2]) == nil then
                return false, S("The boost command has been used incorrectly: @1 Help: /help boost", S("Please enter a valid player!"))
            end
            receiver_name = params[2]
            boost = params[3]
        end

        if boost == "" or boost == nil or boosts[boost] == nil then
            return false, S("The boost command has been used incorrectly: @1 Help: /help boost", S("Please enter a valid boost!"))
        end

        local res, msg = buy_boost(name, receiver_name, boost, (minetest.get_player_privs(name).booster and false or true))

        if not res then
            return true, msg
        else
            return true, ""
        end
	end,
})

local function boosts_formspec(selected)
    local boosts_list = ""
    local boosts_indexed = index_table(boosts)

    for k, v in pairs(boosts_indexed) do
        if k > 1 then
            boosts_list = boosts_list .. ","
        end
        boosts_list = boosts_list .. v["key"]
    end

    local boost = boosts_indexed[selected]
    
    return (
        "formspec_version[6]" ..
        "size[10,5]" ..
        "label[0.5,0.5;"..S("Available boosts").."]" ..
        "textlist[0.5,1;4.5,3.5;selected;"..boosts_list..";"..selected..";false]" ..
        "label[5.5,1.2;"..S("@1 boost", boost["key"]).."]" ..
        "label[5.5,2.1;"..S("Privilege: @1", boost["value"]["priv"]).."]" ..
        "label[5.5,2.5;"..S("Duration: @1 minutes", (boost["value"]["duration"] / 60)).."]" ..
        "label[5.5,3.1;"..S("Cost: @1", (boost["value"]["cost"] and (boost["value"]["cost"]["type"] == "item" and boost["value"]["cost"]["stack"]["count"].."x "..(ItemStack(boost["value"]["cost"]["stack"]["item"])):get_description() or boost["value"]["cost"]["amount"].." "..currency) or S("free"))).."]" ..
        "button_exit[5.5,3.7;3,0.8;buy;Buy "..boost["key"].."]" -- No localization because translation is client-side
    )
end

minetest.register_chatcommand("boosts", {
    description = S("Lists available boosts."),
    privs = {},
    func = function(name)
        if get_table_length(boosts) > 0 then
            minetest.show_formspec(name, "boosts:available_boosts", boosts_formspec(1))
	        return true, ""
        else
            return false, S("No boosts available!")
        end
    end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "boosts:available_boosts" then
        return
    end

    local name = player:get_player_name()

    if fields.selected then
        local event = minetest.explode_textlist_event(fields.selected)

        if event.type == "CHG" then
            minetest.show_formspec(name, "boosts:available_boosts", boosts_formspec(event.index))
        end
    end

    if fields.buy then
        local res, msg = buy_boost(name, name, fields.buy:gsub("Buy ", ""), (minetest.get_player_privs(name).booster and false or true))

        if not res and msg then
            minetest.chat_send_player(name, msg)
        end
    end
end)

-- Remove boosts in case of rejoin
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    local pmeta = player:get_meta()
    local active_boosts = minetest.deserialize(pmeta:get_string("boosts:active_boosts"))
        
    if active_boosts ~= nil then
        if get_table_length(active_boosts) > 0 then
            minetest.log("action", "[Boosts] Removing active boosts of "..name.." from previous session")
        end
        for i in ipairs(active_boosts) do
            if boosts[active_boosts[i]] then
                set_priv(name, boosts[active_boosts[i]]["priv"], nil)
                minetest.chat_send_player(name, S("Your @1 boost from your previous session has been removed!", active_boosts[i]))
            else
                minetest.log("error", "[Boosts] Couldn't remove active "..active_boosts[i].." boost of "..name.." from previous session: Configuration of boost not found. "..name.." still has the privilege of a "..active_boosts[i].." boost!")
            end
            table.remove(active_boosts, get_index(active_boosts[i], active_boosts))
        end
        pmeta:set_string("boosts:active_boosts", minetest.serialize(active_boosts))
    end
end)


-- ---------------------------
-- Check boosts config

local function check_boost(boost)
    if boost["priv"] == nil or boost["cost"] == nil or boost["duration"] == nil then
        return "Incomplete configuration"
    end

    if boost["duration"] <= 0 then
        return "Invalid duration"
    end

    if minetest.registered_privileges[boost["priv"]] == nil then
        return "Assigned privilege not found"

    end
    
    if boost["cost"] then
        if boost["cost"]["type"] == nil then
            return "Cost type required"
        end

        if boost["cost"]["type"] == "item" then
            if boost["cost"]["stack"] == nil then
                return "ItemStack required"
            end

            if boost["cost"]["stack"]["item"] == nil or boost["cost"]["stack"]["count"] == nil then
                return "ItemStack incomplete"
            end

            if boost["cost"]["stack"]["count"] < 1 then
                return "Invalid item count"
            end

            if not (ItemStack(boost["cost"]["stack"]["item"])):is_known() then
                return "Item not found"
            end

            return true
        else
            if boost["cost"]["amount"] == nil then
                return "Money amount required"
            end

            if boost["cost"]["amount"] < 0 then
                return "Invalid money amount"
            end

            if boost["cost"]["amount"] == 0 then
                return "Money amount is set to zero. For a boost to be free, set cost to false instead."
            end

            return true, true
        end
    end

    return true
end

local function check_boosts()
    local use_money = false
    local provider = get_money_provider()

    for boost, definition in pairs(boosts) do
        local result, cost_money = check_boost(definition)

        if result ~= true then
            boosts[boost] = nil
            minetest.log("error", "[Boosts] Configuration error with "..boost.." boost: "..result)
        end

        if cost_money then
            use_money = true

            if provider == nil then
                boosts[boost] = nil
            end
        end
    end

    if use_money then
        if provider == nil then
            minetest.log("error", "[Boosts] Boost(s) with money payment, but no supported money mod found! If using item-based money mods like currency, please use the \"item\" cost type.")
        end
    end
end

minetest.register_on_mods_loaded(function()    
    if minetest.get_modpath("money") then
        money.version = 1
        if not money.get or not money.set then
            money.get = money.get_money
            money.set = money.set_money
        end
        money_mod = money
    elseif minetest.get_modpath("money2") then
        money_mod = money2
    elseif minetest.get_modpath("money3") then
        money_mod = money3
    end

    if minetest.settings:get("currency") then
        currency = minetest.settings:get("currency")
    elseif money_mod then
        if money_mod.version > 1 then
            currency = money_mod.currency_name
        elseif CURRENCY_PREFIX then
            currency = CURRENCY_PREFIX
        end
    else
        currency = "Minegeld"
    end

    check_boosts()
end)
