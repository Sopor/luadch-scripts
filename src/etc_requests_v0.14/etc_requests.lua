﻿--[[

  etc_requests by pulsar

    Version: Luadch LUA 5.1x

    v0.1

      - Befehl: [+!#]request show  / anzeigen aller Request Einträge
      - Befehl: [+!#]request showall  / anzeigen aller Einträge
      - Befehl: [+!#]request add <relname>  / eintragen eines Request Releases
      - Befehl: [+!#]request del <relname>  / löschen eines Releases (Request/Filled)
      - Befehl: [+!#]request delall  / löschen aller Releases
      - Befehl: [+!#]filled show  / anzeigen aller Filled Releases
      - Befehl: [+!#]filled add <relname>  / eintragen eines FilledReleases

    v0.2

      - Funktion: Eingabe prüfen auf Leerstellen
      - Befehl: [+!#]request delr  / löschen aller Request Einträge
      - Befehl: [+!#]request delf  / löschen aller Filled Einträge

    v0.3

      - Funktion: Aktivierung / Deaktivierung der Leerstellenprüfung

    v0.4

      - Korrigiert: Fehler in den Language-Dateien
      - Funktion: Senden der Liste beim Login
      - Änderung: Timer Funktion

    v0.5

      - Korrigiert: Fehler in Timer Funktion

    v0.6

      - Verbessert / Erweitert: Datenbank
      - Hinzugefügt: Nummerierung
      - Hinzugefügt: Datum

    v0.7: by Jerker

      - Fixed problem with empty message

    v0.8: by Jerker

      - Added setting for date format
      - Added timer function to automatically delete old request
      - Added command: [+!#]request delf  / delete all Deleted requests
      - Added Swedish
      - Fixed bug in onBroadcast
      - Send PM to requester when filled if user is online or at next login
      - Sets filled request as deleted when PM is sent

    v0.9: by Sopor
        - changed all the messages from german to english
        - renamed check_spaces to check_scene because it will include all none scene chars
          allowed chars are: ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._()
        - changed check_spaces output message for all languages except lang.de

   v0.10: by Sopor
        - fixed bug in not allowed chars (underscore is now allowed in file names)

   v0.11: by Sopor
        - tab is not allowed before or after a release name

   v0.12: by Sopor
        - removed all double words in rightclick menu (Request / add / add a release)

   v0.13: by Sopor
        - fixed the "bad argument #1 to 'find' (string expected, got nil)"

   v0.14: by Sopor
        - release name must contain a dash followed by at least one char

   v0.15: by Sopor
        - change a little bit here and there to improve the script

]]--


--------------
--[SETTINGS]--
--------------

local scriptname = "etc_requests"
local scriptversion = "0.15"

local scriptlang = cfg.get "language"
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or { }; err = err and hub.debug( err )

--> Command request
local cmd_request = "request"

--> Parameter request
local cmd_p_request_add = "add"
local cmd_p_request_show = "show"
local cmd_p_request_showall = "showall"
local cmd_p_request_del = "del"
local cmd_p_request_delall = "delall"
local cmd_p_request_delr = "delr"
local cmd_p_request_delf = "delf"
local cmd_p_request_deld = "deld"
local cmd_p_request_showdel = "showdel"

--> Command filled
local cmd_filled = "filled"

--> Parameter filled
local cmd_p_filled_add = "add"
local cmd_p_filled_show = "show"

--> Who can use the normal commands
local minlevel = 10

--> Who can delete individual release from the database
local oplevel = 60

--> Who is allowed to all requests, filled or completely delete the database
local masterlevel = 100

--> Valid date formats are dmy (day.month.year), mdy (month/day/year) and ymd (year-month-day)
local dateformat = "mdy"

--> Delete request after days, no value equals disabled
local keepdays = 30

--> At which level the table is to be sent at login or timer? (true=YES/false=NO)
local sendto = {

  [ 0 ] = false, --> unreg
  [ 10 ] = true, --> guest
  [ 20 ] = true, --> reg
  [ 30 ] = true, --> vip
  [ 40 ] = true, --> svip
  [ 50 ] = false, --> server
  [ 55 ] = false, --> sbot
  [ 60 ] = true, --> operator
  [ 70 ] = true, --> supervisor
  [ 80 ] = true, --> admin
  [ 100 ] = true, --> hubowner
}

--> When should the table be sent?
local sendtime = {

  ["03:00"] = true,
  ["06:00"] = true,
  ["09:00"] = true,
  ["12:00"] = true,
  ["15:00"] = true,
  ["18:00"] = true,
  ["21:00"] = true,
  ["23:00"] = true,
  ["00:00"] = true,

}

--> Send table when logging into the hub? (true=YES/false=NO)
local sendonconnect = true

--> Only allow scene release chars? (true=YES/false=NO)
local check_scene = true

--> Database
local requests_file = "scripts/etc_requests/releases.tbl"

--> When you are not allowed to use the command
local msg_denied = lang.msg_denied or "[ REQUESTS ]--> You are not allowed to use this command!"

--> msgs
local msgs = {

msg_etc_001 = lang.msg_etc_001 or "   |   by: ",
msg_etc_002 = lang.msg_etc_002 or "   |   requested by: ",
msg_etc_003 = lang.msg_etc_003 or "   |   filled by: ",
msg_etc_004 = lang.msg_etc_004 or "   |   deleted by: ",
msg_etc_005 = lang.msg_etc_005 or "REQUEST      ",
msg_etc_006 = lang.msg_etc_006 or "FILLED       ",
msg_etc_007 = lang.msg_etc_007 or "DELETED      ",
msg_etc_008 = lang.msg_etc_008 or "ID: ",
msg_etc_009 = lang.msg_etc_009 or "[ REQUESTS ]--> Added by   ",
msg_etc_010 = lang.msg_etc_010 or "[ REQUESTS ]--> Filled by   ",
msg_etc_011 = lang.msg_etc_011 or "[ REQUESTS ]--> Your request will automatically be deleted after %i days.",
msg_etc_012 = lang.msg_etc_012 or "[ REQUESTS ]--> Use +filled add %i to fill this request within %i days.", -- Sopor

msg_etc_101 = lang.msg_etc_101 or "[ REQUESTS ]--> The following release was deleted:   ",
msg_etc_102 = lang.msg_etc_102 or "[ REQUESTS ]--> All releases were deleted!",
msg_etc_103 = lang.msg_etc_103 or "[ REQUESTS ]--> All releases with status REQUEST were deleted!",
msg_etc_104 = lang.msg_etc_104 or "[ REQUESTS ]--> All releases with status FILLED were deleted!",
msg_etc_105 = lang.msg_etc_105 or "[ REQUESTS ]--> All releases with status DELETED were deleted!",

msg_etc_201 = lang.msg_etc_201 or "[ REQUESTS ]--> Release not found.",
msg_etc_202 = lang.msg_etc_202 or "[ REQUESTS ]--> There are no releases in the database.",
msg_etc_203 = lang.msg_etc_203 or "[ REQUESTS ]--> Input with unallowed chars, you are only allowed to use scene release names!",
msg_etc_204 = lang.msg_etc_204 or "[ REQUESTS ]--> Request: unknown param [2]",
msg_etc_205 = lang.msg_etc_205 or "[ REQUESTS ]--> Filled: unknown param [2]",
msg_etc_206 = lang.msg_etc_206 or "[ REQUESTS ]--> Release already added as REQUEST.",
msg_etc_207 = lang.msg_etc_207 or "[ REQUESTS ]--> Release already added as FILLED.",
msg_etc_208 = lang.msg_etc_208 or "[ REQUESTS ]--> Release already added as DELETED.",

}

--> Rightclick menus
local ucmd_menu_request_add = lang.ucmd_menu_request_add or { "Requests", "add", "a release" }
local ucmd_menu_filled_add = lang.ucmd_menu_filled_add or { "Requests", "add", "a release as filled" }
local ucmd_menu_request_show = lang.ucmd_menu_request_show or { "Requests", "show", "all requests" }
local ucmd_menu_filled_show = lang.ucmd_menu_filled_show or { "Requests", "show", "all filled" }
local ucmd_menu_del_show = lang.ucmd_menu_del_show or { "Requests", "show", "all deleted" }
local ucmd_menu_request_showall = lang.ucmd_menu_request_showall or { "Requests", "show", "all releases" }
local ucmd_menu_del_request = lang.ucmd_menu_del_request or { "Requests", "delete", "one release" }
local ucmd_menu_del_requests_all_r = lang.ucmd_menu_del_requests_all_r or { "Requests", "delete", "all requested releases" }
local ucmd_menu_del_requests_all_f = lang.ucmd_menu_del_requests_all_f or { "Requests", "delete", "all filled releases" }
local ucmd_menu_del_requests_all_d = lang.ucmd_menu_del_requests_all_d or { "Requests", "delete", "all deleted releases" }
local ucmd_menu_del_requests_all = lang.ucmd_menu_del_requests_all or { "Requests", "delete", "all releases" }

local ucmd_relname = lang.ucmd_relname or "Name of the release"

--> Help function
local help_title = lang.help_title or "etc_requests.lua"
local help_usage = lang.help_usage or "[+!#]request show / [+!#]request showall / [+!#]request add <relname> / [+!#]request del <relname> / [+!#]request delall / [+!#]filled show / [+!#]filled add <relname> / [+!#]request showdel\n\n\tUse only allowed chars and complete release names! All other requests will be deleted!"
local help_desc = lang.help_desc or  "a script to request / fill releases"

--> Message header
local msg_header = [[


===========================================================================================================================================
                                                                                                                                  REQUESTS

    ]]

--> Message footer
local msg_footer = [[

===========================================================================================================================================
    ]]


----------
--[CODE]--
----------

local hub_getbot = hub.getbot()
local hub_getusers = hub.getusers
local hub_broadcast = hub.broadcast
local hub_isnickonline = hub.isnickonline
local utf_match = utf.match
local utf_format = utf.format
local util_savetable = util.savetable
local util_loadtable = util.loadtable
local table_remove = table.remove

local request_add
local request_show
local filled_add
local filled_show
local request_showall
local del_request
local del_requests_all_r
local del_requests_all_f
local del_requests_all_d
local del_requests_all
local del_show

local delay = 60
local os_time = os.time
local os_date = os.date
local os_difftime = os.difftime
local start = os_time()

local requests_tbl = util_loadtable( requests_file ) or {}

--> Flags ( dont change it! )
local tDate = "tDate"
local tNick_R = "tNick_R"
local tNick_F = "tNick_F"
local tNick_D = "tNick_D"
local tRel = "tRel"
local tRelFlag = "tRelFlag"
local tAdded = "tAdded"
local R = "R"
local F = "F"
local D = "D"

local dateparser = function()
  local day = os_date( "%d" )
  local month = os_date( "%m" )
  local year = os_date( "%Y" )
  local datum
  if dateformat == "dmy" then
    datum = day .. "." .. month .. "." .. year
  elseif dateformat == "mdy" then
    datum = month .. "/" .. day .. "/" .. year
  elseif dateformat == "ymd" then
    datum = year .. "-" .. month .. "-" .. day
  else
    datum = day .. "." .. month .. "." .. year
  end
  return datum
end

hub.setlistener( "onBroadcast", { },
  function( user, adccmd, txt )
    local s1 = utf.match( txt, "^[+!#](%a+)" )
    local s2 = utf.match( txt, "^[+!#]%a+ (%a+)" )
    local s3 = utf.match( txt, "^[+!#]%a+ %a+ (.+%-.+)" )

    request_add = function()
      local user_level = user:level()
      local user_nick = user:nick()
      if user_level >= minlevel then
        if check_scene then
          if (s3 == nil) then
            user:reply( help_usage, hub_getbot )
            return PROCESSED
          else
            local scene = string.find( s3, "[\9\32-\39\42-\44\47\58-\64\91-\94\96\123-\126\128-\193]" )
            if not scene then
              local check_tRelFlag_R = false
              local check_tRelFlag_F = false
              local check_tRelFlag_D = false
              for index, tbl in pairs( requests_tbl ) do
                for k, v in pairs( tbl ) do
                  if ( k == tRel and v == s3 ) then
                    if requests_tbl[ index ].tRelFlag == R then
                      check_tRelFlag_R = true
                      break
                    end
                    if requests_tbl[ index ].tRelFlag == F then
                      check_tRelFlag_F = true
                      break
                    end
                    if requests_tbl[ index ].tRelFlag == D then
                      check_tRelFlag_D = true
                      break
                    end
                  end
                end
              end
              if check_tRelFlag_R then
                user:reply( msgs.msg_etc_206, hub_getbot )
                return PROCESSED
              elseif check_tRelFlag_F then
                user:reply( msgs.msg_etc_207, hub_getbot )
                return PROCESSED
              elseif check_tRelFlag_D then
                user:reply( msgs.msg_etc_208, hub_getbot )
                return PROCESSED
              else
                local n = table.maxn( requests_tbl )
                local i = n + 1
                requests_tbl[ i ] = {}
                requests_tbl[ i ].tDate = dateparser()
                requests_tbl[ i ].tNick_R = user_nick
                requests_tbl[ i ].tRel = s3
                requests_tbl[ i ].tRelFlag = R
                requests_tbl[ i ].tAdded = os_time()
                util_savetable( requests_tbl, "requests_tbl", requests_file )
                hub_broadcast( msgs.msg_etc_009 .. user_nick .. ":   " .. s3 .. " " .. utf_format( msgs.msg_etc_012, keepdays ), hub_getbot ) --Sopor
                user:reply( utf_format(msgs.msg_etc_011, keepdays ), hub_getbot) -- Sopor
                return PROCESSED
              end
  
            else
              user:reply( msgs.msg_etc_203, hub_getbot )
              return PROCESSED
            end
          end
        else
          local check_tRelFlag_R = false
          local check_tRelFlag_F = false
          local check_tRelFlag_D = false
          for index, tbl in pairs( requests_tbl ) do
            for k, v in pairs( tbl ) do
              if ( k == tRel and v == s3 ) then
                if requests_tbl[ index ].tRelFlag == R then
                  check_tRelFlag_R = true
                  break
                end
                if requests_tbl[ index ].tRelFlag == F then
                  check_tRelFlag_F = true
                  break
                end
                if requests_tbl[ index ].tRelFlag == D then
                  check_tRelFlag_D = true
                  break
                end
              end
            end
          end
          if check_tRelFlag_R then
            user:reply( msgs.msg_etc_206, hub_getbot )
            return PROCESSED
          elseif check_tRelFlag_F then
            user:reply( msgs.msg_etc_207, hub_getbot )
            return PROCESSED
          elseif check_tRelFlag_D then
            user:reply( msgs.msg_etc_208, hub_getbot )
            return PROCESSED
          else
            local n = table.maxn( requests_tbl )
            local i = n + 1
            requests_tbl[ i ] = {}
            requests_tbl[ i ].tDate = dateparser()
            requests_tbl[ i ].tNick_R = user_nick
            requests_tbl[ i ].tRel = s3
            requests_tbl[ i ].tRelFlag = R
            requests_tbl[ i ].tAdded = os_time()
            util_savetable( requests_tbl, "requests_tbl", requests_file )
            hub_broadcast( msgs.msg_etc_009 .. user_nick .. ":   " .. s3, hub_getbot )
            user:reply(utf_format(msgs.msg_etc_011, keepdays), hub_getbot)
            return PROCESSED
          end
        end
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    filled_add = function()
      local user_level = user:level()
      local user_nick = user:nick()
      if user_level >= minlevel then
        local check_tRel = false
        local check_tRelFlag_R = false
        local check_tRelFlag_F = false
        local check_tRelFlag_D = false
        local i
        for index, tbl in pairs( requests_tbl ) do
          for k, v in pairs( tbl ) do
            if ( k == tRel and v == s3 ) then
              i = index
              check_tRel = true
              if requests_tbl[ index ].tRelFlag == R then
                check_tRelFlag_R = true
                break
              end
              if requests_tbl[ index ].tRelFlag == F then
                check_tRelFlag_F = true
                break
              end
              if requests_tbl[ index ].tRelFlag == D then
                check_tRelFlag_D = true
                break
              end
            end
          end
        end
        if not check_tRel then
          user:reply( msgs.msg_etc_201, hub_getbot )
          return PROCESSED
        end
        if check_tRelFlag_F then
          user:reply( msgs.msg_etc_207, hub_getbot )
          return PROCESSED
        end
        if check_tRelFlag_D then
          user:reply( msgs.msg_etc_208, hub_getbot )
          return PROCESSED
        end
        if check_tRelFlag_R then
          requests_tbl[ i ].tNick_F = user_nick
          requests_tbl[ i ].tRelFlag = F
          local requester = hub_isnickonline(requests_tbl[ i ].tNick_R)
          if requester then
            requester:reply( msgs.msg_etc_010 .. user_nick .. ":   " .. s3, hub_getbot, hub_getbot )
            requests_tbl[ i ].tNick_D = hub_getbot:nick()
            requests_tbl[ i ].tRelFlag = D
          end
          util_savetable( requests_tbl, "requests_tbl", requests_file )
          hub_broadcast( msgs.msg_etc_010 .. user_nick .. ":   " .. s3, hub_getbot )
          return PROCESSED
        end
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    request_show = function()
      local user_level = user:level()
      if user_level >= minlevel then
        local msg = "\n"
        if next( requests_tbl ) then
          for index, tbl in ipairs( requests_tbl ) do
            for k, v in pairs( tbl ) do
              if ( k == tRelFlag and v == R ) then
                msg = msg .. msgs.msg_etc_008 .. utf_format("%02i", index) .. "  |  " .. tbl[ tDate ] .. "  |  " .. msgs.msg_etc_005 ..
                "\t" .. tbl[ tRel ] .. msgs.msg_etc_002 .. tbl[ tNick_R ] .. "\n"
              end
            end
          end
          if msg ~= "\n" then
            user:reply( msg_header .. msg .. msg_footer, hub_getbot, hub_getbot )
          else
            user:reply( msgs.msg_etc_202, hub_getbot )
          end
          return PROCESSED
        else
          user:reply( msgs.msg_etc_202, hub_getbot )
          return PROCESSED
        end
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    filled_show = function()
      local user_level = user:level()
      if user_level >= minlevel then
        local msg = "\n"
        if next( requests_tbl ) then
          for index, tbl in ipairs( requests_tbl ) do
            for k, v in pairs( tbl ) do
              if ( k == tRelFlag and v == F ) then
                msg = msg .. msgs.msg_etc_008 .. utf_format("%02i", index) .. "  |  " .. tbl[ tDate ] .. "  |  " .. msgs.msg_etc_006 ..
                "\t" .. tbl[ tRel ] .. msgs.msg_etc_002 .. tbl[ tNick_R ] .. msgs.msg_etc_003 .. tbl[ tNick_F ] .. "\n"
              end
            end
          end
          if msg ~= "\n" then
            user:reply( msg_header .. msg .. msg_footer, hub_getbot, hub_getbot )
          else
            user:reply( msgs.msg_etc_202, hub_getbot )
          end
          return PROCESSED
        else
          user:reply( msgs.msg_etc_202, hub_getbot )
          return PROCESSED
        end
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    request_showall = function()
      local user_level = user:level()
      if user_level >= minlevel then
        local msg = "\n"
        local msg2 = "\n"
        local msg3 = "\n"
        if next( requests_tbl ) then
          for index, tbl in ipairs( requests_tbl ) do
            for k, v in pairs( tbl ) do
              if ( k == tRelFlag and v == R ) then
                msg = msg .. msgs.msg_etc_008 .. utf_format("%02i", index) .. "  |  " .. tbl[ tDate ] .. "  |  " .. msgs.msg_etc_005 ..
                "\t" .. tbl[ tRel ] .. msgs.msg_etc_002 .. tbl[ tNick_R ] .. "\n"
              end
              if ( k == tRelFlag and v == F ) then
                msg2 = msg2 .. msgs.msg_etc_008 .. utf_format("%02i", index) .. "  |  " .. tbl[ tDate ] .. "  |  " .. msgs.msg_etc_006 ..
                "\t" .. tbl[ tRel ] .. msgs.msg_etc_002 .. tbl[ tNick_R ] .. msgs.msg_etc_003 .. tbl[ tNick_F ] .. "\n"
              end
              --if ( k == tRelFlag and v == D ) then
                --msg3 = msg3 .. msgs.msg_etc_008 .. utf_format("%02i", index) .. "  |  " .. tbl[ tDate ] .. "  |  " .. msgs.msg_etc_007 ..
                --"\t" .. tbl[ tRel ] .. msgs.msg_etc_002 .. tbl[ tNick_R ] .. msgs.msg_etc_004 .. tbl[ tNick_D ] .. "\n"
              --end
            end
          end
          if msg ~= "\n" or msg2 ~= "\n" or msg3 ~= "\n" then
            user:reply( msg_header .. msg .. msg2 .. msg3 .. msg_footer, hub_getbot, hub_getbot )
          else
            user:reply( msgs.msg_etc_202, hub_getbot )
          end
          return PROCESSED
        else
          user:reply( msgs.msg_etc_202, hub_getbot )
          return PROCESSED
        end
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    del_show = function()
      local user_level = user:level()
      if user_level >= minlevel then
        local msg = "\n"
        if next( requests_tbl ) then
          for index, tbl in ipairs( requests_tbl ) do
            for k, v in pairs( tbl ) do
              if ( k == tRelFlag and v == D ) then
                msg = msg .. msgs.msg_etc_008 .. utf_format("%02i", index) .. "  |  " .. tbl[ tDate ] .. "  |  " .. msgs.msg_etc_007 ..
                "\t" .. tbl[ tRel ] .. msgs.msg_etc_002 .. tbl[ tNick_R ] .. msgs.msg_etc_004 .. tbl[ tNick_D ] .. "\n"
              end
            end
          end
          if msg ~= "\n" then
            user:reply( msg_header .. msg .. msg_footer, hub_getbot, hub_getbot )
          else
            user:reply( msgs.msg_etc_202, hub_getbot )
          end
          return PROCESSED
        else
          user:reply( msgs.msg_etc_202, hub_getbot )
          return PROCESSED
        end
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    del_request = function()
      local user_level = user:level()
      local user_nick = user:nick()
      if user_level >= oplevel then
        local check_tRel = false
        local check_tRelFlag_R = false
        local check_tRelFlag_F = false
        local check_tRelFlag_D = false
        local i
        for index, tbl in pairs( requests_tbl ) do
          for k, v in pairs( tbl ) do
            if ( k == tRel and v == s3 ) then
              check_tRel = true
              i = index
              if requests_tbl[ index ].tRelFlag == R then
                check_tRelFlag_R = true
                break
              end
              if requests_tbl[ index ].tRelFlag == F then
                check_tRelFlag_F = true
                break
              end
              if requests_tbl[ index ].tRelFlag == D then
                check_tRelFlag_D = true
                break
              end
            end
          end
        end
        if check_tRel then
          if check_tRelFlag_R then
            requests_tbl[ i ].tNick_D = user_nick
            requests_tbl[ i ].tRelFlag = D
            util_savetable( requests_tbl, "requests_tbl", requests_file )
            user:reply( msgs.msg_etc_101 .. s3, hub_getbot )
            return PROCESSED
          elseif check_tRelFlag_F then
            requests_tbl[ i ].tNick_D = user_nick
            requests_tbl[ i ].tRelFlag = D
            util_savetable( requests_tbl, "requests_tbl", requests_file )
            user:reply( msgs.msg_etc_101 .. s3, hub_getbot )
            return PROCESSED
          elseif check_tRelFlag_D then
            user:reply( msgs.msg_etc_208, hub_getbot )
            return PROCESSED
          end
        else
          user:reply( msgs.msg_etc_201, hub_getbot )
          return PROCESSED
        end
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    del_requests_all_r = function()
      local user_level = user:level()
      local user_nick = user:nick()
      if user_level >= masterlevel then
        local check = false
        for key, value in pairs( requests_tbl ) do
          if key ~= nil then
            check = true
            break
          end
        end
        if check then
          for index, tbl in pairs( requests_tbl ) do
            for k, v in pairs( tbl ) do
              if ( k == tRelFlag and v == R ) then
                requests_tbl[ index ].tNick_D = user_nick
                requests_tbl[ index ].tRelFlag = D
                break
              end
            end
          end
          util_savetable( requests_tbl, "requests_tbl", requests_file )
          user:reply( msgs.msg_etc_103, hub_getbot )
          return PROCESSED
        else
          user:reply( msgs.msg_etc_202, hub_getbot )
          return PROCESSED
        end
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    del_requests_all_f = function()
      local user_level = user:level()
      local user_nick = user:nick()
      if user_level >= masterlevel then
        local check = false
        for key, value in pairs( requests_tbl ) do
          if key ~= nil then
            check = true
            break
          end
        end
        if check then
          for index, tbl in pairs( requests_tbl ) do
            for k, v in pairs( tbl ) do
              if ( k == tRelFlag and v == F ) then
                requests_tbl[ index ].tNick_D = user_nick
                requests_tbl[ index ].tRelFlag = D
                break
              end
            end
          end
          util_savetable( requests_tbl, "requests_tbl", requests_file )
          user:reply( msgs.msg_etc_104, hub_getbot )
          return PROCESSED
        else
          user:reply( msgs.msg_etc_202, hub_getbot )
          return PROCESSED
        end
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    del_requests_all_d = function()
      local user_level = user:level()
      local user_nick = user:nick()
      if user_level >= masterlevel then
        local check = false
        for key, value in pairs( requests_tbl ) do
          if key ~= nil then
            check = true
            break
          end
        end
        if check then
          local index = 1
          while index <= #requests_tbl do
            if ( requests_tbl[ index].tRelFlag == D ) then
              table_remove(requests_tbl, index )
            else
              index = index + 1
            end
          end
          util_savetable( requests_tbl, "requests_tbl", requests_file )
          user:reply( msgs.msg_etc_105, hub_getbot )
          return PROCESSED
        else
          user:reply( msgs.msg_etc_202, hub_getbot )
          return PROCESSED
        end
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    del_requests_all = function()
      local user_level = user:level()
      if user_level >= masterlevel then
        local check = false
        for key, value in pairs( requests_tbl ) do
          if key ~= nil then
            check = true
            break
          end
        end
        if check then
          for index, tbl in pairs( requests_tbl ) do
            requests_tbl[ index ] = nil
          end
          util_savetable( requests_tbl, "requests_tbl", requests_file )
          user:reply( msgs.msg_etc_102, hub_getbot )
          return PROCESSED
        else
          user:reply( msgs.msg_etc_202, hub_getbot )
          return PROCESSED
        end
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    if s1 == cmd_request then
      local user_level = user:level()
      if user_level >= minlevel then
        if s2 == cmd_p_request_add then
          request_add()
        elseif s2 == cmd_p_request_show then
          request_show()
        elseif s2 == cmd_p_request_showall then
          request_showall()
        elseif s2 == cmd_p_request_del then
          del_request()
        elseif s2 == cmd_p_request_delr then
          del_requests_all_r()
        elseif s2 == cmd_p_request_delf then
          del_requests_all_f()
        elseif s2 == cmd_p_request_deld then
          del_requests_all_d()
        elseif s2 == cmd_p_request_delall then
          del_requests_all()
        elseif s2 == cmd_p_request_showdel then
          del_show()
        else
          user:reply( help_usage, hub_getbot )
        end
        return PROCESSED
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end

    if s1 == cmd_filled then
      local user_level = user:level()
      if user_level >= minlevel then
        if s2 == cmd_p_filled_add then
          filled_add()
        elseif s2 == cmd_p_filled_show then
          filled_show()
        else
          user:reply( help_usage, hub_getbot )
        end
        return PROCESSED
      else
        user:reply( msg_denied, hub_getbot )
        return PROCESSED
      end
    end
    return nil
  end
)

hub.setlistener( "onLogin", {},
  function( user )
    local user_level = user:level()
    if user_level >= minlevel then
      local msg = "\n"
      local msg2 = "\n"
      if next( requests_tbl ) then
        for index, tbl in ipairs( requests_tbl ) do
          for k, v in pairs( tbl ) do
            if ( k == tRelFlag and v == R ) then
              msg = msg .. msgs.msg_etc_008 .. utf_format("%02i", index) .. "  |  " .. tbl[ tDate ] .. "  |  " .. msgs.msg_etc_005 .. "\t" .. tbl[ tRel ] .. msgs.msg_etc_001 .. tbl[ tNick_R ] .. "\n"
            end
            if ( k == tRelFlag and v == F ) then
              if tbl[ tNick_R ] == user:nick() then
                msg2 = msg2 .. msgs.msg_etc_008 .. utf_format("%02i", index) .. "  |  " .. tbl[ tDate ] .. "  |  " .. msgs.msg_etc_006 .. "\t" .. tbl[ tRel ] .. msgs.msg_etc_001 .. tbl[ tNick_F ] .. "\n"
                tbl[ tRelFlag ] = D
                tbl[ tNick_D ] = hub_getbot:nick()
              end
            end
          end
        end
        if sendonconnect and sendto[ user_level ] then
          if msg ~= "\n" then
            user:reply( msg_header .. msg .. msg_footer, hub_getbot )
          end
        end
        if msg2 ~= "\n" then
          util_savetable( requests_tbl, "requests_tbl", requests_file )
          user:reply( msg_header .. msg2 .. msg_footer, hub_getbot, hub_getbot )
        end
      end
    end
  end
)

hub.setlistener( "onTimer", { },
  function()
    if os_difftime( os_time() - start ) >= delay then
      if sendtime[ os.date( "%H:%M" ) ] then
        if next( requests_tbl ) then
          local msg = "\n"
          local msg2 = "\n"
          local msg3 = "\n"
          for index, tbl in ipairs( requests_tbl ) do
            if keepdays and tbl[ tRelFlag ] ~= D and tbl[ tAdded ] and os_time() - tbl[ tAdded ] > keepdays * 24 * 60 * 60 then
              tbl[ tRelFlag ] = D
              tbl[ tNick_D ] = hub_getbot:nick()
              msg3 = msg3 .. msgs.msg_etc_008 .. utf_format("%02i", index) .. "  |  " .. tbl[ tDate ] .. "  |  " .. msgs.msg_etc_007 .. "\t" .. tbl[ tRel ] .. msgs.msg_etc_001 .. tbl[ tNick_D ] .. "\n"
            else
              if tbl[ tRelFlag ] == R then
                msg = msg .. msgs.msg_etc_008 .. utf_format("%02i", index) .. "  |  " .. tbl[ tDate ] .. "  |  " .. msgs.msg_etc_005 .. "\t" .. tbl[ tRel ] .. msgs.msg_etc_001 .. tbl[ tNick_R ] .. "\n"
              end
              if tbl[ tRelFlag ] == F then
                msg2 = msg2 .. msgs.msg_etc_008 .. utf_format("%02i", index) .. "  |  " .. tbl[ tDate ] .. "  |  " .. msgs.msg_etc_006 .. "\t" .. tbl[ tRel ] .. msgs.msg_etc_001 .. tbl[ tNick_F ] .. "\n"
              end
            end
          end
          if msg ~= "\n" or msg2 ~= "\n" or msg3 ~= "\n" then
            if msg == "\n" then
              msg = ""
            end
            if msg2 == "\n" then
              msg2 = ""
            end
            if msg3 == "\n" then
              msg3 = ""
            else
              util_savetable( requests_tbl, "requests_tbl", requests_file )
            end
            for sid, user in pairs( hub_getusers() ) do
              if not user:isbot() then
                if sendto[ user:level() ] then
                  user:reply( msg_header .. msg .. msg2 .. msg3 .. msg_footer, hub_getbot )
                end
              end
            end
          end
        end
      end
      start = os_time()
    end
    return nil
  end
)

hub.setlistener( "onStart", {},
  function()
    local help = hub.import "cmd_help"
    if help then
      help.reg( help_title, help_usage, help_desc, minlevel )
    end
    local ucmd = hub.import "etc_usercommands"
    if ucmd then
      ucmd.add( ucmd_menu_request_add, cmd_request, { cmd_p_request_add, "%[line:" .. ucmd_relname .. "]" }, { "CT1" }, minlevel )
      ucmd.add( ucmd_menu_filled_add, cmd_filled, { cmd_p_filled_add, "%[line:" .. ucmd_relname .. "]" }, { "CT1" }, minlevel )
      ucmd.add( ucmd_menu_request_showall, cmd_request, { cmd_p_request_showall, " " }, { "CT1" }, minlevel )
      ucmd.add( ucmd_menu_request_show, cmd_request, { cmd_p_request_show, " " }, { "CT1" }, minlevel )
      ucmd.add( ucmd_menu_filled_show, cmd_filled, { cmd_p_filled_show, " " }, { "CT1" }, minlevel )
      ucmd.add( ucmd_menu_del_request, cmd_request, { cmd_p_request_del, "%[line:" .. ucmd_relname .. "]" }, { "CT1" }, oplevel )
      ucmd.add( ucmd_menu_del_requests_all_r, cmd_request, { cmd_p_request_delr, " " }, { "CT1" }, masterlevel )
      ucmd.add( ucmd_menu_del_requests_all_f, cmd_request, { cmd_p_request_delf, " " }, { "CT1" }, masterlevel )
      ucmd.add( ucmd_menu_del_requests_all_d, cmd_request, { cmd_p_request_deld, " " }, { "CT1" }, masterlevel )
      ucmd.add( ucmd_menu_del_requests_all, cmd_request, { cmd_p_request_delall, " " }, { "CT1" }, masterlevel )
      ucmd.add( ucmd_menu_del_show, cmd_request, { cmd_p_request_showdel, " " }, { "CT1" }, oplevel )
    end
    return nil
  end
)

hub.debug( "** Loaded "..scriptname.."_"..scriptversion..".lua **" )

---------
--[END]--
---------