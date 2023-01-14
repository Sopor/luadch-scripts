--[[

    etc_motd.lua by blastbeat

        - this script sends a message to users after login

        v0.08: by Sopor
            - added command to show motd
            - added rightclick
            - added help

        v0.07: by pulsar
            - removed "etc_motd_motd" from "cfg/cfg.tbl"
            - added lang files
                - added banner msg to the lang files

        v0.06: by pulsar
            - possibility to activate/deactivate the script
            - possibility to use %s in the motd to get users nickname (without nicktag)

        v0.05: by pulsar
            - possibility to set target (main/pm/both)  / request by DerWahre
            - add new table lookups
            - code cleaning

        v0.04: by pulsar
            - add user permissions
            - export scriptsettings to "/cfg/cfg.tbl"

        v0.03: by blastbeat
            - clean up

        v0.02: by blastbeat
            - updated script api

]]--


--------------
--[SETTINGS]--
--------------

local scriptname = "etc_motd"
local scriptversion = "0.08"

local cmd1 = "motd"

----------------------------
--[DEFINITION/DECLARATION]--
----------------------------

--// table lookups
local cfg_get = cfg.get
local cfg_loadlanguage = cfg.loadlanguage
local hub_getbot = hub.getbot()
local hub_debug = hub.debug
local utf_format = utf.format

local utf_match = utf.match
local hub_import = hub.import
local util_getlowestlevel = util.getlowestlevel

--// imports
local scriptlang = cfg_get( "language" )
local lang, err = cfg_loadlanguage( scriptlang, scriptname ); lang = lang or { }; err = err and hub_debug( err )
local activate = cfg_get( "etc_motd_activate" )
local permission = cfg_get( "etc_motd_permission" )
local destination_main = cfg_get( "etc_motd_destination_main" )
local destination_pm = cfg_get( "etc_motd_destination_pm" )

local help, ucmd, hubcmd

--// msg
local msg_motd = lang.msg_motd or [[  no rules ]]

local help_title = lang.help_title or "etc_motd.lua"
local help_usage = lang.help_usage or "[+!#]motd"
local help_desc = lang.help_desc or "this script shows the message of the day"
local msg_denied = lang.msg_denied or "You are not allowed to use this command!"
local ucmd_menu1 = lang.ucmd_menu1 or {"General", "MOTD"}

----------
--[CODE]--
----------
local minlevel = util_getlowestlevel( permission )

hub.setlistener("onBroadcast", {},
    function(user, adccmd, txt)
        local msg1 = utf_match(txt, "^[+!#](%a+)")
        local user_level = user:level()
        local user_firstnick = user:firstnick()
        if msg1 == cmd1 then
            if permission[ user_level ] then
                local motd = utf_format( msg_motd, user_firstnick )
                if destination_main then user:reply( motd, hub_getbot ) end
                if destination_pm then user:reply( motd, hub_getbot, hub_getbot ) end
            else
                user:reply(msg_denied, hub_getbot)
            end
            return PROCESSED
        end
        return nil
    end
)

hub.setlistener( "onLogin", {},
    function( user )
        local user_level = user:level()
        local user_firstnick = user:firstnick()
        if activate then
            if permission[ user_level ] then
                local msg = utf_format( msg_motd, user_firstnick )
                if destination_main then user:reply( msg, hub_getbot ) end
                if destination_pm then user:reply( msg, hub_getbot, hub_getbot ) end
            end
        end
        return nil
    end
)

hub.setlistener("onStart", {},
    function()
        help = hub_import( "cmd_help" )
        if help then
            help.reg(help_title, help_usage, help_desc, minlevel)
        end
        ucmd = hub_import "etc_usercommands"
        if ucmd then
            ucmd.add( ucmd_menu1, cmd1, {}, {"CT1"}, minlevel)
        end
        return nil
    end
)

hub_debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )

---------
--[END]--
---------
