--[[

    etc_mainecho.lua by pulsar

        v0.5: by Sopor
            - changed: now only compatible with Luadch 3.x and higher

        v0.4:
            - removed table lookups
            - extended database scheme  / idea by Sopor
            - using user:firstnick() instead of user:nick()  / idea by Sopor
            - add command to activate bot sleep mode

        v0.3:
            - cleaning code
            - add table lookups
            - add trigger echoes to table (as value)
            - at possibility to use own botname
            - translate the script to english
            - exclude trigger table to "scripts/data/etc_mainecho.tbl"

        v0.2:
            - added: 'string.lower' function

        v0.1:
            - its a trigger bot :)

]]--


--------------
--[SETTINGS]--
--------------

local scriptname = "etc_mainecho"
local scriptversion = "0.4"

local cmd = "sleep"  -- bot sleep command

local permission = {  --// choose which levels can trigger the bot

    [ 0 ] = false,  -- unreg
    [ 10 ] = false,  -- guest
    [ 20 ] = true,  -- reg
    [ 30 ] = true,  -- vip
    [ 40 ] = true,  -- svip
    [ 50 ] = false,  -- server
    [ 60 ] = true,  -- operator
    [ 70 ] = true,  -- supervisor
    [ 80 ] = true,  -- admin
    [ 100 ] = true,  -- hubowner
}

local minlevel = util.getlowestlevel( permission )  -- permission for the sleep command

local bot_name = "[BOT]Triggy"  -- without whitespaces!
local bot_desc = "[ BOT ] trigger me softly :)"  -- default bot description
local bot_desc_sleep = "[ BOT ] sleeping... (duration: %s)"  -- default bot description while sleeping

local use_own_bot = false  -- if false then the msg will be send from hubbot

local trigger_delay = 3  -- delay for trigger msg in seconds

local sleep_delay = 10  -- bot sleep time after sleep command in minutes
local sleep_msg = "Okay, I'll sleep a bit now..."  -- bot sleep message

local msg_denied = "[ MAINECHO ]--> You are not allowed to use this command."

local ucmd_menu_ct1_1 = { "Hub", "etc", "Mainecho", "bot sleep" }  -- rightclick

--// imports
local echo_file = "scripts/data/etc_mainecho.tbl"
local echo_tbl = util.loadtable( echo_file )


----------
--[CODE]--
----------

local list_trigger_delay, list_sleep_delay = {}, {}  -- for the timer, do not tough this!
local sleep = false
local sleep_delay_seconds = sleep_delay * 60

--// register a new bot
local reg_bot = function()
    local err, bot
    local nick, desc = bot_name, bot_desc
    bot, err = hub.regbot{ nick = nick, desc = desc, client = function( bot, cmd ) return true end }
end

if use_own_bot then reg_bot() end

--// get bot
local botname = function()
    local bot = hub.getbot()
    if use_own_bot then bot = hub.isnickonline( bot_name ) end
    return bot
end

local rnd_start = 0
local rnd = function( num )
    rnd_start = rnd_start + 1
    math.randomseed( os.time() + rnd_start )
    return math.random( 1, num )
end

--// check mainchat
hub.setlistener( "onBroadcast", {},
    function( user, adccmd, txt )
        local user_firstnick = user:firstnick()
        local user_level = user:level()
        local trigger, n
        if permission[ user_level ] then
            for k, v in pairs( echo_tbl ) do
                local s = txt:lower():find( k )
                if s then
                    n = rnd( #echo_tbl[ k ] )
                    trigger = echo_tbl[ k ][ n ]
                    break
                end
            end
            if trigger and ( not sleep ) then
                list_trigger_delay[ os.time() ] = function()
                    local msg = utf.format( trigger, user_firstnick )
                    hub.broadcast( msg, botname() )
                end
            end
        end
        return nil
    end
)

local onbmsg = function( user, command, parameters )
    if user:level() >= minlevel then
        sleep = true
        hub.broadcast( sleep_msg, botname() )
        -- if use_own_bot then
            -- botname():inf():setnp( "DE", hub.escapeto( bot_desc_sleep ) )  -- add sleep desc to bot
            -- hub.sendtoall( "BINF " .. botname():sid() .. " DE" .. hub.escapeto( bot_desc_sleep ) .. "\n" )  -- send desc to all
        -- end
        list_sleep_delay[ os.time() ] = function()
            sleep = false
            if use_own_bot then
                botname():inf():setnp( "DE", hub.escapeto( bot_desc ) )  -- add default desc to bot
                hub.sendtoall( "BINF " .. botname():sid() .. " DE" .. hub.escapeto( bot_desc ) .. "\n" )  -- send desc to all
            end
        end
    else
        user:reply( msg_denied, hub.getbot() )
    end
    return PROCESSED
end

--// timer
hub.setlistener( "onTimer", {},
    function()
        for time, func in pairs( list_trigger_delay ) do  -- timer #1
            if os.time() - time >= trigger_delay then
                func()
                list_trigger_delay[ time ] = nil
            end
        end
        for time, func in pairs( list_sleep_delay ) do  -- timer #2
            if os.time() - time >= sleep_delay_seconds then
                func()
                list_sleep_delay[ time ] = nil
            end
            if os.time() - time < sleep_delay_seconds then
                if use_own_bot then
                    local t = sleep_delay_seconds - ( os.time() - time )
                    local msg = utf.format( bot_desc_sleep, t )
                    botname():inf():setnp( "DE", hub.escapeto( msg ) )
                    hub.sendtoall( "BINF " .. botname():sid() .. " DE" .. hub.escapeto( msg ) .. "\n" )
                end
            end
        end
        return nil
    end
)

hub.setlistener( "onStart", {},
    function()
        local ucmd = hub.import( "etc_usercommands" )    -- add usercommand
        if ucmd then
            ucmd.add( ucmd_menu_ct1_1, cmd, { }, { "CT1" }, minlevel )
        end
        local hubcmd = hub.import( "etc_hubcommands" )    -- add hubcommand
        assert( hubcmd )
        assert( hubcmd.add( cmd, onbmsg ) )
        return nil
    end
)

hub.debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )