--[[

    usr_upload_speed.lua

        - This script compares the speed prefix and Upload Speed from INF US field.
          If the speed prefix doesn't match the upload speed the user may have activated the built-in limiter in AirDC++ or Web Client.
          Should work with hubs that add a speed value as well, such as [100Mbit].

         - v0.8: by Sopor
             - should be used together with the included etc_trafficmanager.lua v2.2.3
             - using CID to remove old blocks after a user got a new prefix
             - not announce a blocked user again after +reload
             - added ban_interval
             - cleaning up some unnecessary code

         - v0.7: by Sopor
             - no longer removing the speed prefix when blocking a user

        - v0.6: by Sopor
            - added DC++/ApexDC++/EiskaltDC++, but they need to use the limiter (Maximum Upload Rate) for speeds that doesn't exists in the line speed

        - v0.5: by Sopor
            - warn user, grace period (same as opchat_interval), then block downloads, unblock if prefix and US match again

        - v0.4: by Sopor
            - less spam in OpChat by adding opchat_interval

        - v0.3: by Sopor
            - should only check AirDC++ and AirDC++w
            - should announce in OpChat too low and too high prefix/US

        - v0.2: by Sopor
            - should not generate any errors if the user/bot has no US

        - v0.1: by Sopor
            - initial version, a script to detect upload speed difference from prefix and INF US field

]]--

local scriptname = "usr_upload_speed"
local scriptversion = "0.8"

--// "AirDC" = only AirDC++/Web Client / "both" = AirDC++/Web Client + DC++/ApexDC++/EiskaltDC++ //--
local check_client = "both"

--// DC++ INF US lookup table (prefix - INF US) //--
local dcpp_us_table = {
    [1]    = 131072,       -- if you need additional speeds, you have to calculate them by yourself and add them
    [2]    = 262144,
    [5]    = 655360,       -- to calculate the 'Maximum Upload Rate' for clients with fixed 'Line speed (upload)' like DC++/ApexDC++/EiskaltDC++ ..
    [10]   = 1310720,      -- you need to take the speed in Mbit, multiply it by 131072 to get bytes per second and divide that number by 1024 to get KiB/s
    [20]   = 2621440,      -- in the dcpp_us_table add [speed] = bytes, and tell the user to put the KiB/s in their DC++/ApexDC++/EiskaltDC++ client at the 'Maximum Upload Rate'
    [50]   = 6553600,
    [100]  = 13107200,
    [150]  = 19660800,      -- for DC++/ApexDC++/EiskaltDC++ tell the user to add 19200 to the 'Maximum Upload Rate' in their client
    [250]  = 32768000,      -- for DC++/ApexDC++/EiskaltDC++ tell the user to add 32000 to the 'Maximum Upload Rate' in their client
    [300]  = 39321600,      -- for DC++/ApexDC++/EiskaltDC++ tell the user to add 38400 to the 'Maximum Upload Rate' in their client
    [500]  = 65536000,      -- for DC++/ApexDC++/EiskaltDC++ tell the user to add 64000 to the 'Maximum Upload Rate' in their client
    [600]  = 78643200,      -- for DC++/ApexDC++/EiskaltDC++ tell the user to add 76800 to the 'Maximum Upload Rate' in their client
    [1000] = 131072000,
}

local exludedlevels = { --// 0 = included / 1 = excluded //--
    [ 0 ]   = 1, -- unreg
    [ 10 ]  = 1, -- guest
    [ 20 ]  = 0, -- reg
    [ 30 ]  = 0, -- vip
    [ 40 ]  = 0, -- svip
    [ 50 ]  = 1, -- server
    [ 55 ]  = 1, -- sbot
    [ 60 ]  = 1, -- operator
    [ 70 ]  = 1, -- supervisor
    [ 80 ]  = 1, -- admin
    [ 100 ] = 1, -- hubowner
}

local allowed_percentage = 0 --// percentage between prefix and upload speed (default: 0) //--
local opchat_interval = 1800 --// time in seconds before the next OP message (default: 3600) //--
local ban_interval = 3600 --// seconds before automatic block (default: 3600 / 0 = disable automatic block) //--

