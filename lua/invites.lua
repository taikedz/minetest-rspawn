rspawn.invites = {}

-- invitations[guest] = host
rspawn.invitations = {}

local invite_charge = {}

levvy_name = minetest.settings:get("rspawn.levvy_name") or "default:cobble"
levvy_qtty = tonumber(minetest.settings:get("rspawn.levvy_qtty")) or 10
levvy_nicename = "cobblestone"

minetest.after(0,function()
    if minetest.registered_items[levvy_name] then
        levvy_nicename = minetest.registered_nodes[levvy_name].description
    else
        minetest.debug("No such item "..levvy_name.." -- reverting to defaults.")
        levvy_name = "default:cobble"
        levvy_qtty = 99
    end
end)

local function canvisit(hostname, guestname)
    local glist = rspawn.playerspawns["guest lists"][hostname] or {}
    return glist[guestname] == 1
end

local function find_levvy(player)
    -- return itemstack index, and stack itself, with qtty removed
    -- or none if not found/not enough found
    local i

    if not player then
        minetest.log("action", "Tried to access undefined player")
        return false
    end

    local pname = player:get_player_name()
    local player_inv = minetest.get_inventory({type='player', name = pname})
    local total_count = 0

    if not player_inv then
        minetest.log("action", "Could not access inventory for "..pname)
        return false
    end

    for i = 1,32 do
        local itemstack = player_inv:get_stack('main', i)
        local itemname = itemstack:get_name()
        if itemname == levvy_name then
            if itemstack:get_count() >= levvy_qtty then
                return true
            else
                total_count = total_count + itemstack:get_count()

                if total_count >= (levvy_qtty) then
                    return true
                end
            end
        end
    end

    minetest.chat_send_player(pname, "You do not have enough "..levvy_nicename.." to pay the spawn levvy for your invitation.")
    return false
end

function rspawn:consume_levvy(player)
    if not player then
        minetest.log("action", "Tried to access undefined player")
        return false
    end

    local i
    local pname = player:get_player_name()
    local player_inv = minetest.get_inventory({type='player', name = pname})
    local total_count = 0

    -- TODO combine find_levvy and consume_levvy so that we're
    --    not scouring the inventory twice...
    if find_levvy(player) then
        for i = 1,32 do
            local itemstack = player_inv:get_stack('main', i)
            local itemname = itemstack:get_name()
            if itemname == levvy_name then
                if itemstack:get_count() >= levvy_qtty then
                    itemstack:take_item(levvy_qtty)
                    player_inv:set_stack('main', i, itemstack)
                    return true
                else
                    total_count = total_count + itemstack:get_count()
                    itemstack:clear()
                    player_inv:set_stack('main', i, itemstack)

                    if total_count >= (levvy_qtty) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function rspawn.invites:addplayer(hostname, guestname)
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    if guestlist[guestname] == 0 then
        guestlist[guestname] = 1
        minetest.chat_send_player(guestname, hostname.." let you back into their spawn.")

    elseif rspawn:consume_levvy(minetest.get_player_by_name(hostname) ) then -- Automatically notifies host if they don't have enough
        guestlist[guestname] = 1
        minetest.chat_send_player(guestname, hostname.." added you to their spawn! You can now visit them with /spawn visit "..hostname)
    end
    
    minetest.chat_send_player(hostname, guestname.." is allowed to visit your spawn.")
    rspawn.playerspawns["guest lists"][hostname] = guestlist
end

function rspawn.invites:exileplayer(hostname, guestname)
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    if guestlist[guestname] == 1 then
        guestlist[guestname] = 0
        rspawn.playerspawns["guest lists"][hostname] = guestlist

    else
        minetest.chat_send_player(hostname, guestname.." is not in your accepted guests list.")
        return
    end

    minetest.chat_send_player(guestname, hostname.." banishes you!")
    rspawn.invites:kick(hostname, guestname)
end

function rspawn.invites:kick(hostname, guestname)
    local guest = minetest.get_player_by_name(guestname)
    local guestpos = guest:getpos()
    local hostspawnpos = rspawn.playerspawns[hostname]
    local guestspawnpos = rspawn.playerspawns[guestname]

    if vector.distance(guestpos, hostspawnpos) then
        guest:setpos(guestspawnpos)
    end
end

function rspawn.invites:listguests(hostname)
    local guests = ""
    local guestlist = rspawn.playerspawns["guest lists"][hostname] or {}

    for guestname,status in pairs(guestlist) do
        if status == 1 then status = "" else status = " (exiled)"

        guests = ", "..guestname..status
    end

    minetest.chat_send_player(hostname, guests)
end

function rspawn.invites:listhosts(guestname)
    local hosts = ""

    for _,hostname in ipairs(rspawn.playerspawns["guest lists"]) do
        for gname,status in pairs(rspawn.playerspawns["guest lists"][hostname]) do
            if guestname == gname then
                if status == 1 then status = "" else status = " (exiled)"

                hosts = ", "..hostname..status
            end
        end
    end

    minetest.chat_send_player(guestname, hosts)
end

function rspawn.invites:visitplayer(hostname, guestname)
    local guest = minetest.get_player_by_name(guestname)
    local hostpos = rspawn.playerspawns[hostname]

    if guest and hostpos and canvisit(hostname, guestname) then
        guest:setpos(hostpos)
    else
        minetest.log("error", "[rspawn] Missing spawn position data for "..hostname)
        minetest.chat_send_player(guestname, "Could not find spawn position for "..hostname)
    end
end
