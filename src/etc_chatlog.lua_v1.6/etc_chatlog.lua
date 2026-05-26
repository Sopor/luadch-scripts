--[[

    etc_chatlog.lua by Motnahp

        v1.6: by Sopor
            - etc_nospam.lua is now included to prevent blocked messages to be sent to history log
            - ptx_mainchatblockclean.lua is now included and will clear history log after a main chat clean
              NOTE: if you are running etc_nospam.lua and/or ptx_mainchatblockclean.lua you need to remove them from cfg.tbl
            - blocks message with too many characters
            - blocks message with too many rows (line breaks)
            - tell level 60 and above when someone gets blocked
            - send logs and warnings to Hubbot and/or OPChat
            - usage will now show different commands for users and ops

       v1.51: by Sopor
            - temporary fix for: etc_chatlog.lua:299: bad argument #1 to 'byte' (string expected, got nil) (listener: onBroadcast; script: 'etc_chatlog.lua')
                - fix: https://github.com/luadch/luadch/issues/211

        v1.5: by pulsar
            - suppresses the output if there are no entries
            - changed some visuals

        v1.4: by pulsar
            - better command check
                - fix: #162 -> https://github.com/luadch/luadch/issues/162
            - removed "max_characters" functionality from code
                - fix: #62 -> https://github.com/luadch/luadch/issues/62
                - fix: #158 -> https://github.com/luadch/luadch/issues/158

        v1.3: by pulsar
            - set "saveit" to 1
            - changed visuals

        v1.2: by pulsar
            - removed table lookups
            - prevent users who do not have the permission to chat in the main (etc_msgmanager_permission_main) not to be logged

        v1.1: by pulsar
            - fix #62 / thx Sopor
                - added "max_characters" for default amount of characters for each post at Login

        v1.0: by pulsar
            - fix missing permission check in "onLogin" listener  / thx Sopor

        v0.9: by pulsar
            - removed "etc_chatlog_min_level" import
                - using util.getlowestlevel( tbl ) instead of "etc_chatlog_min_level"

        v0.8: by pulsar
            - change date style
            - remove dateparser() function

        v0.7: by Motnahp
            - fix permission vars

        v0.6: by pulsar
            - changed visual output style

        v0.5: by pulsar
            - changed visual output style

        v0.4: by pulsar
            - add lang feature
            - code cleaning
            - table lookups
            - export scriptsettings to "cfg/cfg.tbl"

        v0.3: by Motnahp
            - changed save methode -> no more (failed) commands will be logged

        v0.2: by Motnahp
            - cleanup and improved performance

        v0.1: by Motnahp
            - logs mainchat to table
            - logs exceptions, because not everyone wants to see chathistory on login
            - adds commands [+!#]history [show|toggle|reset_t_logs|reset_t_exceptions|showexceptions]
                > explained in Settings > help msgs >
            - adds help for commands
            - adds ucmd

]]--

--// settings

local scriptname = "etc_chatlog"
local scriptversion = "1.6"

local cmd = "history"

--// cmd parameters
local prm1 = "show"
local prm2 = "toggle"
local prm3 = "reset_t_logs"
local prm4 = "reset_t_exceptions"
local prm5 = "showexceptions"

--// permissions
local min_level_adv = cfg.get( "etc_chatlog_min_level_adv" )
local permission = cfg.get( "etc_chatlog_permission" )
local max_lines = cfg.get( "etc_chatlog_max_lines" )
local default_lines = cfg.get( "etc_chatlog_default_lines" )

--// imports
local hubcmd, help

--// mainchat clean settings
local nospam = {

    iMaxChars = 2048, -- maximum characters in one sentence
    iMaxRows  = 10,   -- maximum lines (new lines)

    iTime  = 5,       -- seconds before the exact same characters can be sent again
    iCount = 1,

    report_activate = true,  -- if you want to see who is getting blocked (true/false)
    report_level    = 60,    -- should be level 60 or higher
    report_hubbot   = true,  -- send who is getting blocked to hubbot (true/false)
    report_opchat   = false, -- send who is getting blocked to OPChat (true/false)

    exludePro = {
        [ 0 ]   = 0, -- unreg
        [ 10 ]  = 0, -- guest
        [ 20 ]  = 0, -- reg
        [ 30 ]  = 0, -- vip
        [ 40 ]  = 0, -- svip
        [ 50 ]  = 1, -- server
        [ 55 ]  = 1, -- sbot
        [ 60 ]  = 1, -- operator
        [ 70 ]  = 1, -- supervis
        [ 80 ]  = 1, -- admin
        [ 100 ] = 0, -- hubowner
    },

    -- excluded users (use all lowercase)
    exludeUser = {
        -- ["username"] = true,

        },
}

--// mainchat clean settings
local mainchat_cmd = "mainchat"
local mainchat_clean = "clean"
local mainchat_clean_level = 100 -- who should be able to perform a mainchat clean
local show_user = true           -- show who has performed the mainchat clean (true/false)

local sBot = hub.getbot()
local report = hub.import("etc_report")
local tSpamUsers = {}

--// mainchat locked
local mainchat_locked = false

--// local tabels and storage paths --
local exceptions_path = "scripts/data/etc_chatlog_exceptions.tbl"
local log_path = "scripts/data/etc_chatlog_log.tbl"
local t_exceptions = util.loadtable( exceptions_path ) or { }  -- load the exceptions
local t_log = util.loadtable( log_path ) or { }  -- load the log
local msgmanager_permission = cfg.get( "etc_msgmanager_permission_main" )

--// functions
local buildlog
local show_t_exceptions

--// variables
local savehistory = 0
local saveit = 1  -- chat arrivals to save t_log

local scriptlang = cfg.get "language"
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or { }; err = err and hub.debug( err )

--// msgs
local help_title = lang.help_title or "Chatlog for Regs"  -- for regs
local help_usage = lang.help_usage or "[+!#]history show [<lines>] or [+!#]history toggle"
local help_desc = lang.help_desc or "Shows the last written messages in mainchat, you can toggle it on/off."

local help_titleo = lang.help_titleo or "Chatlog for Owners"  -- for owner
local help_usageo = lang.help_usageo or "[+!#]history [reset_t_logs|reset_t_exceptions]  / or: [+!#]history showexceptions"
local help_desco = lang.help_desco or "Delete Chatlog / or: delete list of deniers."

local msg_usage = lang.msg_usage or "Usage: [+!#]history show [<lines>] or [+!#]history toggle"
local msg_usageo = lang.msg_usageo or "Usage: [+!#]history show [<lines>] / [+!#]history toggle / [+!#]history [reset_t_logs|reset_t_exceptions]  / [+!#]history showexceptions"

local msg_denied = lang.msg_denied or "[ CHATLOG ]--> You are not allowed to use this command."
local msg_leave = lang.msg_leave or "[ CHATLOG ]--> Chatlog mode: off"
local msg_join = lang.msg_join or "[ CHATLOG ]--> Chatlog mode: on"
local msg_del_log = lang.msg_del_log or "[ CHATLOG ]--> Chatlog was cleaned."
local msg_del_exceptions = lang.msg_del_exceptions or "[ CHATLOG ]--> List of Chatlog-deniers was cleaned."  -- debug
local msg_intro = lang.msg_intro or "The last  %s  post(s):"
local msg_deniers = lang.msg_deniers or "\nList of Chatlog-deniers:"
local msg_empty = lang.msg_empty or "[ CHATLOG ]--> No entry"

local ucmd_menu_show = lang.ucmd_menu_show or { "Hub", "etc", "Chatlog", "show" }  -- reg
local ucmd_menu_toggle = lang.ucmd_menu_toggle or { "Hub", "etc", "Chatlog", "Mode", "on\\off" }  -- reg
local ucmd_menu_reset_t_log = lang.ucmd_menu_reset_t_log or { "Hub", "etc", "Chatlog", "Admin", "clean Chatlog" }  -- owner
local ucmd_menu_showexceptions = lang.ucmd_menu_showexceptions or { "Hub", "etc", "Chatlog", "Admin", "show Chatlog-deniers" }  -- owner
local ucmd_menu_reset_t_exceptions = lang.ucmd_menu_reset_t_exceptions or { "Hub", "etc", "Chatlog", "Admin", "clean Chatlog-deniers" }  -- owner
local ucmd_popup = lang.ucmd_popup or "How many posts?"

local logo_1 = lang.logo_1 or [[


=== CHATLOG =====================================================================================
%s
   ]]

local logo_2 = lang.logo_2 or [[

===================================================================================== CHATLOG ===
  ]]

--// msgs for nospam
local msg_warning_spam = lang.msg_warning_spam or "Take it easy with your keystrokes!"
local msg_warning_chars = lang.msg_warning_chars or "Your message is too long!"
local msg_warning_rows = lang.msg_warning_rows or "Your message has too many lines!"

--// msgs for mainchatclean
local help_title_clean = lang.help_title_clean or "Main chat clean"
local help_desc_clean = lang.help_desc_clean or "Will clean mainchat and empty the main chat history"
local help_usage_clean = lang.help_usage_clean or "[+!#]mainchat [clean|unlock|lock]"
local msg_usage_clean = lang.msg_usage_clean or "Usage: [+!#]mainchat [clean|unlock|lock]"
local msg_denied_clean = lang.msg_denied_clean or "You are not allowed to use this command."
local ucmd_menu_clean = lang.ucmd_menu_clean or { "Hub", "Main chat", "CLEAN" }
local ucmd_menu_lock   = lang.ucmd_menu_lock   or { "Hub", "Main chat", "LOCK" }
local ucmd_menu_unlock = lang.ucmd_menu_unlock or { "Hub", "Main chat", "UNLOCK" }

local cleaning_started = lang.cleaning_started or "Main chat cleaning started"
local cleaning_by = lang.cleaning_by or " by "
local still_cleaning = lang.still_cleaning or "...still cleaning main chat...\n"
local cleaning_finished = lang.cleaning_finished or "Main chat is now cleaned!\n"

local main_locked = lang.main_locked or "Main chat is locked, you are not able to write anything."
local main_unlocked = lang.main_unlocked or "Main chat is unlocked, you can write again."
local main_locked_user = lang.main_locked_user or "Main chat is locked, only operators can write."
local main_locked_op = lang.main_locked_op or "Main chat is already locked."
local main_unlocked_op = lang.main_unlocked_op or "Main chat is already unlocked."

--// code

local min_level = util.getlowestlevel( permission )

local tbl_is_empty = function( tbl )
    if next( tbl ) == nil then return true else return false end
end

local onbmsg = function( user, adccmd, parameters )

    local local_prms = (parameters or "") .. " "
    local user_level = user:level( )
    local id, amount = utf.match( local_prms, "^(%S+) (.*)" )
    amount = utf.match( local_prms, "^%S+ ([-]?%d+)" )

    if not amount then
        amount = default_lines
    else
        amount = tonumber(amount)
    end

    if id == prm1 then  -- show
        if user_level >= min_level then
            if not tbl_is_empty( t_log ) then
                user:reply( buildlog( amount, false ), hub.getbot() )
            else
                user:reply( msg_empty, hub.getbot() )
            end
        else
            user:reply( msg_denied, hub.getbot())
        end
        return PROCESSED
    end

    if id == prm2 then  -- toggle
        local inlist, nick, cid, hash = false, user:nick(), user:cid(), user:hash()
        if permission[ user_level ] then
            local key
            for i, excepttbl in ipairs( t_exceptions ) do
                if excepttbl.nick == nick
                or (excepttbl.cid == cid and excepttbl.hash == hash) then
                    inlist = true
                    key = i
                    break
                end
            end
            if inlist then
                table.remove( t_exceptions, key )
                util.savearray( t_exceptions, exceptions_path )
                user:reply( msg_join, hub.getbot() )
            else
                t_exceptions[#t_exceptions + 1] = {
                    nick = nick,
                    cid  = cid,
                    hash = hash
                }
                util.savearray( t_exceptions, exceptions_path )
                user:reply( msg_leave, hub.getbot() )
            end
        else
            user:reply( msg_denied, hub.getbot() )
        end
        return PROCESSED
    end

    if id == prm3 then  -- reset_t_logs
        if user_level >= min_level_adv then
            t_log = {}
            util.savearray( t_log, log_path )
            user:reply( msg_del_log, hub.getbot() )
        else
            user:reply( msg_denied, hub.getbot() )
        end
        return PROCESSED
    end

    if id == prm4 then  -- reset_t_exceptions
        if user_level >= min_level_adv then
            t_exceptions = {}
            util.savearray( t_exceptions, exceptions_path )
            user:reply( msg_del_exceptions, hub.getbot() )
        else
            user:reply( msg_denied, hub.getbot() )
        end
        return PROCESSED
    end

    if id == prm5 then  -- showexceptions
        if user_level >= min_level_adv then
            user:reply( show_t_exceptions(), hub.getbot() )
        else
            user:reply( msg_denied, hub.getbot() )
        end
        return PROCESSED
    end

    if user:level() >= min_level_adv then
        user:reply( msg_usageo, hub.getbot() )
    else
        user:reply( msg_usage, hub.getbot() )
    end
    return PROCESSED
end


-- mainchat clean command handler
local onMainchatCmd = function(user, adccmd, parameters)
    local showuser = ""
    local param = utf.match(parameters or "", "^(%S+)")

    if user:level() < mainchat_clean_level then
        user:reply( msg_denied_clean, hub.getbot() )
        return PROCESSED
    end

    if param == "lock" then
        if user:level() < mainchat_clean_level then
            user:reply( msg_denied_clean, hub.getbot() )
            return PROCESSED
        end
    
        if mainchat_locked then
            user:reply( main_locked_op, hub.getbot())
            return PROCESSED
        end
    
        mainchat_locked = true
        hub.broadcast( main_locked, sBot)
        return PROCESSED
    end
    
    if param == "unlock" then
        if user:level() < mainchat_clean_level then
            user:reply( msg_denied_clean, hub.getbot() )
            return PROCESSED
        end
    
        if not mainchat_locked then
            user:reply( main_unlocked_op, hub.getbot() )
            return PROCESSED
        end
    
        mainchat_locked = false
        hub.broadcast( main_unlocked, sBot)
        return PROCESSED
    end

    if param ~= "clean" then
        user:reply( msg_usage_clean, hub.getbot() )
        return PROCESSED
    end

    -- log the action before reset
    table.insert(t_log, {
        os.date("%Y-%m-%d / %H:%M:%S"),
        "***",
        "Main chat cleaned by "..user:nick()
    })
    util.savearray(t_log, log_path)

    -- visual clean
    if show_user then
        showuser = cleaning_by ..user:nick()
    end
    hub.broadcast( cleaning_started ..showuser..string.rep("\t\t\t\t\t\t\n", 7500)..still_cleaning..string.rep("\t\t\t\t\t\t\n", 7500)..cleaning_finished, sBot )
--        hub.getbot()
--    )

    -- hard reset history
    t_log = {}
    util.savearray(t_log, log_path)

    return PROCESSED