local cfg_get = cfg.get
local hub_debug = hub.debug
local hub_getusers = hub.getusers
local opchat = hub.import "bot_opchat"
local block = hub.import "etc_trafficmanager"
local getbot = hub.getbot
local util = util

local last_announce = {}
local mismatch_state = {}
local warn_time = {}

local blocked_cids_file = "scripts/data/usr_upload_speed_cids.tbl"

local blocked_cids = {}
local function load_cids()
    local f = loadfile(blocked_cids_file)
    if f then
        local t = f()
        if type(t) == "table" then
            blocked_cids = t
        end
    end
end

local function save_cids()
    local f = io.open(blocked_cids_file, "w")
    if not f then return end

    f:write("return {\n")

    for cid, v in pairs(blocked_cids) do
        f:write(string.format( '    ["%s"] = { nick = %q, reason = %q, time = %d },\n', cid, v.nick, v.reason, v.time ))
    end

    f:write("}\n")
    f:close()
end

local matchUser = function(user)
    local inf = user:inf()
    if not inf then
        warn_time[user:nick()] = nil
        return nil
    end

    local USpeed = tonumber(inf:getnp("US"))
    local USpeedString
    if type(USpeed) == "number" then
        USpeedString = string.format("%.2f", (USpeed / 1000 / 1000) * 8)
    else
        USpeedString = inf:getnp("US") or "N/A"
    end

    local prefix = string.match(user:nick(), "^(%b[])[^ ]+")
    if not prefix then
        mismatch_state[user:nick()] = nil
        warn_time[user:nick()] = nil
        return nil
    end

    local version = user:version() or ""

    local is_airdc = string.match(version, "^AirDC%+%+")
    local is_dcpp =
        string.match(version, "%+%+") or
        string.match(version, "ApexDC%+%+") or
        string.match(version, "EiskaltDC%+%+")

    if check_client == "AirDC" then
        if not is_airdc then
            mismatch_state[user:nick()] = nil
            warn_time[user:nick()] = nil
            return nil
        end
    elseif check_client == "both" then
        if not (is_airdc or is_dcpp) then
            mismatch_state[user:nick()] = nil
            warn_time[user:nick()] = nil
            return nil
        end
    end

    local speed_prefix = string.match(prefix, "(%d+)")
    if not speed_prefix or not USpeed then
        mismatch_state[user:nick()] = nil
        warn_time[user:nick()] = nil
        return nil
    end

    local nick = user:nick()
    local cid = user:cid()

    local entry = blocked_cids[cid]

    if entry and entry.nick ~= nick then
    local ok = pcall(function() block.del(entry.nick, scriptname) end)

    if ok then
        blocked_cids[cid] = nil
        save_cids()
    end
