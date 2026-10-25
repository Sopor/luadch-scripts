--[[

    etc_masspmoffline.lua by Sopor

        - sends a PM to all registered users that are online
        - stores a PM for registered users that are offline
        - delivers stored PMs when the user next logs in
        - automatically removes stored PMs after the selected duration
        - schedule a message
        - send an online, offline or schedule message without a sender

    usage:
        [+!#]masspm [NOSENDER] [LEVEL=<LEVEL>] <MSG>
        [+!#]masspm [NOSENDER] <OFFLINE|BOTH> <DURATION> [LEVEL=<LEVEL>] <MSG>
        [+!#]masspm [LEVEL=<LEVEL>] <MSG>
        [+!#]masspm <OFFLINE | BOTH> <DURATION> [LEVEL=<LEVEL>] <MSG>
        [+!#]masspm SCHEDULE <YYYY-MM-DD> <HH:MM> [NOSENDER] [LEVEL=<LEVEL>] <MSG>
        [+!#]masspm <LIST | DELETE <ID> | CLEAR>

    examples:
        +masspm The hub will restart in 10 minutes.
        +masspm offline 7d Welcome back! Please read the new hub rules.
        +masspm both 3w The hub rules have been updated.

        v1.5
            - adds Luadch-style mass-message formatting with the sent date and time
            - send messages without a sender
            - rearrange the right-click menu
            - send schedule online message

        v1.4
            - sends online PMs without requiring the ONLINE mode or a duration
            - supports minute, hour, day, week and Month message durations

        v1.3
            - stores offline messages by registered nickname
            - supports level-specific broadcasts and message queue management

        v1.2
            - no information

        v1.1
            - queue offline PMs by registered account identity
            - added safe data loading, backup writes and bounded retention

        v1.0
            - first release

]]--

--------------------
-- CONFIG
--------------------

local scriptname = "etc_masspmoffline"
local scriptversion = "1.5"

local data_file = "scripts/data/etc_masspmoffline.tbl"
local data_temp_file = data_file .. ".tmp"
local data_backup_file = data_file .. ".bak"
local levels = cfg.get( "levels" )

-- users at this level and above can run the masspm command
local oplevel = 60

-- messages are delivered only to users at enabled levels
-- offline messages are queued for registered accounts, then this setting is checked when the account login and the message is delivered
local masspm_level = {
    [ 0 ]   = 0, -- UNREG
    [ 10 ]  = 0, -- GUEST
    [ 20 ]  = 1, -- REG  (enabled by default)
    [ 30 ]  = 1, -- VIP  (enabled by default)
    [ 40 ]  = 1, -- SVIP (enabled by default)
    [ 50 ]  = 0, -- SERVER
    [ 55 ]  = 0, -- SBOT
    [ 60 ]  = 0, -- OPERATOR
    [ 70 ]  = 0, -- SUPERVISOR
    [ 80 ]  = 0, -- ADMIN
    [ 100 ] = 0, -- HUBOWNER
}

-- use 'custom' to place the right-click menu in the root or use 'original' to place it where Luadch has its message menu
local rcmenu = "custom"

-- how often expired messages are removed from the .tbl file in seconds
local cleanup_interval = 600

-- maximum retention period accepted by the command in days
local max_retention_days = 365

-- <<<<<< DON'T CHANGE THIS >>>>>>
local max_retention_seconds = max_retention_days * 86400

--------------------
-- MESSAGES
--------------------

local msg_denied = "[ MASS PM ] --> You are not allowed to use this command."

local msg_usage = "[ MASS PM ] --> Usage: [+!#]masspm [NOSENDER] [LEVEL=<LEVEL>] <MSG> | [+!#]masspm [NOSENDER] <OFFLINE | BOTH> <DURATION> [LEVEL=<LEVEL>] <MSG> | [+!#]masspm <LIST | DELETE <ID> | CLEAR>"

local msg_schedule_usage = "[ MASS PM ] --> Usage: [+!#]masspm schedule YYYY-MM-DD HH:MM [NOSENDER] [LEVEL=<LEVEL>] <MSG>"

local msg_schedule_time = "[ MASS PM ] --> The scheduled date and time must be valid, use 24-hour YYYY-MM-DD HH:MM, and it must be in the future."

local msg_duration = "[ MASS PM ] --> DURATION must be a whole number followed by m, h, d, w, or M (for example, 10h or 2w)."

local msg_duration_max = "[ MASS PM ] --> DURATION must not exceed " .. max_retention_days .. "."

local msg_level = "[ MASS PM ] --> LEVEL must be a whole number of at least 0."

local msg_no_registered = "[ MASS PM ] --> No eligible registered users were found."

local msg_sent = "[ MASS PM ] --> Sent to online users: "

local msg_queued = ", saved for offline users: "

local msg_expires = ". Offline messages expire: "

local msg_save_failed = "[ MASS PM ] --> The offline queue could not be saved. Offline PMs were not queued."

local msg_no_saved = "[ MASS PM ] --> There are no saved offline messages or scheduled messages."

local msg_clear_usage = "Usage:  [+!#]masspm clear DELETE"

local msg_mass_with_sender = [[


=== MASS MESSAGE ======================================================================================================

Sender:  %s   |   Date:  %s   |   Time:  %s

Message:  %s

====================================================================================================== MASS MESSAGE ===
]]

local msg_mass_to_level = [[


=== MASS MESSAGE ======================================================================================================

Sender:  %s   |   Date:  %s   |   Time:  %s  |  Sent to all users with level:  %s

Message:  %s

====================================================================================================== MASS MESSAGE ===
]]

local msg_mass_without_sender = [[


=== MASS MESSAGE ======================================================================================================

Date:  %s   |   Time:  %s

Message:  %s

====================================================================================================== MASS MESSAGE ===
]]

local help_title = "etc_masspmoffline.lua"

local help_usage = [[


=== MASS PM ====================================== OP USAGE ===

 [+!#]masspm [NOSENDER] [LEVEL=<LEVEL>] <MSG>
 [+!#]masspm [NOSENDER] <OFFLINE|BOTH> <DURATION> [LEVEL=<LEVEL>] <MSG>
 [+!#]masspm SCHEDULE <YYYY-MM-DD> <HH:MM> [NOSENDER] [LEVEL=<LEVEL>] <MSG>
 [+!#]masspm LIST
 [+!#]masspm DELETE <ID>
 [+!#]masspm CLEAR

 (no mode) - send the PM immediately to eligible registered users that are online
 NOSENDER  - send without a sender
 OFFLINE   - save the PM for eligible registered users that are currently offline
 BOTH      - send the PM to online users and save it for offline users
 SCHEDULE  - send the PM to users online at the selected future date and time
 DURATION  - how long an offline PM is kept: m=minutes, h=hours, d=days,
             w=weeks, M=months (for example, 10h or 2w; maximum ]] .. max_retention_days .. [[)
 LEVEL     - optional exact user level; overrides the enabled levels above

 LIST          - list each distinct saved broadcast and its queued recipient count
 DELETE <ID>   - delete one saved offline/scheduled message
 CLEAR         - erase all saved offline/scheduled messages

 Example:
 [+!#]masspm level=30 Please read the updated hub rules.
 [+!#]masspm nosender This is a message without a sender.
 [+!#]masspm both 2w level=30 Please read the updated hub rules.
 [+!#]masspm schedule 2026-10-09 21:00 nosender level=30 Please read the updated hub rules.

=== OP USAGE ====================================== MASS PM ===
]]

local help_desc = "Sends a PM to eligible registered users, including users that are offline."

--------------------
-- LOCALS
--------------------

local hub_bot = hub.getbot()
local hub_debug = hub.debug
local hubcmd
local messages = {}
local schedules = {}
local scheduled_key = "\31SCHEDULED"
local last_cleanup = 0
local message_sequence = 0

local text_upper = ( utf and utf.upper ) or string.upper
local text_match = ( utf and utf.match ) or string.match
local table_sort = table.sort

--------------------
-- DATA
--------------------

local function clone_messages( source )

    local copy = {}

    for nick, entry in pairs( source ) do
        if type( entry ) == "table" and type( entry.messages ) == "table" then
            copy[ nick ] = { nick = entry.nick, messages = {} }

            for i, message in ipairs( entry.messages ) do
                if type( message ) == "table" then
                    copy[ nick ].messages[ i ] = {
                        id = message.id,
                        sender = message.sender,
                        text = message.text,
                        created = message.created,
                        expires = message.expires,
                        target_level = message.target_level,
                        without_sender = message.without_sender,
                    }
                end
            end
        end
    end

    return copy

end

local function clone_schedules( source )

    local copy = {}

    for id, schedule in pairs( source ) do
        if type( schedule ) == "table" then
            copy[ id ] = {
                sender = schedule.sender,
                sender_key = schedule.sender_key,
                text = schedule.text,
                execute_at = schedule.execute_at,
                target_level = schedule.target_level,
                without_sender = schedule.without_sender,
            }
        end
    end

    return copy

end
local function write_line( f, line )

    local ok, err = f:write( line )

    if not ok then
        return false, err
    end

    return true

end

local function savetbl()

    local f, err = io.open( data_temp_file, "w" )

    if not f then
        hub_debug( "** " .. scriptname .. " could not open temporary data file: " .. tostring( err ) .. " **" )
        return false
    end

    local function write( line )
        local ok, write_err = write_line( f, line )
        if not ok then
            f:close()
            os.remove( data_temp_file )
            hub_debug( "** " .. scriptname .. " could not write data file: " .. tostring( write_err ) .. " **" )
            return false
        end
        return true
    end

    if not write( "return {\n" ) then return false end

    for nick, entry in pairs( messages ) do
        if type( entry ) == "table" and type( entry.messages ) == "table" then
            if not write( "    [" .. string.format( "%q", nick ) .. "] = {\n" ) then return false end
            if not write( "        [\"nick\"] = " .. string.format( "%q", entry.nick or "" ) .. ",\n" ) then return false end
            if not write( "        [\"messages\"] = {\n" ) then return false end

            for _, message in ipairs( entry.messages ) do
                if type( message ) == "table" then
                    if not write( "            {\n" ) then return false end
                    if not write( "                [\"id\"] = " .. string.format( "%q", message.id or "" ) .. ",\n" ) then return false end
                    if not write( "                [\"sender\"] = " .. string.format( "%q", message.sender or "" ) .. ",\n" ) then return false end
                    if not write( "                [\"text\"] = " .. string.format( "%q", message.text or "" ) .. ",\n" ) then return false end
                    if not write( "                [\"created\"] = " .. tostring( tonumber( message.created ) or 0 ) .. ",\n" ) then return false end
                    if not write( "                [\"expires\"] = " .. tostring( tonumber( message.expires ) or 0 ) .. ",\n" ) then return false end
                    if message.target_level ~= nil then
                        if not write( "                [\"target_level\"] = " .. tostring( tonumber( message.target_level ) or 0 ) .. ",\n" ) then return false end
                    end
                    if message.without_sender == true then
                        if not write( "                [\"without_sender\"] = true,\n" ) then return false end
                    end                    if not write( "            },\n" ) then return false end
                end
            end

            if not write( "        },\n" ) then return false end
            if not write( "    },\n" ) then return false end
        end
    end

    if next( schedules ) then
        if not write( "    [" .. string.format( "%q", scheduled_key ) .. "] = {\n" ) then return false end

        for id, schedule in pairs( schedules ) do
            if type( schedule ) == "table" then
                if not write( "        [" .. string.format( "%q", id ) .. "] = {\n" ) then return false end
                if not write( "            [\"sender\"] = " .. string.format( "%q", schedule.sender or "" ) .. ",\n" ) then return false end
                if not write( "            [\"sender_key\"] = " .. string.format( "%q", schedule.sender_key or "" ) .. ",\n" ) then return false end
                if not write( "            [\"text\"] = " .. string.format( "%q", schedule.text or "" ) .. ",\n" ) then return false end
                if not write( "            [\"execute_at\"] = " .. tostring( tonumber( schedule.execute_at ) or 0 ) .. ",\n" ) then return false end
                if schedule.target_level ~= nil then
                    if not write( "            [\"target_level\"] = " .. tostring( tonumber( schedule.target_level ) or 0 ) .. ",\n" ) then return false end
                end
                if schedule.without_sender == true then
                    if not write( "            [\"without_sender\"] = true,\n" ) then return false end
                end
                if not write( "        },\n" ) then return false end
            end
        end

        if not write( "    },\n" ) then return false end
    end
    if not write( "}\n" ) then return false end

    local close_ok, close_err = f:close()
    if not close_ok then
        os.remove( data_temp_file )
        hub_debug( "** " .. scriptname .. " could not close temporary data file: " .. tostring( close_err ) .. " **" )
        return false
    end

    os.remove( data_backup_file )

    local old_file = io.open( data_file, "r" )
    local had_old_file = old_file ~= nil
    if old_file then old_file:close() end

    if had_old_file then
        local backup_ok, backup_err = os.rename( data_file, data_backup_file )
        if not backup_ok then
            os.remove( data_temp_file )
            hub_debug( "** " .. scriptname .. " could not back up data file: " .. tostring( backup_err ) .. " **" )
            return false
        end
    end

    local commit_ok, commit_err = os.rename( data_temp_file, data_file )
    if not commit_ok then
        if had_old_file then
            os.rename( data_backup_file, data_file )
        end
        hub_debug( "** " .. scriptname .. " could not replace data file: " .. tostring( commit_err ) .. " **" )
        return false
    end

    return true

end

local function loadtbl()

    local function load_table( file_name )
        -- Lua 5.2+ loads the table in an empty environment, so stored data
        -- cannot execute hub functions when the script starts.
        local f, load_err = loadfile( file_name, "t", {} )

        if not f then
            return nil, load_err
        end

        local ok, t = pcall( f )

        if ok and type( t ) == "table" then
            return t
        end

        return nil, "data file did not return a table"
    end

    local t, load_err = load_table( data_file )

    if t then
        messages = t
        return
    end

    local backup, backup_err = load_table( data_backup_file )

    if backup then
        messages = backup
        local restored, restore_err = os.rename( data_backup_file, data_file )

        if restored then
            hub_debug( "** " .. scriptname .. " restored data from backup **" )
        else
            hub_debug( "** " .. scriptname .. " loaded backup but could not restore it: " .. tostring( restore_err ) .. " **" )
        end
        return
    end

    if load_err and not string.find( load_err, "No such file" ) then
        hub_debug( "** " .. scriptname .. " could not load " .. data_file .. ": " .. load_err .. " **" )
    elseif backup_err and not string.find( backup_err, "No such file" ) then
        hub_debug( "** " .. scriptname .. " could not load " .. data_backup_file .. ": " .. backup_err .. " **" )
    end

end

-- Older releases stored queue entries under a CID-based key.  The registered
-- nickname is the identity used by getregusers() and is also available while a
-- user is offline, so rewrite older data to nickname keys as it is loaded.
local function normalize_messages()

    local normalized = {}
    local used_ids = {}
    local legacy_ids = {}
    local legacy_count = 0
    local changed = false

        local raw_schedules = messages[ scheduled_key ]
    schedules = {}

    if raw_schedules ~= nil then
        messages[ scheduled_key ] = nil

        if type( raw_schedules ) ~= "table" then
            changed = true
        else
            for id, schedule in pairs( raw_schedules ) do
                local execute_at = type( schedule ) == "table" and tonumber( schedule.execute_at )

                if type( id ) ~= "string" or id == "" or not execute_at or execute_at <= 0 or type( schedule.text ) ~= "string" then
                    changed = true
                else
                    local target_level = tonumber( schedule.target_level )

                    if schedule.target_level ~= nil and target_level == nil then
                        changed = true
                    end

                    schedules[ id ] = {
                        sender = type( schedule.sender ) == "string" and schedule.sender or "",
                        sender_key = type( schedule.sender_key ) == "string" and schedule.sender_key or "",
                        text = schedule.text,
                        execute_at = execute_at,
                        target_level = target_level,
                        without_sender = schedule.without_sender == true,
                    }
                end
            end
        end
    end
for _, entry in pairs( messages ) do
        if type( entry ) == "table" and type( entry.messages ) == "table" then
            for _, message in ipairs( entry.messages ) do
                if type( message ) == "table" and type( message.id ) == "string" and message.id ~= "" then
                    used_ids[ message.id ] = true
                end
            end
        end
    end

    local function legacy_id( message )

        local signature = string.format(
            "%q\30%q\30%s\30%s\30%s",
            message.sender or "",
            message.text or "",
            tostring( tonumber( message.created ) or 0 ),
            tostring( tonumber( message.expires ) or 0 ),
            tostring( tonumber( message.target_level ) or "" )
        )

        if not legacy_ids[ signature ] then
            local id

            repeat
                legacy_count = legacy_count + 1
                id = "legacy-" .. legacy_count
            until not used_ids[ id ]

            legacy_ids[ signature ] = id
            used_ids[ id ] = true
        end

        return legacy_ids[ signature ]

    end

    for key, entry in pairs( messages ) do
        if type( entry ) ~= "table" or type( entry.messages ) ~= "table" then
            changed = true
        else
            local nick = entry.nick

            if type( nick ) ~= "string" or nick == "" then
                changed = true
            else
                if key ~= nick or normalized[ nick ] then
                    changed = true
                end

                normalized[ nick ] = normalized[ nick ] or {
                    nick = nick,
                    messages = {},
                }

                for _, message in ipairs( entry.messages ) do
                    if type( message ) ~= "table" then
                        changed = true
                    else
                        local id = message.id

                        if type( id ) ~= "string" or id == "" then
                            id = legacy_id( message )
                            changed = true
                        end

                        local target_level = tonumber( message.target_level )

                        if message.target_level ~= nil and target_level == nil then
                            changed = true
                        end

                        table.insert( normalized[ nick ].messages, {
                            id = id,
                            sender = message.sender,
                            text = message.text,
                            created = message.created,
                            expires = message.expires,
                            target_level = target_level,
                            without_sender = message.without_sender == true,
                        } )
                    end
                end
            end
        end
    end

    messages = normalized
    return changed

end

local function clean_expired_messages( now )

    local previous = clone_messages( messages )
    local changed = false

    for nick, entry in pairs( messages ) do
        if type( entry ) ~= "table" or type( entry.messages ) ~= "table" then
            messages[ nick ] = nil
            changed = true
        else
            for i = #entry.messages, 1, -1 do
                local message = entry.messages[ i ]

                if type( message ) ~= "table" or tonumber( message.expires ) == nil or now >= tonumber( message.expires ) then
                    table.remove( entry.messages, i )
                    changed = true
                end
            end

            if #entry.messages == 0 then
                messages[ nick ] = nil
                changed = true
            end
        end
    end

    if changed and not savetbl() then
        messages = previous
        return false
    end

    return true

end

--------------------
-- UTILS
--------------------

local function user_enabled( user )

    return not user:isbot() and masspm_level[ user:level() ] == 1

end

local function expiry_after_months( now, months )

    local date = os.date( "*t", now )
    local month_index = date.month - 1 + months

    date.year = date.year + math.floor( month_index / 12 )
    date.month = ( month_index % 12 ) + 1
    date.isdst = nil

    local last_day = os.date( "*t", os.time( {
        year = date.year,
        month = date.month + 1,
        day = 0,
        hour = 12,
    } ) ).day

    date.day = math.min( date.day, last_day )
    return os.time( date )

end

local function expiry_after_duration( now, duration_text )

    local amount_text, unit = text_match( duration_text or "", "^(%d+)([mhdwM])$" )

    if not amount_text then
        return nil, msg_duration
    end

    local amount = tonumber( amount_text )

    if not amount or amount < 1 then
        return nil, msg_duration
    end

    local expires

    if unit == "m" then
        expires = now + ( amount * 60 )
    elseif unit == "h" then
        expires = now + ( amount * 3600 )
    elseif unit == "d" then
        expires = now + ( amount * 86400 )
    elseif unit == "w" then
        expires = now + ( amount * 7 * 86400 )
    else
        expires = expiry_after_months( now, amount )
    end

    if not expires or expires <= now or expires - now > max_retention_seconds then
        return nil, msg_duration_max
    end

    return expires

end

local function account_enabled( account )

    return account and account.is_bot ~= 1 and account.is_bot ~= true and masspm_level[ tonumber( account.level ) ] == 1

end

local function account_matches_target_level( account, target_level )

    if not account or account.is_bot == 1 or account.is_bot == true then
        return false
    end

    if target_level ~= nil then
        return tonumber( account.level ) == target_level
    end

    return account_enabled( account )

end

local function account_key( nick )

    if nick and nick ~= "" then
        return nick
    end

    return nil

end

local function message_enabled( user, message )

    if user:isbot() then
        return false
    end

    local target_level = tonumber( message.target_level )

    if target_level ~= nil then
        return user:level() == target_level
    end

    return user_enabled( user )

end

local function message_id_exists( id )

    for _, entry in pairs( messages ) do
        if type( entry ) == "table" and type( entry.messages ) == "table" then
            for _, message in ipairs( entry.messages ) do
                if type( message ) == "table" and message.id == id then
                    return true
                end
            end
        end
    end

    return false

end

local function new_message_id( now )

    local id

    repeat
        message_sequence = message_sequence + 1
        id = "masspm-" .. now .. "-" .. message_sequence
    until not message_id_exists( id )

    return id

end

local function new_schedule_id( now )

    local id

    repeat
        message_sequence = message_sequence + 1
        id = "schedule-" .. now .. "-" .. message_sequence
    until not schedules[ id ] and not message_id_exists( id )

    return id

end

local function scheduled_timestamp( date_text, time_text, now )

    if not text_match( date_text or "", "^%d%d%d%d%-%d%d%-%d%d$" ) or not text_match( time_text or "", "^%d%d:%d%d$" ) then
        return nil
    end

    local year, month, day = text_match( date_text, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$" )
    local hour, minute = text_match( time_text, "^(%d%d):(%d%d)$" )
    local execute_at = os.time( {
        year = tonumber( year ),
        month = tonumber( month ),
        day = tonumber( day ),
        hour = tonumber( hour ),
        min = tonumber( minute ),
        sec = 0,
        isdst = nil,
    } )

    if not execute_at or execute_at <= now or os.date( "%Y-%m-%d %H:%M", execute_at ) ~= date_text .. " " .. time_text then
        return nil
    end

    return execute_at

end
local function queue_message( key, nick, id, sender, text, created, expires, target_level, without_sender )

    messages[ key ] = messages[ key ] or {
        nick = nick,
        messages = {},
    }

    messages[ key ].nick = nick

    table.insert( messages[ key ].messages, {
        id = id,
        sender = sender,
        text = text,
        created = created,
        expires = expires,
        target_level = target_level,
        without_sender = without_sender == true,
    } )

end

local function format_mass_message( sender, text, created, target_level, without_sender )

    local date = os.date( "%Y-%m-%d", created )
    local time = os.date( "%X", created )

    if without_sender then
        return string.format( msg_mass_without_sender, date, time, text )
    end

    if target_level ~= nil then
        return string.format( msg_mass_to_level, sender, date, time, target_level, text )
    end

    return string.format( msg_mass_with_sender, sender, date, time, text )

end
local function run_due_schedules( now )

    local due = {}

    for id, schedule in pairs( schedules ) do
        if now >= schedule.execute_at then
            table.insert( due, { id = id, schedule = schedule } )
        end
    end

    table.sort( due, function( a, b )
        if a.schedule.execute_at == b.schedule.execute_at then
            return a.id < b.id
        end
        return a.schedule.execute_at < b.schedule.execute_at
    end )

    for _, item in ipairs( due ) do
        local id = item.id
        local schedule = schedules[ id ]

        if schedule == item.schedule then
            local ok, regusers = pcall( hub.getregusers )

            if not ok or type( regusers ) ~= "table" then
                hub_debug( "** " .. scriptname .. " could not run " .. id .. ": could not read the registered user list **" )
            else
                local outgoing_message = format_mass_message( schedule.sender, schedule.text, now, schedule.target_level, schedule.without_sender == true )

                for _, account in ipairs( regusers ) do
                    local target_key = account_key( account.nick )
                    local is_sender = target_key and schedule.sender_key ~= "" and target_key == schedule.sender_key

                    if account.nick == schedule.sender then
                        is_sender = true
                    end

                    if not is_sender and account_matches_target_level( account, schedule.target_level ) then
                        local target = hub.isnickonline( account.nick )

                        if target then
                            local sent, send_err = pcall( function()
                                target:reply( outgoing_message, hub_bot, hub_bot )
                            end )

                            if not sent then
                                hub_debug( "** " .. scriptname .. " could not send scheduled PM to " .. account.nick .. ": " .. tostring( send_err ) .. " **" )
                            end
                        end
                    end
                end

                local previous = clone_schedules( schedules )
                schedules[ id ] = nil

                if not savetbl() then
                    schedules = previous
                    hub_debug( "** " .. scriptname .. " could not save after running " .. id .. " **" )
                end
            end
        end
    end

end
local function saved_message_groups( now )

    local groups = {}

    for _, entry in pairs( messages ) do
        if type( entry ) == "table" and type( entry.messages ) == "table" then
            for _, message in ipairs( entry.messages ) do
                if type( message ) == "table" and type( message.id ) == "string" and message.id ~= "" and tonumber( message.expires ) and now < tonumber( message.expires ) then
                    groups[ message.id ] = groups[ message.id ] or {
                        id = message.id,
                        sender = message.sender or "",
                        text = message.text or "",
                        created = tonumber( message.created ) or 0,
                        expires = tonumber( message.expires ) or 0,
                        target_level = tonumber( message.target_level ),
                        recipients = 0,
                    }
                    groups[ message.id ].recipients = groups[ message.id ].recipients + 1
                end
            end
        end
    end

    for id, schedule in pairs( schedules ) do
        if type( schedule ) == "table" and tonumber( schedule.execute_at ) then
            groups[ id ] = {
                id = id,
                sender = schedule.sender or "",
                text = schedule.text or "",
                created = tonumber( schedule.execute_at ),
                execute_at = tonumber( schedule.execute_at ),
                target_level = tonumber( schedule.target_level ),
                scheduled = true,
            }
        end
    end
    local list = {}

    for _, group in pairs( groups ) do
        table.insert( list, group )
    end

    table.sort( list, function( a, b )
        if a.created == b.created then
            return a.id < b.id
        end
        return a.created < b.created
    end )

    return list

end

local function list_saved_messages( user, now )

    local list = saved_message_groups( now )

    if #list == 0 then
        user:reply( msg_no_saved, hub_bot )
        return
    end

    user:reply( "[ MASS PM ] --> Saved offline broadcasts and scheduled messages: " .. #list, hub_bot )

    for _, message in ipairs( list ) do
        local target = "enabled levels"

        if message.target_level ~= nil then
            target = "level " .. message.target_level
        end

        if message.scheduled then
            user:reply(
                "[ MASS PM ] --> ID: " .. message.id ..
                " | scheduled: " .. os.date( "%Y-%m-%d %H:%M", message.execute_at ) ..
                " | target: " .. target ..
                " | from: " .. message.sender .. " | message: " .. message.text, hub_bot )
        else
            user:reply(
                "[ MASS PM ] --> ID: " .. message.id ..
                " | queued users: " .. message.recipients ..
                " | target: " .. target ..
                " | expires: " .. os.date( "%Y-%m-%d %H:%M", message.expires ) ..
                " | from: " .. message.sender .. " | message: " .. message.text, hub_bot )
        end

    end

end

local function delete_saved_message( id )

    if schedules[ id ] then
        local previous_schedules = clone_schedules( schedules )
        schedules[ id ] = nil

        if not savetbl() then
            schedules = previous_schedules
            return nil
        end

        return 1, true
    end

    local previous = clone_messages( messages )
    local deleted = 0

    for nick, entry in pairs( messages ) do
        if type( entry ) == "table" and type( entry.messages ) == "table" then
            for i = #entry.messages, 1, -1 do
                if type( entry.messages[ i ] ) == "table" and entry.messages[ i ].id == id then
                    table.remove( entry.messages, i )
                    deleted = deleted + 1
                end
            end

            if #entry.messages == 0 then
                messages[ nick ] = nil
            end
        end
    end

    if deleted == 0 then
        return 0
    end

    if not savetbl() then
        messages = previous
        return nil
    end

    return deleted

end

local function clear_saved_messages()

    local previous = messages
    local previous_schedules = clone_schedules( schedules )
    local deleted = 0

    for _, entry in pairs( messages ) do
        if type( entry ) == "table" and type( entry.messages ) == "table" then
            deleted = deleted + #entry.messages
        end
    end

    for _ in pairs( schedules ) do
        deleted = deleted + 1
    end

    messages = {}
    schedules = {}

    if not savetbl() then
        messages = previous
        schedules = previous_schedules
        return nil
    end

    return deleted

end

--------------------
-- COMMAND HANDLER
--------------------

local onbmsg = function( user, cmd, parameters, txt )

    if user:level() < oplevel then
        user:reply( msg_denied, hub_bot )
        return PROCESSED
    end

    local data = parameters or ""
    local action, action_arg = text_match( data, "^%s*(%S+)%s*(.-)%s*$" )
    local action_upper = action and text_upper( action )
    local now = os.time()

    if action_upper == "LIST" then
        if action_arg ~= "" then
            user:reply( msg_usage, hub_bot )
            return PROCESSED
        end

        clean_expired_messages( now )
        list_saved_messages( user, now )
        return PROCESSED
    end

    if action_upper == "DELETE" then
        local id = text_match( action_arg or "", "^(%S+)$" )

        if not id then
            user:reply( msg_usage, hub_bot )
            return PROCESSED
        end

        clean_expired_messages( now )
        local deleted, scheduled = delete_saved_message( id )

        if deleted == nil then
            user:reply( "[ MASS PM ] --> The saved message could not be deleted.", hub_bot )
        elseif deleted == 0 then
            user:reply( "[ MASS PM ] --> No saved message has the ID " .. id .. ".", hub_bot )
        elseif scheduled then
            user:reply( "[ MASS PM ] --> Deleted scheduled message " .. id .. ".", hub_bot )
        else
            user:reply( "[ MASS PM ] --> Deleted " .. id .. " for " .. deleted .. " queued user(s).", hub_bot )
        end

        return PROCESSED
    end

    if action_upper == "CLEAR" or action_upper == "ERASE" then
        if action_arg ~= "DELETE" then
            user:reply( msg_clear_usage, hub_bot )
            return PROCESSED
        end

        local deleted = clear_saved_messages()

        if deleted == nil then
            user:reply( "[ MASS PM ] --> The saved messages could not be erased.", hub_bot )
        else
            user:reply( "[ MASS PM ] --> Erased all saved offline messages (" .. deleted .. " queued user(s)).", hub_bot )
        end

        return PROCESSED
    end

    if action_upper == "SCHEDULE" then
        local date_text, time_text, schedule_text = text_match( action_arg or "", "^(%d%d%d%d%-%d%d%-%d%d)%s+(%d%d:%d%d)%s+(.+)$" )

        if not schedule_text then
            user:reply( msg_schedule_usage, hub_bot )
            return PROCESSED
        end

        local execute_at = scheduled_timestamp( date_text, time_text, now )

        if not execute_at then
            user:reply( msg_schedule_time, hub_bot )
            return PROCESSED
        end

        local schedule_action, schedule_arg = text_match( schedule_text, "^%s*(%S+)%s*(.-)%s*$" )
        local schedule_action_upper = schedule_action and text_upper( schedule_action )
        local without_sender = false

        if schedule_action_upper == "NOSENDER" then
            without_sender = true
            schedule_text = schedule_arg or ""
        end

        local target_level
        local option, value, text = text_match( schedule_text, "^(%S+)=(%S+)%s+(.+)$" )

        if option and text_upper( option ) == "LEVEL" then
            if not text_match( value, "^%d+$" ) then
                user:reply( msg_level, hub_bot )
                return PROCESSED
            end

            target_level = tonumber( value )

            if not target_level or target_level < 0 then
                user:reply( msg_level, hub_bot )
                return PROCESSED
            end

            schedule_text = text
        end

        if not text_match( schedule_text, "%S" ) then
            user:reply( msg_schedule_usage, hub_bot )
            return PROCESSED
        end

        local id = new_schedule_id( now )
        local previous_schedules = clone_schedules( schedules )
        local sender_nick = user:nick()

        schedules[ id ] = {
            sender = sender_nick,
            sender_key = account_key( user:regnick() or sender_nick ) or "",
            text = schedule_text,
            execute_at = execute_at,
            target_level = target_level,
            without_sender = without_sender,
        }

        if not savetbl() then
            schedules = previous_schedules
            user:reply( "[ MASS PM ] --> The scheduled message could not be saved.", hub_bot )
            return PROCESSED
        end

        user:reply( "[ MASS PM ] --> Scheduled " .. id .. " for " .. os.date( "%Y-%m-%d %H:%M", execute_at ) .. ".", hub_bot )
        return PROCESSED
    end
    local without_sender = false
    local command_data = data

    if action_upper == "NOSENDER" then
        without_sender = true
        command_data = action_arg or ""
        action, action_arg = text_match( command_data, "^%s*(%S+)%s*(.-)%s*$" )
        action_upper = action and text_upper( action )
    end

    local mode = "DIRECT"
    local duration_text
    local text = command_data

    if action_upper == "OFFLINE" or action_upper == "BOTH" then
        mode = action_upper
        duration_text, text = text_match( action_arg or "", "^(%S+)%s+(.+)$" )

        if not duration_text or not text then
            user:reply( msg_usage, hub_bot )
            return PROCESSED
        end
    elseif not text_match( text, "%S" ) then
        user:reply( msg_usage, hub_bot )
        return PROCESSED
    end

    local target_level
    local option, value, option_text = text_match( text, "^(%S+)=(%S+)%s+(.+)$" )

    if option and text_upper( option ) == "LEVEL" then
        if not text_match( value, "^%d+$" ) then
            user:reply( msg_level, hub_bot )
            return PROCESSED
        end

        target_level = tonumber( value )

        if not target_level or target_level < 0 then
            user:reply( msg_level, hub_bot )
            return PROCESSED
        end

        text = option_text
    end

    local expires

    if mode ~= "DIRECT" then
        local duration_error
        expires, duration_error = expiry_after_duration( now, duration_text )

        if not expires then
            user:reply( duration_error, hub_bot )
            return PROCESSED
        end
    end

    local ok, regusers = pcall( hub.getregusers )

    if not ok or type( regusers ) ~= "table" then
        user:reply( "[ MASS PM ] --> Could not read the registered user list.", hub_bot )
        return PROCESSED
    end

    local sender_nick = user:nick()
    local sender_key = account_key( user:regnick() or sender_nick )
    local online_count = 0
    local offline_count = 0
    local eligible_count = 0
    local message_id
    local outgoing_message = format_mass_message( sender_nick, text, now, target_level, without_sender )

    if mode ~= "DIRECT" then
        message_id = new_message_id( now )
    end

    local previous

    if mode ~= "DIRECT" then
        clean_expired_messages( now )
        previous = clone_messages( messages )
    end

    -- Registered nicknames are the only stable lookup available for offline
    -- accounts, and are also used again when the user logs in.
    for _, account in ipairs( regusers ) do
        local target_key = account_key( account.nick )
        local is_sender = target_key and sender_key and target_key == sender_key

        if account.nick == sender_nick then
            is_sender = true
        end

        if account_matches_target_level( account, target_level ) and not is_sender then
            eligible_count = eligible_count + 1

            local target = hub.isnickonline( account.nick )

            if target then
                if mode ~= "OFFLINE" then
                    local sent, send_err = pcall( function()
                        target:reply( outgoing_message, hub_bot, hub_bot )
                    end )

                    if sent then
                        online_count = online_count + 1
                    else
                        hub_debug( "** " .. scriptname .. " could not send PM to " .. account.nick .. ": " .. tostring( send_err ) .. " **" )
                    end
                end
            elseif mode ~= "DIRECT" then
                if target_key then
                    queue_message( target_key, account.nick, message_id, sender_nick, text, now, expires, target_level, without_sender )
                    offline_count = offline_count + 1
                end
            end
        end
    end

    if eligible_count == 0 then
        user:reply( msg_no_registered, hub_bot )
        return PROCESSED
    end

    if offline_count > 0 and not savetbl() then
        messages = previous
        user:reply( msg_save_failed, hub_bot )
        return PROCESSED
    end

    if mode == "DIRECT" then
        user:reply( msg_sent .. online_count, hub_bot )
    else
        user:reply(
            msg_sent .. online_count ..
            msg_queued .. offline_count ..
            msg_expires .. os.date( "%Y-%m-%d %H:%M", expires ),
            hub_bot
        )
    end

    return PROCESSED

end

--------------------
-- LISTENERS
--------------------

hub.setlistener( "onLogin", {},

    function( user )

        local now = os.time()
        local key = account_key( user:regnick() or user:nick() )
        local entry = key and messages[ key ]

        if not entry or type( entry.messages ) ~= "table" then
            return nil
        end

        local remaining = {}

        for _, message in ipairs( entry.messages ) do
            if type( message ) == "table" and tonumber( message.expires ) and now < tonumber( message.expires ) then
                if message_enabled( user, message ) then
                    local sent, send_err = pcall( function()
                        user:reply( format_mass_message( message.sender or "", message.text or "", tonumber( message.created ) or now, tonumber( message.target_level ), message.without_sender == true ), hub_bot, hub_bot )
                    end )

                    if not sent then
                        table.insert( remaining, message )
                        hub_debug( "** " .. scriptname .. " could not deliver PM to " .. user:nick() .. ": " .. tostring( send_err ) .. " **" )
                    end
                end
            end
        end

        local previous = entry

        if #remaining == 0 then
            messages[ key ] = nil
        else
            messages[ key ] = {
                nick = key,
                messages = remaining,
            }
        end

        if not savetbl() then
            messages[ key ] = previous
        end

        return nil

    end
)

hub.setlistener( "onTimer", {},

    function()

        local now = os.time()

        run_due_schedules( now )

        if now - last_cleanup >= cleanup_interval then
            clean_expired_messages( now )
            last_cleanup = now
        end

        return nil

    end
)

hub.setlistener( "onStart", {}, function()

    hubcmd = hub.import( "etc_hubcommands" )
    assert( hubcmd )
    assert( hubcmd.add( "masspm", onbmsg ) )

    local help = hub.import( "cmd_help" )

    if help then
        help.reg( help_title, help_usage, help_desc, oplevel )
    end

    local ucmd = hub.import( "etc_usercommands" )
    if not ucmd then return nil end

    local cmd = "masspm"
    local menu

    if rcmenu == "original" then
        menu = { "User", "Messages", "Mass", "PM" }
    else
        menu = { "Mass PM" }
    end

local function menu_path( title, subtitle, item )
    local path = {}

    for i, menu_item in ipairs( menu ) do
        path[ i ] = menu_item
    end

    table.insert( path, title )

    if subtitle then
        table.insert( path, subtitle )
    end

    if item then
        table.insert( path, item )
    end

    return path
end

    --------------
    -- OP MENU
    --------------

    ucmd.add( menu_path( "Send online", "message" ), cmd, { "%[line:Message:]" }, { "CT1" }, oplevel )
    ucmd.add( menu_path( "Send online", "message without sender" ), cmd, { "nosender", "%[line:Message:]" }, { "CT1" }, oplevel )

    ucmd.add( menu_path( "Send offline", "message" ), cmd, { "offline", "%[line:Duration (e.g., 10h, 5d or 2w):]", "%[line:Message:]" }, { "CT1" }, oplevel )
    ucmd.add( menu_path( "Send offline", "message without sender" ), cmd, { "nosender", "offline", "%[line:Duration (e.g., 10h or 2w):]", "%[line:Message:]" }, { "CT1" }, oplevel )

    ucmd.add( menu_path( "Send online and offline", "message" ), cmd, { "both", "%[line:Duration (e.g., 10h, 5d or 2w):]", "%[line:Message:]" }, { "CT1" }, oplevel )
    ucmd.add( menu_path( "Send online and offline", "message without sender" ), cmd, { "nosender", "both", "%[line:Duration (e.g., 10h or 2w):]", "%[line:Message:]" }, { "CT1" }, oplevel )

    ucmd.add( menu_path( "Schedule", "message" ), cmd, { "schedule", "%[line:Date (YYYY-MM-DD):]", "%[line:Time (HH:MM):]", "%[line:Message:]" }, { "CT1" }, oplevel )
    ucmd.add( menu_path( "Schedule", "message without sender" ), cmd, { "schedule", "%[line:Date (YYYY-MM-DD):]", "%[line:Time (HH:MM):]", "nosender", "%[line:Message:]" }, { "CT1" }, oplevel )

    ucmd.add( menu_path( "List saved messages" ), cmd, { "list" }, { "CT1" }, oplevel )
    ucmd.add( menu_path( "Delete saved message" ), cmd, { "delete", "%[line:Message ID:]" }, { "CT1" }, oplevel )
    ucmd.add( menu_path( "Clear all saved messages" ), cmd, { "clear", "%[line:Type DELETE to confirm]" }, { "CT1" }, oplevel )

    local level_list = {}
    local i = 1

    for level, name in pairs( levels ) do
        if level > 0 then
            level_list[ i ] = level
            i = i + 1
        end
    end

    table_sort( level_list )

    ----------------------------
    -- OP MENU FOR SEND TO LEVEL
    ----------------------------

    for _, level in ipairs( level_list ) do

        ucmd.add( menu_path( "Send online", "message to level (without sender)", levels[ level ] ), cmd, { "%[line:Leave empty or add nosender:]", "level=" .. level, "%[line:Message:]" }, { "CT1" }, oplevel )

        ucmd.add( menu_path( "Send offline", "message to level (without sender)", levels[ level ] ), cmd, { "offline", "%[line:Duration (e.g., 10h, 5d or 2w):]", "%[line:Leave empty or add nosender:]", "level=" .. level, "%[line:Message:]" }, { "CT1" }, oplevel )

        ucmd.add( menu_path( "Send online and offline", "message to level (without sender)", levels[ level ] ), cmd, { "both", "%[line:Duration (e.g., 10h, 5d or 2w):]", "%[line:Leave empty or add nosender:]", "level=" .. level, "%[line:Message:]" }, { "CT1" }, oplevel )

        ucmd.add( menu_path( "Schedule", "message to level (without sender)", levels[ level ] ), cmd, { "schedule", "%[line:Date (YYYY-MM-DD):]", "%[line:Time (HH:MM):]", "%[line:Leave empty or add nosender:]", "level=" .. level, "%[line:Message:]" }, { "CT1" }, oplevel )

    end

    return nil

end
)

--------------------
-- LOAD DATA
--------------------

loadtbl()
if normalize_messages() and not savetbl() then
    hub_debug( "** " .. scriptname .. " could not migrate saved messages to nickname keys **" )
end
clean_expired_messages( os.time() )
hub_debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )

-----------
--[ END ]--
-----------