end

hub.setlistener( "onStart", { },
    function( )
        local help = hub.import "cmd_help"
        if help then
            help.reg( help_title, help_usage, help_desc, min_level )  -- reg help
            help.reg( help_titleo, help_usageo, help_desco, min_level_adv )  -- owner help
            help.reg( help_title_clean, help_usage_clean, help_desc_clean, mainchat_clean_level ) -- mainchatclean help
        end
        local ucmd = hub.import "etc_usercommands"  -- add usercommand
        if ucmd then
            ucmd.add( ucmd_menu_show, cmd, { prm1, "%[line:" .. ucmd_popup .. " (max." .. max_lines .. ")" .. "]"}, { "CT1" }, min_level )  -- show
            ucmd.add( ucmd_menu_toggle, cmd, { prm2 }, { "CT1" }, min_level )  -- toggle
            ucmd.add( ucmd_menu_reset_t_log, cmd, { prm3 }, { "CT1" }, min_level_adv )  -- reset t_log
            ucmd.add( ucmd_menu_showexceptions, cmd, { prm5 }, { "CT1" }, min_level_adv )  -- shows t_exception
            ucmd.add( ucmd_menu_reset_t_exceptions, cmd, { prm4 }, { "CT1" }, min_level_adv )  -- reset t_exceptions
            ucmd.add( ucmd_menu_clean, "mainchat", { "clean" }, { "CT1" }, mainchat_clean_level ) -- clean mainchat
            ucmd.add( ucmd_menu_lock, "mainchat", { "lock" }, { "CT1" }, mainchat_clean_level ) -- lock mainchat
            ucmd.add( ucmd_menu_unlock, "mainchat", { "unlock" }, { "CT1" }, mainchat_clean_level ) -- unlock mainchat
        end
        hubcmd = hub.import "etc_hubcommands"  -- add hubcommand
        assert( hubcmd )
        assert( hubcmd.add( cmd, onbmsg ) )
        assert( hubcmd.add( "mainchat", onMainchatCmd ) )
        return nil
    end
)