end
    local already_blocked = false

    if block and type(block.is_blocked) == "function" then
        already_blocked = block.is_blocked(nick)
    end
    local level = nil
    pcall(function() level = user:level() end)
    if level and exludedlevels[level] == 1 then
        mismatch_state[nick] = nil
        warn_time[nick] = nil
        return nil
    end

    local USpeedPrefix

    -- AirDC++ calculation
    if is_airdc then
        USpeedPrefix = (tonumber(speed_prefix) * 1000 * 1000) / 8
    else
        -- DC++ family via lookup table
        USpeedPrefix = dcpp_us_table[tonumber(speed_prefix)]
        if not USpeedPrefix then
            mismatch_state[nick] = nil
            warn_time[nick] = nil
            return nil
        end
    end

    if tonumber(USpeed) > USpeedPrefix then
        mismatch_state[nick] =
            "[ SPEED PREFIX ]--> The user " .. nick .. " has a lower PREFIX than INF. - PREFIX: " .. prefix .. " INF: " .. USpeedString

        if (not already_blocked) and (not warn_time[nick]) then
            warn_time[nick] = os.time()
            if user and type(user.reply) == "function" then
                pcall(function()
                    if ban_interval == 0 then
                        user:reply( "\n\n[ SPEED PREFIX ]--> WARNING: your UPLOAD SPEED (" .. USpeedString .. ") is higher than your PREFIX (" .. tostring(speed_prefix) .. "). Please correct your speed prefix.\n\n" ..
                            "[ SPEED PREFIX ]--> VARNING: din UPPLADDNINGSHASTIGHET (" .. USpeedString .. ") är högre än ditt PREFIX (" .. tostring(speed_prefix) .. "). Vänligen korrigera ditt hastighetsprefix.\n", getbot(), getbot() )
                    else
                        user:reply( "\n\n[ SPEED PREFIX ]--> WARNING: your UPLOAD SPEED (" .. USpeedString .. ") is higher than your PREFIX (" .. tostring(speed_prefix) .. "). Fix this within " .. tostring(math.ceil(ban_interval / 60)) .. " minute(s) or you will be blocked.\n\n" ..
                            "[ SPEED PREFIX ]--> VARNING: din UPPLADDNINGSHASTIGHET (" .. USpeedString .. ") är högre än ditt PREFIX (" .. tostring(speed_prefix) .. "). Fixa detta inom " .. tostring(math.ceil(ban_interval / 60)) .. " minut(er) eller så kommer du att bli blockerad.\n", getbot(), getbot() )
                    end
                end)
            end
        end
        return nil
    end

    local diff = USpeedPrefix - USpeed
    if (diff * 100 / USpeedPrefix) > allowed_percentage then
        mismatch_state[nick] =
            "[ SPEED PREFIX ]--> The user " .. nick .. " has a higher PREFIX than INF. - PREFIX: " .. prefix .. " INF: " .. USpeedString

        if (not already_blocked) and (not warn_time[nick]) then
            warn_time[nick] = os.time()
            if user and type(user.reply) == "function" then
                pcall(function()
                    if ban_interval == 0 then
                        user:reply( "\n\n[ SPEED PREFIX ]--> WARNING: your PREFIX (" .. tostring(speed_prefix) .. ") is higher than your UPLOAD SPEED (" .. USpeedString .. "). Please correct your speed prefix.\n\n" ..
                            "[ SPEED PREFIX ]--> VARNING: ditt PREFIX (" .. tostring(speed_prefix) .. ") är högre än din UPPLADDNINGSHASTIGHET (" .. USpeedString .. "). Vänligen korrigera ditt hastighetsprefix.\n", getbot(), getbot() )
                    else
                        user:reply( "\n\n[ SPEED PREFIX ]--> WARNING: your PREFIX (" .. tostring(speed_prefix) .. ") is higher than your UPLOAD SPEED (" .. USpeedString .. "). Fix this within " .. tostring(math.ceil(ban_interval / 60)) .. " minute(s) or you will be blocked.\n\n" ..
                            "[ SPEED PREFIX ]--> VARNING: ditt PREFIX (" .. tostring(speed_prefix) .. ") är högre än din UPPLADDNINGSHASTIGHET (" .. USpeedString .. "). Fixa detta inom " .. tostring(math.ceil(ban_interval / 60)) .. " minut(er) eller du kommer att bli blockerad.\n", getbot(), getbot() )
                    end
                end)
            end
        end
    else
        mismatch_state[nick] = nil
        warn_time[nick] = nil

        local firstnick = nick
        local block_file = "scripts/data/etc_trafficmanager.tbl"
        local ok, blocked_tbl = pcall(function() return util.loadtable(block_file) end)
        if ok and type(blocked_tbl) == "table" and blocked_tbl[firstnick] ~= nil then
            if block and type(block.del) == "function" then
                local ok2, res2 = pcall(function() return block.del(firstnick, scriptname) end)
                local ok3, blocked_tbl2 = pcall(function() return util.loadtable(block_file) end)
                if ok3 and type(blocked_tbl2) == "table" and blocked_tbl2[firstnick] == nil then
                    blocked_cids[user:cid()] = nil
                    save_cids()
                    pcall(function()
                        if opchat and type(opchat.feed) == "function" then
                            opchat.feed("[ SPEED PREFIX ]--> User " .. tostring(firstnick) .. " has been unblocked: PREFIX matches UPLOAD SPEED.")
                        end
                    end)
                    if user and type(user.reply) == "function" then
                        pcall(function()
                            user:reply("\n\n[ SPEED PREFIX ]--> You have been unblocked: your PREFIX now matches your UPLOAD SPEED.\n\n" ..
                            "[ SPEED PREFIX ]--> Du har blivit avblockerad: ditt PREFIX matchar nu din UPPLADDNINGSHASTIGHET.\n", getbot(), getbot())
                        end)
                    end
                end
            end
        end
    end

    return nil
end

hub.setlistener("onStart", {},
    function()
        load_cids()
        for sid, user in pairs(hub_getusers()) do
            matchUser(user)
        end
        return nil
    end
)

hub.setlistener("onExit", {},
    function()
        return nil
    end
)

hub.setlistener("onInf", {},
    function(user, cmd)
        matchUser(user)
        return nil
    end
)

hub.setlistener("onTimer", {},
    function()
        local now = os.time()
        for nick, msg in pairs(mismatch_state) do
        local target_user = nil

        for sid, u in pairs(hub_getusers()) do
            if u:nick() == nick then
                target_user = u
                break
            end
        end

        -- User is no longer online
        if not target_user then
            mismatch_state[nick] = nil
            warn_time[nick] = nil
            last_announce[nick] = nil
        else
            local blocked = false
            if block and type(block.is_blocked) == "function" then
                blocked = block.is_blocked(nick)
            end
            if (not blocked) and (not last_announce[nick] or (now - last_announce[nick]) >= opchat_interval) then
                pcall(function() if opchat and type(opchat.feed) == "function" then opchat.feed(msg) end end)
                last_announce[nick] = now
            end
            local w = warn_time[nick]

            if ban_interval == 0 then
                -- automatic blocking disabled
            elseif not w or (now - w) < ban_interval then
            else
                local target_user = nil
                for sid, u in pairs(hub_getusers()) do
                    if u:nick() == nick then
                        target_user = u
                        break
                    end
                end
                local target_firstnick = nick
                if block and type(block.add) == "function" then
                    local reason = "Upload speed mismatch - PREFIX vs UPLOAD SPEED"
                    local ok, res = pcall(function() return block.add(target_firstnick, scriptname, reason) end)
                    local block_file = "scripts/data/etc_trafficmanager.tbl"
                    local ok2, blocked_tbl = pcall(function() return util.loadtable(block_file) end)
                    if ok2 and type(blocked_tbl) == "table" and blocked_tbl[target_firstnick] ~= nil then
                        if target_user then
                            blocked_cids[target_user:cid()] = {
                                nick = target_firstnick,
                                reason = reason,
                                time = os.time(),
                            }
                            save_cids()
                        end

                        mismatch_state[nick] = nil
                        warn_time[nick] = nil
                        last_announce[nick] = now
                        pcall(function()
                            if opchat and type(opchat.feed) == "function" then
                                opchat.feed("[ SPEED PREFIX ]--> User " .. tostring(target_firstnick) .. " has been blocked due to upload speed mismatch.")
                            end
                        end)
                        if target_user and type(target_user.reply) == "function" then
                            pcall(function()
                                target_user:reply("\n\n[ SPEED PREFIX ]--> You were blocked due to upload speed mismatch. Contact an operator if you have got a faster upload speed, so we can change your prefix.\n\n" ..
                                "[ SPEED PREFIX ]--> Du blev blockerad på grund av att uppladdningshastigheten inte stämmer. Kontakta en operatör om du har en snabbare uppladdningshastighet, så att vi kan ändra ditt prefix.\n", getbot(), getbot())
                            end)
                        end
                    end
                end
            end
        end
      end
        return nil
    end
)

hub_debug("** Loaded " .. scriptname .. " " .. scriptversion .. " **")