hub.setlistener( "onLogin", { },
    function( user, nick )
        local allows, nick, cid, hash = true, user:nick( ), user:cid( ), user:hash( )
        local key
        if permission[ user:level() ] then
            for i, excepttbl in ipairs( t_exceptions ) do  -- is user in t_exception ?
                if excepttbl.nick == nick then
                    allows = false  -- does the user want to read the chatlog?
                    break
                elseif excepttbl.cid == cid and excepttbl.hash == hash then
                    allows = false  -- does the user want to read the chatlog?
                    break
                end
            end
            if allows and ( not tbl_is_empty( t_log ) ) then
                user:reply( buildlog( default_lines, true ), hub.getbot() )
            end
        end
        return nil
    end
)

local function SendReport(text)
    if report then
        report.send(
            nospam.report_activate,
            nospam.report_hubbot,
            nospam.report_opchat,
            nospam.report_level,
            text
        )
    end
end

local function CountRows(msg)
    local _, n = string.gsub(msg or "", "\n", "")
    return n + 1
end

local function CheckNoSpam(user, msg)

    if nospam.exludePro[user:level()] == 1 then
        return nil
    end

    if nospam.exludeUser[string.lower(user:nick())] then
        return nil
    end

    -- char limit
    if nospam.iMaxChars > 0 then
        local len = #msg
        if len > nospam.iMaxChars then
            user:reply(
                string.format(msg_warning_chars, len, nospam.iMaxChars),
                hub.getbot()
            )
            SendReport(
                string.format(
                    "[ NOSPAM ] %s | Too many characters %d / %d",
                    user:nick(),
                    len,
                    nospam.iMaxChars
                )
            )
            return PROCESSED
        end
    end


    -- row limit
    if nospam.iMaxRows > 0 then
        local rows = CountRows(msg)
        if rows > nospam.iMaxRows then
            user:reply(
                string.format(msg_warning_rows, rows, nospam.iMaxRows),
                hub.getbot()
            )
            SendReport(
                string.format(
                    "[ NOSPAM ] %s | Too many rows %d / %d",
                    user:nick(),
                    rows,
                    nospam.iMaxRows
                )
            )
            return PROCESSED
        end
    end

    -- duplicate spam
    local entry = tSpamUsers[user:nick()]
    local now = os.time()

    if entry and entry.msg == msg and (now - entry.time) <= nospam.iTime then
        if entry.count >= nospam.iCount then
            user:reply( msg_warning_spam, hub.getbot() )
            SendReport("[ NOSPAM ] "..user:nick().." | Duplicate spam")
            return PROCESSED
        end
        entry.count = entry.count + 1
    else
        tSpamUsers[user:nick()] = { msg = msg, time = now, count = 1 }
    end

    return nil
end

hub.setlistener("onBroadcast", {},
    function(user, adccmd, msg)

        -- empty message
        if not adccmd[6] or adccmd[6] == "" then
            return nil
        end

        local cleanmsg = hub.escapefrom(adccmd[6])

        -- block mainchat when locked
        if mainchat_locked and user:level() < mainchat_clean_level then
            user:reply( main_locked_user, hub.getbot())
            return PROCESSED
        end

        -- nospam check first (blocks everything)
        local blocked = CheckNoSpam(user, cleanmsg)
        if blocked then
            return PROCESSED
        end

        -- normal chatlog logic (only if not blocked)
        local result = string.byte(cleanmsg, 1)
        if msgmanager_permission[user:level()]
        and result ~= 33 and result ~= 35 and result ~= 43 then

            local t = {
                os.date("%Y-%m-%d / %H:%M:%S"),
                user:nick(),
                cleanmsg
            }

            table.insert(t_log, t)

            for i = 1, #t_log - max_lines do
                table.remove(t_log, 1)
            end

            savehistory = savehistory + 1
            if savehistory >= saveit then
                savehistory = 0
                util.savearray(t_log, log_path)
            end
        end

        return nil
    end
)

hub.setlistener( "onExit", { },
    function( )  -- save both tables
        util.savearray( t_log, log_path )
        util.savearray( t_exceptions, exceptions_path )
    end
)

buildlog = function( amount_lines, login )  -- builds the logmsg
    local amount = ( amount_lines or default_lines )
    if amount >= max_lines then  -- make sure nobody lets it "spam"
        amount = max_lines
    end
    local log_msg = "\n"
    local lines_msg = ""
    -- set variables for loop
    local x = amount
    if amount > #t_log then  -- makes sure it doesn't send more as it got
        x,amount = #t_log,#t_log
    end
    x = #t_log - x

    for i,v in ipairs( t_log ) do  -- loop thru the table
        if i > x then   -- makes sure it doesn't send more than you want
            if login then
                log_msg = log_msg .. " [ " .. v[ 1 ] .. " ] <" .. v[ 2 ] .. "> " .. v[ 3 ] .. "\n"  -- for msg at login
            else
                log_msg = log_msg .. "[" .. i .. "] - [ " .. v[ 1 ] .. " ] <" .. v[ 2 ] .. "> " .. v[ 3 ] .. "\n"  -- for msg at cmd
            end
        end
    end
    lines_msg = utf.format( msg_intro, amount )  -- adds amount into 'header'
    --log_msg = utf.format( logo_1, lines_msg ) .. log_msg .. logo_2  --  combines 'header' and logos with history
    log_msg = lines_msg .. "\n" .. log_msg

    return log_msg
end

show_t_exceptions = function ( )  -- returns t_exceptions
    local msg = ""
    for i, excepttbl in ipairs( t_exceptions ) do
        msg = msg.."\n\t\t\t\t\t  " .. ( excepttbl.nick or "-nobody-" )
    end
    return utf.format( logo_1, msg_deniers ) .. msg .. logo_2
end

hub.debug( "** Loaded " .. scriptname .. ".lua **" )
